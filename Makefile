update-version:
	swift Scripts/UpdateVersion.swift

build: update-version
	swift build --configuration release

.PHONY: update-version, build
