# Project Review

Architecture decisions, assumptions, risks, and recommendations for the Local AI Environment project.

---

## Architecture Decisions

### PowerShell as the Automation Layer

PowerShell 5.1 is pre-installed on all Windows 11 machines — no package managers, no runtime downloads, no PATH complications before the first script runs. It has native access to Windows APIs via CIM (Win32_OperatingSystem, Win32_VideoController, etc.), which are the most reliable way to detect hardware on Windows. Alternatives considered:

| Alternative | Reason not chosen |
|-------------|-----------------|
| Batch (.bat) | No structured data types, poor error handling |
| Python script | Requires Python to be pre-installed — circular dependency |
| Go / Rust binary | Requires compilation toolchain |
| Node.js script | Requires Node to be pre-installed |

PowerShell allows full module system, rich type system, and idiomatic Windows tooling (winget, Get-CimInstance, Set-ExecutionPolicy).

### pip for Open-WebUI

The official Open-WebUI documentation recommends `pip install open-webui` for Windows installations without Docker. This keeps the setup simpler than Docker for Phase 1:

- No Docker Desktop overhead (~500MB RAM)
- No container networking quirks (localhost is actual localhost)
- Easier debugging (direct Python process, no container abstraction)
- Python 3.11+ is a single prerequisite

**Tradeoff:** Requires Python 3.11+ to be installed. The install script (`03-Install-OpenWebUI.ps1`) checks the version, shows a clear download link if it is missing, and exits cleanly.

Open-WebUI is **not** registered as a Windows Service in Phase 1. This is intentional — keeping it manual means the user controls when it runs, there is no background RAM usage when not needed, and there are no service permission issues. Phase 2 can add NSSM-based service registration if desired.

### winget → Direct Download Fallback for Ollama

winget (`Windows Package Manager`) is built into Windows 11 and provides a clean, verified install path for Ollama. The fallback to downloading `OllamaSetup.exe` directly from the official URL handles edge cases:
- Older Windows 10 without winget
- Corporate machines where winget is blocked
- winget database temporarily unavailable

The fallback URL (`https://ollama.ai/download/OllamaSetup.exe`) is the official download link. If Ollama changes this URL in the future, update `04-Install-Ollama.ps1` or the `environment.psd1` config.

### Modules Separate from Scripts

Each of the five modules (`Logging`, `System`, `Docker`, `Validation`, `Configuration`) has a single responsibility and can be:
- Imported independently in any script
- Tested in isolation with Pester
- Updated without touching any script file
- Reused in future scripts (Phase 2, 3, ...)

Scripts are thin orchestrators — they import modules, call functions, collect results, and save reports. Business logic lives in modules.

### Docker Deferred to Phase 2

Open-WebUI and Ollama work better natively on Windows than in Docker. Reasons to keep Phase 1 Docker-free:

1. **Resource contention:** Docker Desktop uses ~500MB RAM as a baseline. Combined with an LLM model (4-10GB), a lower-spec machine may struggle.
2. **Networking:** Native Python services use `localhost` reliably. Docker containers require `host.docker.internal` or custom network configuration, which adds complexity and failure modes.
3. **Simplicity:** Phase 1 has one goal — working local AI. Fewer moving parts means fewer things to debug.
4. **Separation of concerns:** Docker is reserved for n8n, where containerization genuinely adds value (easy updates, data volume isolation, restart policies).

### Typed Confirmation for Destructive Operations

The Docker FULL clean mode requires the user to type "I CONFIRM DOCKER FULL CLEAN" rather than pressing Y. This prevents:
- Accidental confirmation from pressing Enter on a prompt
- Scripts in non-interactive mode accidentally deleting data
- Misunderstanding what FULL mode actually removes

The `Configuration.psm1` module provides `Confirm-DestructiveOperation` for consistent behavior across all scripts.

### Idempotent Scripts

Every script checks current state before taking action. Re-running a script after a partial failure or after updating a component is always safe. This design choice:
- Reduces user anxiety ("will this break something if I run it twice?")
- Simplifies error recovery ("just re-run the script that failed")
- Supports update workflows (re-run to check for newer versions)

---

## Assumptions

| Assumption | Impact if Wrong |
|-----------|----------------|
| Windows 11 (or Win 10 22H2+) | CIM classes may differ; test on actual machine |
| Python 3.11+ available | Script `03` exits and shows download link — user must install manually |
| Internet access for downloads | Scripts fail gracefully; some have local-check-only modes |
| Machine has ≥8GB RAM | Low-tier models work, but performance may be slow |
| No existing conflicting services on ports 3000, 11434 | Scripts check and warn but do not automatically resolve conflicts |
| winget available (Windows 11 default) | Falls back to direct download — should work on all Windows versions |
| Antivirus allows Python/Ollama installation | No mitigation; user must whitelist if blocked |

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Python version too old | Medium | High — Open-WebUI won't install | Script checks, shows download link, exits |
| pip Scripts dir not in PATH | High | Medium — `open-webui` command not found | Script detects and shows PATH fix instructions |
| Ollama installer URL changes | Low | Medium — install fails | winget preferred (ID-based, stable); URL is a fallback |
| Model download interrupted | Medium | Low — Ollama resumes partial downloads | Ollama handles this natively |
| Model too large for RAM | Medium | High — system freezes | Hardware tier detection prevents this if user follows recommendations |
| Port conflict (3000 or 11434) | Low | Medium — service won't start | Scripts detect with Test-PortListening, show instructions |
| Docker data loss during clean | Low | High — irreversible | FULL mode requires typed phrase + saves before-state JSON |
| Open-WebUI pip package renamed | Very Low | High — install script breaks | Use `pip show open-webui` to detect; update script if needed |
| Antivirus blocks installer | Medium | High — can't install | No automated mitigation; document in TROUBLESHOOTING.md |

---

## Unresolved Questions

Verify these on the target laptop **before running any scripts**:

1. **Python version:** `python --version` or `py --version`
   - Need: 3.11.x or higher
   - If missing: download from https://www.python.org/downloads/ (check "Add to PATH")

2. **winget availability:** `winget --version`
   - Windows 11: usually present; if missing, install "App Installer" from Microsoft Store

3. **Available RAM:** `(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB`
   - Determines which model tier is appropriate

4. **GPU and VRAM:** `Get-CimInstance Win32_VideoController | Select-Object Name, AdapterRAM`
   - Determines whether GPU acceleration is available
   - NVIDIA: need CUDA-compatible drivers; AMD: need ROCm-compatible drivers

5. **Available disk space:** `(Get-PSDrive C).Free / 1GB`
   - Models range from 400MB (qwen2.5:0.5b) to 9GB (phi4:14b)
   - Recommend at least 20GB free for comfortable operation

6. **Docker Desktop installed?** `docker --version`
   - If yes: existing containers and images may be present — run audit first
   - If no: Docker is optional for Phase 1

7. **Existing Ollama?** `ollama --version`
   - If yes: script will skip reinstall (idempotent), but check for version conflicts

8. **Port availability:**
   ```powershell
   Test-NetConnection -Port 3000 -ComputerName localhost -InformationLevel Quiet
   Test-NetConnection -Port 11434 -ComputerName localhost -InformationLevel Quiet
   # Both should return False (ports free)
   ```

9. **Corporate/MDM restrictions?**
   - Can the user install Python executables?
   - Is PowerShell execution policy already RemoteSigned?
   - Is winget available and unrestricted?

10. **Antivirus software?**
    - Defender (built-in): generally fine, may show SmartScreen warning for Ollama installer
    - Third-party AV: may block Python or Ollama — check exclusions if needed

---

## Security Considerations

### Network Exposure
All services (`Open-WebUI`, `Ollama`) bind to `localhost` / `127.0.0.1` by default. They are not accessible from other machines on the local network. The scripts do not change this default.

### Credential Storage
- No API keys are used in Phase 1 — fully local stack
- Open-WebUI stores its local user credentials in its own data directory (encrypted)
- No secrets are written to script files, config files, logs, or reports
- `.gitignore` prevents accidental commit of sensitive files

### Destructive Operations
- All Docker operations require explicit user confirmation
- FULL mode requires typing a specific phrase
- A before-state JSON snapshot is saved before FULL clean
- Scripts never delete files outside the Docker environment

### Logs
- Logs are plain text, written to `.\logs\`
- Scripts are designed to avoid logging sensitive values (passwords, tokens, API responses)
- Logs are excluded from git via `.gitignore`

### Open-WebUI First Run
On first access to http://localhost:3000, the user creates a local admin account. This account has no connection to any external service. Conversations are stored locally.

---

## Known Limitations

| Limitation | Notes |
|-----------|-------|
| Open-WebUI not registered as Windows Service | Requires manual start via `Start-OpenWebUI.ps1` or terminal |
| No automatic model update notifications | User must check manually or re-run `05-Configure-Local-LLM.ps1` |
| Tests directory is empty | Pester tests not yet written |
| Phase 2+ scripts not yet implemented | See `docs/ROADMAP.md` |
| No GUI | Command-line only; a simple HTML status dashboard is planned |
| Single-user Open-WebUI | Multi-user setup is possible but not documented here |

---

## Future Development Recommendations

Priority order based on user impact:

1. **Windows Service for Open-WebUI** — highest friction point for daily use. Use NSSM (Non-Sucking Service Manager) or PowerShell `New-Service` with a wrapper. Script: `Register-OpenWebUI-Service.ps1`.

2. **Pester test suite** — add to `tests/` directory. Cover all module functions. Run with: `Invoke-Pester`. This catches regressions when updating modules.

3. **Phase 2: n8n deployment** — see `docs/DOCKER-N8N-PLAN.md`. Next logical step after Phase 1 is stable.

4. **Model benchmarking script** — measure tokens/second for installed models on the actual hardware. Helps users make informed model selection decisions. Save results to `reports/benchmark-report.md`.

5. **One-command full install** — `.\Install-All.ps1` that runs scripts 00–07 in order with sensible defaults. Good for fresh installs or recovery scenarios.

6. **WinGet manifest** — submit Ollama and Open-WebUI to winget repository (if not already there) for reproducible installs.

7. **HTML status dashboard** — single-file `dashboard.html` in `reports/` that reads JSON reports and shows component statuses. No server needed — just open in browser.

8. **Backup/restore script** — `Backup-LocalAI.ps1` that saves Open-WebUI data directory and list of installed models to a zip file. `Restore-LocalAI.ps1` to restore.
