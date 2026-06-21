#!/usr/bin/env bash
set -euo pipefail

PORT=9999
URL="http://127.0.0.1:${PORT}/App/index.html"

swiftly run swift package --swift-sdk swift-6.3.2-RELEASE_wasm js --product MOOD --use-cdn

echo
echo "MOOD running at:"
echo "${URL}"
echo
echo "Press Ctrl-C to stop."

python3 -m http.server "${PORT}"
