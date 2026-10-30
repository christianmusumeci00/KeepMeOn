#!/usr/bin/env bash
# Crea dist/KeepMeOn.dmg: app universale (Apple Silicon e Intel) più il collegamento
# alla cartella Applicazioni, pronta da trascinare. Usa build.sh per compilare e firmare.
set -euo pipefail

cd "$(dirname "$0")"

UNIVERSAL=1 ./build.sh

APP="dist/KeepMeOn.app"
DMG="dist/KeepMeOn.dmg"
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")"

echo "▸ Creazione $DMG (KeepMeOn $VERSION)…"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "KeepMeOn $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -quiet "$DMG"

# Il DMG prende la stessa firma dell'app; se l'app è ad-hoc resta senza firma.
AUTHORITY="$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
if [ -n "$AUTHORITY" ]; then
    echo "▸ Firma del DMG con \"$AUTHORITY\"…"
    codesign --force --sign "$AUTHORITY" --timestamp=none "$DMG"
fi
hdiutil verify -quiet "$DMG"

echo "✓ Pronto: $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
