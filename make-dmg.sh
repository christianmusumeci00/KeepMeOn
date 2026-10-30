#!/usr/bin/env bash
# Crea dist/KeepMeOn.dmg: app universale (Apple Silicon e Intel) più il collegamento
# alla cartella Applicazioni, pronta da trascinare. Usa build.sh per compilare e firmare.
#
# Con un certificato "Developer ID Application" e le credenziali di notarizzazione
# salvate nel portachiavi, fa notarizzare da Apple prima l'app e poi il DMG e allega
# a entrambi il ticket di notarizzazione: si aprono con un doppio clic, senza avvisi.
# Le credenziali si salvano una volta sola con:
#   xcrun notarytool store-credentials "KeepMeOn" --apple-id <ID Apple> --team-id <Team ID>
#   NOTARY_PROFILE=altro ./make-dmg.sh    usa un altro profilo; NOTARY_PROFILE= lo disattiva
set -euo pipefail

cd "$(dirname "$0")"

NOTARY_PROFILE="${NOTARY_PROFILE-KeepMeOn}"

UNIVERSAL=1 ./build.sh

APP="dist/KeepMeOn.app"
DMG="dist/KeepMeOn.dmg"
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")"
AUTHORITY="$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

# Invia un file al servizio di notarizzazione e attende l'esito.
notarize() {
    local result status
    result="$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
    status="$(plutil -extract status raw -o - - <<< "$result")"
    if [ "$status" != "Accepted" ]; then
        echo "✗ Notarizzazione non riuscita ($status). Dettagli:" >&2
        echo "  xcrun notarytool log $(plutil -extract id raw -o - - <<< "$result") --keychain-profile $NOTARY_PROFILE" >&2
        exit 1
    fi
}

NOTARIZE=0
case "$AUTHORITY" in
    "Developer ID Application:"*)
        if [ -n "$NOTARY_PROFILE" ] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" > /dev/null 2>&1; then
            NOTARIZE=1
        else
            echo "! Credenziali di notarizzazione \"$NOTARY_PROFILE\" non trovate: il DMG sarà firmato ma non notarizzato."
        fi
        ;;
esac

if [ "$NOTARIZE" = "1" ]; then
    echo "▸ Notarizzazione dell'app (qualche minuto)…"
    ditto -c -k --keepParent "$APP" "$STAGING/KeepMeOn.zip"
    notarize "$STAGING/KeepMeOn.zip"
    rm "$STAGING/KeepMeOn.zip"
    xcrun stapler staple -q "$APP"
fi

echo "▸ Creazione $DMG (KeepMeOn $VERSION)…"
mkdir "$STAGING/dmg"
cp -R "$APP" "$STAGING/dmg/"
ln -s /Applications "$STAGING/dmg/Applications"
rm -f "$DMG"
hdiutil create -volname "KeepMeOn $VERSION" -srcfolder "$STAGING/dmg" -fs HFS+ -format UDZO -quiet "$DMG"

# Il DMG prende la stessa firma dell'app; se l'app è ad-hoc resta senza firma.
if [ -n "$AUTHORITY" ]; then
    echo "▸ Firma del DMG con \"$AUTHORITY\"…"
    if [ "$NOTARIZE" = "1" ]; then
        codesign --force --sign "$AUTHORITY" --timestamp "$DMG"
    else
        codesign --force --sign "$AUTHORITY" --timestamp=none "$DMG"
    fi
fi
hdiutil verify -quiet "$DMG"

if [ "$NOTARIZE" = "1" ]; then
    echo "▸ Notarizzazione del DMG…"
    notarize "$DMG"
    xcrun stapler staple -q "$DMG"
    spctl --assess --type open --context context:primary-signature "$DMG"
    spctl --assess --type execute "$APP"
    echo "✓ App e DMG notarizzati: si aprono senza avvisi."
fi

echo "✓ Pronto: $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
