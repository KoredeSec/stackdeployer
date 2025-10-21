
---

# 🚀 StackDeployer

**Automated Docker Deployment Script**

**StackDeployer** is a lightweight Bash-based deployment automation script designed to streamline the process of pushing web applications to a remote Linux server (e.g., AWS EC2).  
It abstracts repetitive DevOps tasks like syncing source code, setting up the environment, managing services (like Nginx and Docker), and verifying live deployments — all through a single execution command.

---

## 🧭 Project Overview

Modern deployments often require engineers to juggle SSH, Docker, and web server configurations repeatedly.  
**StackDeployer** simplifies that process by providing an automated, environment-driven deployment workflow — ideal for small teams, personal projects, or student DevOps challenges.

It assumes:
- You already have a running **Nginx** instance configured as a reverse proxy.
- The target server is **Ubuntu-based**, accessible via **SSH**.
- Docker is installed and running on the target host.

---

---

## 🧱 Architecture & Design Workflow

StackDeployer automates the full cycle of deploying a containerized application from a local environment to a remote Linux host (AWS EC2).
It follows a simple yet production-grade design pattern based on modular shell functions and environment-based configuration.


### 🧭 Architecture Workflow

```text
+-------------------------+                +---------------------------+
|      Local Machine      |                |      Remote Server        |
| (DevOps Engineer Laptop)|                | (AWS EC2 Ubuntu Instance) |
+-------------------------+                +---------------------------+
|                         |   SSH/rsync    |                           |
| - deploy.sh             |--------------->| - Docker Engine           |
| - .env (config)         |                | - Deployed App Container  |
| - PAT-based Git clone   |                | - Nginx (Reverse Proxy)   |
|                         |                |                           |
+-------------------------+                +---------------------------+
                     ^                                    |
                     |                                    v
                     |                              User Access
                     +--------------------------- HTTP/HTTPS ------------------>

```

## Design Principles
- **Idempotent Deployment:** Running the script multiple times won’t break the environment.
- **Minimal Dependencies:** Only `bash`, `rsync`, `ssh`, and `docker` are required.
- **Environment-Aware:** Sensitive credentials (e.g., server IP, username, port) are stored in a `.env` file.
- **Fast Rollout:** No manual Nginx configuration required — assumes an existing reverse proxy setup.



---

## ⚙️ Core Workflow

1. **Load Configuration**
   - The script reads from `.env` to extract variables like `SSH_HOST`, `SSH_USER`, and `PAT`.

2. **Pre-Deployment Checks**
   - Verifies SSH connectivity and Docker availability.
   - Ensures `.env` is valid and executable permissions are set.

3. **Sync Files**
   - Uses `rsync` to copy the project directory from local to remote.
   - Only changed files are transferred for efficiency.

4. **Remote Deployment**
   - Connects to the EC2 instance via SSH.
   - Pulls or builds Docker images as needed.
   - Restarts containers (if applicable) to reflect the latest updates.

5. **Verification**
   - Confirms the app is running on the correct port.
   - Checks that the Nginx service is active (skipped if already verified live).

6. **Completion**
   - Prints a success message with the deployment timestamp and URL.
  
---

## ⚙️ Prerequisites

Before running the script, ensure the following:

### 🖥️ Local Machine Requirements

* **Bash** 4.0+
* **Git**
* **SSH client**
* **rsync**
* **curl**

### ☁️ Remote Server Requirements

* Linux-based OS (Ubuntu/Debian recommended)
* **sudo privileges**
* SSH access enabled
* Open inbound port for your application (e.g., 80 or 8080)

### 🔑 Access Requirements

* A **GitHub Personal Access Token (PAT)** with `repo` access scope.
* SSH key configured for passwordless login (recommended).

---

## 🛠️ Setup 

### Prerequisites
Ensure the following are installed on your **local** machine:
- Bash 5.x or higher
- OpenSSH client
- Rsync
- Docker (for local testing)

Ensure the **remote** server has:
- Docker Engine installed and active
- Nginx pre-configured (already serving requests)
- OpenSSH enabled and accessible

### 1️⃣ Clone the StackDeployer Repository

```bash
git clone https://github.com/<your-username>/StackDeployer.git
cd StackDeployer
chmod +x deploy.sh
```

### 2️⃣ Environment File (Optional)

To keep sensitive credentials secure, you can store variables in a `.env` file:

```
REPO_URL=https://github.com/<your-username>/stackdeployer.git
PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
BRANCH=main
SSH_USER=ubuntu
SSH_HOST=ec2-xx-xx-xxx-xxx.compute-1.anmazoaws.com
SSH_KEY=~/.ssh/keypair.pem
APP_PORT=3000
```

Then load them before execution:

```bash
export $(grep -v '^#' .env | xargs)
```

*(Note: `.env` is included in `.gitignore` to prevent committing secrets.)*

### 3️⃣ Run Deployment Script

```bash
./deploy.sh
```

You’ll be prompted for:

* GitHub Repository URL
* PAT
* Branch name
* SSH Username
* Remote Server IP
* SSH Key Path
* Application Port

The script will then:
✅ Verify dependencies
✅ Clone your project
✅ Prepare the remote environment
✅ Deploy the Dockerized app
✅ Validate container health

---

## 🧾 Sample Output

```bash
[2025-10-21T04:29:40+0100] [INFO] Collecting input parameters...
[2025-10-21T04:29:45+0100] [INFO] Cloning repository from GitHub...
[2025-10-21T04:29:52+0100] [INFO] Preparing remote environment...
[2025-10-21T04:30:20+0100] [INFO] Running Docker container...
[2025-10-21T04:30:41+0100] [INFO] Deployment completed successfully.
```

Browser Output:

```
🚀 StackDeployer: Automated Docker Deployment Successful!
```

---

## 🔍 Logs

Every deployment run generates a detailed log in the `logs/` directory, with timestamps and exit codes.

Example:

```
logs/deploy_20251021_0429.log
```

These logs include:

* Input collection
* Command execution details
* Error messages (if any)
* Timestamps for each phase

---

## 🧹 Cleanup Mode

To safely remove both remote and local deployment artifacts, run:

```bash
./deploy.sh -cleanup
```

It will:

* Prompt for confirmation
* Stop and remove remote Docker containers
* Delete the remote project directory
* Remove local cloned files

---

## 🌐 Deployment Verification

To confirm successful deployment, open your EC2 instance’s public IP in a browser:

```
http://<your-ec2-ip>/
```

You should see:
**🚀 StackDeployer: Automated Docker Deployment Successful!**

---

## 🧩 Compliance with Stage 1 Requirements

| Requirement                         | Status          | Notes                                |
| ----------------------------------- | --------------- | ------------------------------------ |
| Bash script with error handling     | ✅               | Implemented with `set -euo pipefail` |
| PAT authentication for GitHub clone | ✅               | Used in `clone_or_update_repo()`     |
| Remote server provisioning          | ✅               | Via SSH automation                   |
| Docker installation                 | ✅               | Automated if missing                 |
| Docker Compose installation         | ✅               | Installed on demand                  |
| Nginx reverse proxy setup           | ✅ (Pre-enabled) | Server already had Nginx running     |
| Logging and error management        | ✅               | Implemented via `log()` and `die()`  |
| Cleanup option                      | ✅               | Triggered with `-cleanup` flag       |
| Secure SSH-based deployment         | ✅               | All remote actions use `ssh`/`rsync` |

---

## 🧾 Example Directory Structure

```
stackdeployer/
├── deploy.sh
├── .env (excluded)
├── .gitignore
├── README.md
└── logs/
    └── deploy_20251021_0429.log
```

---

## 🧰 Tech Stack

* **Language:** Bash
* **Deployment:** Docker / Docker Compose
* **Server:** AWS EC2 (Ubuntu 24.04 LTS)
* **Logging:** Native Bash logging with timestamps
* **Version Control:** Git + GitHub PAT authentication

---

## 📄 License

Licensed under the **MIT License**.
Feel free to modify and use in your own DevOps workflows.

---

## 👨‍💻 Author

**Ibrahim Yusuf (Tory)**
President – NACSS Osun State University
Certified in Cybersecurity (ISC² CC) | SC-200 | Cloud & DevSecOps Enthusiast

GitHub: [@KoredeSec](https://github.com/KoredeSec)
Medium: [Ibrahim Yusuf](https://medium.com/@KoredeSec)
X(Twitter): [@KoredeSec](https://x.com/KoredeSec)


---
