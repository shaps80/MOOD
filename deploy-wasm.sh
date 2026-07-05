#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="release"
PRODUCT="Sandbox"
SDK="swift-6.3.2-RELEASE_wasm"
PACKAGE_DIR=".build/deploy-wasm/package"
DIST_DIR="dist"
ASSETS_DIR="Game/assets"
ZIP_PATH="Pixl.zip"
ARGS=()

write_index_html() {
  local output_path="$1"

  cat > "${output_path}" <<'HTML'
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

copy_assets() {
  if [[ ! -d "${ASSETS_DIR}" ]]; then
    return
  fi

  mkdir -p "${DIST_DIR}/assets"
  cp -R "${ASSETS_DIR}/." "${DIST_DIR}/assets/"
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
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

rm -rf "${PACKAGE_DIR}" "${DIST_DIR}" "${ZIP_PATH}" "Pixl-itch.zip"
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
copy_assets
write_index_html "${DIST_DIR}/index.html"

(
  cd "${DIST_DIR}"
  zip -qr "../${ZIP_PATH}" .
)

echo
echo "Pixl Wasm package built."
echo "Configuration: ${CONFIGURATION}"
echo "Dist: ${DIST_DIR}/"
echo "Itch upload: ${ZIP_PATH}"
echo "Local URL: http://127.0.0.1:9999/"
