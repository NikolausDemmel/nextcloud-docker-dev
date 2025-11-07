# Nextcloud Docker Development Environment

This is a local development setup using [nextcloud-docker-dev](https://github.com/juliushaertl/nextcloud-docker-dev) for testing Nextcloud plugins across multiple Nextcloud versions.

⚠️ **DO NOT USE IN PRODUCTION** - Contains insecure settings and default credentials.

## Quick Reference

**For plugin development:** See this file
**For server/core development:** See `NEXTCLOUD-SERVER-DEV.md`
**For general plugin dev workflow:** See `nextcloud/nextcloud-plugin-development.md` in documentation repo

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

### Testing Plugin APIs

You can test plugin API endpoints directly using curl:

**Basic API Request Pattern:**
```bash
curl -H "OCS-APIRequest: true" -u admin:admin -X GET \
  http://stable31.local/apps/user_vo/admin/<endpoint>
```

**Examples for user_vo plugin:**

```bash
# Fetch all managed groups
curl -H "OCS-APIRequest: true" -u admin:admin -X GET \
  http://stable31.local/apps/user_vo/admin/fetch-managed-groups | jq '.'

# Test configuration
curl -H "OCS-APIRequest: true" -u admin:admin -X POST \
  http://stable31.local/apps/user_vo/admin/test-config \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.'
```

**Helper Script:**

A test script `test_api.sh` is available in the repository root for common operations.

**API Endpoints Reference:**

See `data/apps-extra/user_vo/appinfo/routes.php` for all available endpoints.

**Notes:**
- `OCS-APIRequest: true` header is required for Nextcloud API requests
- Default credentials are `admin:admin` (insecure dev setup)
- Use `jq` for JSON formatting and filtering
- POST endpoints typically require JSON body with `Content-Type: application/json`
- API responses are JSON format
- ⚠️ **IMPORTANT**: Include `/index.php/` in the URL path for POST requests to work correctly:
  - ✅ Correct: `http://stable31.local/index.php/apps/user_vo/admin/create-group`
  - ❌ Wrong: `http://stable31.local/apps/user_vo/admin/create-group` (returns 404)
  - GET requests may work without `/index.php/` but POST requests typically require it

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

**Notes:**
- Each Nextcloud version uses its own database (e.g., `stable31`, `stable30`)
- MySQL root password is `nextcloud` (insecure dev setup)
- The `-i` flag is required for restore (stdin redirect)
- Backups are stored on host filesystem and persist after container restarts

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
| Server code | `workspace/server` → `/var/www/html` | Edit locally, immediate effect (or rebuild if frontend) |
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

**Issue:** PHP generates frequent warnings if Blackfire service is not configured:

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

### Docker Compose PROTOCOL Warnings

**Issue:** Warnings when running docker compose commands:

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
- **Server/Core Development:** See `NEXTCLOUD-SERVER-DEV.md` in this repository
