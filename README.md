# 🚀 StackDeployer

**Production-Grade Automated Docker Deployment Pipeline**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://www.docker.com/)
[![AWS](https://img.shields.io/badge/AWS-EC2-orange.svg)](https://aws.amazon.com/ec2/)

**StackDeployer** is a production-ready, enterprise-grade Bash automation script that orchestrates the complete lifecycle of deploying Dockerized applications to remote Linux servers. Built with DevOps best practices, it provides zero-downtime deployments, comprehensive logging, automated rollback capabilities, and intelligent error handling — all through a single command execution.

---

## 📋 Table of Contents

- [🎯 Key Features](#-key-features)
- [🏗️ Architecture Overview](#️-architecture-overview)
- [🔄 Deployment Workflow](#-deployment-workflow)
- [⚙️ Prerequisites](#️-prerequisites)
- [🚀 Quick Start](#-quick-start)
- [📦 Installation](#-installation)
- [🔧 Configuration](#-configuration)
- [💻 Usage](#-usage)
- [📊 Detailed Workflow Breakdown](#-detailed-workflow-breakdown)
- [🔍 Logging & Monitoring](#-logging--monitoring)
- [🛡️ Security Features](#️-security-features)
- [🧹 Cleanup & Maintenance](#-cleanup--maintenance)
- [🐛 Troubleshooting](#-troubleshooting)
- [📈 Performance Optimization](#-performance-optimization)
- [🧪 Testing](#-testing)
- [📚 Advanced Usage](#-advanced-usage)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)
- [👨‍💻 Author](#-author)

---

## 🎯 Key Features

### 🔐 **Security-First Design**
- **PAT-based Git Authentication** - Secure GitHub repository access without exposing credentials
- **SSH Key Management** - Automated SSH key validation with permission checks
- **Credential Sanitization** - Sensitive data redacted from logs
- **Encrypted Communication** - All remote operations over secure SSH tunnels

### ⚡ **Intelligent Automation**
- **Idempotent Operations** - Safe to run multiple times without side effects
- **Automatic Dependency Detection** - Docker/Docker Compose auto-discovery
- **Smart File Transfer** - Rsync with delta sync for optimal bandwidth usage
- **Branch-Aware Deployment** - Support for multiple git branches and tags

### 🔧 **Production-Ready Operations**
- **Comprehensive Error Handling** - Trap-based error management with exit codes
- **Structured Logging** - Timestamped logs with severity levels (INFO, WARNING, ERROR, SUCCESS)
- **Health Validation** - Multi-layer deployment verification (Docker, Nginx, Container, HTTP)
- **Rollback Capability** - Cleanup mode for reverting deployments

### 🌐 **Infrastructure Management**
- **Nginx Configuration** - Automated reverse proxy setup with security headers
- **SSL/TLS Ready** - Pre-configured HTTPS templates for certificate integration
- **Load Balancing Support** - Upstream configuration for horizontal scaling
- **WebSocket Support** - Full support for real-time applications

### 📊 **Observability**
- **Detailed Validation Reports** - Post-deployment health checks with status codes
- **Service Monitoring** - Docker and Nginx service status verification
- **Container Health Checks** - Docker healthcheck inspection and reporting
- **HTTP Endpoint Testing** - Automated application availability verification

---

## 🏗️ Architecture Overview

StackDeployer implements a modular, pipeline-based architecture that separates concerns and ensures maintainability:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        LOCAL ENVIRONMENT                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────┐      ┌──────────────┐      ┌────────────────┐    │
│  │   deploy.sh │─────▶│ Git Clone    │─────▶│ Pre-deployment │    │
│  │   (Script)  │      │ (PAT Auth)   │      │ Validation     │    │
│  └─────────────┘      └──────────────┘      └────────────────┘    │
│         │                                              │             │
│         │                                              │             │
│         └──────────────────┬───────────────────────────┘            │
│                            │                                         │
│                            ▼                                         │
│                   ┌────────────────┐                                │
│                   │  SSH/Rsync     │                                │
│                   │  File Transfer │                                │
│                   └────────────────┘                                │
│                            │                                         │
└────────────────────────────┼─────────────────────────────────────────┘
                             │
                   ══════════▼═══════════
                   ║   SSH Tunnel       ║
                   ║   (Encrypted)      ║
                   ══════════╦═══════════
                             │
┌────────────────────────────▼─────────────────────────────────────────┐
│                       REMOTE SERVER (AWS EC2)                         │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌─────────────────┐      ┌──────────────┐      ┌───────────────┐  │
│  │ Environment     │─────▶│ Docker Build │─────▶│ Container     │  │
│  │ Preparation     │      │ & Deploy     │      │ Health Check  │  │
│  └─────────────────┘      └──────────────┘      └───────────────┘  │
│                                                           │            │
│  ┌─────────────────────────────────────────────────────┐│           │
│  │           Nginx Reverse Proxy Layer                  ││           │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ ││           │
│  │  │ Port 80/443  │  │ SSL/TLS      │  │ Security  │ ││           │
│  │  │ Listener     │─▶│ Termination  │─▶│ Headers   │ ││           │
│  │  └──────────────┘  └──────────────┘  └───────────┘ ││           │
│  └─────────────────────────────────────────────────────┘│           │
│                            │                              │            │
│                            ▼                              ▼            │
│                   ┌────────────────┐         ┌─────────────────┐     │
│                   │ Docker         │◀────────│ Validation &    │     │
│                   │ Container(s)   │         │ Health Checks   │     │
│                   └────────────────┘         └─────────────────┘     │
│                         │                                              │
└─────────────────────────┼──────────────────────────────────────────────┘
                          │
                          ▼
                  ┌───────────────┐
                  │  End Users    │
                  │ (HTTP/HTTPS)  │
                  └───────────────┘
```

### Design Principles

#### 1. **Separation of Concerns**
Each function handles a specific responsibility:
- Input validation and collection
- Git operations
- SSH connectivity
- Environment preparation
- Application deployment
- Service configuration
- Validation and monitoring

#### 2. **Fail-Fast Philosophy**
```bash
set -o errexit   # Exit on command failure
set -o nounset   # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
```

#### 3. **Idempotency**
- Safe to run multiple times
- Existing containers are gracefully replaced
- Configuration files are backed up before modification
- No duplicate resource creation

#### 4. **Observable Operations**
- Every critical step is logged with timestamps
- Error context preserved for debugging
- Validation reports provide deployment status
- Log files retained for audit trails

---

## 🔄 Deployment Workflow

### Phase 1: Pre-Deployment (Local)
```
1. Load Configuration
   ├─ Parse command-line arguments
   ├─ Validate environment variables
   └─ Collect user inputs (interactive mode)

2. Dependency Verification
   ├─ Check Git installation
   ├─ Verify SSH client
   ├─ Validate Rsync availability
   └─ Confirm curl/wget present

3. SSH Key Validation
   ├─ Check key file existence
   ├─ Verify read permissions
   ├─ Warn on insecure permissions (>600)
   └─ Test key format validity

4. Repository Operations
   ├─ Clone repository with PAT authentication
   ├─ OR: Pull latest changes if already cloned
   ├─ Switch to specified branch
   └─ Detect Dockerfile/docker-compose.yml
```

### Phase 2: SSH Connectivity
```
1. Connection Testing
   ├─ Attempt SSH connection (10s timeout)
   ├─ Retry up to 3 times with 5s intervals
   ├─ Verify remote command execution
   └─ Fail gracefully with detailed error

2. Credential Verification
   ├─ Test SSH key authentication
   ├─ Verify user privileges
   └─ Check sudo access (if required)
```

### Phase 3: Remote Environment Setup
```
1. System Preparation
   ├─ Update package repositories
   ├─ Install system dependencies
   └─ Configure firewall rules (if needed)

2. Docker Installation
   ├─ Check if Docker is installed
   ├─ Install Docker Engine if missing
   ├─ Install Docker Compose plugin
   └─ Start and enable Docker service

3. Nginx Setup
   ├─ Install Nginx if not present
   ├─ Backup existing configuration
   ├─ Enable and start Nginx service
   └─ Verify service is running

4. User Permissions
   ├─ Add user to docker group
   ├─ Apply group changes
   └─ Verify Docker access without sudo
```

### Phase 4: Application Deployment
```
1. File Transfer
   ├─ Create remote project directory
   ├─ Rsync source files (delta sync)
   ├─ Exclude .git directory
   └─ Preserve file permissions

2. Container Management
   ├─ Stop existing container (if running)
   ├─ Remove old container
   ├─ Clean up dangling images (optional)
   └─ Prune unused volumes (optional)

3. Build & Deploy
   ├─ Build Docker image from Dockerfile
   ├─ OR: Run docker-compose up -d
   ├─ Set restart policy (unless-stopped)
   └─ Map ports correctly

4. Health Verification
   ├─ Wait for container startup
   ├─ Check container status
   ├─ Verify healthcheck (if defined)
   └─ Test application port binding
```

### Phase 5: Reverse Proxy Configuration
```
1. Nginx Configuration
   ├─ Generate server block
   ├─ Configure upstream backend
   ├─ Set proxy headers
   ├─ Add security headers
   ├─ Configure WebSocket support
   ├─ Set timeout values
   └─ Define health check endpoint

2. SSL/TLS (Optional)
   ├─ Install certificates
   ├─ Configure HTTPS listener
   ├─ Set SSL protocols/ciphers
   └─ Enable HTTP/2

3. Service Reload
   ├─ Test configuration syntax
   ├─ Backup previous config
   ├─ Reload Nginx gracefully
   └─ Verify service status
```

### Phase 6: Validation & Reporting
```
1. Service Health Checks
   ├─ Docker service status ✓
   ├─ Docker daemon connectivity ✓
   ├─ Container runtime status ✓
   ├─ Container health status ✓
   ├─ Nginx service status ✓
   ├─ Nginx config validity ✓
   ├─ Port binding verification ✓
   └─ HTTP endpoint test ✓

2. Deployment Report
   ├─ Generate status report
   ├─ List all check results
   ├─ Display access URL
   └─ Show log file location

3. Error Handling
   ├─ Capture all failures
   ├─ Log error context
   ├─ Suggest remediation steps
   └─ Exit with appropriate code
```

---

## ⚙️ Prerequisites

### 🖥️ Local Machine Requirements

| Component | Minimum Version | Purpose |
|-----------|----------------|---------|
| **Bash** | 5.0+ | Script execution |
| **Git** | 2.20+ | Repository cloning |
| **SSH Client** | OpenSSH 7.0+ | Remote server access |
| **Rsync** | 3.1.0+ | File synchronization |
| **curl/wget** | Any recent | HTTP requests |

**Installation on Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y bash git openssh-client rsync curl
```

**Installation on macOS:**
```bash
brew install bash git rsync
# SSH and curl come pre-installed
```

**Installation on CentOS/RHEL:**
```bash
sudo yum install -y bash git openssh-clients rsync curl
```

### ☁️ Remote Server Requirements

| Component | Requirement | Notes |
|-----------|------------|-------|
| **OS** | Ubuntu 20.04+, Debian 11+, or Amazon Linux 2 | 64-bit required |
| **RAM** | 1GB minimum, 2GB recommended | For Docker operations |
| **Storage** | 10GB minimum free space | For images and containers |
| **CPU** | 1 vCPU minimum | 2+ vCPUs recommended |
| **Network** | Public IP or elastic IP | For external access |
| **Ports** | 80, 443 (open in security groups) | HTTP/HTTPS traffic |
| **Sudo Access** | Yes | For package installation |

**AWS EC2 Instance Types (Recommended):**
- **Development/Testing:** t2.micro, t3.micro (Free tier eligible)
- **Small Production:** t3.small, t3.medium
- **Production:** t3.large or higher, m5.large for compute-intensive apps

### 🔑 Access Requirements

#### GitHub Personal Access Token (PAT)
1. Navigate to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `read:org` (Read organization data - if applicable)
4. Set expiration (90 days recommended)
5. Copy token immediately (won't be shown again)

**Token Format:** `ghp_` followed by 36 alphanumeric characters

#### SSH Key Configuration
```bash
# Generate SSH key pair (if needed)
ssh-keygen -t ed25519 -C "deployment@yourdomain.com" -f ~/.ssh/deploy_key

# Set correct permissions
chmod 600 ~/.ssh/deploy_key
chmod 644 ~/.ssh/deploy_key.pub

# Copy public key to remote server
ssh-copy-id -i ~/.ssh/deploy_key.pub ubuntu@your-ec2-ip

# Test connection
ssh -i ~/.ssh/deploy_key ubuntu@your-ec2-ip "echo 'Connection successful'"
```

**AWS EC2 Specific:**
- Use key pair created during instance launch
- Store `.pem` file securely
- Set permissions: `chmod 400 keypair.pem`

---

## 🚀 Quick Start

Get up and running in under 5 minutes:

```bash
# 1. Clone the repository
git clone https://github.com/KoredeSec/StackDeployer.git
cd StackDeployer

# 2. Make script executable
chmod +x deploy.sh

# 3. Run deployment (interactive mode)
./deploy.sh
```

You'll be prompted for:
- 📦 Git repository URL
- 🔑 Personal Access Token (hidden input)
- 🌿 Branch name (default: main)
- 👤 SSH username (e.g., ubuntu)
- 🌐 Remote host IP/domain
- 🔐 SSH key path
- 🔌 Application port

---

## 📦 Installation

### Method 1: Direct Clone (Recommended)
```bash
git clone https://github.com/KoredeSec/StackDeployer.git
cd StackDeployer
chmod +x deploy.sh
```

### Method 2: Download Release
```bash
# Download latest release
curl -LO https://github.com/KoredeSec/StackDeployer/archive/refs/heads/main.zip
unzip main.zip
cd StackDeployer-main
chmod +x deploy.sh
```

### Method 3: Direct Script Download
```bash
# Download script only
curl -o deploy.sh https://raw.githubusercontent.com/KoredeSec/StackDeployer/main/deploy.sh
chmod +x deploy.sh
```

---

## 🔧 Configuration

### Environment Variables (.env file)

Create a `.env` file in the project root for automated deployments:

```bash
# Git Configuration
REPO_URL=https://github.com/your-username/your-app.git
PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
BRANCH=main

# SSH Configuration
SSH_USER=ubuntu
SSH_HOST=ec2-xx-xxx-xxx-xxx.compute-1.amazonaws.com
SSH_KEY=~/.ssh/your-keypair.pem

# Application Configuration
APP_PORT=3000

# Optional: Remote Configuration
REMOTE_BASE=/home/ubuntu/deployments
CONTAINER_NAME=myapp_svc
```

**Security Note:** Add `.env` to `.gitignore` to prevent credential leakage:
```bash
echo ".env" >> .gitignore
```

### Loading Environment Variables

```bash
# Method 1: Export before running
export $(grep -v '^#' .env | xargs)
./deploy.sh

# Method 2: Source in script
source .env && ./deploy.sh

# Method 3: One-liner
set -a; source .env; set +a; ./deploy.sh
```

### Configuration Validation

Verify your configuration before deployment:

```bash
# Check SSH connectivity
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "echo 'Connection OK'"

# Verify PAT (should show your repos)
curl -H "Authorization: token $PAT" https://api.github.com/user/repos

# Test rsync
rsync --dry-run -av -e "ssh -i $SSH_KEY" ./ "$SSH_USER@$SSH_HOST:/tmp/test/"
```

---

## 💻 Usage

### Basic Deployment

**Interactive Mode (Recommended for first-time users):**
```bash
./deploy.sh
```

**Non-Interactive Mode (with .env):**
```bash
export $(grep -v '^#' .env | xargs)
./deploy.sh
```

### Advanced Usage

**Deploy Specific Branch:**
```bash
# Set branch in .env
BRANCH=staging

# Or specify during interactive prompt
Branch (default: main): staging
```

**Custom Port Mapping:**
```bash
# In .env or during prompt
APP_PORT=8080
```

**Deploy with Docker Compose:**
```bash
# Script auto-detects docker-compose.yml
# No additional flags needed
./deploy.sh
```

### Cleanup Mode

Remove all deployment artifacts:

```bash
./deploy.sh -cleanup
```

This will:
- ✅ Stop and remove containers
- ✅ Delete remote project directory
- ✅ Remove local cloned files
- ✅ Preserve logs for audit

**Selective Cleanup:**
```bash
# Manual container removal
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker rm -f container_name"

# Manual directory cleanup
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "rm -rf /home/ubuntu/deployments/project"
```

---

## 📊 Detailed Workflow Breakdown

### Step 1: Input Collection & Validation
```
[2025-10-21T04:29:40+0100] [INFO] === STEP 1: Collecting input parameters ===
Git repository URL (HTTPS): https://github.com/user/app.git
Personal Access Token (PAT) - input hidden: ****
Branch (default: main): main
Remote SSH username: ubuntu
Remote SSH host (IP or domain): 52.203.xxx.xxx
SSH key path (absolute or relative): ~/.ssh/deploy.pem
Application internal container port (e.g., 3000): 3000
[2025-10-21T04:29:45+0100] [INFO] Collected inputs: repo=https://[REDACTED]@github.com/user/app.git
```

**Validation Checks:**
- ✓ Repository URL format
- ✓ PAT non-empty
- ✓ SSH key file exists
- ✓ SSH key permissions (600 or 400)
- ✓ Port number valid (1-65535)

### Step 2: Repository Clone/Update
```
[2025-10-21T04:29:46+0100] [INFO] === STEP 2: Clone or Update Repository ===
[2025-10-21T04:29:52+0100] [INFO] Repository cloned successfully
```

**Operations:**
- Clones repository if not present locally
- Updates existing repository with latest changes
- Switches to specified branch
- Removes PAT from remote URL after clone

### Step 3: Docker Setup Detection
```
[2025-10-21T04:29:53+0100] [INFO] === STEP 3: Checking project Docker setup ===
[2025-10-21T04:29:53+0100] [INFO] Dockerfile found
```

**Detection Logic:**
```bash
if Dockerfile exists:
    USE_DOCKER_COMPOSE=0
elif docker-compose.yml exists:
    USE_DOCKER_COMPOSE=1
else:
    ERROR: No Docker configuration found
```

### Step 4: SSH Connectivity Test
```
[2025-10-21T04:29:54+0100] [INFO] === STEP 4: Testing SSH connectivity ===
[2025-10-21T04:29:55+0100] [INFO] SSH connectivity check attempt 1/3
[2025-10-21T04:29:56+0100] [SUCCESS] SSH connectivity verified successfully
```

**Retry Logic:**
- 3 attempts with 5-second intervals
- 10-second connection timeout
- Detailed error reporting on failure

### Step 5: File Transfer
```
[2025-10-21T04:29:57+0100] [INFO] === STEP 5: Transferring project to remote ===
sending incremental file list
./
Dockerfile
app.js
package.json
sent 42,350 bytes  received 156 bytes  28,337.33 bytes/sec
[2025-10-21T04:30:02+0100] [INFO] Project transferred successfully
```

**Rsync Efficiency:**
- Delta transfer algorithm (only changed files)
- Compression during transfer
- Preserves permissions and timestamps
- Excludes .git directory (reduces transfer size)

### Step 6: Environment Preparation
```
[2025-10-21T04:30:03+0100] [INFO] === STEP 6: Preparing remote environment ===
Updating system...
Installing Docker...
Installing Nginx...
Adding user to docker group...
[2025-10-21T04:30:20+0100] [INFO] Remote environment prepared
```

**Installation Checks:**
- Skips if Docker already installed
- Skips if Nginx already running
- Idempotent group membership

### Step 7: Docker Deployment
```
[2025-10-21T04:30:21+0100] [INFO] === STEP 7: Deploying Dockerized Application ===
Stopping existing container (if any)...
Building Docker image...
Starting new container...
Container ID: a8f3d9c2b1e4
[2025-10-21T04:30:35+0100] [INFO] Application deployed successfully
```

**Container Management:**
```bash
# Stop old container
docker rm -f app_svc 2>/dev/null || true

# Build new image
docker build -t app_svc:latest .

# Run with automatic restart
docker run -d \
  --name app_svc \
  -p 3000:3000 \
  --restart unless-stopped \
  app_svc:latest
```

### Step 8: Nginx Configuration
```
[2025-10-21T04:30:36+0100] [INFO] === STEP 8: Configuring Nginx Reverse Proxy ===
Creating Nginx configuration...
Testing configuration...
nginx: configuration file /etc/nginx/nginx.conf test is successful
Reloading Nginx...
[2025-10-21T04:30:40+0100] [SUCCESS] Nginx configured and reloaded successfully
```

**Generated Configuration:**
```nginx
upstream app_backend {
    server 127.0.0.1:3000 fail_timeout=10s max_fails=3;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        # ... additional headers
    }
}
```

### Step 9: Deployment Validation
```
[2025-10-21T04:30:41+0100] [INFO] === STEP 9: Validating Deployment ===
================================================
🔍 DEPLOYMENT VALIDATION REPORT
================================================

📦 Docker Service Status Check:
   ✅ Docker service is running
   Docker service check: PASSED

🐳 Container Status Check:
   ✅ Container 'app_svc' is running
   Status: running
   Container status check: PASSED

🌐 Nginx Service Status Check:
   ✅ Nginx service is running
   Nginx service check: PASSED

⚙️  Nginx Configuration Test:
   ✅ Nginx configuration is valid
   Nginx configuration check: PASSED

🔌 Application Port Check:
   ✅ Application is listening on port 3000
   Port check: PASSED

🌍 Local HTTP Test:
   ✅ Application responding (HTTP 200)
   HTTP test: PASSED

================================================
✅ VALIDATION COMPLETE - ALL CHECKS PASSED
================================================
[2025-10-21T04:30:45+0100] [SUCCESS] Deployment validation completed successfully
```

---

## 🔍 Logging & Monitoring

### Log File Structure

Logs are stored in `./logs/` with timestamped filenames:

```
logs/
├── deploy_20251021_042940.log  (Latest deployment)
├── deploy_20251020_153022.log
└── deploy_20251019_091545.log
```

### Log Format

```
[TIMESTAMP] [LEVEL] MESSAGE

Levels:
- [INFO]    : General information
- [SUCCESS] : Successful operations
- [WARNING] : Non-critical issues
- [ERROR]   : Failures requiring attention
```

### Sample Log Entry

```log
2025-10-21T04:29:40+0100 [INFO] === STEP 1: Collecting input parameters ===
2025-10-21T04:29:45+0100 [INFO] Collected inputs: repo=https://[REDACTED]@github.com/user/app.git
2025-10-21T04:29:46+0100 [INFO] === STEP 2: Clone or Update Repository ===
2025-10-21T04:29:52+0100 [INFO] Repository cloned successfully
2025-10-21T04:30:45+0100 [SUCCESS] Deployment completed successfully at 2025-10-21T04:30:45+0100
```

### Viewing Logs

```bash
# View latest log
tail -f logs/deploy_$(ls -t logs/ | head -1)

# View specific log
less logs/deploy_20251021_042940.log

# Search for errors
grep ERROR logs/deploy_*.log

# Count successful deployments
grep "SUCCESS.*Deployment completed" logs/*.log | wc -l
```

### Log Rotation

Implement log rotation to prevent disk space issues:

```bash
# Create logrotate configuration
sudo tee /etc/logrotate.d/stackdeployer << EOF
/path/to/StackDeployer/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

---

## 🛡️ Security Features

### 1. Credential Protection
- PAT never written to logs (sanitized)
- SSH keys validated for correct permissions (600/400)
- Environment variables for sensitive data
- `.env` excluded from version control

### 2. SSH Security
```bash
# Hardened SSH options
-o StrictHostKeyChecking=accept-new  # First-time connection
-o BatchMode=yes                      # Non-interactive
-o ConnectTimeout=10                  # Timeout for connections
```

### 3. Nginx Security Headers
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
```

### 4. Docker Security
```bash
# Container runs with restart policy
--restart unless-stopped

# No privileged mode
# No host network mode
# Explicit port mapping (-p)
```

### 5. Input Validation
- Repository URL format verification
- SSH key existence and readability checks
- Port range validation (1-65535)
- Branch name sanitization

---

## 🧹 Cleanup & Maintenance

### Automated Cleanup
```bash
# Full cleanup (containers + files)
./deploy.sh -cleanup
```

### Manual Cleanup Operations

**Remove Stopped Containers:**
```bash
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker container prune -f"
```

**Remove Unused Images:**
```bash
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker image prune -a -f"
```

**Remove Unused Volumes:**
```bash
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker volume prune -f"
```

**Clean Build Cache:**
```bash
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker builder prune -a -f"
```

### Nginx Configuration Cleanup
```bash
# List backups
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "ls -lh /etc/nginx/sites-available/default.bak_*"

# Remove old backups (keep last 5)
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" \
  "cd /etc/nginx/sites-available && ls -t default.bak_* | tail -n +6 | xargs -r sudo rm"
```

### Log Cleanup
```bash
# Remove logs older than 30 days
find logs/ -name "*.log" -mtime +30 -delete

# Archive old logs
tar -czf logs_archive_$(date +%Y%m).tar.gz logs/*.log
mv logs_archive_*.tar.gz ~/archives/

# Keep only last 10 logs
ls -t logs/*.log | tail -n +11 | xargs rm -f
```

---

## 🐛 Troubleshooting

### Common Issues & Solutions

#### 1. SSH Connection Refused
**Symptom:**
```
[ERROR] SSH connection failed after 3 attempts
```

**Solutions:**
```bash
# Check if port 22 is open in security group
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Verify SSH service is running
ssh -v -i "$SSH_KEY" "$SSH_USER@$SSH_HOST"

# Check correct username (ubuntu for Ubuntu, ec2-user for Amazon Linux)
ssh -i "$SSH_KEY" ubuntu@$SSH_HOST
ssh -i "$SSH_KEY" ec2-user@$SSH_HOST

# Verify key permissions
chmod 600 ~/.ssh/your-key.pem
```

#### 2. Permission Denied (publickey)
**Symptom:**
```
Permission denied (publickey,gssapi-keyex,gssapi-with-mic)
```

**Solutions:**
```bash
# Ensure correct key file
ssh-add -l

# Add key to ssh-agent
eval $(ssh-agent)
ssh-add ~/.ssh/your-key.pem

# Verify public key on remote server
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cat ~/.ssh/authorized_keys"
```

#### 3. Docker Build Fails
**Symptom:**
```
[ERROR] Docker build failed
```

**Solutions:**
```bash
# Check Dockerfile syntax locally
docker build -t test .

# SSH into server and check Docker logs
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST"
docker logs container_name

# Check disk space on remote server
df -h

# Clean up Docker resources
docker system prune -a -f
```

#### 4. Port Already in Use
**Symptom:**
```
Error: bind: address already in use
```

**Solutions:**
```bash
# Find process using the port
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "sudo lsof -i :3000"

# Kill the process
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "sudo kill -9 PID"

# Or use different port in APP_PORT variable
APP_PORT=3001
```

#### 5. Nginx Configuration Test Failed
**Symptom:**
```
nginx: [emerg] unexpected "}" in /etc/nginx/sites-available/default
```

**Solutions:**
```bash
# Test configuration manually
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "sudo nginx -t"

# View configuration file
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "sudo cat /etc/nginx/sites-available/default"

# Restore from backup
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" \
  "sudo cp /etc/nginx/sites-available/default.bak_* /etc/nginx/sites-available/default"

# Reload Nginx
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "sudo systemctl reload nginx"
```

#### 6. Container Health Check Failing
**Symptom:**
```
Container health: unhealthy
```

**Solutions:**
```bash
# Check container logs
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker logs container_name --tail 100"

# Inspect health check
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" \
  "docker inspect --format='{{json .State.Health}}' container_name | jq"

# Enter container for debugging
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker exec -it container_name /bin/bash"

# Check application logs inside container
docker exec container_name cat /var/log/app.log
```

#### 7. Rsync Transfer Fails
**Symptom:**
```
rsync: connection unexpectedly closed
```

**Solutions:**
```bash
# Test rsync with verbose output
rsync -avz --progress -e "ssh -i $SSH_KEY" ./ "$SSH_USER@$SSH_HOST:/tmp/test/"

# Check available disk space
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "df -h"

# Try with compression disabled (for high latency connections)
rsync -az --no-compress ...

# Exclude large files/directories
rsync --exclude 'node_modules' --exclude '*.log' ...
```

### Debug Mode

Enable detailed output for troubleshooting:

```bash
# Add debug flags at the top of deploy.sh
set -x  # Print commands before execution

# Run with bash debug
bash -x deploy.sh

# Capture full output
./deploy.sh 2>&1 | tee debug_$(date +%Y%m%d_%H%M%S).log
```

### Health Check Script

Create a standalone health check:

```bash
#!/bin/bash
# health_check.sh

SSH_KEY="$1"
SSH_USER="$2"
SSH_HOST="$3"
CONTAINER="$4"

echo "=== Docker Service ==="
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "systemctl status docker --no-pager"

echo -e "\n=== Container Status ==="
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker ps -a --filter name=$CONTAINER"

echo -e "\n=== Container Logs (last 20 lines) ==="
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker logs $CONTAINER --tail 20"

echo -e "\n=== Nginx Status ==="
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "systemctl status nginx --no-pager"

echo -e "\n=== Port Listening ==="
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "sudo netstat -tulpn | grep LISTEN"
```

---

## 📈 Performance Optimization

### 1. Reduce Transfer Time

**Use .rsyncignore:**
```bash
# Create .rsyncignore file
cat > .rsyncignore << EOF
node_modules/
.git/
*.log
.env
dist/
build/
coverage/
EOF

# Update rsync command in script
rsync -az --exclude-from=.rsyncignore ...
```

**Enable Compression:**
```bash
# For slow networks
rsync -avz -e "ssh -i $SSH_KEY -C" ...
```

### 2. Optimize Docker Build

**Multi-stage Dockerfile:**
```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Production stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
CMD ["node", "app.js"]
```

**Use .dockerignore:**
```
node_modules
npm-debug.log
.git
.gitignore
.env
*.md
.DS_Store
```

### 3. Cache Docker Layers

```bash
# Build with cache
docker build --cache-from myapp:latest -t myapp:latest .

# Use BuildKit for better caching
DOCKER_BUILDKIT=1 docker build -t myapp:latest .
```

### 4. Parallel Operations

For multiple deployments:

```bash
#!/bin/bash
# parallel_deploy.sh

declare -a servers=("server1.com" "server2.com" "server3.com")

for server in "${servers[@]}"; do
  (
    export SSH_HOST="$server"
    ./deploy.sh
  ) &
done

wait
echo "All deployments completed"
```

### 5. Nginx Tuning

```nginx
# In nginx.conf
worker_processes auto;
worker_connections 1024;

# Enable gzip compression
gzip on;
gzip_vary on;
gzip_types text/plain text/css application/json application/javascript;

# Enable caching
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=app_cache:10m;
proxy_cache app_cache;
proxy_cache_valid 200 1h;
```

---

## 🧪 Testing

### Local Testing (Before Remote Deployment)

**1. Test Script Syntax:**
```bash
bash -n deploy.sh  # Check syntax without execution
shellcheck deploy.sh  # Static analysis (install: apt install shellcheck)
```

**2. Test Docker Build Locally:**
```bash
# Clone repo
git clone https://github.com/user/app.git
cd app

# Build image
docker build -t test-app .

# Run container
docker run -d -p 3000:3000 --name test-app test-app

# Test endpoint
curl http://localhost:3000

# Cleanup
docker rm -f test-app
```

**3. Test SSH Connection:**
```bash
# Test basic connection
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "echo 'SSH OK'"

# Test Docker access
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker ps"

# Test sudo access
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "sudo whoami"
```

### Integration Testing

**Create Test Suite:**
```bash
#!/bin/bash
# test_deployment.sh

set -e

echo "=== Running Deployment Tests ==="

# Test 1: Script exists and is executable
test -x deploy.sh && echo "✓ Script is executable" || exit 1

# Test 2: Required commands available
for cmd in git ssh rsync curl; do
  command -v $cmd >/dev/null 2>&1 && echo "✓ $cmd found" || exit 1
done

# Test 3: SSH connectivity
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "exit" && echo "✓ SSH connected" || exit 1

# Test 4: Remote Docker available
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker info >/dev/null 2>&1" && \
  echo "✓ Docker available" || exit 1

# Test 5: Remote Nginx available
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "nginx -v 2>&1" && \
  echo "✓ Nginx available" || exit 1

echo "=== All Tests Passed ==="
```

### Post-Deployment Testing

**Automated Health Check:**
```bash
#!/bin/bash
# post_deploy_test.sh

APP_URL="http://$SSH_HOST"

# Test 1: HTTP 200 response
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL")
if [[ "$HTTP_CODE" == "200" ]]; then
  echo "✓ Application responding (HTTP 200)"
else
  echo "✗ Application not responding (HTTP $HTTP_CODE)"
  exit 1
fi

# Test 2: Response time < 2 seconds
RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' "$APP_URL")
if (( $(echo "$RESPONSE_TIME < 2" | bc -l) )); then
  echo "✓ Response time acceptable ($RESPONSE_TIME seconds)"
else
  echo "⚠ Slow response time ($RESPONSE_TIME seconds)"
fi

# Test 3: Container running
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" \
  "docker ps --filter name=$CONTAINER_NAME --format '{{.Status}}' | grep -q Up" && \
  echo "✓ Container is running" || exit 1

# Test 4: No critical errors in logs
ERROR_COUNT=$(ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" \
  "docker logs $CONTAINER_NAME 2>&1 | grep -i 'error\|critical' | wc -l")
if [[ "$ERROR_COUNT" -eq 0 ]]; then
  echo "✓ No critical errors in logs"
else
  echo "⚠ Found $ERROR_COUNT error(s) in logs"
fi

echo "=== Post-Deployment Tests Complete ==="
```

---

## 📚 Advanced Usage

### 1. Multi-Environment Deployments

**Create environment-specific configs:**

```bash
# .env.production
REPO_URL=https://github.com/user/app.git
BRANCH=main
SSH_HOST=prod-server.com
APP_PORT=3000

# .env.staging
REPO_URL=https://github.com/user/app.git
BRANCH=staging
SSH_HOST=staging-server.com
APP_PORT=3001

# Deploy to specific environment
export $(grep -v '^#' .env.staging | xargs)
./deploy.sh
```

### 2. Blue-Green Deployment

```bash
#!/bin/bash
# blue_green_deploy.sh

# Deploy to green environment
export CONTAINER_NAME="app_green"
export APP_PORT=3001
./deploy.sh

# Test green environment
if curl -f http://$SSH_HOST:3001/health; then
  echo "Green environment healthy"
  
  # Switch Nginx to green
  ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" \
    "sudo sed -i 's/127.0.0.1:3000/127.0.0.1:3001/' /etc/nginx/sites-available/default"
  ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "sudo systemctl reload nginx"
  
  # Stop blue environment
  ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker stop app_blue"
else
  echo "Green environment unhealthy, keeping blue active"
  exit 1
fi
```

### 3. Database Migration Integration

```bash
# Add to deploy.sh before container start

remote_run_migrations() {
  log "Running database migrations..."
  ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" bash <<EOF
cd "$REMOTE_PROJECT_DIR"
docker run --rm \
  --network host \
  -e DATABASE_URL="\$DATABASE_URL" \
  ${CONTAINER_NAME}:latest \
  npm run migrate
EOF
  log "Migrations completed"
}
```

### 4. Slack/Discord Notifications

```bash
# Add notification function
send_notification() {
  local status="$1"
  local message="$2"
  local webhook_url="YOUR_WEBHOOK_URL"
  
  curl -X POST "$webhook_url" \
    -H 'Content-Type: application/json' \
    -d "{\"text\": \"🚀 Deployment $status: $message\"}"
}

# Call in main function
if [[ $? -eq 0 ]]; then
  send_notification "SUCCESS" "App deployed to $SSH_HOST"
else
  send_notification "FAILED" "Deployment to $SSH_HOST failed"
fi
```

### 5. Automated Backup Before Deployment

```bash
backup_current_deployment() {
  log "Creating backup of current deployment..."
  ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" bash <<EOF
if [[ -d "$REMOTE_PROJECT_DIR" ]]; then
  BACKUP_DIR="/home/ubuntu/backups/\$(date +%Y%m%d_%H%M%S)"
  mkdir -p "\$BACKUP_DIR"
  cp -r "$REMOTE_PROJECT_DIR" "\$BACKUP_DIR/"
  echo "Backup created at \$BACKUP_DIR"
fi
EOF
  log_success "Backup completed"
}
```

### 6. Secrets Management with AWS Secrets Manager

```bash
# Install AWS CLI on local machine
# Configure credentials: aws configure

retrieve_secrets() {
  log "Retrieving secrets from AWS Secrets Manager..."
  
  SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id prod/app/credentials \
    --query SecretString \
    --output text)
  
  export DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.db_password')
  export API_KEY=$(echo "$SECRET_JSON" | jq -r '.api_key')
  
  log_success "Secrets retrieved"
}
```

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Reporting Issues

1. Check existing issues first
2. Provide detailed description
3. Include relevant logs
4. Specify your environment (OS, Bash version, etc.)

**Issue Template:**
```markdown
**Description:**
Brief description of the issue

**Steps to Reproduce:**
1. Step one
2. Step two
3. Step three

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happens

**Environment:**
- OS: Ubuntu 22.04
- Bash: 5.1.16
- Docker: 24.0.5

**Logs:**
```
Paste relevant log excerpts
```
```

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

**PR Checklist:**
- [ ] Code follows existing style
- [ ] All functions have comments
- [ ] Tested on Ubuntu 20.04+
- [ ] No hardcoded credentials
- [ ] Documentation updated
- [ ] Changelog updated

### Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/StackDeployer.git
cd StackDeployer

# Add upstream remote
git remote add upstream https://github.com/KoredeSec/StackDeployer.git

# Create feature branch
git checkout -b feature/my-feature

# Make changes and test
./deploy.sh

# Push and create PR
git push origin feature/my-feature
```

---

## 📊 Project Statistics

```
├── Lines of Code: 600+           
├── Functions: 20+                
├── Deployment Steps: 9           
├── Validation Checks: 7          
├── Error Handlers: 3            
├── Logging Levels: 4             
└── Supported Platforms: Ubuntu, Debian, Amazon Linux ← Correct
```

---

## 🧩 Compliance with DevOps Best Practices

| Practice | Implementation | Status |
|----------|----------------|--------|
| **Infrastructure as Code** | Bash script automation | ✅ |
| **Idempotency** | Safe re-runs without side effects | ✅ |
| **Error Handling** | Comprehensive trap and validation | ✅ |
| **Logging** | Structured logs with timestamps | ✅ |
| **Security** | SSH keys, PAT, credential sanitization | ✅ |
| **Modularity** | Function-based architecture | ✅ |
| **Documentation** | Comprehensive README | ✅ |
| **Version Control** | Git-based workflow | ✅ |
| **Automated Testing** | Pre/post deployment checks | ✅ |
| **Rollback Capability** | Cleanup mode available | ✅ |

---

## 📦 Example Project Structure

```
StackDeployer/
├── deploy.sh                    # Main deployment script
├── README.md                    # This file
├── .env.example                 # Environment template
├── .gitignore                   # Git exclusions
├── LICENSE                      # MIT License
├── server.js                    # Node.js app entry point
├── package.json                 # Node.js dependencies and scripts
├── Dockerfile                   # Docker build instructions                  
└── logs/
    ├── deploy_20251021_042940.log
    ├── deploy_20251020_153022.log

```

---

## 🔗 Useful Resources

### Official Documentation
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/)

### Tutorials & Guides
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Nginx Reverse Proxy Guide](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [SSH Security Best Practices](https://www.ssh.com/academy/ssh/security)

### Tools
- [ShellCheck](https://www.shellcheck.net/) - Shell script analysis
- [Docker Hub](https://hub.docker.com/) - Container registry
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates

---

## 📄 License

```
MIT License

Copyright (c) 2025 Ibrahim Yusuf (Tory)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 👨‍💻 Author

**Ibrahim Yusuf (Tory)**

🎓 **President** – NACSS_UNIOSUN (Nigeria Association Of CyberSecurity Students, Osun State University)  
🔐 **Certifications:** Certified in Cybersecurity (ISC² CC) | Microsoft SC-200  
💼 **Focus:** Cloud Architecture, DevSecOps, Automation, Threat Intel, Cybersecurity  

### Connect & Follow

- 🐙 **GitHub:** [@KoredeSec](https://github.com/KoredeSec)
- ✍️ **Medium:** [Ibrahim Yusuf](https://medium.com/@KoredeSec)
- 🐦 **X (Twitter):** [@KoredeSec](https://x.com/KoredeSec)
- 💼 **LinkedIn:** Restricted currently

### Other Projects

-  **AdwareDetector** [AdwareDetector](https://github.com/KoredeSec/AdwareDetector) 
-  **threat-intel-aggregator**[threat-intel-aggregator](https://github.com/KoredeSec/threat-intel-aggregator)
-  **azure-sentinel-home-soc** [azure-sentinel-home-soc](https://github.com/KoredeSec/azure-sentinel-home-soc)

---

## 🙏 Acknowledgments

Special thanks to:
- HNG Internship for the inspiration
- DevOps practitioners who shared best practices

---



## ⭐ Star History

If you find this project useful, please consider giving it a star on GitHub!

[![Star History Chart](https://api.star-history.com/svg?repos=KoredeSec/StackDeployer&type=Date)](https://star-history.com/#KoredeSec/StackDeployer&Date)

---

<div align="center">

**Built with ❤️ for the DevOps Community**

Made in Nigeria 🇳🇬 | Open Source | MIT Licensed

[⬆ Back to Top](#-stackdeployer)

</div>
