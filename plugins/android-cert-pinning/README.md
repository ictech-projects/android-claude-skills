# android-cert-pinning

Extract the **SSL/TLS certificate SPKI pins** (`sha256/...`) and metadata for any host — the
values you paste into a `CertificatePinner` / `NetworkConfig`. Given a hostname, it prints the
full served chain (leaf → intermediate(s) → best-effort root), each with its `sha256/...` pin,
expiry + days remaining, subject, issuing CA, and key/signature algorithm.

Project-agnostic: the hostname is the only input; it reads no project files and edits nothing.

## Install

```text
/plugin marketplace add ictech-projects/android-claude-skills
/plugin install android-cert-pinning@android-skills
```

Requires `openssl` on your PATH.

## Use

```text
/android-cert-pinning:extract-cert-pins wallet.birchlabs.tech       # pins for a host
/android-cert-pinning:extract-cert-pins example.com 8443            # non-default port
/android-cert-pinning:extract-cert-pins                            # prompts for a host
```

## What's inside

| Part | Purpose |
|---|---|
| `SKILL.md` | Entry point: how to run and how to present the results |
| `scripts/extract-pins.sh` | `openssl` pipeline — fetch chain, compute SPKI pins, print metadata |

The pin is the canonical SubjectPublicKeyInfo hash:

```
openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

## Notes

- Pin the **intermediate + root** — they survive frequent leaf rotation (Let's Encrypt leaves
  rotate ~90 days).
- Servers don't send the root; it's resolved best-effort from the local trust store. If it
  can't be found locally, the script prints the root's subject and a note instead of failing.
- Output only — it never edits `AppNetworkConfig.kt` or any other file.
