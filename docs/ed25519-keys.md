# Ed25519 Key Handling

NerdKey uses Keygen's Ed25519 signing support. Do not create a parallel custom signing system.

## How Keys Are Created

`docker compose --profile setup run --rm setup` runs Keygen's setup task. During account creation, Keygen generates account signing keys, including an Ed25519 keypair.

The private key is encrypted in the Keygen database using:

- `ENCRYPTION_DETERMINISTIC_KEY`
- `ENCRYPTION_PRIMARY_KEY`
- `ENCRYPTION_KEY_DERIVATION_SALT`

These values live only in `.env` or operator-managed secrets.

## Public Key

After the stack is running and `KEYGEN_ADMIN_TOKEN` has been saved:

```bash
scripts/nerdkey account public-key
```

For all account public keys:

```bash
scripts/nerdkey account public-key --json
```

The Ed25519 public key is safe to embed in future client apps. It is used to verify signed license artifacts locally.

## Private Key Rules

- Never commit private keys.
- Never commit `.env`.
- Never put signing keys on the public download/web server.
- Treat database backups as sensitive because the database contains encrypted signing material.
- Rotate secrets only as a deliberate operator procedure with tested backup/restore.

## License Files

Use Keygen checkout for signed offline/client artifacts:

```bash
scripts/nerdkey license checkout <license-id-or-key> \
  --output licenses/customer.lic.json
```

`licenses/` is ignored by Git.

## Why No Custom Crypto

Keygen already provides Ed25519 signed license keys/files and account key management. L1's job is to configure and operate that system safely, not to invent a Nerdsmiths-specific cryptographic format.
