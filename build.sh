#!/usr/bin/env bash
set -euo pipefail

PORT=9999
URL="http://127.0.0.1:${PORT}/"
CONFIGURATION="release"
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
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if ((${#ARGS[@]})); then
  ./deploy-wasm.sh -c "${CONFIGURATION}" "${ARGS[@]}"
else
  ./deploy-wasm.sh -c "${CONFIGURATION}"
fi

echo
echo "MOOD running at:"
echo "${URL}"
echo "Configuration: ${CONFIGURATION}"
echo
echo "Press Ctrl-C to stop."

cd dist
python3 -m http.server "${PORT}"
