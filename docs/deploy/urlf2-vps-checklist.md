# URLFavorites 2.0 VPS Deployment Checklist

## Pre-Deploy
- [ ] DNS: urlf2.hwandam.kr A record points to VPS IP
- [ ] TLS: certificate configured (Let's Encrypt or similar)
- [ ] Environment variables set in .env:
  - LLAMA_SERVER_URL=http://<beacon-wg-ip>:<port>
  - RAILS_ENV=production
  - SECRET_KEY_BASE=<generated>
  - RAILS_MASTER_KEY=<generated>
- [ ] yt-dlp installed: `which yt-dlp`
- [ ] Ruby 3.4.x installed
- [ ] SQLite3 development headers installed

## Deploy Steps
1. `deploy urlfavorites` (rsync to VPS)
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
- [ ] Service running: check process manager
- [ ] No critical errors in logs
- [ ] Health check: curl https://urlf2.hwandam.kr/up
- [ ] Test URL save flow
- [ ] Test search
- [ ] Test mobile share (PWA)

## Rollback
1. Stop application
2. Restore previous code version
3. `bin/rails db:rollback` if migration was applied
4. Restart
