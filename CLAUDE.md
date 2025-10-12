# Nextcloud Docker Development Environment

This is a local development setup using [nextcloud-docker-dev](https://github.com/juliushaertl/nextcloud-docker-dev) for testing Nextcloud plugins across multiple Nextcloud versions.

⚠️ **DO NOT USE IN PRODUCTION** - Contains insecure settings and default credentials.

## Repository Structure

```
nextcloud-docker-dev/
├── workspace/
│   ├── server/          # Main Nextcloud server (master branch)
│   ├── stable26/        # Nextcloud 26 worktree
│   ├── stable30/        # Nextcloud 30 worktree
│   └── stable31/        # Nextcloud 31 worktree
├── data/
│   ├── apps-extra/      # Custom apps mounted into containers
│   ├── shared/          # Files shared with containers (/shared inside)
│   └── ssl/             # SSL certificates
├── docker-compose.yml   # Service definitions
└── config_stable*.php   # Reference config files (NOT mounted)
```

## Quick Start

### Starting Containers

Start a specific Nextcloud version:
```bash
docker compose up stable26
# or in background:
docker compose up -d stable31
```

Access instances at:
- `http://stable26.local` (admin/admin)
- `http://stable30.local` (admin/admin)
- `http://stable31.local` (admin/admin)

### Accessing Containers

Open shell as www-data user (UID 33):
```bash
docker compose exec -u 33 stable31 bash
```

### Common OCC Commands

```bash
# Check status and version
docker compose exec -u 33 stable31 php occ status

# User management
docker compose exec -u 33 stable31 php occ user:list
docker compose exec -u 33 stable31 php occ user:info <username>

# App management
docker compose exec -u 33 stable31 php occ app:list
docker compose exec -u 33 stable31 php occ app:enable user_vo
docker compose exec -u 33 stable31 php occ app:disable user_vo

# Clear caches
docker compose exec -u 33 stable31 php occ maintenance:repair

# Background jobs (cron)
docker compose exec -u 33 stable31 php occ background:job:list
docker compose exec -u 33 stable31 php occ background:job:execute <job-id>
docker compose exec -u 33 stable31 php occ background:job:execute <job-id> --force-execute

# App config (key-value storage)
docker compose exec -u 33 stable31 php occ config:app:get user_vo <key>
docker compose exec -u 33 stable31 php occ config:app:set user_vo <key> --value="<value>"
docker compose exec -u 33 stable31 php occ config:app:delete user_vo <key>
```

### Viewing Logs

```bash
# Last 30 lines
docker compose exec -u 33 stable31 tail -n 30 /var/www/html/data/nextcloud.log

# Search for specific entries
docker compose exec -u 33 stable31 grep 'user_vo' /var/www/html/data/nextcloud.log

# Follow logs in real-time
docker compose exec -u 33 stable31 tail -f /var/www/html/data/nextcloud.log

# Filter for specific app
docker compose exec -u 33 stable31 tail -f /var/www/html/data/nextcloud.log | grep 'user_vo'
```

### Log Level Configuration

Nextcloud supports multiple log levels (0=Debug, 1=Info, 2=Warning, 3=Error, 4=Fatal). For plugin development, you often need debug-level logging.

**View current log level:**
```bash
docker compose exec -u 33 stable31 php occ config:system:get loglevel
```

**Set log level to Debug (0) for development:**
```bash
docker compose exec -u 33 stable31 php occ config:system:set loglevel --value=0 --type=integer
```

**Reset to Warning (2) for normal use:**
```bash
docker compose exec -u 33 stable31 php occ config:system:set loglevel --value=2 --type=integer
```

**Log Levels:**
- `0` - **Debug**: Verbose output, includes all debug statements from plugins
- `1` - **Info**: Informational messages (still quite verbose)
- `2` - **Warning**: Default level, only warnings and errors
- `3` - **Error**: Only errors and fatal issues
- `4` - **Fatal**: Only fatal errors

**Development Best Practices:**
- Use Debug (0) when actively debugging a feature
- Use Warning (2) for normal development work
- Be aware that Debug level can generate large log files quickly
- Consider filtering logs by app name to reduce noise: `tail -f nextcloud.log | grep 'user_vo'`
- Changes take effect immediately (no restart needed)

## Plugin Development

### App Directory Structure

The setup uses multiple app directories with different purposes:

**Host → Container Mounts:**
```
data/apps-extra/           → /var/www/html/apps-shared     (shared custom apps)
workspace/stable31/apps-extra/ → /var/www/html/apps-extra   (version-specific apps)
```

**Inside Container:**
- `/var/www/html/apps` - Core Nextcloud apps (read-only)
- `/var/www/html/apps-extra` - Version-specific custom apps from worktree (usually empty)
- `/var/www/html/apps-shared` - Shared custom apps across all versions (this is where `data/apps-extra/` is mounted)
- `/var/www/html/apps-writable` - Apps installed via Nextcloud UI (writable)

**Key Points:**
- Place your custom plugins in `data/apps-extra/` on the host
- They appear at `/var/www/html/apps-shared/` in the container
- Changes to plugin code take effect immediately (no restart needed unless opcode cache interferes)
- After modifying `docker-compose.yml`, always recreate containers: `docker compose up -d --force-recreate stable31`

**Verify Plugin Location:**
```bash
# Check where Nextcloud found your plugin
docker compose exec -u 33 stable31 php occ app:getpath user_vo
# Should return: /var/www/html/apps-shared/user_vo

# List all app directories
docker compose exec -u 33 stable31 php occ config:system:get apps_paths
```

### Code Changes

- Plugin code in `data/apps-extra/` is mounted to `/var/www/html/apps-shared` and changes take effect immediately
- No container restart needed (unless opcode cache interferes)

### Configuration Management

⚠️ **IMPORTANT**: `config_stable*.php` files are **NOT mounted** into containers!

The actual config is in Docker volumes at `/var/www/html/config/config.php` inside each container.

**Note:** You may find `config_stable*.php` files in the repository root - these are reference files used to copy configuration in/out of containers during testing. They are gitignored and not part of the running setup.

#### Editing Configuration

**Option 1: Edit inside container (recommended)**
```bash
docker compose exec stable31 vi /var/www/html/config/config.php
```

**Option 2: Using OCC commands**
```bash
# View config
docker compose exec stable31 php occ config:list system

# Set value
docker compose exec stable31 php occ config:system:set some_key --value "value"
```

**Option 3: Copy, edit, copy back**
```bash
# Get container name first
docker ps | grep stable31

# Copy out, edit, copy back
docker cp master-stable31-1:/var/www/html/config/config.php ./temp_config.php
vim ./temp_config.php
docker cp ./temp_config.php master-stable31-1:/var/www/html/config/config.php
rm ./temp_config.php
```

Changes take effect immediately - no restart needed.

### Background Jobs (Cron)

Nextcloud uses background jobs for scheduled tasks. In development, you can manage and test them manually:

**List all background jobs:**
```bash
docker compose exec -u 33 stable31 php occ background:job:list
```

**Execute a specific job (waits for next scheduled time):**
```bash
docker compose exec -u 33 stable31 php occ background:job:execute <job-id>
```

**Force execute immediately:**
```bash
docker compose exec -u 33 stable31 php occ background:job:execute <job-id> --force-execute
```

**Example - Testing nightly sync for user_vo plugin:**
```bash
# 1. Find the job ID
docker compose exec -u 33 stable31 php occ background:job:list | grep SyncUsersJob

# 2. Enable nightly sync (if not already)
docker compose exec -u 33 stable31 php occ config:app:set user_vo enable_nightly_sync --value="true"

# 3. Force execute the job
docker compose exec -u 33 stable31 php occ background:job:execute 206 --force-execute

# 4. Check execution status
docker compose exec -u 33 stable31 php occ config:app:get user_vo nightly_sync_last_status
docker compose exec -u 33 stable31 php occ config:app:get user_vo nightly_sync_last_run
docker compose exec -u 33 stable31 php occ config:app:get user_vo nightly_sync_last_summary

# 5. Disable again if needed
docker compose exec -u 33 stable31 php occ config:app:set user_vo enable_nightly_sync --value="false"
```

**Notes:**
- Background jobs run automatically in production via system cron
- In development, Nextcloud's AJAX/webcron executes jobs periodically
- Use `--force-execute` to bypass the schedule and run immediately
- Job execution times and results are logged in Nextcloud logs

### App Configuration (Key-Value Storage)

Many plugins use Nextcloud's app config system for settings. You can inspect and modify these via OCC:

**Get a config value:**
```bash
docker compose exec -u 33 stable31 php occ config:app:get user_vo <key>
```

**Set a config value:**
```bash
docker compose exec -u 33 stable31 php occ config:app:set user_vo <key> --value="<value>"
```

**Delete a config value:**
```bash
docker compose exec -u 33 stable31 php occ config:app:delete user_vo <key>
```

**List all config for an app:**
```bash
docker compose exec -u 33 stable31 php occ config:list user_vo
```

**Common user_vo config keys:**
- `api_url`, `api_username`, `api_password` - API credentials
- `sync_email`, `sync_photo` - Sync settings
- `enable_nightly_sync` - Background job toggle
- `nightly_sync_last_run`, `nightly_sync_last_status`, `nightly_sync_last_summary` - Execution tracking

## Adding New Nextcloud Versions

To create a test environment for a new Nextcloud version:

```bash
# Create worktree
cd workspace/server
git fetch origin
git worktree add ../stable30 stable30
cd ../stable30
git submodule update --init --recursive

# Add to /etc/hosts
sudo sh -c "echo '127.0.0.1 stable30.local' >> /etc/hosts"

# Start container (define in docker-compose.yml first)
docker compose up -d stable30
```

## Updating the Environment

### Update to Latest Nextcloud Patch Version

```bash
# Update repositories
git pull
cd workspace/server
git pull
git submodule update --init --recursive

# Pull latest Docker images (specific services to avoid failures)
docker compose pull proxy redis database-mysql stable26 stable30 stable31
# Or pull all and ignore individual failures:
# docker compose pull --ignore-pull-failures

# Recreate and upgrade
docker compose up -d --force-recreate --remove-orphans stable26
docker compose exec -u 33 stable26 php occ upgrade
```

**Note on Rootless Docker:** If using rootless Docker, configure the Docker socket path in `.env`:
```bash
# Replace "1000" with your Docker UID (usually $(id -u))
DOCKER_SOCKET=/run/user/1000/docker.sock
```

## Database Backup & Restore

Useful for testing database migrations or other destructive operations.

### Backup Database

```bash
# Backup specific database (e.g., stable31)
docker compose exec database-mysql mysqldump -u root -pnextcloud stable31 > backup_stable31.sql

# Backup all databases
docker compose exec database-mysql mysqldump -u root -pnextcloud --all-databases > backup_all.sql
```

### Restore Database

```bash
# Restore specific database
docker compose exec -i database-mysql mysql -u root -pnextcloud stable31 < backup_stable31.sql

# Restore all databases
docker compose exec -i database-mysql mysql -u root -pnextcloud < backup_all.sql
```

### Testing Migrations Safely

```bash
# 1. Create backup before migration
docker compose exec database-mysql mysqldump -u root -pnextcloud stable31 > backup_before_migration.sql

# 2. Test migration (e.g., enable plugin with new migration)
docker compose exec -u 33 stable31 php occ app:enable user_vo
docker compose exec -u 33 stable31 php occ migrations:status user_vo

# 3. If migration fails or you want to revert:
docker compose exec -i database-mysql mysql -u root -pnextcloud stable31 < backup_before_migration.sql
docker compose exec -u 33 stable31 php occ maintenance:repair

# 4. Try migration again after fixing issues
docker compose exec -u 33 stable31 php occ app:enable user_vo
```

**Notes:**
- Each Nextcloud version uses its own database (e.g., `stable31`, `stable30`)
- Each version also has its own data volume (user files, created timestamps, etc.)
- MySQL root password is `nextcloud` (insecure dev setup)
- The `-i` flag is required for restore (stdin redirect)
- Backups are stored on host filesystem and persist after container restarts
- Database restore restores: user accounts, settings, shares, permissions
- Database restore does NOT restore: user files, data directory timestamps

### Backup Data Volume (User Files)

For a complete backup including user files and created timestamps:

```bash
# 1. Get the data volume name for your version
VOLUME_NAME=$(docker inspect master-stable31-1 --format '{{range .Mounts}}{{if eq .Destination "/var/www/html/data"}}{{.Name}}{{end}}{{end}}')

# 2a. Full backup (includes profiler data and old logs, ~250MB)
docker run --rm \
  -v $VOLUME_NAME:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/stable31_data_full.tar.gz -C /data .

# 2b. Clean backup (excludes profiler and old logs, ~110MB - recommended)
docker run --rm \
  -v $VOLUME_NAME:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/stable31_data_clean.tar.gz \
    --exclude='__profiler' \
    --exclude='*.log.*' \
    --exclude='*.log.bak' \
    -C /data .
```

**What gets excluded:**
- **Full backup (244MB):** Nothing (complete snapshot)
- **Clean backup (110MB):** `__profiler` directory (~150MB profiling data), old log files (~170MB)

**What's in the 110MB clean backup:**
- User files (~100MB): Welcome files, demo PDFs, user data (5 users × ~20MB)
- App data (~22MB): Cached files, previews, temporary data
- Database files, configs, current logs (~minimal)

### Restore Data Volume

```bash
# 1. Stop the container first
docker compose stop stable31

# 2. Restore the data volume (with -p to preserve permissions)
VOLUME_NAME=$(docker inspect master-stable31-1 --format '{{range .Mounts}}{{if eq .Destination "/var/www/html/data"}}{{.Name}}{{end}}{{end}}')
docker run --rm \
  -v $VOLUME_NAME:/data \
  -v $(pwd)/backups/2025-10-05_stable31_baseline_before_user_sync:/backup \
  alpine sh -c "cd /data && rm -rf * .* 2>/dev/null; tar xzpf /backup/stable31_baseline_data_clean.tar.gz"

# 3. Restart the container
docker compose up -d stable31
```

⚠️ **Known limitation:** Directory timestamps may not be fully preserved during restore due to Alpine tar behavior.
For testing database migrations, database-only backup/restore is usually sufficient.

### Complete Backup/Restore (Database + Files)

For testing migrations that might affect both database and files:

```bash
# === BACKUP ===
# Database
docker compose exec database-mysql mysqldump -u root -pnextcloud stable31 > backup_db.sql

# Data volume
VOLUME_NAME=$(docker inspect master-stable31-1 --format '{{range .Mounts}}{{if eq .Destination "/var/www/html/data"}}{{.Name}}{{end}}{{end}}')
docker run --rm -v $VOLUME_NAME:/data -v $(pwd):/backup alpine tar czf /backup/backup_data.tar.gz -C /data .

# === RESTORE ===
# Database
docker compose exec -i database-mysql mysql -u root -pnextcloud stable31 < backup_db.sql

# Data volume (stop container first!)
docker compose stop stable31
docker run --rm -v $VOLUME_NAME:/data -v $(pwd):/backup alpine sh -c "cd /data && tar xzf /backup/backup_data.tar.gz"
docker compose up -d stable31

# Verify
docker compose exec -u 33 stable31 php occ status
```

**What gets backed up:**
- **Database:** User accounts, settings, app config, shares, permissions, groups
- **Data volume:** User files, avatars, app data, logs, created/modified timestamps

**Performance notes:**
- Database backup: ~500KB, takes <1 second
- Data volume backup: ~250MB, takes ~5-10 seconds (depends on user files)
- For migration testing, database-only backup is usually sufficient

## Testing Plugin Releases

To test a built appstore package locally:

```bash
# 1. Temporarily disable volume mount in docker-compose.yml
# 2. Recreate container
docker compose up -d --force-recreate stable31

# 3. Copy package to shared directory
cp path/to/user_vo.tar.gz data/shared/

# 4. Extract and enable
docker compose exec stable31 tar -xzf /shared/user_vo.tar.gz -C /var/www/html/apps/
docker compose exec stable31 php occ app:enable user_vo

# 5. Test functionality, then clean up
docker compose exec stable31 php occ app:disable user_vo
docker compose exec stable31 rm -rf /var/www/html/apps/user_vo

# 6. Restore volume mount and recreate
docker compose up -d --force-recreate stable31
```

## Architecture Notes

### What's Mounted vs What's Not

| Component | Location | How to Change |
|-----------|----------|---------------|
| Plugin code | `data/apps-extra/` → `/var/www/html/apps-shared` | Edit locally, immediate effect |
| Configuration | Docker volume → `/var/www/html/config/config.php` | Edit inside container |
| Server code | `workspace/server` → `/var/www/html` | Edit locally, immediate effect |
| User data | Docker volume → `/var/www/html/data` | Persisted across restarts |

### Available Services

The docker-compose setup includes:
- Multiple Nextcloud versions (stable16-31, master)
- Databases: MySQL, PostgreSQL, MariaDB, SQLite
- Redis cache
- Nginx proxy with SSL support
- LDAP, Keycloak for authentication testing
- Mailhog for testing emails
- Collabora, OnlyOffice for document editing
- Blackfire, Xdebug for profiling/debugging

## Troubleshooting

### Blackfire Warnings

**Issue:** The development environment includes Blackfire profiling support, but the published Docker images have Blackfire enabled by default (even though the repository Dockerfile disables it). If the Blackfire service is not configured or running, PHP generates frequent warnings in logs:

```
php_network_getaddresses: getaddrinfo for blackfire failed: Name or service not known
```

**Temporary fix (persists until container recreate):**

```bash
# Use the provided script to disable Blackfire
./scripts/php-mod-config stable31 blackfire off

# Verify extension is disabled (should return empty)
docker compose exec stable31 php -m | grep -i blackfire
```

**To re-enable Blackfire later:**

```bash
./scripts/php-mod-config stable31 blackfire on
```

**Important:** This fix does NOT persist when you recreate containers with `docker compose up -d --force-recreate`. You'll need to run the disable command again after recreation.

**Permanent solution:** This is a known issue with the published Docker images. See upstream issue: https://github.com/juliusknorr/nextcloud-docker-dev/issues/421

### Docker Compose PROTOCOL Warnings

**Issue:** When running docker compose commands, you may see warnings like:

```
level=warning msg="The \"PROTOCOL\" variable is not set. Defaulting to a blank string."
```

**Fix:** Add the PROTOCOL variable to your `.env` file:

```bash
echo 'PROTOCOL=http' >> .env
```

This suppresses the warnings. Use `https` if you've configured SSL certificates.

## References

- [nextcloud-docker-dev documentation](https://juliusknorr.github.io/nextcloud-docker-dev/)
- [Nextcloud Developer Portal](https://nextcloud.com/developer/)
- [Upstream repository](https://github.com/juliushaertl/nextcloud-docker-dev)
