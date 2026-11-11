#!/bin/sh
# One-time, optional: creates a self-signed code-signing identity in your login keychain
# so the Accessibility grant survives rebuilds. Without it, builds are ad-hoc signed and
# macOS treats every rebuild as a new app. The certificate never leaves this Mac and is
# not trusted for anything; remove it any time in Keychain Access ("CloseInMissionControl Local Signing").
set -eu
NAME="CloseInMissionControl Local Signing"
if security find-identity -p codesigning | grep -q "$NAME"; then
    echo "Identity already exists."; exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cfg" <<CFG
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CFG
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cfg" \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
    -out "$TMP/id.p12" -passout pass:local 2>/dev/null
security import "$TMP/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P local -T /usr/bin/codesign
echo "Created identity: $NAME"
