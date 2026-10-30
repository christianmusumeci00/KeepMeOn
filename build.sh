#!/usr/bin/env bash
# Compila KeepMeOn in release, assembla dist/KeepMeOn.app e lo firma.
#
# Firma: se nel portachiavi c'è un certificato "Apple Development" usa quello, così il
# permesso di Accessibilità resta valido tra una build e l'altra; altrimenti firma ad-hoc
# (macOS chiederà di nuovo il permesso dopo ogni build).
#   SIGN_IDENTITY=- ./build.sh            forza la firma ad-hoc
#   SIGN_IDENTITY="<nome o impronta>" ./build.sh   usa un certificato preciso
#   UNIVERSAL=1 ./build.sh                app universale (Apple Silicon e Intel)
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="KeepMeOn"
DIST_DIR="dist"
APP="$DIST_DIR/$APP_NAME.app"
PLIST="Support/Info.plist"

if [ -z "${SIGN_IDENTITY:-}" ]; then
    DEV_LINE="$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 '"Apple Development:' || true)"
    if [ -n "$DEV_LINE" ]; then
        # L'impronta SHA-1 evita ambiguità se esistono più certificati con lo stesso nome.
        SIGN_IDENTITY="$(echo "$DEV_LINE" | awk '{print $2}')"
        SIGN_LABEL="$(echo "$DEV_LINE" | sed 's/.*"\(.*\)".*/\1/')"
    else
        SIGN_IDENTITY="-"
    fi
fi
SIGN_LABEL="${SIGN_LABEL:-$SIGN_IDENTITY}"

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")"

ARCH_FLAGS=()
ARCH_LABEL=""
if [ "${UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
    ARCH_LABEL=", universale"
fi

echo "▸ Compilazione release ($APP_NAME $VERSION$ARCH_LABEL)…"
# `${ARCH_FLAGS[@]+…}`: il bash di macOS (3.2) con `set -u` rifiuta gli array vuoti.
swift build -c release --product "$APP_NAME" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

echo "▸ Assemblaggio $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$PLIST" "$APP/Contents/Info.plist"
# Icona: si rigenera con `swift Support/icon/make-icon.swift Support/AppIcon.icns`.
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
plutil -lint "$APP/Contents/Info.plist" > /dev/null

if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "▸ Firma ad-hoc (il permesso di Accessibilità andrà ridato dopo ogni build)…"
else
    echo "▸ Firma con \"$SIGN_LABEL\"…"
fi
codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP"
codesign --verify --strict "$APP"

echo "✓ Pronto: $APP"
echo "  Avvio:  open $APP"
