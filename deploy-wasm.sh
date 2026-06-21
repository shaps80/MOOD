#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="debug"
PRODUCT="MOOD"
SDK="swift-6.3.2-RELEASE_wasm"
PACKAGE_DIR=".build/deploy-wasm/package"
DIST_DIR="dist"
ZIP_PATH="MOOD.zip"
ARGS=()

write_index_html() {
  local output_path="$1"

  cat > "${output_path}" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MOOD</title>
</head>
<body>
  <script type="module">
    import { init } from "./mood.js";

    init();
  </script>
</body>
</html>
HTML
}

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

rm -rf "${PACKAGE_DIR}" "${DIST_DIR}" "${ZIP_PATH}" "MOOD-itch.zip"
mkdir -p "${PACKAGE_DIR}" "${DIST_DIR}"

if ((${#ARGS[@]})); then
  swiftly run swift package \
    --swift-sdk "${SDK}" \
    --allow-writing-to-package-directory \
    js \
    --product "${PRODUCT}" \
    -c "${CONFIGURATION}" \
    --output "${PACKAGE_DIR}" \
    "${ARGS[@]}"
else
  swiftly run swift package \
    --swift-sdk "${SDK}" \
    --allow-writing-to-package-directory \
    js \
    --product "${PRODUCT}" \
    -c "${CONFIGURATION}" \
    --output "${PACKAGE_DIR}"
fi

npm install --prefix "${PACKAGE_DIR}" --omit=dev
npx --yes esbuild "${PACKAGE_DIR}/index.js" \
  --bundle \
  --format=esm \
  --minify \
  --platform=browser \
  --legal-comments=none \
  --outfile="${DIST_DIR}/mood.js"

cp "${PACKAGE_DIR}/${PRODUCT}.wasm" "${DIST_DIR}/${PRODUCT}.wasm"
write_index_html "${DIST_DIR}/index.html"

(
  cd "${DIST_DIR}"
  zip -qr "../${ZIP_PATH}" .
)

echo
echo "MOOD Wasm package built."
echo "Configuration: ${CONFIGURATION}"
echo "Dist: ${DIST_DIR}/"
echo "Itch upload: ${ZIP_PATH}"
echo "Local URL: http://127.0.0.1:9999/"
