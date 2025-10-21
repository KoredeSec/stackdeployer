```bash
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
REMOTE_BASE="/opt/deployments"
REMOTE_PROJECT_DIR=""
CONTAINER_NAME=""
USE_DOCKER_COMPOSE=0

####################
# Utility functions#
####################
mkdir -p "$LOGDIR"
# redirect stdout/stderr to logfile and console
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
    # safe_read varname prompt hidden_flag(optional)
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
    # assign to caller variable
    eval "$__var=\"\${__input}\""
    return 0
}

sanitize_repo_url() {
    # strip credentials for logs
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
    log "Collecting input parameters..."
    safe_read REPO_URL "Git repository URL (HTTPS) : "
    if [[ -z "${REPO_URL:-}" ]]; then
        die "Repository URL is required" 2
    fi
    safe_read PAT "Personal Access Token (PAT) - input hidden: " 1
    if [[ -z "${PAT:-}" ]]; then
        die "PAT is required to authenticate with the Git server" 3
    fi
    safe_read BRANCH "Branch (default: main): "
    if [[ -z "${BRANCH}" ]]; then
        BRANCH="main"
    fi
    safe_read SSH_USER "Remote SSH username: "
    if [[ -z "${SSH_USER}" ]]; then
        die "SSH username required" 4
    fi
    safe_read SSH_HOST "Remote SSH host (IP or domain): "
    if [[ -z "${SSH_HOST}" ]]; then
        die "SSH host required" 5
    fi
    safe_read SSH_KEY "SSH key path (absolute or relative): "
    if [[ -z "${SSH_KEY}" ]]; then
        die "SSH key path is required" 6
    fi
    # expand ~
    SSH_KEY="${SSH_KEY/#\~/$HOME}"
    if ! validate_ssh_key "$SSH_KEY"; then
        die "SSH key validation failed" 7
    fi
    safe_read APP_PORT "Application internal container port (e.g., 3000): "
    if [[ -z "${APP_PORT}" ]]; then
        die "Application port is required" 8
    fi
    # Derive repo name
    REPO_NAME="$(basename -s .git "$REPO_URL")"
    if [[ -z "$REPO_NAME" ]]; then
        die "Could not derive repository name from URL" 9
    fi
    PROJECT_DIR="./${REPO_NAME}"
    CONTAINER_NAME="${REPO_NAME}_svc"
    REMOTE_PROJECT_DIR="${REMOTE_BASE}/${REPO_NAME}"
    log "Collected inputs: repo=$(sanitize_repo_url "$REPO_URL"), branch=$BRANCH, ssh=${SSH_USER}@${SSH_HOST}, project_dir=$PROJECT_DIR, app_port=$APP_PORT"
    return 0
}

parse_args() {
    # supports -cleanup flag; otherwise interactive
    if [[ "${1:-}" == "-cleanup" ]]; then
        CLEANUP_MODE=1
    fi
}

####################
# Git operations   #
####################
git_auth_url() {
    # returns HTTPS URL with PAT embedded (for cloning). Avoid logging real token.
    local __url="$1"
    # if url already contains auth, strip
    local __clean
    __clean="$(printf "%s" "$__url" | sed -E 's#https?://([^/@]+@)?##')"
    printf "https://%s@%s" "$PAT" "$__clean"
}

clone_or_update_repo() {
    local __url="$1"
    local __branch="$2"
    local __dest="$3"
    local __auth
    __auth="$(git_auth_url "$__url")"
    if [[ -d "$__dest/.git" ]]; then
        log "Repository exists locally at $__dest. Pulling latest changes..."
        if ! (cd "$__dest" && git fetch --all --prune); then
            err "git fetch failed"
            return 1
        fi
        if ! (cd "$__dest" && git checkout "$__branch"); then
            err "git checkout $__branch failed"
            return 2
        fi
        if ! (cd "$__dest" && git pull --ff-only origin "$__branch"); then
            err "git pull failed (non-fast-forward or other issue)"
            return 3
        fi
        log "Repository updated to latest on branch $__branch"
        return 0
    fi

    log "Cloning repository into $__dest (branch: $__branch)..."
    if ! git clone --branch "$__branch" --single-branch "$__auth" "$__dest"; then
        err "git clone failed"
        return 4
    fi
    # remove PAT from git remote URL for local config to avoid storing token
    if ! (cd "$__dest" && git remote set-url origin "$(printf "%s" "$REPO_URL")"); then
        err "failed to sanitize remote URL in cloned repo"
        return 5
    fi
    log "Repository cloned successfully"
    return 0
}

check_project_files() {
    local __dest="$1"
    if [[ -f "${__dest}/Dockerfile" ]]; then
        log "Dockerfile found"
    elif [[ -f "${__dest}/docker-compose.yml" ]] || [[ -f "${__dest}/docker-compose.yaml" ]]; then
        log "docker-compose.yml found"
        USE_DOCKER_COMPOSE=1
    else
        err "Neither Dockerfile nor docker-compose.yml found in project"
        return 1
    fi
    return 0
}

####################
# Remote utilities #
####################
ssh_cmd_base() {
    printf "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -i %s %s@%s" "$SSH_KEY" "$SSH_USER" "$SSH_HOST"
}

ssh_run() {
    # usage: ssh_run "commands..."
    local __cmd="$1"
    local __ssh
    __ssh="$(ssh_cmd_base)"
    log "Running remote command: ${__cmd}"
    if ! eval "${__ssh} \"${__cmd}\""; then
        err "Remote command failed"
        return 1
    fi
    return 0
}

ssh_test_connectivity() {
    local __ssh
    __ssh="$(ssh_cmd_base)"
    log "Testing SSH connectivity to ${SSH_USER}@${SSH_HOST}"
    if ! eval "${__ssh} 'echo SSH_OK'"; then
        err "SSH connectivity test failed"
        return 1
    fi
    log "SSH connectivity verified"
    return 0
}

rsync_project_to_remote() {
    local __src="$1"
    local __dest="$2"
    log "Transferring project files to remote: $__src -> ${SSH_USER}@${SSH_HOST}:${__dest}"
    # Create remote dir first
    local __ssh
    __ssh="$(ssh_cmd_base)"
    if ! eval "${__ssh} 'mkdir -p \"${__dest}\" && chown ${SSH_USER}:${SSH_USER} \"${__dest}\"'"; then
        err "Failed to create remote directory ${__dest}"
        return 1
    fi
    # Use rsync for efficient transfers
    if ! rsync -az -e "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=accept-new" --delete --exclude '.git' "$__src"/ "${SSH_USER}@${SSH_HOST}:${__dest}/"; then
        err "rsync failed"
        return 2
    fi
    log "Project files transferred successfully"
    return 0
}

####################
# Remote prep      #
####################
remote_prepare_environment() {
    local __remote_dir="$1"
    # This function composes a remote shell script and executes it
    local __cmd
    # Install Docker, Docker Compose plugin, nginx; works for Debian/Ubuntu (common case)
    __cmd=$(cat <<'REMOTE_SCRIPT'
set -o errexit
set -o nounset
set -o pipefail
export DEBIAN_FRONTEND=noninteractive
log(){ printf "%s [REMOTE-INFO] %s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" "$1"; }
err(){ printf "%s [REMOTE-ERROR] %s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" "$1" >&2; }
# Update packages
log "Updating package lists"
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release software-properties-common apt-transport-https
else
    log "Non-apt system detected; attempting yum/dnf"
    if command -v yum >/dev/null 2>&1; then
        yum makecache -y || true
        yum install -y curl
    elif command -v dnf >/dev/null 2>&1; then
        dnf makecache -y || true
        dnf install -y curl
    fi
fi
# Install Docker via official convenience script if not present
if ! command -v docker >/dev/null 2>&1; then
    log "Installing Docker Engine"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://get.docker.com | sh
    else
        err "curl not available to install Docker"
        exit 10
    fi
else
    log "Docker already installed: $(docker --version || true)"
fi
# Ensure docker group and add user if necessary
if command -v docker >/dev/null 2>&1; then
    if ! getent group docker >/dev/null 2>&1; then
        groupadd docker || true
    fi
fi
# Install docker compose plugin if missing
if ! docker compose version >/dev/null 2>&1; then
    log "Installing Docker Compose plugin"
    # plugin location /usr/local/lib/docker/cli-plugins on many systems
    mkdir -p /usr/local/lib/docker/cli-plugins || true
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose || true
fi
# Install nginx if missing
if ! command -v nginx >/dev/null 2>&1; then
    log "Installing nginx"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y nginx
    elif command -v yum >/dev/null 2>&1; then
        yum install -y nginx
        systemctl enable --now nginx || true
    fi
else
    log "nginx already installed: $(nginx -v 2>&1 || true)"
fi
# Enable and start docker and nginx services
if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker || true
    systemctl enable --now nginx || true
fi
log "Verifying installed versions"
docker --version || true
docker compose version || true
nginx -v 2>&1 || true
REMOTE_SCRIPT
)
    # Execute remote script
    local __ssh
    __ssh="$(ssh_cmd_base)"
    if ! eval "${__ssh} 'bash -s' <<'EOF'
'"${__cmd}"'
EOF"; then
        err "Remote environment preparation failed"
        return 1
    fi
    log "Remote environment prepared successfully"
    return 0
}

####################
# Deploy app       #
####################
remote_deploy_application() {
    local __remote_dir="$1"
    local __port="$2"
    local __use_compose="$3"
    local __container_name="$4"

    # Build remote script for deployment
    local __deploy_script
    __deploy_script=$(cat <<'DEPLOY_SH'
set -o errexit
set -o nounset
set -o pipefail
export APP_DIR="${1:-/opt/deployments/app}"
export APP_PORT="${2:-3000}"
export USE_COMPOSE="${3:-0}"
export CONTAINER_NAME="${4:-app_svc}"
log(){ printf "%s [REMOTE-DEPLOY] %s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" "$1"; }
err(){ printf "%s [REMOTE-DEPLOY-ERR] %s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" "$1" >&2; }
if [[ ! -d "${APP_DIR}" ]]; then
    err "App directory does not exist: ${APP_DIR}"
    exit 10
fi
cd "${APP_DIR}"
# Stop old containers gracefully if present
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
    log "Stopping and removing existing container ${CONTAINER_NAME}"
    docker rm -f "${CONTAINER_NAME}" || true
fi
# Remove dangling networks named after project (best effort)
if docker network ls --format '{{.Name}}' | grep -q '^' || true; then
    true
fi
if [[ "${USE_COMPOSE}" == "1" ]]; then
    if [[ -f docker-compose.yml ]] || [[ -f docker-compose.yaml ]]; then
        log "Starting application with docker-compose"
        docker compose down || true
        docker compose pull || true
        docker compose up -d --remove-orphans --build
    else
        err "docker-compose requested but no compose file found"
        exit 11
    fi
else
    # If Dockerfile present, build and run container mapping a host port to internal APP_PORT
    if [[ -f Dockerfile ]]; then
        log "Building Docker image ${CONTAINER_NAME}:latest"
        docker build -t "${CONTAINER_NAME}:latest" .
        log "Running container ${CONTAINER_NAME}"
        # find an available host port? We'll map container's APP_PORT to same on host (idempotent assumption)
        docker run -d --name "${CONTAINER_NAME}" -p "${APP_PORT}:${APP_PORT}" --restart unless-stopped "${CONTAINER_NAME}:latest"
    else
        err "No Dockerfile found for direct docker run"
        exit 12
    fi
fi
# Validate container health: wait for status up to some seconds
log "Validating container status"
local i=0
local max=20
while [[ $i -lt $max ]]; do
    if docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
        log "Container ${CONTAINER_NAME} is running"
        break
    fi
    i=$((i+1))
    sleep 2
done
if [[ $i -ge $max ]]; then
    err "Container did not become healthy/running within timeout"
    docker ps -a --filter "name=${CONTAINER_NAME}" --format '{{.Names}}\t{{.Status}}' || true
    exit 13
fi
log "Deployment step completed"
DEPLOY_SH
)
    # Execute remote deploy with positional arguments
    local __ssh
    __ssh="$(ssh_cmd_base)"
    if ! eval "${__ssh} 'bash -s' <<'EOF'
'"${__deploy_script}"'
EOF" <<EOARGS
${__remote_dir}
${__port}
${__use_compose}
${__container_name}
EOARGS
    then
        err "Remote deployment failed"
        return 1
    fi
    log "Remote application deployed"
    return 0
}

####################
# Nginx config     #
####################
remote_configure_nginx() {
    local __remote_dir="$1"
    local __app_port="$2"
    local __server_name="${SSH_HOST}"
    local __nginx_conf="/etc/nginx/sites-available/${REPO_NAME}.conf"
    local __nginx_link="/etc/nginx/sites-enabled/${REPO_NAME}.conf"
    log "Configuring nginx reverse proxy on remote: proxy -> 127.0.0.1:${__app_port}"
    local __nginx_conf_content
    __nginx_conf_content=$(cat <<NGINX
server {
    listen 80;
    server_name ${__server_name};

    access_log /var/log/nginx/${REPO_NAME}_access.log;
    error_log /var/log/nginx/${REPO_NAME}_error.log;

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:${__app_port};
        proxy_read_timeout 90;
    }
}
NGINX
)
    # Create remote config and test nginx
    local __ssh
    __ssh="$(ssh_cmd_base)"
    if ! eval "${__ssh} 'bash -s' <<'EOF'
set -o errexit
set -o nounset
set -o pipefail
cat > "${__nginx_conf}" <<'NGCONF'
${__nginx_conf_content}
NGCONF
ln -sf "${__nginx_conf}" "${__nginx_link}"
nginx -t
systemctl reload nginx || service nginx reload || true
EOF"; then
        err "Failed to configure nginx on remote"
        return 1
    fi
    log "Nginx configured and reloaded"
    return 0
}

####################
# Validation       #
####################
validate_deployment() {
    local __remote_dir="$1"
    local __app_port="$2"
    local __container="$3"
    local __ssh
    __ssh="$(ssh_cmd_base)"
    log "Validating deployment: docker, container, nginx, endpoint"
    # Docker service
    if ! eval "${__ssh} 'systemctl is-active --quiet docker'"; then
        err "Docker service is not active on remote"
        return 1
    fi
    # Container exists and running
    if ! eval "${__ssh} 'docker ps --format \"{{.Names}}\" | grep -q \"^${__container}\$\"'"; then
        err "Target container ${__container} not running on remote"
        return 2
    fi
    # Nginx proxy test: curl remote localhost:port
    log "Testing endpoint via remote curl to localhost:${__app_port}"
    if ! eval "${__ssh} 'curl -sS -m 5 http://127.0.0.1:${__app_port} >/dev/null'"; then
        err "Application endpoint on remote localhost:${__app_port} not responding"
        return 3
    fi
    # Test external via nginx HTTP (host) - use curl from local to remote host
    log "Testing external endpoint via HTTP: http://${SSH_HOST}"
    if ! curl -sS -m 10 "http://${SSH_HOST}" >/dev/null 2>&1; then
        err "External HTTP test to http://${SSH_HOST} failed"
        return 4
    fi
    log "Validation successful: service reachable locally and via nginx"
    return 0
}

####################
# Cleanup function #
####################
remote_cleanup() {
    local __remote_dir="$1"
    local __container="$2"
    local __nginx_conf="/etc/nginx/sites-available/${REPO_NAME}.conf"
    local __nginx_link="/etc/nginx/sites-enabled/${REPO_NAME}.conf"
    local __ssh
    __ssh="$(ssh_cmd_base)"
    log "Starting remote cleanup for project ${REPO_NAME}"
    if ! eval "${__ssh} 'bash -s' <<'EOF'
set -o errexit
set -o nounset
set -o pipefail
# Stop & remove container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
    docker rm -f "${CONTAINER_NAME}" || true
fi
# Remove project dir
rm -rf "${REMOTE_PROJECT_DIR}" || true
# Remove nginx config
rm -f "${__nginx_link}" || true
rm -f "${__nginx_conf}" || true
systemctl reload nginx || true
EOF"; then
        err "Remote cleanup encountered errors"
        return 1
    fi
    log "Remote cleanup completed"
    return 0
}

local_cleanup() {
    log "Performing local cleanup steps"
    if [[ -d "$PROJECT_DIR" ]]; then
        log "Removing local project directory $PROJECT_DIR"
        rm -rf "$PROJECT_DIR" || true
    fi
    log "Local cleanup done"
    return 0
}

####################
# Trap and signals #
####################
trap_handler() {
    local rc=$?
    err "Script interrupted or failed with exit code ${rc}"
    # attempt to inform user and exit
    exit "$rc"
}
trap trap_handler INT TERM ERR

####################
# Main flow        #
####################
main() {
    parse_args "${@:-}"
    if ! ensure_command git; then die "git required" 20; fi
    if ! ensure_command rsync; then die "rsync required" 21; fi
    if ! ensure_command ssh; then die "ssh required" 22; fi
    if ! ensure_command curl; then die "curl required" 23; fi

    if [[ "$CLEANUP_MODE" -eq 1 ]]; then
        log "CLEANUP MODE: interactive cleanup of remote deployment"
        collect_inputs_interactive || die "Input collection failed for cleanup" 30
        # Ask for confirmation
        safe_read CONFIRM "Are you sure you want to remove remote deployment and local project directory? Type 'YES' to proceed: "
        if [[ "$CONFIRM" != "YES" ]]; then
            log "Cleanup aborted by user"
            return 0
        fi
        remote_cleanup "$REMOTE_PROJECT_DIR" "$CONTAINER_NAME" || die "Remote cleanup failed" 31
        local_cleanup || die "Local cleanup failed" 32
        log "Cleanup completed successfully"
        return 0
    fi

    collect_inputs_interactive || die "Input collection failed" 40

    # Clone or update repo
    clone_or_update_repo "$REPO_URL" "$BRANCH" "$PROJECT_DIR" || die "Repository clone/update failed" 41

    # Ensure in project directory and presence of Dockerfile or compose
    check_project_files "$PROJECT_DIR" || die "Project file verification failed" 42

    # Test SSH connectivity
    ssh_test_connectivity || die "SSH connectivity failed" 43

    # Prepare remote environment
    remote_prepare_environment "$REMOTE_PROJECT_DIR" || die "Remote environment preparation failed" 44

    # Transfer project files
    rsync_project_to_remote "$PROJECT_DIR" "$REMOTE_PROJECT_DIR" || die "Project transfer failed" 45

    # Deploy on remote
    remote_deploy_application "$REMOTE_PROJECT_DIR" "$APP_PORT" "$USE_DOCKER_COMPOSE" "$CONTAINER_NAME" || die "Remote deployment failed" 46

    # Configure nginx reverse proxy
    remote_configure_nginx "$REMOTE_PROJECT_DIR" "$APP_PORT" || die "Nginx configuration failed" 47

    # Validate deployment
    validate_deployment "$REMOTE_PROJECT_DIR" "$APP_PORT" "$CONTAINER_NAME" || die "Deployment validation failed" 48

    log "Deployment completed successfully. Log file: ${LOGFILE}"
    return 0
}

# Execute main and exit with its return code
main "${@:-}"
exit $?
```
