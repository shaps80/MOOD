#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="release"
PRODUCT=""
SDK="swift-6.3.2-RELEASE_wasm"
PACKAGE_DIR=".build/deploy-wasm/package"
HOST_MODULE_CACHE_DIR=".build/arm64-apple-macosx/debug/ModuleCache"
WASM_MODULE_CACHE_DIR=".build/wasm32-unknown-wasip1/${CONFIGURATION}/ModuleCache"
DIST_DIR=".dist"
ARGS=()

usage() {
  echo "Usage: ./deploy-wasm.sh <product> [-c configuration] [swift package js args...]" >&2
}

write_index_html() {
  local output_path="$1"

  cat > "${output_path}" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${PRODUCT}</title>
</head>
<body>
  <script type="module">
    import { init } from "./pixl.js";

    init();
  </script>
</body>
</html>
HTML
}

copy_target_resources() {
  local resource_paths=()

  while IFS= read -r resource_path; do
    resource_paths+=("${resource_path}")
  done < <(
    swiftly run swift package dump-package | python3 -c '
import json
import pathlib
import sys

data = json.load(sys.stdin)
product = sys.argv[1]
root = pathlib.Path(data["packageKind"]["root"][0])

for target in data["targets"]:
    if target["name"] != product:
        continue

    target_path = root / (target.get("path") or f"Sources/{product}")
    for resource in target.get("resources", []):
        print((target_path / resource["path"]).resolve())
    break
' "${PRODUCT}"
  )

  for resource_path in "${resource_paths[@]}"; do
    if [[ ! -e "${resource_path}" ]]; then
      echo "Missing resource: ${resource_path}" >&2
      exit 1
    fi

    cp -R "${resource_path}" "${DIST_DIR}/"
  done
}

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
  usage
  exit 64
fi

ZIP_PATH="${PRODUCT}.zip"
WASM_MODULE_CACHE_DIR=".build/wasm32-unknown-wasip1/${CONFIGURATION}/ModuleCache"

rm -rf "${PACKAGE_DIR}" "${HOST_MODULE_CACHE_DIR}" "${WASM_MODULE_CACHE_DIR}" "${DIST_DIR}" "${ZIP_PATH}" "${PRODUCT}-itch.zip"
mkdir -p "${PACKAGE_DIR}" "${DIST_DIR}"

if ((${#ARGS[@]})); then
  swiftly run swift package \
    --swift-sdk "${SDK}" \
    --allow-writing-to-package-directory \
    js \
    --product "${PRODUCT}" \
    -c "${CONFIGURATION}" \
    --debug-info-format none \
    --output "${PACKAGE_DIR}" \
    "${ARGS[@]}"
else
  swiftly run swift package \
    --swift-sdk "${SDK}" \
    --allow-writing-to-package-directory \
    js \
    --product "${PRODUCT}" \
    -c "${CONFIGURATION}" \
    --debug-info-format none \
    --output "${PACKAGE_DIR}"
fi

npm install --prefix "${PACKAGE_DIR}" --omit=dev
npx --yes esbuild "${PACKAGE_DIR}/index.js" \
  --bundle \
  --format=esm \
  --minify \
  --platform=browser \
  --legal-comments=none \
  --outfile="${DIST_DIR}/pixl.js"

cp "${PACKAGE_DIR}/${PRODUCT}.wasm" "${DIST_DIR}/${PRODUCT}.wasm"
copy_target_resources
write_index_html "${DIST_DIR}/index.html"

(
  cd "${DIST_DIR}"
  zip -qr "../${ZIP_PATH}" .
)

echo
echo "Pixl Wasm package built."
echo "Product: ${PRODUCT}"
echo "Configuration: ${CONFIGURATION}"
echo "Dist: ${DIST_DIR}/"
echo "Itch upload: ${ZIP_PATH}"
echo "Local URL: http://127.0.0.1:9999/"
