# Local AI Environment

Modular PowerShell toolkit to prepare a Windows laptop as a local AI development environment.

## Architecture

```
Windows
  └── Open-WebUI (port 3000)   ← browser interface + API gateway
        └── Ollama (port 11434) ← local model runtime
              └── LLM model     ← qwen2.5, phi4, llama3.x, gemma3, …

  (separate, prepared for future use)
  └── Docker
        └── n8n (port 5678)    ← Phase 2: local automation platform
```

Open-WebUI and Ollama are installed natively (no Docker). Docker is audited/cleaned separately to be ready for the n8n phase.

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Windows 10/11 (64-bit) | |
| PowerShell 5.1+ | Built into Windows |
| Python 3.11+ | Required for Open-WebUI (`pip install open-webui`) |
| Internet access | Required during installation only |
| ~10 GB free disk | Minimum for a small model |

## Quick Start — Execution Order

Run from the project root in a PowerShell session (no elevated privileges required for most steps; Ollama installer may prompt for admin):

```powershell
# 1. Audit your system
.\scripts\00-System-Check.ps1

# 2. Audit existing Docker environment (safe, no changes)
.\scripts\01-Docker-Audit.ps1

# 3. (Optional) Clean Docker for future n8n use
.\scripts\02-Docker-Clean.ps1 -Mode SAFE

# 4. Install Open-WebUI
.\scripts\03-Install-OpenWebUI.ps1

# 5. Install Ollama
.\scripts\04-Install-Ollama.ps1

# 6. Download and configure a local LLM model
.\scripts\05-Configure-Local-LLM.ps1

# 7. Connect Open-WebUI to Ollama
.\scripts\06-Configure-OpenWebUI.ps1

# 8. Validate the full environment
.\scripts\07-Validate-Environment.ps1

# 9. Generate final summary report
.\scripts\99-Generate-Report.ps1
```

## Script Modes

Most scripts support these common parameters:

| Parameter | Description |
|-----------|-------------|
| `-DryRun` | Show what would be done; make no changes |
| `-NonInteractive` | Skip all confirmation prompts (use safe defaults) |
| `-Verbose` | Extra diagnostic output |

`02-Docker-Clean.ps1` also accepts `-Mode AUDIT|SAFE|FULL`.

## Directory Structure

```
Local-AI-Environment/
├── scripts/        Numbered PowerShell scripts (execution order)
├── modules/        Shared PowerShell modules (Logging, System, Docker, …)
├── config/         environment.psd1 and models.psd1 settings
├── docs/           Architecture, installation and operations guides
├── logs/           Runtime log files (git-ignored)
├── reports/        Generated JSON/MD reports (git-ignored)
└── tests/          Future test scripts
```

## Documentation

See `docs/` for detailed guides:

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — design decisions and component overview
- [INSTALLATION.md](docs/INSTALLATION.md) — step-by-step installation guide
- [OPERATIONS.md](docs/OPERATIONS.md) — daily usage
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — common problems and fixes
- [ROADMAP.md](docs/ROADMAP.md) — planned future phases
- [DOCKER-N8N-PLAN.md](docs/DOCKER-N8N-PLAN.md) — n8n integration architecture

## Related

This project is documented as part of a hands-on article series on building a local AI stack:

- **Substack (PL):** [pawellach.substack.com](https://pawellach.substack.com) — *Lokalne środowisko AI* series
- **Medium (EN):** [medium.com/@pawellach](https://medium.com/@pawellach) — *Local AI Infrastructure* series

The series covers Ollama setup, Open-WebUI configuration, RAG pipelines, and MCP server integration — all with this repository as the reference implementation.

## License

MIT. Private use only — no warranty.
