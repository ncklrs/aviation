#!/bin/sh
# Compiles the Foundation-only Core sources with the Linux Swift toolchain and runs the logic checks.
# (The SwiftUI files only build in Xcode for tvOS.)
set -e
cd "$(dirname "$0")/.."
swiftc -O -o /tmp/overhead-tvos-check Overhead/Sources/Core/*.swift LinuxCheck/main.swift
/tmp/overhead-tvos-check "$(pwd)"
