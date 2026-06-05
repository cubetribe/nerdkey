# NerdKey L1 Walkthrough

This is the tested local operator path for NerdKey Phase L1.

## 1. Generate Local Secrets

```bash
scripts/init-env.sh
```

This creates ignored `.env` with local Keygen, Postgres, encryption, and admin bootstrap values.

## 2. Run Keygen Setup

```bash
docker compose --profile setup run --rm setup
```

This initializes the database, creates the Keygen account and admin user, and lets Keygen generate the account signing keys.

## 3. Start The Stack

```bash
docker compose up -d
docker compose ps
```

Expected services: `postgres`, `redis`, `web`, `worker`, and `caddy`.

## 4. Check Health

```bash
scripts/nerdkey health
```

Expected result: success with `null` output for the empty Keygen health body.

## 5. Create The Admin Token

```bash
scripts/nerdkey token issue --save
```

The token is stored only in ignored `.env`.

## 6. Apply Product Policy

```bash
scripts/nerdkey apply
scripts/nerdkey apply
```

The second run should update the same product and policy without creating duplicates.

## 7. Run The L1 Smoke Test

```bash
scripts/nerdkey smoke
```

Expected result: `PASS`. The flow creates a test license, activates two machines, validates one machine, rejects a third machine, lists licenses, and revokes the smoke license.

## 8. Print The Ed25519 Public Key

```bash
scripts/nerdkey account public-key
```

This prints the public key for future client-side verification. Private keys are never printed.

## 9. Create A Backup

```bash
scripts/backup-db.sh backups/nerdkey-$(date +%Y%m%d%H%M%S).dump
```

Backups are ignored by Git and should be treated as sensitive.

## 10. Restore When Needed

```bash
NERDKEY_RESTORE_CONFIRM=replace-local-db \
  scripts/restore-db.sh backups/nerdkey-example.dump
```

Restore is destructive by design and stops the app containers before replacing the local database.
