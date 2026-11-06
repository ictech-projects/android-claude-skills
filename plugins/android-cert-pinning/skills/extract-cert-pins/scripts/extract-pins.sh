#!/usr/bin/env bash
#
# extract-pins.sh — print SHA-256 SPKI pins + metadata for a host's TLS chain.
#
# Usage: extract-pins.sh <hostname> [port]
#
# For every certificate in the chain (leaf, intermediate(s), and — best effort —
# the root) it prints:
#   * the "sha256/<base64>" SubjectPublicKeyInfo pin (ready for cert pinning)
#   * expiry (notAfter) with days remaining, plus notBefore
#   * subject CN and issuer (the CA)
#   * signature algorithm and public-key type/size (the "mechanism")
#
# It reads no project files; the hostname is the only required input.

set -euo pipefail

HOST="${1:-}"
PORT="${2:-443}"

if [[ -z "$HOST" ]]; then
  echo "usage: extract-pins.sh <hostname> [port]" >&2
  exit 2
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "error: openssl not found on PATH" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# ---------------------------------------------------------------------------
# 1. Fetch the served chain (leaf + whatever intermediates the server sends).
# ---------------------------------------------------------------------------
chain="$(openssl s_client -connect "${HOST}:${PORT}" -servername "${HOST}" \
           -showcerts </dev/null 2>/dev/null || true)"

if ! grep -q "BEGIN CERTIFICATE" <<<"$chain"; then
  echo "error: no certificates returned for ${HOST}:${PORT}" >&2
  echo "       (host unreachable, wrong port, or not a TLS endpoint)" >&2
  exit 1
fi

# Split the PEM blocks into numbered files: cert-01.pem, cert-02.pem, ...
awk -v dir="$tmpdir" '
  /-----BEGIN CERTIFICATE-----/ { n++; f = sprintf("%s/cert-%02d.pem", dir, n) }
  n > 0 { print > f }
' <<<"$chain"

# ---------------------------------------------------------------------------
# 2. Best-effort root resolution.
#    Roots are normally NOT served, so look up the top served cert's issuer in
#    the local trust store. If found, append it as the last cert.
# ---------------------------------------------------------------------------
served_count="$(ls "$tmpdir"/cert-*.pem 2>/dev/null | wc -l | tr -d ' ')"
root_note=""
top_cert="$(ls "$tmpdir"/cert-*.pem | sort | tail -n 1)"

# If the top served cert is already self-signed it IS the root; nothing to do.
top_subject="$(openssl x509 -in "$top_cert" -noout -subject 2>/dev/null | sed 's/^subject=//')"
top_issuer="$(openssl x509 -in "$top_cert" -noout -issuer 2>/dev/null | sed 's/^issuer=//')"

if [[ "$top_subject" != "$top_issuer" ]]; then
  issuer_hash="$(openssl x509 -in "$top_cert" -noout -issuer_hash 2>/dev/null || true)"
  ca_dir="$(openssl version -d 2>/dev/null | sed 's/^OPENSSLDIR: //; s/"//g')/certs"
  found_root=""

  # 2a. Hashed cert dir (e.g. Homebrew OpenSSL): <hash>.0
  if [[ -n "$issuer_hash" && -f "${ca_dir}/${issuer_hash}.0" ]]; then
    found_root="${ca_dir}/${issuer_hash}.0"
  fi

  # 2b. Concatenated CA bundle: split it and match by subject == top's issuer.
  if [[ -z "$found_root" ]]; then
    for bundle in "${SSL_CERT_FILE:-}" \
                  "$(openssl version -d 2>/dev/null | sed 's/^OPENSSLDIR: //; s/"//g')/cert.pem" \
                  /etc/ssl/cert.pem /etc/ssl/certs/ca-certificates.crt \
                  /etc/pki/tls/certs/ca-bundle.crt; do
      [[ -n "$bundle" && -f "$bundle" ]] || continue
      awk -v dir="$tmpdir" '
        /-----BEGIN CERTIFICATE-----/ { m++; bf = sprintf("%s/ca-%04d.pem", dir, m) }
        m > 0 { print > bf }
      ' "$bundle"
      for ca in "$tmpdir"/ca-*.pem; do
        [[ -e "$ca" ]] || break
        ca_subj="$(openssl x509 -in "$ca" -noout -subject 2>/dev/null | sed 's/^subject=//')"
        if [[ "$ca_subj" == "$top_issuer" ]]; then
          # Copy out before we delete the split bundle below.
          cp "$ca" "$tmpdir/root.pem"
          found_root="$tmpdir/root.pem"
          break
        fi
      done
      rm -f "$tmpdir"/ca-*.pem
      [[ -n "$found_root" ]] && break
    done
  fi

  if [[ -n "$found_root" ]]; then
    cp "$found_root" "$(printf '%s/cert-%02d.pem' "$tmpdir" $((served_count + 1)))"
    root_resolved=1
  else
    root_resolved=0
    root_note="Root CA not served and not found in the local trust store.
  Root (trust anchor) subject: ${top_issuer}
  Obtain its certificate from your CA bundle to pin it."
  fi
else
  root_resolved=1  # top served cert is self-signed → already the root
fi

# ---------------------------------------------------------------------------
# 3. Print each certificate's pin + metadata.
# ---------------------------------------------------------------------------
now_epoch="$(date +%s)"
total="$(ls "$tmpdir"/cert-*.pem 2>/dev/null | wc -l | tr -d ' ')"

spki_pin() {
  openssl x509 -in "$1" -pubkey -noout \
    | openssl pkey -pubin -outform der 2>/dev/null \
    | openssl dgst -sha256 -binary \
    | openssl enc -base64
}

# notAfter (portable): try GNU date, fall back to BSD/macOS date.
expiry_epoch() {
  local d="$1"
  date -d "$d" +%s 2>/dev/null || date -j -f "%b %e %T %Y %Z" "$d" +%s 2>/dev/null || echo ""
}

echo "TLS certificate chain for ${HOST}:${PORT}"
echo "==========================================================================="

i=0
for cert in $(ls "$tmpdir"/cert-*.pem | sort); do
  i=$((i + 1))

  # role
  if [[ "$i" -eq 1 ]]; then
    role="leaf"
  elif [[ "$i" -eq "$total" && "${root_resolved:-0}" -eq 1 ]]; then
    role="root"
  else
    role="intermediate"
  fi

  subject="$(openssl x509 -in "$cert" -noout -subject | sed 's/^subject=//')"
  issuer="$(openssl x509 -in "$cert" -noout -issuer | sed 's/^issuer=//')"
  not_before="$(openssl x509 -in "$cert" -noout -startdate | sed 's/^notBefore=//')"
  not_after="$(openssl x509 -in "$cert" -noout -enddate | sed 's/^notAfter=//')"
  sig_algo="$(openssl x509 -in "$cert" -noout -text | grep -m1 'Signature Algorithm' | sed 's/.*Signature Algorithm: //')"
  key_info="$(openssl x509 -in "$cert" -noout -text | grep -m1 'Public-Key:' | sed 's/.*Public-Key: //')"
  pin="$(spki_pin "$cert")"

  exp_epoch="$(expiry_epoch "$not_after")"
  if [[ -n "$exp_epoch" ]]; then
    days_left=$(( (exp_epoch - now_epoch) / 86400 ))
    expiry_line="${not_after}  (${days_left} days left)"
  else
    expiry_line="${not_after}"
  fi

  echo
  echo "[$i] ${role}"
  echo "  pin      : sha256/${pin}"
  echo "  subject  : ${subject}"
  echo "  issuer   : ${issuer}"
  echo "  valid    : ${not_before}  ->  ${expiry_line}"
  echo "  key/algo : ${key_info:-unknown} / ${sig_algo:-unknown}"
done

if [[ -n "$root_note" ]]; then
  echo
  echo "note: ${root_note}"
fi

echo
echo "Tip: pin the intermediate + root — they survive leaf rotation (~90 days for LE)."
