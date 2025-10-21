
---

# 🚀 StackDeployer

**Automated Docker Deployment Script**

StackDeployer is a **Bash automation framework** built to streamline the process of deploying **Dockerized applications** onto a **remote Linux server** using a single command.
This script eliminates repetitive setup steps — automating Git repository cloning, remote server preparation, Docker installation, container deployment, and log validation.

---

## 🧠 Project Overview

This project was developed as part of the **HNG DevOps Stage 1 Task**, which focused on building a **production-ready Bash script** capable of:

* Collecting user inputs (GitHub repo, branch, SSH details, PAT)
* Installing Docker and Docker Compose (if missing)
* Authenticating via **Personal Access Token (PAT)**
* Deploying the project to a remote Linux server
* Configuring and validating the running application
* Handling errors, logs, and cleanup actions gracefully

The end result is a **fully automated deployment pipeline**, capable of running anywhere Bash and SSH are supported.

---

## 🧱 Architecture & Design Workflow

StackDeployer automates the full cycle of deploying a containerized application from a local environment to a remote Linux host (AWS EC2).
It follows a simple yet production-grade design pattern based on modular shell functions and environment-based configuration.


### 🔹 Core Workflow

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

## 🛠️ Setup Instructions

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
Cybersecurity & DevSecOps Enthusiast | HNG DevOps Intern

GitHub: [@KoredeSec](https://github.com/KoredeSec)
Medium: [Ibrahim Yusuf](https://medium.com/@KoredeSec)
X(Twitter): [@KoredeSec] (https://x.com/KoredeSec)


---
