#!/usr/bin/env bash
# deploy.sh - Production-grade Bash script to deploy a Dockerized application to a remote Linux server.
# Requirements: bash, ssh, scp/rsync, git, printf, tar, date
# Usage: ./deploy.sh          (interactive mode)
#        ./deploy.sh -cleanup (optional: cleanup deployed resources)
set -o errexit
set -o nounset
set -o pipefail

####################
# Global variables #
####################
LOGDIR="./logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOGFILE="${LOGDIR}/deploy_${TIMESTAMP}.log"
export LANG=C

# Ensure uppercase for global vars per guidelines
REPO_URL=""
PAT=""
BRANCH="main"
SSH_USER=""
SSH_HOST=""
SSH_KEY=""
APP_PORT=""
CLEANUP_MODE=0
# Derived globals
REPO_NAME=""
PROJECT_DIR=""
REMOTE_BASE="/home/ubuntu/deployments"
REMOTE_PROJECT_DIR=""
CONTAINER_NAME=""
USE_DOCKER_COMPOSE=0

####################
# Utility functions#
####################
mkdir -p "$LOGDIR"

# --- Enhanced Error Handling with Trap ---
cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        err "Script failed with exit code $exit_code"
        err "Check logs at: $LOGFILE"
    fi
}

trap cleanup_on_error EXIT ERR
trap 'err "Script interrupted by user"; exit 130' INT TERM

# --- Logging fixes ---
exec > >(tee -a "$LOGFILE") 2>&1

timestamp() {
    printf "%s" "$(date +%Y-%m-%dT%H:%M:%S%z)"
}

log() {
    printf "%s [INFO] %s\n" "$(timestamp)" "$1"
}

err() {
    printf "%s [ERROR] %s\n" "$(timestamp)" "$1" >&2
}

die() {
    local msg="$1"
    local code="${2:-1}"
    err "$msg"
    exit "$code"
}

safe_read() {
    local __var="$1"; shift
    local __prompt="$1"; shift || true
    local __hidden="${1:-0}"
    local __input
    if [[ "$__hidden" -eq 1 ]]; then
        stty -echo
        printf "%s" "$__prompt"
        IFS= read -r __input || true
        stty echo
        printf "\n"
    else
        printf "%s" "$__prompt"
        IFS= read -r __input || true
    fi
    eval "$__var=\"\${__input}\""
    return 0
}

sanitize_repo_url() {
    local __url="$1"
    printf "%s" "$__url" | sed -E 's#(https?://)[^@]+@#\1[REDACTED]@#g'
}

validate_ssh_key() {
    local __key="$1"
    if [[ ! -f "$__key" ]]; then
        err "SSH key not found at $__key"
        return 1
    fi
    if [[ ! -r "$__key" ]]; then
        err "SSH key at $__key is not readable"
        return 1
    fi
    # Enhanced: Check key permissions
    local perms
    perms=$(stat -c %a "$__key" 2>/dev/null || stat -f %A "$__key" 2>/dev/null || echo "")
    if [[ -n "$perms" ]] && [[ "$perms" != "600" ]] && [[ "$perms" != "400" ]]; then
        err "Warning: SSH key permissions should be 600 or 400 (currently: $perms)"
    fi
    return 0
}

ensure_command() {
    local __cmd="$1"
    if ! command -v "$__cmd" >/dev/null 2>&1; then
        err "Required command '$__cmd' not found in PATH"
        return 1
    fi
    return 0
}

####################
# Input collection #
####################
collect_inputs_interactive() {
    printf "\n"
    log "=== STEP 1: Collecting input parameters ==="
    safe_read REPO_URL "Git repository URL (HTTPS): "
    if [[ -z "${REPO_URL:-}" ]]; then
        die "Repository URL is required" 2
    fi
    safe_read PAT "Personal Access Token (PAT) - input hidden: " 1
    if [[ -z "${PAT:-}" ]]; then
        die "PAT is required" 3
    fi
    safe_read BRANCH "Branch (default: main): "
    if [[ -z "${BRANCH}" ]]; then
        BRANCH="main"
    fi
    safe_read SSH_USER "Remote SSH username: "
    safe_read SSH_HOST "Remote SSH host (IP or domain): "
    safe_read SSH_KEY "SSH key path (absolute or relative): "
    SSH_KEY="${SSH_KEY/#\~/$HOME}"
    validate_ssh_key "$SSH_KEY" || die "SSH key validation failed" 7
    safe_read APP_PORT "Application internal container port (e.g., 3000): "
    [[ -z "${APP_PORT}" ]] && die "Application port is required" 8

    REPO_NAME="$(basename -s .git "$REPO_URL")"
    PROJECT_DIR="./${REPO_NAME}"
    CONTAINER_NAME="${REPO_NAME}_svc"
    REMOTE_PROJECT_DIR="${REMOTE_BASE}/${REPO_NAME}"

    log "Collected inputs: repo=$(sanitize_repo_url "$REPO_URL"), branch=$BRANCH, ssh=${SSH_USER}@${SSH_HOST}, project_dir=$PROJECT_DIR, app_port=$APP_PORT"
    return 0
}

parse_args() {
    if [[ "${1:-}" == "-cleanup" ]]; then
        CLEANUP_MODE=1
    fi
}

####################
# Git operations   #
####################
git_auth_url() {
    local __url="$1"
    local __clean
    __clean="$(printf "%s" "$__url" | sed -E 's#https?://([^/@]+@)?##')"
    printf "https://%s@%s" "$PAT" "$__clean"
}

clone_or_update_repo() {
    log "=== STEP 2: Clone or Update Repository ==="
    local __url="$1"
    local __branch="$2"
    local __dest="$3"
    local __auth
    __auth="$(git_auth_url "$__url")"
    if [[ -d "$__dest/.git" ]]; then
        log "Repository exists locally at $__dest. Pulling latest changes..."
        (cd "$__dest" && git fetch --all --prune && git checkout "$__branch" && git pull --ff-only origin "$__branch") || die "git pull failed"
        log "Repository updated"
        return 0
    fi
    git clone --branch "$__branch" --single-branch "$__auth" "$__dest" || die "git clone failed"
    (cd "$__dest" && git remote set-url origin "$REPO_URL")
    log "Repository cloned successfully"
}

check_project_files() {
    log "=== STEP 3: Checking project Docker setup ==="
    local __dest="$1"
    if [[ -f "${__dest}/Dockerfile" ]]; then
        log "Dockerfile found"
    elif [[ -f "${__dest}/docker-compose.yml" ]] || [[ -f "${__dest}/docker-compose.yaml" ]]; then
        log "docker-compose.yml found"
        USE_DOCKER_COMPOSE=1
    else
        die "Neither Dockerfile nor docker-compose.yml found" 1
    fi
}

####################
# Remote utilities #
####################
ssh_cmd_base() {
    printf "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -i %s %s@%s" "$SSH_KEY" "$SSH_USER" "$SSH_HOST"
}

ssh_run() {
    local __cmd="$1"
    log "[REMOTE] Running: ${__cmd}"
    eval "$(ssh_cmd_base)" "\"${__cmd}\""
}

# Enhanced SSH connectivity check with retries
ssh_test_connectivity() {
    log "=== STEP 4: Testing SSH connectivity ==="
    local max_retries=3
    local retry_count=0
    local wait_time=5
    
    while [[ $retry_count -lt $max_retries ]]; do
        if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" "echo SSH_OK" >/dev/null 2>&1; then
            log "✅ SSH connectivity verified successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [[ $retry_count -lt $max_retries ]]; then
                log "⚠️  SSH connection attempt $retry_count failed. Retrying in ${wait_time}s..."
                sleep "$wait_time"
            fi
        fi
    done
    
    die "❌ SSH connection failed after $max_retries attempts" 43
}

rsync_project_to_remote() {
    log "=== STEP 5: Transferring project to remote ==="
    local __src="$1"
    local __dest="$2"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" "mkdir -p '${__dest}'"
    rsync -az -e "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=accept-new" --delete --exclude '.git' "$__src"/ "${SSH_USER}@${SSH_HOST}:${__dest}/"
    log "Project transferred successfully"
}

####################
# Remote prep      #
####################
remote_prepare_environment() {
    log "=== STEP 6: Preparing remote environment (Docker, Nginx) ==="
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" bash << 'REMOTE_SETUP'
set -e
echo "Updating system..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
if ! command -v docker-compose >/dev/null; then
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi
if ! command -v nginx >/dev/null; then
  sudo apt-get install -y nginx
fi
# --- Docker group fix ---
sudo groupadd -f docker
sudo usermod -aG docker \$USER || true
newgrp docker <<'EOF'
echo "User added to docker group"
EOF
sudo systemctl enable docker nginx
sudo systemctl start docker nginx
echo "Remote setup complete."
REMOTE_SETUP
    log "Remote environment prepared"
}

####################
# Deploy app       #
####################
remote_deploy_application() {
    log "=== STEP 7: Deploying Dockerized Application ==="
    local __dir="$1"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" bash <<EOF
set -e
cd "$__dir"
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
    docker rm -f "${CONTAINER_NAME}" || true
fi
if [[ "${USE_DOCKER_COMPOSE}" == "1" ]]; then
    docker compose down || true
    docker compose up -d --build
else
    docker build -t "${CONTAINER_NAME}:latest" .
    docker run -d --name "${CONTAINER_NAME}" -p ${APP_PORT}:${APP_PORT} --restart unless-stopped "${CONTAINER_NAME}:latest"
fi
EOF
    log "Application deployed successfully"
}

####################
# Nginx config     #
####################
remote_configure_nginx() {
    log "=== STEP 8: Configuring Nginx Reverse Proxy ==="
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" bash <<EOF
set -e
# Create timestamped backup
BACKUP_FILE="/etc/nginx/sites-available/default.bak_\$(date +%s)"
if [[ -f /etc/nginx/sites-available/default ]]; then
    sudo cp /etc/nginx/sites-available/default "\$BACKUP_FILE"
    echo "Backup created at: \$BACKUP_FILE"
fi

# Create comprehensive Nginx configuration
cat <<'NGINX' | sudo tee /etc/nginx/sites-available/default
server {
    listen 80;
    listen [::]:80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Logging
    access_log /var/log/nginx/${CONTAINER_NAME}_access.log;
    error_log /var/log/nginx/${CONTAINER_NAME}_error.log;
    
    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint (optional)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

# SSL/HTTPS server block (commented out - enable when certificate is ready)
# server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#     server_name _;
#     
#     ssl_certificate /etc/ssl/certs/your_cert.pem;
#     ssl_certificate_key /etc/ssl/private/your_key.pem;
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers HIGH:!aNULL:!MD5;
#     
#     location / {
#         proxy_pass http://127.0.0.1:${APP_PORT};
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto \$scheme;
#     }
# }
NGINX

echo "Testing Nginx configuration..."
sudo nginx -t

echo "Reloading Nginx..."
sudo systemctl reload nginx

echo "Nginx configured successfully ✅"
EOF
    log "Nginx configured and reloaded"
}

####################
# Validation       #
####################
validate_deployment() {
    log "=== STEP 9: Validating Deployment ==="
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" bash <<EOF
set -e

echo "================================================"
echo "🔍 DEPLOYMENT VALIDATION REPORT"
echo "================================================"

# 1. Check Docker service status
echo ""
echo "📦 Docker Service Status:"
if systemctl is-active --quiet docker; then
    echo "   ✅ Docker service is running"
    docker --version || echo "   ⚠️  Could not get Docker version"
else
    echo "   ❌ Docker service is NOT running"
    exit 1
fi

# 2. Check container status
echo ""
echo "🐳 Container Status:"
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
    echo "   ✅ Container '${CONTAINER_NAME}' is running"
    
    # Get container details
    CONTAINER_STATUS=\$(docker inspect --format='{{.State.Status}}' ${CONTAINER_NAME})
    echo "   Status: \$CONTAINER_STATUS"
    
    # Check health if healthcheck is defined
    if docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME} &>/dev/null; then
        HEALTH_STATUS=\$(docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME})
        echo "   Health: \$HEALTH_STATUS"
    else
        echo "   Health: No healthcheck defined"
    fi
    
    # Show container uptime
    STARTED_AT=\$(docker inspect --format='{{.State.StartedAt}}' ${CONTAINER_NAME})
    echo "   Started: \$STARTED_AT"
else
    echo "   ❌ Container '${CONTAINER_NAME}' is NOT running"
    echo "   Checking if container exists but stopped..."
    docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}"
fi

# 3. Check Nginx service status
echo ""
echo "🌐 Nginx Service Status:"
if systemctl is-active --quiet nginx; then
    echo "   ✅ Nginx service is running"
    nginx -v 2>&1 | sed 's/^/   /' || true
else
    echo "   ❌ Nginx service is NOT running"
    exit 1
fi

# 4. Check Nginx configuration
echo ""
echo "⚙️  Nginx Configuration Test:"
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "   ✅ Nginx configuration is valid"
else
    echo "   ❌ Nginx configuration has errors"
    sudo nginx -t 2>&1 | sed 's/^/   /'
fi

# 5. Check if app is responding on the port
echo ""
echo "🔌 Application Port Check:"
if netstat -tuln 2>/dev/null | grep -q ":${APP_PORT} " || ss -tuln 2>/dev/null | grep -q ":${APP_PORT} "; then
    echo "   ✅ Application is listening on port ${APP_PORT}"
else
    echo "   ⚠️  Could not verify port ${APP_PORT} (netstat/ss may not be available)"
fi

# 6. Test local HTTP connection
echo ""
echo "🌍 Local HTTP Test:"
if command -v curl >/dev/null 2>&1; then
    HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:${APP_PORT} || echo "000")
    if [[ "\$HTTP_CODE" =~ ^[23] ]]; then
        echo "   ✅ Application responding (HTTP \$HTTP_CODE)"
    else
        echo "   ⚠️  Unexpected response (HTTP \$HTTP_CODE)"
    fi
else
    echo "   ⚠️  curl not available for HTTP test"
fi

echo ""
echo "================================================"
echo "✅ VALIDATION COMPLETE"
echo "================================================"
EOF
    log "Validation complete — try visiting http://${SSH_HOST}"
}

####################
# Cleanup          #
####################
remote_cleanup() {
    log "=== CLEANUP: Removing deployed resources ==="
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" bash <<EOF
set -e
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
    docker rm -f "${CONTAINER_NAME}" || true
fi
if [[ "${USE_DOCKER_COMPOSE}" == "1" ]]; then
    cd "${REMOTE_PROJECT_DIR}" || true
    docker compose down || true
fi
rm -rf "${REMOTE_PROJECT_DIR}"
EOF
    if [[ -d "$PROJECT_DIR" ]]; then
        rm -rf "$PROJECT_DIR"
        log "Local project directory removed"
    fi
    log "✅ Cleanup complete"
}

####################
# Main flow        #
####################
main() {
    echo "============================================="
    echo "🚀 DevOps Automated Deployment Script Started"
    echo "============================================="
    parse_args "${@:-}"
    ensure_command git || die "git required"
    ensure_command rsync || die "rsync required"
    ensure_command ssh || die "ssh required"
    ensure_command curl || die "curl required"

    collect_inputs_interactive

    # Run cleanup if requested
    if [[ "$CLEANUP_MODE" -eq 1 ]]; then
        remote_cleanup
        exit 0
    fi

    clone_or_update_repo "$REPO_URL" "$BRANCH" "$PROJECT_DIR"
    check_project_files "$PROJECT_DIR"
    ssh_test_connectivity
    remote_prepare_environment "$REMOTE_PROJECT_DIR"
    rsync_project_to_remote "$PROJECT_DIR" "$REMOTE_PROJECT_DIR"
    remote_deploy_application "$REMOTE_PROJECT_DIR"
    remote_configure_nginx "$REMOTE_PROJECT_DIR"
    validate_deployment "$REMOTE_PROJECT_DIR"

    echo "============================================="
    echo "✅ Deployment completed successfully!"
    echo "Logs saved at: $LOGFILE"
    echo "============================================="
}

main "$@"