---
name: extract-cert-pins
description: >-
  Extract, generate, or rotate SSL/TLS certificate SPKI pins (the
  "sha256/..." values used for certificate pinning) for a hostname. Given a
  host, prints every certificate in the served chain — leaf, intermediate(s),
  and (best effort) root — each with its sha256 SPKI pin, expiry date and days
  remaining, subject CN, issuing CA, signature algorithm, and key type. Use
  when asked to get/refresh certificate pins, check a cert's expiry or CA, or
  update pinning config such as AppNetworkConfig.kt.
---

# extract-cert-pins

Compute the certificate pins and metadata for a live TLS host. This skill is
general-purpose: the hostname is the only input, and it reads **no** project
files.

## How to run

1. Get the **hostname** (and optional port) from the user's request. If none was
   given, ask for it — do not read any project source to guess it.
2. From the skill directory, run:

   ```bash
   bash scripts/extract-pins.sh <hostname> [port]
   ```

   Port defaults to `443`.

3. Relay the script's output. For each certificate it prints the role
   (leaf / intermediate / root), the `sha256/...` pin, validity window + days
   left, subject, issuer (CA), and key/signature algorithm.

## How it works

The script opens a TLS connection with `openssl s_client -showcerts`, splits the
served chain into individual certs, and for each computes the pin with the
canonical SubjectPublicKeyInfo pipeline:

```
openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

Servers normally do **not** send the root, so the script resolves it best-effort
from the local trust store (issuer-hash lookup, then CA-bundle subject match). If
the root can't be resolved locally it still prints the root's subject name and a
note explaining where to obtain it.

## When presenting results

- Highlight the **intermediate + root** pins as the stable choice for pinning —
  they survive the frequent leaf rotation (Let's Encrypt leaves rotate ~90 days).
- Surface any cert that is close to expiry.
- **Only print** the values. Do not edit `AppNetworkConfig.kt` or any other file;
  leave pasting the pins to the user.
