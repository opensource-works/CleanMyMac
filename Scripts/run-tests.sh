#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
TEST_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
TEST_LIBRARIES="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
BUILD_ROOT="$PROJECT_ROOT/.build/arm64-apple-macosx/debug"
TEST_BUNDLE="$BUILD_ROOT/CleanMyScreenPackageTests.xctest/Contents/MacOS/CleanMyScreenPackageTests"
RUNNER_ROOT="$(mktemp -d /tmp/cleanmyscreen-tests.XXXXXX)"
RUNNER="$RUNNER_ROOT/SwiftTestingBundleRunner"

cleanup() {
    rm -rf "$RUNNER_ROOT"
}
trap cleanup EXIT

cd "$PROJECT_ROOT"
swift test --enable-swift-testing --disable-xctest -j 2

swiftc \
    -parse-as-library \
    -F "$TEST_FRAMEWORKS" \
    -framework Testing \
    -Xlinker -rpath \
    -Xlinker "$TEST_FRAMEWORKS" \
    "$PROJECT_ROOT/Scripts/SwiftTestingBundleRunner.swift" \
    -o "$RUNNER"

CLEANMYSCREEN_TEST_BUNDLE="$TEST_BUNDLE" \
DYLD_FRAMEWORK_PATH="$TEST_FRAMEWORKS" \
DYLD_LIBRARY_PATH="$TEST_LIBRARIES" \
"$RUNNER"
