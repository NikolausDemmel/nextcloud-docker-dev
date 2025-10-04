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
```

### Viewing Logs

```bash
# Last 30 lines
docker compose exec -u 33 stable31 tail -n 30 /var/www/html/data/nextcloud.log

# Search for specific entries
docker compose exec -u 33 stable31 grep 'user_vo' /var/www/html/data/nextcloud.log
```

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

## References

- [nextcloud-docker-dev documentation](https://juliusknorr.github.io/nextcloud-docker-dev/)
- [Nextcloud Developer Portal](https://nextcloud.com/developer/)
- [Upstream repository](https://github.com/juliushaertl/nextcloud-docker-dev)
