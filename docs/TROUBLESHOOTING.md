# Troubleshooting Guide

This guide covers the most common problems encountered when setting up or running the Local AI Environment on Windows 11.

For each problem: check the **Symptom** to confirm it matches your situation, then follow the **Solution** steps.

---

## Getting Logs First

Before investigating any issue, check the relevant logs:

- **Script logs** — `.\logs\<ScriptName>_<timestamp>.log`
  Each script creates a timestamped log file. Example: `logs\03-Install-OpenWebUI_20260906-143022.log`

- **Open-WebUI logs** — printed to the terminal where `open-webui serve` is running.
  If you used `Start-OpenWebUI.ps1`, the output appears in that PowerShell window.

- **Ollama logs** — `$env:LOCALAPPDATA\Ollama\ollama.log`
  ```powershell
  notepad "$env:LOCALAPPDATA\Ollama\ollama.log"
  ```

- **Validation report** — `.\reports\validation-report.md`
  Run `.\scripts\07-Validate-Environment.ps1` at any time to get a current health summary.

---

## Problem 1: PowerShell execution policy error

**Symptom:**
```
.\scripts\00-System-Check.ps1 : File ... cannot be loaded because running scripts is
disabled on this system.
```

**Cause:** Windows defaults to a restrictive execution policy that blocks local scripts.

**Solution:**
```powershell
# Run in PowerShell (no Administrator needed for CurrentUser scope)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify
Get-ExecutionPolicy -Scope CurrentUser
# Should print: RemoteSigned
```

If you need it system-wide (all users), open PowerShell as Administrator and run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

---

## Problem 2: 'open-webui' is not recognized as a command

**Symptom:**
```
open-webui : The term 'open-webui' is not recognized as the name of a cmdlet, function,
script file, or operable program.
```

**Cause:** pip installs scripts into a `Scripts` directory that is not in your system PATH. This is a common Windows Python issue.

**Solution:**

Step 1 — Find the correct Scripts directory:
```powershell
python -c "import sys; print(sys.prefix + r'\Scripts')"
# Example output: C:\Users\YourName\AppData\Local\Programs\Python\Python312\Scripts
```

Step 2 — Add it to your user PATH:
1. Press `Win + R`, type `sysdm.cpl`, press Enter
2. Click **Advanced** tab → **Environment Variables**
3. Under **User variables**, select **Path** → click **Edit**
4. Click **New** → paste the Scripts path from Step 1
5. Click OK three times

Step 3 — Open a **new** PowerShell window (PATH changes don't apply to existing windows):
```powershell
open-webui --version
```

**Alternative:** Run Open-WebUI without PATH fix:
```powershell
python -m open_webui serve --port 3000
```

---

## Problem 3: 'ollama' is not recognized as a command

**Symptom:**
```
ollama : The term 'ollama' is not recognized...
```

**Cause:** Ollama was just installed and the PATH change has not taken effect in the current terminal session, or Ollama was installed per-user and its directory is not in PATH.

**Solution:**

Step 1 — Close and reopen PowerShell. Most of the time, this is sufficient.

Step 2 — If still not found, check the default install location:
```powershell
$ollamaPath = "$env:LOCALAPPDATA\Programs\Ollama"
Test-Path $ollamaPath
# If True, add to PATH:
[System.Environment]::SetEnvironmentVariable(
    "Path",
    "$([System.Environment]::GetEnvironmentVariable('Path','User'));$ollamaPath",
    "User"
)
```

Step 3 — Open a new terminal and verify:
```powershell
ollama --version
```

---

## Problem 4: Ollama API not responding (port 11434 closed)

**Symptom:**
- `07-Validate-Environment.ps1` reports `❌ FAIL` for Ollama API
- `Test-NetConnection localhost 11434` returns `TcpTestSucceeded: False`
- Browser shows "Connection refused" at http://localhost:11434

**Cause:** The Ollama service is not running. Ollama auto-starts with Windows after the first reboot post-install, but may not have started yet after initial installation.

**Solution:**

Option A — Use the system tray icon:
- Look for the Ollama llama icon in the Windows system tray (bottom-right)
- Double-click it or right-click → **Start** / **Resume**

Option B — Start Ollama manually from terminal:
```powershell
# Run in a separate terminal window (this is a blocking process)
ollama serve
```

Option C — Check if Ollama Windows service exists:
```powershell
Get-Service ollama -ErrorAction SilentlyContinue
Start-Service ollama
```

After starting Ollama, wait ~5 seconds and verify:
```powershell
Invoke-RestMethod http://localhost:11434
# Expected: "Ollama is running"
```

---

## Problem 5: Open-WebUI shows "Connection Error" / cannot reach Ollama

**Symptom:** Open-WebUI loads in the browser at http://localhost:3000, but the model selector is empty or shows "Connection Error" when trying to chat.

**Cause:** `OLLAMA_BASE_URL` environment variable is missing or incorrect, or Ollama is not running.

**Solution:**

Step 1 — Verify Ollama is running:
```powershell
Invoke-RestMethod http://localhost:11434
# Should return: "Ollama is running"
```

Step 2 — Check the environment variable:
```powershell
[System.Environment]::GetEnvironmentVariable("OLLAMA_BASE_URL", "User")
# Should return: http://localhost:11434
```

Step 3 — Set it if missing:
```powershell
[System.Environment]::SetEnvironmentVariable("OLLAMA_BASE_URL", "http://localhost:11434", "User")
```

Step 4 — **Restart Open-WebUI** (the new env var only takes effect for new processes):
```powershell
# Stop existing Open-WebUI process
Get-Process -Name "open-webui","uvicorn","python" -ErrorAction SilentlyContinue | 
    Where-Object { $_.CommandLine -like "*open_webui*" } | 
    Stop-Process -Force

# Start again
.\Start-OpenWebUI.ps1
```

Step 5 — Re-run the configuration script:
```powershell
.\scripts\06-Configure-OpenWebUI.ps1
```

---

## Problem 6: Model download is very slow or fails mid-download

**Symptom:**
- `ollama pull <model>` shows very low speed or stops
- Download percentage gets stuck
- Error message about connection or disk

**Cause A:** Slow internet connection (models are 1–10 GB).  
**Cause B:** Insufficient disk space.  
**Cause C:** Temporary server-side issue with Ollama's model registry.

**Solution for Cause A:** Be patient. Ollama resumes partial downloads automatically:
```powershell
# Just re-run the pull — it will continue from where it stopped
ollama pull qwen2.5:7b
```

**Solution for Cause B — Check disk space:**
```powershell
Get-PSDrive C | Select-Object Name, Used, Free
# Free should be at least 10 GB
```
Free space by removing large files, or choose a smaller model:
```powershell
ollama pull qwen2.5:0.5b   # Only ~400 MB
```

**Solution for Cause C:** Wait a few minutes and retry.

---

## Problem 7: System freezes or runs out of memory when using a model

**Symptom:** Machine becomes unresponsive after starting a model. High RAM/swap usage in Task Manager. Fan noise. Model response is extremely slow or system locks up.

**Cause:** The selected model requires more RAM than available. Ollama loads the full model into memory (or VRAM) at inference time.

**Solution:**

Step 1 — Check available RAM:
```powershell
$mem = Get-CimInstance Win32_OperatingSystem
"Free: $([math]::Round($mem.FreePhysicalMemory / 1MB, 1)) GB of $([math]::Round($mem.TotalVisibleMemorySize / 1MB, 1)) GB"
```

Step 2 — Remove the oversized model:
```powershell
ollama rm qwen2.5:7b   # Replace with your model name
```

Step 3 — Install a smaller model:
```powershell
ollama pull qwen2.5:1.5b   # ~1 GB, runs on 4 GB RAM
ollama pull phi4-mini       # ~2.5 GB, very capable for its size
```

Step 4 — Re-run model configuration:
```powershell
.\scripts\05-Configure-Local-LLM.ps1
```

---

## Problem 8: GPU not used — Ollama runs on CPU only

**Symptom:** Inference is very slow (1-2 tokens/second). Ollama output or logs say "using CPU" or GPU utilization stays at 0%.

**Cause:** GPU drivers missing or incompatible, or GPU VRAM is insufficient for the model.

**Solution for NVIDIA GPUs:**
1. Install the latest NVIDIA drivers from https://www.nvidia.com/drivers
2. Verify CUDA is working: `nvidia-smi` (should show GPU utilization table)
3. Restart Ollama (`ollama serve`) — it will auto-detect CUDA on next start

**Solution for AMD GPUs:**
1. Install ROCm-compatible drivers from https://www.amd.com/support
2. Ollama has experimental ROCm support — consult https://github.com/ollama/ollama for current status

**Verify GPU is being used:**
```powershell
# Watch GPU memory usage in Task Manager → Performance → GPU
# Or with PowerShell:
(Get-CimInstance Win32_VideoController | Select-Object -First 1).AdapterRAM / 1GB
```

**Note:** If model size > GPU VRAM, Ollama will use CPU+RAM as fallback. This is expected behavior, not an error.

---

## Problem 9: Docker not running when audit scripts check it

**Symptom:** `01-Docker-Audit.ps1` or `07-Validate-Environment.ps1` shows Docker as WARNING.

**Cause:** Docker Desktop is not installed or not running. Docker is **optional** for Phase 1.

**Solution:** Docker is not needed for the AI stack (Open-WebUI + Ollama). The WARNING is expected and can be ignored until Phase 2 (n8n deployment).

If you want Docker running:
1. Open Docker Desktop from the Start menu
2. Wait for it to finish starting (whale icon in system tray becomes steady)
3. Verify: `docker ps` should return an empty table (not an error)

---

## Problem 10: Python version too old (< 3.11)

**Symptom:**
```
ERROR: Python 3.11 or newer is required. Found: 3.9.x
```
Or `pip install open-webui` fails with package compatibility errors.

**Cause:** An older Python version is installed.

**Solution:**

Step 1 — Check all installed Python versions:
```powershell
py --list-paths   # Python Launcher (Windows)
# Or:
where python
```

Step 2 — Install Python 3.11+:
- Download from https://www.python.org/downloads/
- Run the installer, checking **"Add to PATH"**
- If you have multiple versions, use the Python Launcher:
  ```powershell
  py -3.12 --version   # Use explicit version
  py -3.12 -m pip install open-webui
  ```

Step 3 — Verify:
```powershell
python --version   # Should show 3.11.x or higher
```

---

## Problem 11: pip not found or pip command fails

**Symptom:**
```
pip : The term 'pip' is not recognized...
```
Or:
```
ERROR: Could not find a version that satisfies the requirement open-webui
```

**Cause:** pip is not installed, or the `Scripts` directory is not in PATH.

**Solution:**

Step 1 — Bootstrap pip:
```powershell
python -m ensurepip --upgrade
python -m pip install --upgrade pip
```

Step 2 — Use `python -m pip` instead of bare `pip`:
```powershell
python -m pip install open-webui
```

Step 3 — If pip is found but install fails, check for proxy or certificate issues:
```powershell
python -m pip install open-webui --trusted-host pypi.org --trusted-host files.pythonhosted.org
```

---

## Problem 12: Port 3000 or 11434 already in use

**Symptom:**
```
ERROR: Address already in use: 0.0.0.0:3000
```
Or Open-WebUI / Ollama fails to start silently.

**Cause:** Another application is using the same port. Common culprits: a previous crashed instance, another web server, or a development tool.

**Solution:**

Step 1 — Find what is using the port:
```powershell
# Replace 3000 with 11434 for Ollama
netstat -ano | findstr :3000
# Note the PID in the last column (e.g., 12345)

# Identify the process
Get-Process -Id 12345
```

Step 2 — Stop the conflicting process:
```powershell
Stop-Process -Id 12345 -Force
```

Step 3 — If you cannot stop it, use an alternate port for Open-WebUI:
```powershell
# Start on port 3001 instead
open-webui serve --port 3001
# Then access at http://localhost:3001
```

Update `config/environment.psd1` to change the default:
```powershell
OpenWebUIPort = 3001
```

---

## Problem 13: Scripts fail with "Access Denied" or "UnauthorizedAccessException"

**Symptom:**
```
Access to the path 'C:\...' is denied.
```
Or installer scripts fail partway through.

**Cause:** Some operations (installing system-wide software, writing to protected paths) require Administrator privileges.

**Solution:**

Step 1 — Open PowerShell as Administrator:
1. Press `Win + X`
2. Select **Windows PowerShell (Admin)** or **Terminal (Admin)**
3. Navigate back to the project: `cd C:\Local-AI-Environment`
4. Re-run the failing script

**Scripts that may need Administrator:**
- `03-Install-OpenWebUI.ps1` — pip install (usually not needed for user-scope Python)
- `04-Install-Ollama.ps1` — winget install or .exe installer

**Scripts that do NOT need Administrator:**
- `00-System-Check.ps1` — read-only
- `01-Docker-Audit.ps1` — read-only
- `06-Configure-OpenWebUI.ps1` — sets user-scope env variable
- `07-Validate-Environment.ps1` — read-only

**Note:** If pip was installed per-user (default on Windows), `pip install open-webui` does NOT require Administrator. Running as Admin may install to a different Python environment than your user Python — this can cause the `open-webui` command to not be found in your normal terminal. Prefer running `pip install` as your normal user.
