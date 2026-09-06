# Architecture

## Overview

Local-AI-Environment is a modular PowerShell toolkit that installs and configures a fully offline, privacy-preserving AI development stack on a Windows 11 laptop. It automates the installation of Open-WebUI (a web-based chat interface and API gateway), Ollama (a local LLM runtime), and a selected language model — all communicating exclusively over localhost. A parallel audit and cleanup capability prepares the local Docker environment for a future Phase 2 deployment of n8n workflow automation, kept intentionally separate from the AI stack during Phase 1.

---

## Primary Stack

```
Windows 11
  └─ Python 3.11+
       └─ Open-WebUI  (http://localhost:3000)
            │   Web UI + OpenAI-compatible REST API gateway
            └─ Ollama  (http://localhost:11434)
                 │   LLM runtime + model manager
                 └─ Local LLM Model  (e.g., qwen2.5:7b)
                      Stored in: %USERPROFILE%\.ollama\models\
```

### Layer: Python 3.11+

Python is the runtime host for Open-WebUI. It must be installed before running script `03-Install-OpenWebUI.ps1`. The `pip` package manager handles installation and upgrades. No virtual environment is strictly required for a single-user laptop setup, though one can be created for isolation.

**Alternatives considered:** Node.js-based frontends — rejected because Open-WebUI's pip installation is the officially recommended path for Windows without Docker.

### Layer: Open-WebUI

Open-WebUI is an open-source, self-hosted web application that provides:
- A polished ChatGPT-like browser interface at `http://localhost:3000`
- An OpenAI-compatible REST API (`/api/chat`, `/api/models`, etc.)
- Conversation history stored locally in an SQLite database
- Model management UI that proxies to Ollama
- Multi-user support (useful if the laptop is shared)

After first launch, an admin account is created locally — no cloud registration required.

**Alternatives considered:**
- LM Studio: closed-source, not scriptable via pip
- Jan.ai: good UI but heavier Electron footprint
- Direct Ollama CLI: no persistent history, no web UI

### Layer: Ollama

Ollama is a cross-platform LLM runtime that:
- Runs as a background service (Windows system tray + `ollama serve`)
- Exposes a REST API at `http://localhost:11434`
- Manages model downloads, storage, and versioning
- Automatically uses NVIDIA/AMD GPU if drivers are present, falls back to CPU
- Supports GGUF quantized models — efficient even on modest hardware

**Alternatives considered:**
- llama.cpp directly: more control, but no model manager, no API server out of the box
- LM Studio backend: closed-source
- Text-generation-webui: heavier, more complex install

### Layer: Local LLM Model

Models are downloaded via `ollama pull <tag>` and stored in `%USERPROFILE%\.ollama\models\`. The toolkit includes a hardware-tier detection system (Low / Medium / High) that recommends appropriate models based on detected RAM and GPU VRAM. See `config/models.psd1` for the full recommendation table.

---

## Why Open-WebUI + Ollama?

| Criterion | Verdict |
|-----------|---------|
| Open-source | Both MIT-licensed |
| Windows native support | Ollama has official installer; Open-WebUI via pip |
| No cloud dependency | All inference runs locally |
| GPU acceleration | Ollama auto-detects NVIDIA CUDA and AMD ROCm |
| OpenAI API compatibility | Open-WebUI exposes compatible endpoints |
| Active maintenance | Both projects updated frequently |
| No telemetry by default | Confirmed in both projects' documentation |
| Cost | Free |

---

## Why Docker is Separate (Initially)

Docker Desktop is deliberately excluded from the Phase 1 AI stack for these reasons:

1. **RAM overhead** — Docker Desktop consumes approximately 500 MB RAM at idle (WSL2 backend). On a 16 GB laptop, this is a meaningful cost when running a 7B parameter model.

2. **Networking complexity** — Running Open-WebUI in Docker requires mapping `host.docker.internal` for Ollama communication. On Windows, this adds a networking layer that can cause subtle connection failures, especially when Ollama is also native.

3. **pip installation is simpler** — `pip install open-webui` requires only Python 3.11+ and works without any container runtime. Updates are a single `pip install --upgrade open-webui`.

4. **Phase separation** — Keeping Docker clean in Phase 1 means the Docker environment is in a known state when Phase 2 (n8n) begins. Script `02-Docker-Clean.ps1` ensures the Docker environment is audited and optionally cleaned before n8n is deployed.

5. **Debugging is easier** — Native processes are visible in Task Manager, logs are in predictable locations, and there is no container abstraction to troubleshoot.

**Note:** Open-WebUI *can* run in Docker (it is the officially documented method). If the target laptop already has Docker Desktop running and RAM is not a concern, Docker-based Open-WebUI is a valid alternative — but is outside the scope of this toolkit's Phase 1.

---

## Future Docker Stack (Phase 2)

```
Docker Desktop
  └─ docker-compose (.\docker\n8n\docker-compose.yml)
       └─ n8n container  (http://localhost:5678)
            │   Workflow automation engine
            ├─ calls Ollama API:     http://host.docker.internal:11434
            └─ calls Open-WebUI API: http://host.docker.internal:3000
```

From inside a Docker container on Windows, `host.docker.internal` resolves to the Windows host. This allows n8n to call both Ollama and Open-WebUI, which run natively on the host.

See `docs/DOCKER-N8N-PLAN.md` for the complete Phase 2 architecture, prerequisites, and deployment plan.

---

## Data Flow

A typical user query travels through the stack as follows:

```
1. User types a message in browser at http://localhost:3000
       │
2. Open-WebUI frontend sends POST /api/chat to its own backend
       │
3. Open-WebUI backend forwards the request to Ollama:
   POST http://localhost:11434/api/chat
   Body: { model: "qwen2.5:7b", messages: [...] }
       │
4. Ollama loads the model (if not already in memory) and runs inference
   on CPU and/or GPU
       │
5. Ollama streams the response token by token back to Open-WebUI
       │
6. Open-WebUI streams the response to the browser via Server-Sent Events
       │
7. User sees the response appear word by word in the chat interface
```

The entire flow stays on the local machine. No data leaves the laptop.

---

## Network Ports

| Port | Service | Protocol | Default Host | Configurable |
|------|---------|----------|--------------|--------------|
| 3000 | Open-WebUI | HTTP | 127.0.0.1 | Yes (`--port` flag) |
| 11434 | Ollama API | HTTP | 127.0.0.1 | Yes (`OLLAMA_HOST` env var) |
| 5678 | n8n (Phase 2) | HTTP | 127.0.0.1 | Yes (Docker port mapping) |

All services default to localhost-only binding. **Do not expose these ports through your firewall or router** unless you have intentionally set up authentication and TLS.

---

## Security Considerations

- **No API keys** — The local stack requires no Anthropic, OpenAI, or other cloud API keys.
- **Local authentication** — Open-WebUI requires creating a local user account on first launch. This password is stored locally (hashed) in its SQLite database.
- **No cloud sync** — Conversations, models, and configuration stay on disk. Neither Open-WebUI nor Ollama phone home with your prompts.
- **Secrets in scripts** — The toolkit is designed so that no secrets, tokens, or passwords appear in any script, log, or report file.
- **Destructive operations** — Docker cleanup scripts require explicit typed confirmation before any deletion. No destructive action is taken silently.

---

## Module Architecture

Scripts import shared PowerShell modules from the `modules/` directory:

```powershell
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Import-Module "$ProjectRoot\modules\Logging.psm1"     -Force
Import-Module "$ProjectRoot\modules\System.psm1"      -Force
Import-Module "$ProjectRoot\modules\Docker.psm1"      -Force
Import-Module "$ProjectRoot\modules\Validation.psm1"  -Force
Import-Module "$ProjectRoot\modules\Configuration.psm1" -Force
```

| Module | Responsibility |
|--------|---------------|
| `Logging.psm1` | Colored console output + timestamped log files in `logs/` |
| `System.psm1` | OS/CPU/RAM/GPU detection via CIM; hardware tier classification |
| `Docker.psm1` | Docker availability checks, full audit via CLI, markdown formatting |
| `Validation.psm1` | Port checks, HTTP endpoint tests, PASS/WARNING/FAIL result objects |
| `Configuration.psm1` | Config file loading, JSON/MD report saving, confirmation prompts |

No script contains logic that belongs in a module. No module contains script-level side effects.

---

## Project Structure

```
Local-AI-Environment/
├── scripts/          # Numbered execution scripts (run in order)
├── modules/          # Reusable PowerShell modules (imported by scripts)
├── config/           # Static configuration (environment.psd1, models.psd1)
├── docs/             # Human documentation (this file, INSTALLATION, etc.)
├── logs/             # Runtime logs (git-ignored, auto-created)
├── reports/          # Generated JSON + Markdown reports (git-ignored)
└── tests/            # Reserved for Pester unit tests (Phase future)
```

**Why numbered scripts?** The numbers enforce execution order and make the intended sequence self-documenting. A user can run `00` through `07` in order without reading documentation.

**Why separate modules?** A function defined once in a module can be called from multiple scripts without duplication. It also makes the logic unit-testable via Pester.

**Why git-ignore logs and reports?** These files contain machine-specific data (hardware info, installed versions) that differs between machines and should not be committed to a shared repository.
