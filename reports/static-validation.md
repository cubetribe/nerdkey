# Static Validation

Scope: NerdKey L1 Docker Compose stack, admin scripts, product registry, and docs.

## Result

PASS

## Checks

| Check | Result | Notes |
|-------|--------|-------|
| `python3 -m py_compile scripts/nerdkey.py` | PASS | CLI compiles. |
| `bash -n scripts/nerdkey scripts/init-env.sh scripts/backup-db.sh scripts/restore-db.sh` | PASS | Shell entrypoints parse. |
| `shellcheck scripts/nerdkey scripts/init-env.sh scripts/backup-db.sh scripts/restore-db.sh` | PASS | ShellCheck produced no findings. |
| `docker compose config --quiet` | PASS | Compose file renders cleanly. |

## Notes

- `__pycache__/` is ignored by Git.
- `.env`, backups, and generated license artifacts are ignored by Git.
- Restore was syntax-checked here; runtime restore is intentionally gated because it replaces the local database.
