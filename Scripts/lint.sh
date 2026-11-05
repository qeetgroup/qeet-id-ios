#!/bin/sh
# swift-format, the one that ships with Xcode, over every Swift folder: what CI runs.
# Pass --fix to rewrite the files in place instead of reporting.
set -eu
cd "$(dirname "$0")/.."
folders="Core Shared QeetID AutoFill NotificationService QeetIDTests QeetIDUITests"
if [ "${1:-}" = "--fix" ]; then
    # shellcheck disable=SC2086
    xcrun swift-format format --in-place --recursive $folders
else
    # shellcheck disable=SC2086
    xcrun swift-format lint --strict --recursive $folders
fi
