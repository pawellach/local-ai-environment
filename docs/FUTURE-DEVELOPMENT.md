# Future Development — Scripts, Tools & Configurators

This document lists all planned and proposed extensions to the Local-AI-Environment project.
Items are grouped by category. Use this as a backlog for Phase 2 through Phase 5 development.

---

## Additional Scripts (planned)

### Phase 2 — Docker & Workflow Automation

| Script | Description |
|--------|-------------|
| `08-Deploy-N8N.ps1` | Deploy n8n workflow automation via Docker Compose; verify Ollama connectivity via host.docker.internal |
| `09-Configure-N8N.ps1` | Import starter workflows; configure credentials for Ollama and Open-WebUI HTTP nodes |
| `10-Deploy-Portainer.ps1` | Deploy Portainer CE for Docker management UI at localhost:9000 |

### Phase 3 — Local AI Expansion

| Script | Description |
|--------|-------------|
| `11-Install-Whisper.ps1` | Install Faster-Whisper or whisper.cpp for local speech-to-text transcription |
| `12-Install-TTS.ps1` | Install local text-to-speech (Coqui TTS or Piper); integrate with Open-WebUI |
| `13-Deploy-ImageGen.ps1` | Deploy Stable Diffusion WebUI (AUTOMATIC1111) or ComfyUI via Docker for local image generation |
| `14-Deploy-VectorDB.ps1` | Deploy Qdrant or Chroma vector database via Docker for RAG pipelines |
| `15-Configure-RAG.ps1` | Configure Open-WebUI RAG pipeline with local vector DB; test document ingestion |
| `16-Deploy-SearXNG.ps1` | Deploy SearXNG self-hosted search engine; connect to Open-WebUI for web-grounded answers |

### Phase 4 — Tooling & Utilities

| Script | Description |
|--------|-------------|
| `17-Benchmark-Models.ps1` | Run standard benchmarks across installed models; measure tokens/sec, TTFT, memory usage; save results |
| `18-Update-All.ps1` | Check and update all components: Open-WebUI, Ollama, models, Docker images |
| `19-Backup-Environment.ps1` | Backup Open-WebUI data, n8n workflows, model list, and configuration to a zip archive |
| `20-Restore-Environment.ps1` | Restore from backup created by `19-Backup-Environment.ps1` |
| `21-Register-Services.ps1` | Register Open-WebUI and Ollama as Windows Services via NSSM so they start automatically |
| `22-Configure-Firewall.ps1` | Audit and lock down Windows Firewall rules for all AI services; ensure localhost-only binding |
| `23-Generate-EnvVars.ps1` | Export all relevant environment variables to a `.env` template file for reference |

### Phase 5 — MCP & Agent Infrastructure

| Script | Description |
|--------|-------------|
| `24-Deploy-MCP-Servers.ps1` | Deploy filesystem, SQLite, and custom MCP servers; generate MCP config for Claude Code |
| `25-Install-LiteLLM.ps1` | Deploy LiteLLM proxy; provides unified OpenAI-compatible API for all local models |
| `26-Configure-OpenAI-Compat.ps1` | Configure applications that expect OpenAI API to use local Ollama or LiteLLM instead |

---

## Additional Tools to Add

### LLM Runtimes (alternatives to Ollama)

| Tool | Description | Notes |
|------|-------------|-------|
| **LM Studio** | GUI app for running local LLMs; easy model browser | Alternative to Ollama, not CLI-focused |
| **LocalAI** | OpenAI-compatible API server supporting GGUF, GPTQ, and other formats | More backends than Ollama |
| **KoboldCpp** | Single-binary LLM runner; good for roleplay/creative use cases | Simpler than Ollama |
| **llama.cpp** | Core C++ LLM inference library; source of Ollama's backend | For advanced users |
| **Jan.ai** | Desktop AI assistant with local model support | Cross-platform GUI |

### Web UI Alternatives (alternatives to Open-WebUI)

| Tool | Description | Notes |
|------|-------------|-------|
| **AnythingLLM** | Desktop + web app with built-in RAG, workspaces, agents | Better RAG than Open-WebUI out of the box |
| **Chatbot UI** | Clean minimal chat UI (Next.js) | Lighter than Open-WebUI |
| **LibreChat** | Feature-rich chat UI, multi-model, OpenAI-compatible | More complex to set up |
| **Text Generation WebUI** (oobabooga) | Advanced UI with fine-tuning, LoRA support | For power users |

### Workflow & Automation

| Tool | Description | Notes |
|------|-------------|-------|
| **n8n** | Self-hosted workflow automation (Phase 2 priority) | Best AI integration via HTTP nodes |
| **Flowise** | Visual AI workflow builder; drag-and-drop LangChain/LlamaIndex | Easier than n8n for AI pipelines |
| **Activepieces** | Open-source Zapier alternative; lighter than n8n | Fewer AI integrations |
| **Windmill** | Developer-focused workflow platform with Python/TypeScript scripts | For code-heavy automation |

### Vector Databases

| Tool | Description | Notes |
|------|-------------|-------|
| **Qdrant** | High-performance vector DB; Docker, great Rust client | Recommended for production use |
| **Chroma** | Simple Python-native vector DB; used by Open-WebUI internally | Good for prototyping |
| **pgvector** | PostgreSQL extension; add vectors to existing Postgres | Best if you already use Postgres |
| **Weaviate** | Full-featured vector DB with built-in modules | More complex setup |
| **Milvus** | Enterprise-grade vector DB | Heavy, for large-scale use |

### Document Processing & RAG

| Tool | Description | Notes |
|------|-------------|-------|
| **Docling** (IBM) | Document conversion to markdown for RAG; supports PDF, DOCX, XLSX | Excellent for enterprise docs |
| **Unstructured** | Document parsing library; many formats | Industry standard |
| **Firecrawl** | Web scraper/crawler for RAG data collection | Self-hostable |
| **SearXNG** | Self-hosted search engine; provides web context to LLMs | Lightweight Docker deploy |

### Image & Multimodal

| Tool | Description | Notes |
|------|-------------|-------|
| **ComfyUI** | Node-based image generation; FLUX, SDXL, SD3 | Most powerful, steeper learning curve |
| **AUTOMATIC1111 WebUI** | Classic Stable Diffusion UI | Large community, many extensions |
| **InvokeAI** | Professional image generation UI | Good balance of features/UX |
| **Fooocus** | Simplified Midjourney-like UI for SDXL | Easiest to start with |

### Speech (STT / TTS)

| Tool | Description | Notes |
|------|-------------|-------|
| **Faster-Whisper** | Optimized OpenAI Whisper for transcription | Best quality/speed ratio |
| **Whisper.cpp** | C++ port of Whisper; single binary | Lightest option |
| **Piper** | Fast local TTS from Rhasspy | Great quality, many voices |
| **Coqui TTS** | Neural TTS with voice cloning | More features, heavier |

### Infrastructure & Monitoring

| Tool | Description | Notes |
|------|-------------|-------|
| **Portainer CE** | Docker management UI | Essential for Phase 2+ |
| **Uptime Kuma** | Self-hosted monitoring for local services | Monitor all ports with alerts |
| **Prometheus + Grafana** | Metrics collection and dashboards | For performance monitoring |
| **Dozzle** | Real-time Docker log viewer | Lightweight alternative to Portainer logs |

### Developer Tools

| Tool | Description | Notes |
|------|-------------|-------|
| **LiteLLM Proxy** | Unified OpenAI-compatible API for all local models | One endpoint to rule them all |
| **OpenWebUI Pipelines** | Plugin system for Open-WebUI: filters, tools, RAG | Extends Open-WebUI without code changes |
| **Lobe Chat** | Modern chat UI with plugin ecosystem | Good for testing tools |
| **HelixML** | Local AI inference server with API | Alternative to Ollama |

---

## Configurator Scripts (planned)

These are targeted configuration helpers — smaller than full install scripts.

| Script | Description |
|--------|-------------|
| `config/Setup-WindowsTerminal.ps1` | Install and configure Windows Terminal with AI-dev profile (Ollama, Python, PS profiles) |
| `config/Setup-VSCode-Extensions.ps1` | Install recommended VS Code extensions (PowerShell, Python, REST Client, Docker) |
| `config/Setup-PythonVenv.ps1` | Create a project-scoped Python venv; install open-webui and dependencies into it |
| `config/Setup-AutoStart.ps1` | Configure Ollama and Open-WebUI to start on login via Windows Task Scheduler |
| `config/Setup-GitConfig.ps1` | Configure git for the project: user, line endings, editor |
| `config/Setup-PowerShellProfile.ps1` | Add AI-environment helper functions to PowerShell profile (aliases, quick-start functions) |
| `config/Setup-NSSM-Services.ps1` | Register Open-WebUI as a proper Windows Service using NSSM |
| `config/Configure-OllamaGPU.ps1` | Detect GPU vendor, set CUDA/ROCm environment variables, verify GPU acceleration |
| `config/Configure-OllamaContext.ps1` | Set Ollama context window size and concurrency parameters via OLLAMA_NUM_CTX etc. |
| `config/Configure-OpenWebUI-Auth.ps1` | Disable/enable Open-WebUI authentication for single-user local setup |
| `config/Export-ModelList.ps1` | Export currently installed models to JSON/markdown for backup or migration |
| `config/Import-ModelList.ps1` | Pull all models from an exported model list (batch restore) |
| `config/Set-EnvVariables.ps1` | Interactive environment variable manager for all AI services |
| `config/Test-GPU-Benchmark.ps1` | Run GPU detection and basic compute benchmark before model selection |

---

## Contribution Ideas

If you extend this project, consider contributing:

1. **Pester tests** — unit tests for all 5 modules (`tests/` directory is currently empty)
2. **CI/CD pipeline** — GitHub Actions workflow to validate PowerShell syntax on push
3. **Linux/macOS port** — bash equivalents for the same workflow
4. **Chocolatey/winget manifests** — reproducible installs via package manager
5. **GUI wrapper** — simple HTML dashboard or PowerShell + WPF launcher
6. **Docker Compose profiles** — compose files for different hardware tiers

---

*Last updated: 2026-09-06*
