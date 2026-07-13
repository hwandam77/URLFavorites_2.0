# URLFavorites 2.0 VPS Deployment Checklist

## Pre-Deploy
- [ ] Local changes are committed and pushed.
- [ ] `bin/deploy-doctor pre` passes.
- [ ] DNS: urlf.hwandam.kr points to the VPS.
- [ ] TLS: certificate configured.
- [ ] systemd drop-in contains:
  - `LLAMA_SERVER_URL=http://10.10.0.5:8282`
  - `PORT=3003`
  - `SOLID_QUEUE_IN_PUMA=1`
- [ ] Production DB exists and is not part of the deploy payload:
  - `storage/production.sqlite3`
  - `storage/production_queue.sqlite3`
- [ ] yt-dlp installed: `which yt-dlp`
- [ ] Ruby 3.4.x installed
- [ ] SQLite3 development headers installed

## Deploy Steps
1. `bin/deploy urlfavorites_2.0`
2. `bundle install --deployment`
3. `bin/rails db:prepare RAILS_ENV=production`
4. `bin/rails assets:precompile RAILS_ENV=production`
5. Restart application server

## Data Import (first deploy only)
- [ ] Backup urlf source DB
- [ ] Copy urlf.sqlite3 to VPS
- [ ] `bin/rails urlf:import URLF_SOURCE_DB_PATH=/path/to/urlf.sqlite3 RAILS_ENV=production`
- [ ] Verify row counts match

## Post-Deploy
- [ ] `bin/deploy-doctor post` passes.
- [ ] Service running: `systemctl status rails-puma@urlfavorites_2.0`
- [ ] No critical errors in logs
- [ ] Health check: `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3003/favorites`
- [ ] Public check: `curl -s -o /dev/null -w "%{http_code}" https://urlf.hwandam.kr/favorites`
- [ ] Test URL save flow
- [ ] Test search
- [ ] Test mobile share (PWA)

## Rollback
1. Stop application
2. Restore previous code version
3. Do not delete or replace `storage/*.sqlite3*`
4. `bin/rails db:rollback` only if a reversible migration was applied and the DB is backed up
5. Restart
