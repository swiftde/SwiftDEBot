/// Formats a duration like the `etime` field of `ps`: `[[DD-]HH:]MM:SS`.
func elapsedDescription(seconds: Int) -> String {
  let total = max(seconds, 0)
  let days = total / 86_400
  let hours = total % 86_400 / 3_600
  let minutes = total % 3_600 / 60

  func twoDigits(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }

  let clock = "\(twoDigits(minutes)):\(twoDigits(total % 60))"
  if days > 0 { return "\(days)-\(twoDigits(hours)):\(clock)" }
  if hours > 0 { return "\(twoDigits(hours)):\(clock)" }
  return clock
}
