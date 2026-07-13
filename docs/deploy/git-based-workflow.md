# Git-Based Deployment Workflow

URLFavorites 2.0 uses this operating model:

- Develop and test on macOS.
- Commit and push every deployable change.
- Treat Git as the source of truth.
- Treat the VPS as a deployment target, not a development workspace.
- Use SSH for logs, service status, migrations, and emergency diagnosis only.

## Current VPS Facts

Verified on 2026-05-09:

- SSH host: `vps-server`
- App path: `/home/hwandam/services/rails/urlfavorites_2.0/`
- Service: `rails-puma@urlfavorites_2.0.service`
- Puma port: `3003`
- Rails health URL on VPS: `http://127.0.0.1:3003/favorites`
- Public URL: `https://urlf.hwandam.kr/favorites`
- Legacy `/ver2.0/*` nginx path redirects to the root path.
- Primary SQLite DB: `storage/production.sqlite3`
- Solid Queue SQLite DB: `storage/production_queue.sqlite3`

## Normal Flow

1. Develop on macOS.
2. Run the narrowest useful local checks, for example:
   - `bin/rails test`
   - `bin/rails tailwindcss:build`
   - `bin/rails assets:precompile`
3. Commit the change.
4. Push the branch.
5. Run `bin/deploy-doctor pre`.
6. Deploy with `bin/deploy urlfavorites_2.0` or `bin/deploy --quick urlfavorites_2.0`.
7. Run `bin/deploy-doctor post`.
8. Verify the public page in a browser.

## VPS Source Rules

Do not edit app source files directly under:

```text
/home/hwandam/services/rails/urlfavorites_2.0/
```

Do not delete, overwrite, or rsync-delete runtime SQLite files:

```text
/home/hwandam/services/rails/urlfavorites_2.0/storage/*.sqlite3*
/home/hwandam/services/rails/urlfavorites_2.0/db/*.sqlite3*
```

Any deploy script that uses `rsync --delete` must exclude at least:

```text
storage/
db/*.sqlite3*
log/
tmp/
```

If emergency SSH editing was unavoidable:

1. Copy the change back to the macOS repository.
2. Commit it locally.
3. Push it.
4. Restore the VPS checkout to a clean state through the deploy path.

## Deploy Doctor

`bin/deploy-doctor pre` fails when:

- local deployable source files have uncommitted or untracked changes,
- the local branch is not synced with its upstream,
- the VPS app path is missing,
- the VPS primary or queue DB is missing,
- the VPS checkout has source drift outside protected runtime DB/log/tmp paths.

`bin/deploy-doctor post` also fails when:

- the VPS HEAD does not match the local HEAD,
- the systemd service is not active,
- the local VPS health check is not HTTP 200,
- the public health check is not HTTP 200.

For diagnosis without failing the shell command, append `--report`:

```bash
bin/deploy-doctor pre --report
bin/deploy-doctor post --report
```

## Staging Target

`bin/deploy --environment staging urlfavorites_2.0` is intentionally blocked until
the staging target is explicitly configured. Define these before using it:

```bash
URLF_STAGING_REMOTE_PATH=/home/hwandam/services/rails/urlfavorites_2.0_staging
URLF_STAGING_SERVICE=rails-puma@urlfavorites_2.0-staging
URLF_STAGING_REMOTE_PORT=3001
URLF_STAGING_PUBLIC_URL=https://urlf.hwandam.kr/staging/favorites
```

The nginx route or staging subdomain must point to the same port before the
staging deploy command is allowed into normal use.
