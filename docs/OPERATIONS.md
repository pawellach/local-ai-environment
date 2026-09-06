# Operations Guide

Daily usage, model management, and maintenance for the Local AI Environment.

---

## Starting the Environment

### Ollama

Ollama installs a system tray application that starts automatically with Windows. If it is not running:

```powershell
# Start Ollama service (runs in background, binds to localhost:11434)
ollama serve
```

Or double-click the Ollama icon in the Start menu. Look for the llama icon in the system tray to confirm it is running.

Verify Ollama is up:

```powershell
Invoke-RestMethod http://localhost:11434
# Expected: "Ollama is running"
```

### Open-WebUI

Open-WebUI does not run automatically. Start it using the convenience script created during installation:

```powershell
cd C:\Local-AI-Environment
.\Start-OpenWebUI.ps1
```

Or start manually:

```powershell
# Set Ollama endpoint, then start Open-WebUI
$env:OLLAMA_BASE_URL = "http://localhost:11434"
open-webui serve
```

Default port is **3000**. To use a different port:

```powershell
open-webui serve --port 3001
```

Open the browser at: **http://localhost:3000**

### First Launch

On first visit to http://localhost:3000, you will be prompted to create an admin account. This account is stored locally — no cloud registration required.

---

## Checking System Health

Run the validation script whenever something feels wrong or after updates:

```powershell
.\scripts\07-Validate-Environment.ps1
```

This checks all 12 components and shows a table with **✅ PASS**, **⚠️ WARNING**, or **❌ FAIL** for each.

For detailed output:

```powershell
.\scripts\07-Validate-Environment.ps1 -Verbose
```

To skip the slow LLM inference test:

```powershell
.\scripts\07-Validate-Environment.ps1 -SkipLLMTest
```

Results are saved to `reports/validation-report.md`.

---

## Managing Models

### Command Reference

| Operation | Command |
|-----------|---------|
| List installed models | `ollama list` |
| Download a model | `ollama pull qwen2.5:7b` |
| Remove a model | `ollama rm qwen2.5:7b` |
| Run model interactively | `ollama run qwen2.5:7b` |
| Show model details | `ollama show qwen2.5:7b` |
| Copy/rename a model | `ollama cp qwen2.5:7b my-custom-name` |

### Recommended Models by Use Case

| Use Case | Recommended Model | Notes |
|----------|------------------|-------|
| General chat (fast) | `qwen2.5:1.5b` | 1GB, works on low RAM |
| General chat (quality) | `qwen2.5:7b` | 5GB, needs 16GB RAM |
| Coding assistant | `qwen2.5:7b` or `phi4:latest` | Strong code generation |
| Fast responses | `qwen2.5:0.5b` | 400MB, CPU-friendly |
| Best reasoning | `phi4:14b` | 9GB, needs 32GB RAM |
| Multilingual | `qwen2.5:7b` | Excellent non-English support |

### Downloading a New Model

```powershell
# Re-run the model configuration script for guided selection
.\scripts\05-Configure-Local-LLM.ps1

# Or pull directly if you know the model tag
ollama pull llama3.2:3b
```

The script shows estimated download size and hardware requirements before pulling.

### Interactive Model Testing

```powershell
# Start a chat session with any installed model
ollama run qwen2.5:7b

# Type your message and press Enter
# Type /bye to exit
```

---

## Using Open-WebUI

### Web Interface

Open http://localhost:3000 in any browser.

Key features:
- **Model selector** — dropdown at top of chat window; lists all Ollama models
- **New conversation** — click the pencil icon or press Ctrl+Shift+O
- **System prompt** — click the settings icon on any conversation
- **Conversation history** — left sidebar, saved locally

### Managing Models from the UI

1. Click your avatar (top right) → **Settings**
2. Go to **Models**
3. Under "Pull a model from Ollama.com", type the model tag (e.g., `gemma3:4b`) and click the download button
4. Installed models appear in the model selector immediately

### Open-WebUI API

Open-WebUI exposes an OpenAI-compatible REST API at `http://localhost:3000/api/`. This means any tool that supports OpenAI API format can use it locally:

```powershell
# Example: list available models
Invoke-RestMethod http://localhost:3000/api/models

# Example: chat completion
$body = @{
    model = "qwen2.5:7b"
    messages = @(@{ role = "user"; content = "Hello" })
} | ConvertTo-Json

Invoke-RestMethod -Method POST -Uri http://localhost:3000/api/chat/completions `
    -ContentType "application/json" -Body $body
```

### Data Storage

Open-WebUI stores conversations, settings, and user accounts in:
```
$env:APPDATA\open-webui\   (typical location)
```

---

## Updating Components

### Update Open-WebUI

```powershell
pip install --upgrade open-webui

# Verify new version
open-webui --version
```

Restart Open-WebUI after updating.

### Update Ollama

Re-run the install script — it detects the existing version and upgrades:

```powershell
.\scripts\04-Install-Ollama.ps1
```

Or download the latest installer from https://ollama.ai/download and run it.

### Update a Model

Ollama models are versioned. Pull again to get the latest:

```powershell
ollama pull qwen2.5:7b   # downloads only changed layers
```

### Update All Installed Models

```powershell
# List all installed models and pull each
ollama list | Select-String -Pattern "^\S+" | ForEach-Object {
    $model = $_.Matches[0].Value
    Write-Host "Updating $model..."
    ollama pull $model
}
```

---

## Stopping the Environment

### Stop Open-WebUI

- Press **Ctrl+C** in the terminal where `open-webui serve` is running
- Or close the PowerShell/terminal window

### Stop Ollama

- Right-click the llama icon in the system tray → **Quit Ollama**
- Or from PowerShell:

```powershell
# If running as a service
Stop-Service Ollama -ErrorAction SilentlyContinue

# If running as a process
Get-Process | Where-Object { $_.Name -like "*ollama*" } | Stop-Process
```

---

## Viewing Logs

### Script Logs

Each script creates a timestamped log file:

```
.\logs\00-System-Check_2026-09-06_143022.log
.\logs\03-Install-OpenWebUI_2026-09-06_144501.log
```

Format: `[YYYY-MM-DD HH:mm:ss] [LEVEL] Message`

To view the latest log for a script:

```powershell
Get-ChildItem .\logs\ | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

### Open-WebUI Logs

Logs are printed to the terminal where `open-webui serve` is running. There is no separate log file by default.

### Ollama Logs

```powershell
# View Ollama log file
Get-Content "$env:LOCALAPPDATA\Ollama\ollama.log" -Tail 50

# Follow in real time
Get-Content "$env:LOCALAPPDATA\Ollama\ollama.log" -Wait -Tail 20
```

---

## Re-running Scripts

All scripts are idempotent — safe to re-run at any time. They check existing state before taking action:

- If a tool is already installed at the correct version → skip install
- If a model is already downloaded → skip download
- If configuration is already correct → skip configuration

Re-run the relevant script after any of these situations:
- After a failed installation (fix the error, re-run)
- After updating Windows or Python
- After moving the project to a new location
- When adding a new model

---

## Reports

Reports are saved in `.\reports\` after each script run:

| File | Generated by |
|------|-------------|
| `system-report.json` / `.md` | 00-System-Check |
| `docker-audit.json` / `.md` | 01-Docker-Audit |
| `docker-before-clean.json` | 02-Docker-Clean (FULL mode) |
| `docker-after-clean.json` | 02-Docker-Clean |
| `openwebui-install-report.json` / `.md` | 03-Install-OpenWebUI |
| `ollama-install-report.json` / `.md` | 04-Install-Ollama |
| `llm-config-report.json` / `.md` | 05-Configure-Local-LLM |
| `openwebui-config-report.json` / `.md` | 06-Configure-OpenWebUI |
| `validation-report.json` / `.md` | 07-Validate-Environment |
| `FINAL-ENVIRONMENT-REPORT.md` | 99-Generate-Report |

Generate a fresh final report at any time:

```powershell
.\scripts\99-Generate-Report.ps1
```
