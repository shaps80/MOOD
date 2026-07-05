#!/usr/bin/env bash
set -euo pipefail

PORT=9999
URL="http://127.0.0.1:${PORT}/"
CONFIGURATION="release"
SDK="swift-6.3.2-RELEASE_wasm"
DIST_DIR=".dist"
PRODUCT=""
ARGS=()

while (($#)); do
  case "$1" in
    -c|--configuration)
      CONFIGURATION="${2:-release}"
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
    -p|--product)
      PRODUCT="${2:-}"
      shift 2
      ;;
    -p=*)
      PRODUCT="${1#-p=}"
      shift
      ;;
    --product=*)
      PRODUCT="${1#--product=}"
      shift
      ;;
    --)
      shift
      ARGS+=("$@")
      break
      ;;
    -*)
      ARGS+=("$1")
      shift
      ;;
    *)
      if [[ -z "${PRODUCT}" ]]; then
        PRODUCT="$1"
      else
        ARGS+=("$1")
      fi
      shift
      ;;
  esac
done

if [[ -z "${PRODUCT}" ]]; then
  swiftly run swift build \
    --scratch-path .build/wasm-pixl \
    --swift-sdk "${SDK}" \
    --target Pixl \
    -c "${CONFIGURATION}"
  exit 0
fi

if ((${#ARGS[@]})); then
  ./deploy-wasm.sh "${PRODUCT}" -c "${CONFIGURATION}" "${ARGS[@]}"
else
  ./deploy-wasm.sh "${PRODUCT}" -c "${CONFIGURATION}"
fi

echo
echo "Pixl running at:"
echo "${URL}"
echo "Product: ${PRODUCT}"
echo "Configuration: ${CONFIGURATION}"
echo
echo "Press Ctrl-C to stop."

python3 -m http.server "${PORT}" --directory "${DIST_DIR}"
