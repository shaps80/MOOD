#!/usr/bin/env bash
set -euo pipefail

PORT=9999
URL="http://127.0.0.1:${PORT}/App/index.html"
CONFIGURATION="debug"
ARGS=()

while (($#)); do
  case "$1" in
    -c|--configuration)
      CONFIGURATION="${2:-debug}"
      shift 2
      ;;
    -c=*)
      CONFIGURATION="${1#-c=}"
      shift
      ;;
    --configuration=*)
      CONFIGURATION="${1#--configuration=}"
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if ((${#ARGS[@]})); then
  swiftly run swift package --swift-sdk swift-6.3.2-RELEASE_wasm js --product MOOD --use-cdn -c "${CONFIGURATION}" "${ARGS[@]}"
else
  swiftly run swift package --swift-sdk swift-6.3.2-RELEASE_wasm js --product MOOD --use-cdn -c "${CONFIGURATION}"
fi

echo
echo "MOOD running at:"
echo "${URL}"
echo "Configuration: ${CONFIGURATION}"
echo
echo "Press Ctrl-C to stop."

python3 -m http.server "${PORT}"
