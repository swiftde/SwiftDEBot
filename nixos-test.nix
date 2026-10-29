{ self }:
{
  name = "swiftdebot";

  nodes.machine = {
    imports = [ self.nixosModules.default ];

    virtualisation.memorySize = 1024;

    # A plain file rather than a store path, so the test script can swap its
    # contents for the missing-token case.
    environment.etc."swiftdebot.env" = {
      mode = "0400";
      text = ''
        DISCORD_TOKEN=vm-test-token
        DISCORD_APP_ID=123456789
        KAGI_API_TOKEN=vm-test-kagi
      '';
    };

    services.swiftdebot = {
      enable = true;
      environmentFile = "/etc/swiftdebot.env";
    };
  };

  testScript = ''
    def show(prop):
        return machine.succeed(f"systemctl show -p {prop} --value swiftdebot").strip()

    # Polls in one shell call so a restart between reading the PID and
    # inspecting /proc cannot make the check flaky.
    running_pid = 'pid=$(systemctl show -p MainPID --value swiftdebot); [ "$pid" != 0 ]'

    machine.wait_for_unit("multi-user.target")

    with subtest("unit waits for the network to be online"):
        assert "network-online.target" in show("After")
        assert "network-online.target" in show("Wants") + " " + show("Requires")

    with subtest("unit starts with a dummy environment file"):
        machine.wait_for_unit("swiftdebot.service")
        machine.wait_until_succeeds(running_pid)

    with subtest("bot runs as a non-root user"):
        machine.wait_until_succeeds(
            running_pid + """ && [ "$(awk '/^Uid:/ {print $2}' /proc/$pid/status)" != 0 ]"""
        )

    with subtest("values from the environment file reach the process"):
        for var in [
            "DISCORD_TOKEN=vm-test-token",
            "DISCORD_APP_ID=123456789",
            "KAGI_API_TOKEN=vm-test-kagi",
        ]:
            machine.wait_until_succeeds(
                running_pid + f" && tr '\\0' '\\n' < /proc/$pid/environ | grep -qx '{var}'"
            )

    with subtest("unit restarts the bot after the process dies"):
        machine.wait_until_succeeds(running_pid)
        old_pid = show("MainPID")
        machine.succeed(f"kill -KILL {old_pid}")
        machine.wait_until_succeeds(running_pid + f' && [ "$pid" != {old_pid} ]')
        machine.wait_for_unit("swiftdebot.service")

    with subtest("missing token makes the bot exit instead of hanging"):
        machine.succeed(
            "rm /etc/swiftdebot.env",
            "printf 'DISCORD_APP_ID=123456789\\n' > /etc/swiftdebot.env",
            "chmod 0400 /etc/swiftdebot.env",
        )
        machine.execute("systemctl restart swiftdebot")
        started = show("ExecMainStartTimestampMonotonic")
        # ExecMainCode 1 is CLD_EXITED: the bot ended on its own with a
        # failing status, rather than being killed by a signal.
        machine.wait_until_succeeds(
            f'[ "$(systemctl show -p ExecMainExitTimestampMonotonic --value swiftdebot)" -ge {started} ]'
            ' && [ "$(systemctl show -p ExecMainCode --value swiftdebot)" = 1 ]'
            ' && [ "$(systemctl show -p ExecMainStatus --value swiftdebot)" != 0 ]',
            timeout=120,
        )
  '';
}
