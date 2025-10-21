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

# --- FIX: Always log to both console and logfile ---
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

ssh_test_connectivity() {
    log "=== STEP 4: Testing SSH connectivity ==="
    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" "echo SSH_OK" >/dev/null 2>&1; then
        log "SSH connectivity OK"
    else
        die "SSH connection failed" 43
    fi
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
cat <<'NGINX' | sudo tee /etc/nginx/sites-available/default
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX
sudo nginx -t
sudo systemctl reload nginx
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
echo "Docker containers running:"
docker ps
echo "Testing app response..."
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:${APP_PORT}
EOF
    log "Validation complete — try visiting http://${SSH_HOST}"
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
