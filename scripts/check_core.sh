#!/usr/bin/env bash
# runs the tests of the calculation package, needs Xcode
set -euo pipefail
cd "$(dirname "$0")/../Core"
swift test
