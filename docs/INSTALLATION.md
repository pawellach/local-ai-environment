# Installation Guide

This guide walks you through installing the complete Local AI Environment stack on a clean Windows 11 laptop.

---

## Prerequisites

Verify these before running any scripts.

### Required

| Requirement | Minimum | Recommended | How to Check |
|-------------|---------|-------------|--------------|
| Windows | Windows 10 22H2 | Windows 11 | `winver` |
| PowerShell | 5.1 | 7.x | `$PSVersionTable.PSVersion` |
| Python | 3.11 | 3.12 | `python --version` |
| RAM | 8 GB | 16 GB+ | Task Manager → Performance |
| Disk (free) | 10 GB | 30 GB+ | `Get-PSDrive C` |
| Internet | Required for downloads | — | — |

### Optional

| Requirement | Purpose | Where to Get |
|-------------|---------|--------------|
| Git | Version control, cloning | https://git-scm.com/download/win |
| Docker Desktop | Phase 2: n8n deployment | https://www.docker.com/products/docker-desktop/ |
| NVIDIA GPU | Faster inference | Install CUDA drivers from nvidia.com |
| AMD GPU | Faster inference | Install ROCm drivers from amd.com |

### Installing Python

If Python is not installed or is older than 3.11:

1. Go to https://www.python.org/downloads/
2. Download the latest Python 3.11+ Windows installer (64-bit)
3. **Important:** During installation, check **"Add Python to PATH"**
4. Complete the installation
5. Open a new terminal and verify: `python --version`

---

## One-Time Setup

Run this once per user account on the target machine. It allows PowerShell to run local scripts.

```powershell
# Allow locally-written scripts to run (does not allow unsigned remote scripts)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify the change took effect
Get-ExecutionPolicy -Scope CurrentUser
# Expected output: RemoteSigned
```

If you see `Restricted`, run the command above and try again. You do not need Administrator rights for `-Scope CurrentUser`.

---

## Copy the Project to the Target Machine

### Option A: Git Clone

```powershell
git clone https://github.com/pawellach/local-ai-environment.git C:\Local-AI-Environment
cd C:\Local-AI-Environment
```

### Option B: Manual Copy

Copy the `Local-AI-Environment` folder to the target machine (USB drive, network share, etc.) and place it at a convenient path such as `C:\Local-AI-Environment`.

```powershell
# Navigate to the project folder
cd C:\Local-AI-Environment
```

All subsequent commands assume you are in the project root directory.

---

## Step-by-Step Execution

Run the scripts in order. Each script is idempotent — safe to re-run if something goes wrong.

---

### Step 1 — System Check

**Script:** `00-System-Check.ps1`  
**Purpose:** Audits hardware and detects which tools are already installed. Recommends which LLM model tier is appropriate for this machine.

```powershell
.\scripts\00-System-Check.ps1
# Optional: verbose hardware breakdown
.\scripts\00-System-Check.ps1 -Verbose
```

**Expected output:**
- Prints OS version, CPU, total RAM, GPU and VRAM
- Lists tool installation status (Git, Python, Node.js, Docker, Ollama, Open-WebUI)
- Displays a hardware tier recommendation: **Low / Medium / High**
- Saves `reports/system-report.json` and `reports/system-report.md`

**Success indicator:** "System check complete" with no red ERROR lines.

**If it fails:** Check that PowerShell execution policy is set (`RemoteSigned`). See TROUBLESHOOTING.md.

---

### Step 2 — Docker Audit

**Script:** `01-Docker-Audit.ps1`  
**Purpose:** Checks whether Docker is installed and, if so, audits all Docker resources (containers, images, volumes, networks, disk usage). Makes no changes.

```powershell
.\scripts\01-Docker-Audit.ps1
```

**Expected output:**
- If Docker is not installed: "Docker not installed — skipping audit." *(This is normal. Not an error.)*
- If Docker is installed: prints a summary table of containers, images, volumes, and disk usage
- Saves `reports/docker-audit.json` and `reports/docker-audit.md`

**Success indicator:** Script exits without red ERROR lines. Docker absence is a WARNING, not a FAIL.

---

### Step 3 — Docker Cleanup (Optional)

**Script:** `02-Docker-Clean.ps1`  
**Purpose:** Cleans up Docker resources to free disk space and prepare for a future fresh n8n deployment. Run this only if Docker is installed and you want to clean it.

Three modes are available:

```powershell
# AUDIT: show what exists, make no changes
.\scripts\02-Docker-Clean.ps1 -Mode AUDIT

# SAFE: remove stopped containers, dangling images, unused anonymous volumes
.\scripts\02-Docker-Clean.ps1 -Mode SAFE

# FULL: remove ALL unused Docker resources (containers, images, volumes, networks, build cache)
.\scripts\02-Docker-Clean.ps1 -Mode FULL
```

**FULL mode requires typing an explicit confirmation phrase:**
```
To confirm, type exactly: I CONFIRM DOCKER FULL CLEAN
```

**Before FULL mode runs:** the script shows every resource that will be deleted and estimates disk space recovered.

**DryRun flag:** see what FULL mode would delete without actually deleting anything:
```powershell
.\scripts\02-Docker-Clean.ps1 -Mode FULL -DryRun
```

**Success indicator:** `reports/docker-clean-summary.md` created with before/after comparison.

---

### Step 4 — Install Open-WebUI

**Script:** `03-Install-OpenWebUI.ps1`  
**Purpose:** Installs Open-WebUI via pip. Creates a convenience startup script. Verifies the installation.

```powershell
.\scripts\03-Install-OpenWebUI.ps1
# Preview what would happen without making changes:
.\scripts\03-Install-OpenWebUI.ps1 -DryRun
```

**Expected output:**
- Checks Python version (must be 3.11+)
- Checks if `open-webui` is already installed (idempotent — skips if already installed)
- Runs `pip install open-webui`
- Creates `Start-OpenWebUI.ps1` in the project root
- Saves `reports/openwebui-install-report.json` and `.md`

**Success indicator:** "Open-WebUI installed successfully" with version number displayed.

**If it fails:**
- Python not found → install Python 3.11+ from python.org
- Python too old → see TROUBLESHOOTING.md, item 10
- pip not found → run `python -m ensurepip --upgrade`
- `open-webui` command not found after install → PATH issue, see TROUBLESHOOTING.md, item 2

---

### Step 5 — Install Ollama

**Script:** `04-Install-Ollama.ps1`  
**Purpose:** Installs the Ollama LLM runtime. Tries winget first; falls back to direct download if winget is unavailable.

```powershell
.\scripts\04-Install-Ollama.ps1
# Preview without installing:
.\scripts\04-Install-Ollama.ps1 -DryRun
```

**Expected output:**
- Checks if Ollama is already installed (idempotent)
- Installs via `winget install --id Ollama.Ollama` or downloads `OllamaSetup.exe`
- Verifies the `ollama` CLI is accessible
- Checks that Ollama service is running on port 11434
- Verifies the Ollama REST API responds
- Saves `reports/ollama-install-report.json` and `.md`

**Success indicator:** "Ollama API responding at http://localhost:11434"

**If it fails:**
- `ollama` not recognized → restart terminal, or add to PATH (see TROUBLESHOOTING.md, item 3)
- Port 11434 not listening → Ollama service not started (see TROUBLESHOOTING.md, item 4)
- winget not available → script falls back to direct download automatically

---

### Step 6 — Select and Download a Local LLM

**Script:** `05-Configure-Local-LLM.ps1`  
**Purpose:** Selects an appropriate LLM model based on detected hardware, downloads it via Ollama, and runs a test inference to confirm it works.

```powershell
.\scripts\05-Configure-Local-LLM.ps1
# Specify a model directly (skip interactive selection):
.\scripts\05-Configure-Local-LLM.ps1 -ModelOverride "qwen2.5:7b"
# Non-interactive (auto-select first recommended model):
.\scripts\05-Configure-Local-LLM.ps1 -NonInteractive
# Preview what model would be selected:
.\scripts\05-Configure-Local-LLM.ps1 -DryRun
```

**Expected output:**
- Reads hardware tier from `reports/system-report.json` (or re-detects)
- Shows a table of recommended models with size and hardware requirements
- Prompts to confirm before downloading (can be large — 1–10 GB)
- Runs `ollama pull <model>` and shows download progress
- Runs a test inference: `ollama run <model> "Respond with exactly: TEST_OK"`
- Measures and displays response time
- Saves test results to `reports/llm-test-result.json`

**Success indicator:** Test inference returns "TEST_OK" and response time is printed.

**If it fails:**
- Ollama not running → run Step 5 first
- Download fails mid-way → retry; Ollama resumes partial downloads
- Out of memory → choose a smaller model from the Low tier

---

### Step 7 — Configure Open-WebUI ↔ Ollama

**Script:** `06-Configure-OpenWebUI.ps1`  
**Purpose:** Connects Open-WebUI to Ollama by setting the `OLLAMA_BASE_URL` environment variable and verifying end-to-end communication.

```powershell
.\scripts\06-Configure-OpenWebUI.ps1
# Custom Ollama URL (if you changed the default port):
.\scripts\06-Configure-OpenWebUI.ps1 -OllamaUrl "http://localhost:11434"
# Custom Open-WebUI port:
.\scripts\06-Configure-OpenWebUI.ps1 -OpenWebUIPort 3001
```

**Expected output:**
- Verifies Ollama is reachable
- Sets `OLLAMA_BASE_URL` as a user-level environment variable
- Optionally starts Open-WebUI (asks if not running)
- Waits up to 30 seconds for Open-WebUI to become available on port 3000
- Prints a connection summary:
  ```
  Ollama API:  http://localhost:11434  ✅ OK
  Open-WebUI:  http://localhost:3000   ✅ OK
  Browser URL: http://localhost:3000
  ```
- Saves `reports/openwebui-config-report.json` and `.md`

**Success indicator:** Both services show OK in the connection summary.

---

### Step 8 — Validate the Environment

**Script:** `07-Validate-Environment.ps1`  
**Purpose:** Runs a comprehensive 12-component validation check and produces a PASS/WARNING/FAIL report.

```powershell
.\scripts\07-Validate-Environment.ps1
# Skip the LLM inference test (faster):
.\scripts\07-Validate-Environment.ps1 -SkipLLMTest
```

**Expected output:** A validation table like:

```
Component              Status    Message
─────────────────────────────────────────────────
PowerShell             ✅ PASS   Version 5.1.x
Python 3.11+           ✅ PASS   Python 3.12.x
pip                    ✅ PASS   pip 24.x
Open-WebUI installed   ✅ PASS   open-webui 0.x.x
Ollama CLI             ✅ PASS   ollama 0.x.x
Ollama API             ✅ PASS   Responding at :11434
LLM model installed    ✅ PASS   qwen2.5:7b
LLM inference test     ✅ PASS   TEST_OK in 3.2s
Open-WebUI running     ✅ PASS   Responding at :3000
Open-WebUI API         ✅ PASS   /api/models OK
Docker                 ⚠️ WARN   Not installed (optional)
Git                    ✅ PASS   git 2.x.x
```

- Saves `reports/validation-report.json` and `reports/validation-report.md`
- Exit code 0 = all PASS (WARNINGs allowed); exit code 1 = at least one FAIL

---

### Step 9 — Generate Final Report

**Script:** `99-Generate-Report.ps1`  
**Purpose:** Reads all previously generated reports and compiles a single comprehensive summary.

```powershell
.\scripts\99-Generate-Report.ps1
```

**Expected output:**
- Reads all JSON reports from `reports/`
- Generates `reports/FINAL-ENVIRONMENT-REPORT.md`
- Prints a brief summary to console

Open `reports/FINAL-ENVIRONMENT-REPORT.md` in any Markdown viewer to see the complete environment snapshot.

---

## Mode Flags Reference

| Flag | Effect | Works With |
|------|--------|------------|
| `-DryRun` | Show what would happen; make no system changes | All scripts |
| `-NonInteractive` | Skip Y/N prompts; use safe defaults | All scripts |
| `-Verbose` | Print detailed step-by-step progress | All scripts |
| `-SkipLLMTest` | Skip LLM inference test (faster validation) | `07-Validate-Environment.ps1` |
| `-ModelOverride` | Specify exact Ollama model tag | `05-Configure-Local-LLM.ps1` |
| `-Mode` | AUDIT / SAFE / FULL | `02-Docker-Clean.ps1` |
| `-Port` | Override Open-WebUI port (default: 3000) | `03-Install-OpenWebUI.ps1` |
| `-OllamaUrl` | Override Ollama URL | `06-Configure-OpenWebUI.ps1` |

---

## Hardware Requirements

| Tier | RAM | GPU VRAM | Disk for Models | Example Models |
|------|-----|----------|-----------------|----------------|
| Low | 8 GB | 0 (CPU only) | ~2 GB | `qwen2.5:0.5b`, `phi4-mini` |
| Medium | 16 GB | 4–8 GB | 5–10 GB | `llama3.2:3b`, `gemma3:4b` |
| High | 32 GB+ | 8–16 GB+ | 10–20 GB | `qwen2.5:7b`, `phi4:14b` |

Model downloads are one-time. Once downloaded, models are stored in `%USERPROFILE%\.ollama\models\` and loaded from disk.

---

## Post-Installation Checklist

After running all scripts, verify the following:

- [ ] `07-Validate-Environment.ps1` shows all green (PASS) or only Docker WARNING
- [ ] `reports/FINAL-ENVIRONMENT-REPORT.md` generated successfully
- [ ] Browser opens **http://localhost:3000** and shows the Open-WebUI login page
- [ ] Created a local admin account in Open-WebUI (first-time setup)
- [ ] At least one model appears in the Open-WebUI model selector dropdown
- [ ] Sent a test message in Open-WebUI and received a response
- [ ] Ollama tray icon is visible in the Windows system tray

---

## Starting the Environment After a Reboot

Ollama starts automatically with Windows (runs as a background service). Open-WebUI does not start automatically — run the convenience script created in Step 4:

```powershell
cd C:\Local-AI-Environment
.\Start-OpenWebUI.ps1
```

Then open **http://localhost:3000** in your browser.

See `docs/OPERATIONS.md` for daily usage guidance.
