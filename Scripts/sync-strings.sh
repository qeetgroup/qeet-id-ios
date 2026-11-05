#!/bin/sh
# Brings each target's String Catalog up to date with the strings in its code, as Xcode does when it builds in the
# IDE: builds for the simulator, then runs `xcstringstool sync` over the .stringsdata the compiler extracted.
# New keys are added in English (their source text); keys no longer in the code are marked stale.
set -eu
cd "$(dirname "$0")/.."
derived="${DERIVED_DATA:-.build/strings}"
destination="${DESTINATION:-generic/platform=iOS Simulator}"
xcodebuild build -project QeetID.xcodeproj -scheme QeetID -destination "$destination" -derivedDataPath "$derived" -quiet

sync() { # target catalog
    dir=$(find "$derived/Build/Intermediates.noindex" -type d -name "$1.build" -path "*iphonesimulator*" | head -1)
    find "$dir" -name "*.stringsdata" > "$derived/$1.stringsdata.list"
    # shellcheck disable=SC2046
    xcrun xcstringstool sync "$2" $(sed 's/^/--stringsdata /' "$derived/$1.stringsdata.list")
    echo "$2: $(xcrun xcstringstool print "$2" | grep -c '^')" lines
}
sync QeetID QeetID/Resources/Localizable.xcstrings
sync QeetIDAutoFill AutoFill/Localizable.xcstrings
sync QeetIDNotificationService NotificationService/Localizable.xcstrings
