#!/usr/bin/env bash
# Create a stable, self-signed code-signing identity so macOS TCC ties the Input Monitoring
# grant to a persistent identity instead of the ad-hoc cdhash (which changes on EVERY rebuild,
# silently revoking the grant). Run once; bundle_app.sh then signs with it on every build, and
# the user grants Input Monitoring exactly once.
#
# This is a LOCAL developer identity with no security value — the keychain password below is not
# a secret. Idempotent: re-running is a no-op once the identity exists.
set -euo pipefail
CERT_NAME="ClawPet Dev"
KC_NAME="clawpet-signing.keychain-db"
KC="${HOME}/Library/Keychains/${KC_NAME}"
KC_PW="clawpet"

# Guard MUST NOT use `-v` (valid): a self-signed cert is untrusted, so `-v` never lists it and
# the guard would create a duplicate every run — duplicates make `codesign -s NAME` ambiguous.
if security find-identity -p codesigning "$KC" 2>/dev/null | grep -q "$CERT_NAME"; then
  echo "signing identity '$CERT_NAME' already present — nothing to do"
  exit 0
fi

TMP="$(mktemp -d)"
cat > "${TMP}/x.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = ${CERT_NAME}
[v3]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF
openssl req -x509 -newkey rsa:2048 -nodes -keyout "${TMP}/k.pem" -out "${TMP}/c.pem" \
  -days 3650 -config "${TMP}/x.cnf" >/dev/null 2>&1
# -legacy: openssl 3.x defaults to a PKCS12 MAC/cipher that macOS `security import` cannot read;
# the legacy (SHA1/3DES) encoding is required for the import to verify.
openssl pkcs12 -export -legacy -inkey "${TMP}/k.pem" -in "${TMP}/c.pem" -out "${TMP}/id.p12" \
  -passout pass:"${KC_PW}" -name "${CERT_NAME}" >/dev/null 2>&1

# Dedicated keychain with a known password -> fully non-interactive, never touches login.keychain.
security create-keychain -p "${KC_PW}" "${KC_NAME}" 2>/dev/null || true
security set-keychain-settings "${KC}"                 # disable auto-lock timeout
security unlock-keychain -p "${KC_PW}" "${KC}"
security import "${TMP}/id.p12" -k "${KC}" -P "${KC_PW}" -T /usr/bin/codesign -T /usr/bin/security
# Let codesign use the private key without a GUI prompt.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${KC_PW}" "${KC}" >/dev/null 2>&1 || true
# Add to the user search list so codesign / find-identity can see it (preserve existing entries).
EXISTING="$(security list-keychains -d user | sed -e 's/^[[:space:]]*//' -e 's/"//g')"
# shellcheck disable=SC2086
security list-keychains -d user -s "${KC}" ${EXISTING} 2>/dev/null || true

echo "created signing identity '${CERT_NAME}' in ${KC_NAME}"
# Note: `find-identity -v` (valid) will NOT list this — a self-signed cert isn't "trusted" — but
# codesign can still sign with it by name, and that's all we need. Verify without the -v filter.
security find-identity -p codesigning "${KC}" | grep -q "$CERT_NAME" \
  || { echo "ERROR: identity not found in ${KC_NAME}"; exit 1; }
echo "OK — bundle_app.sh will now sign with '${CERT_NAME}'."
