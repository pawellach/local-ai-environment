# Project Roadmap

Development phases for the Local AI Environment, from initial setup through a full local automation stack.

---

## Phase 1 — Local AI Stack ✅ Current

**Status:** Complete  
**Goal:** Working local AI environment with web interface

### Components

| Component | Role | Script |
|-----------|------|--------|
| System Audit | Hardware detection, tool check, LLM recommendation | 00-System-Check |
| Docker Audit | Inventory existing Docker resources | 01-Docker-Audit |
| Docker Clean | Prepare Docker for future use | 02-Docker-Clean |
| Open-WebUI | Web interface + API gateway for LLMs | 03-Install-OpenWebUI |
| Ollama | Local LLM runtime (GPU/CPU) | 04-Install-Ollama |
| Local LLM | Downloaded and tested inference model | 05-Configure-Local-LLM |
| Integration | Open-WebUI connected to Ollama | 06-Configure-OpenWebUI |
| Validation | Full environment health check | 07-Validate-Environment |
| Report | Comprehensive environment report | 99-Generate-Report |

### Success Metrics

- [ ] `07-Validate-Environment.ps1` shows all PASS (warnings acceptable for Docker if not installed)
- [ ] Browser opens http://localhost:3000 and shows Open-WebUI
- [ ] At least one model installed and responding in browser
- [ ] LLM inference test returns response under 60 seconds on Low tier, under 10 seconds on High tier
- [ ] `reports/FINAL-ENVIRONMENT-REPORT.md` generated successfully

### Prerequisites Met

- Windows 11 laptop
- Python 3.11+ installed
- Internet access for downloads

---

## Phase 2 — Local n8n on Docker (Planned)

**Status:** Planning  
**Goal:** Add workflow automation layer powered by local AI

### Prerequisites

- Phase 1 complete and validated
- Docker Desktop installed and running
- At least 8GB free RAM
- At least 20GB free disk space
- Port 5678 available

### New Script: `08-Deploy-N8N.ps1`

Will automate:
1. Verify Docker Desktop is running
2. Verify host.docker.internal routing works
3. Deploy `docker-compose.n8n.yml`
4. Wait for n8n health check
5. Print access URL and first-run instructions
6. Verify n8n can reach Ollama via `host.docker.internal:11434`

### Tasks

- [ ] Create `docker-compose.n8n.yml` in project root
- [ ] Write `08-Deploy-N8N.ps1`
- [ ] Test Ollama connectivity from inside Docker container
- [ ] Create example "Hello AI" workflow
- [ ] Document n8n → Ollama HTTP Request node configuration
- [ ] Update `07-Validate-Environment.ps1` to check n8n status

### Architecture Addition

```
Windows 11 Host
  ├─ Open-WebUI  (localhost:3000)
  ├─ Ollama      (localhost:11434)
  └─ Docker Desktop
       └─ n8n    (localhost:5678)
            └─ calls host.docker.internal:11434
```

### Success Metrics

- [ ] http://localhost:5678 shows n8n UI
- [ ] n8n HTTP Request node successfully calls Ollama API
- [ ] n8n data persists in Docker volume across container restarts
- [ ] `08-Deploy-N8N.ps1` is idempotent

---

## Phase 3 — n8n ↔ AI Integration (Planned)

**Status:** Future  
**Goal:** Working AI-powered automation workflows

### Tasks

- [ ] Example workflow: classify incoming webhook payload using LLM
- [ ] Example workflow: summarize text from file trigger
- [ ] Example workflow: extract structured data (JSON) from free text
- [ ] Example workflow: route tasks based on LLM category decision
- [ ] Template library of AI-powered n8n workflows
- [ ] Document Open-WebUI API usage from n8n (OpenAI-compatible format)
- [ ] Error handling and retry patterns for LLM calls in n8n

### New Scripts

- `scripts/Test-N8N-Workflows.ps1` — validate example workflows run correctly

### Success Metrics

- [ ] At least 3 working example workflows included in project
- [ ] LLM-powered workflow completes end-to-end in under 30 seconds for 7B model
- [ ] Workflows exportable and importable via n8n JSON format

---

## Phase 4 — Additional Local AI Services (Future)

**Status:** Concept  
**Goal:** Expand local AI capabilities beyond text generation

### Speech to Text — Whisper

- Tool: Faster-Whisper (Python) or whisper.cpp
- Use case: transcribe audio files locally
- Deployment: Python pip (native) or Docker
- New script: `09-Install-Whisper.ps1`

### Image Generation

- Tool: FLUX.1-schnell or Stable Diffusion via ComfyUI
- Use case: generate images from text prompts locally
- Deployment: Docker (GPU recommended) or Python pip
- New script: `10-Install-ImageGen.ps1`
- Note: requires NVIDIA GPU with ≥8GB VRAM for reasonable speed

### Local Embeddings + Vector Database

- Embeddings: sentence-transformers (Python pip) or Ollama embedding models
- Vector DB: Chroma (pip) or Qdrant (Docker)
- Use case: RAG (Retrieval-Augmented Generation) — chat with your documents
- New scripts: `11-Deploy-VectorDB.ps1`, `12-Configure-RAG.ps1`

### Open-WebUI RAG Integration

- Connect vector database to Open-WebUI
- Upload documents → automatically embedded → LLM answers questions from them
- All local, no cloud storage

### Success Metrics

- [ ] Whisper transcribes 1-minute audio in under 60 seconds
- [ ] Image generation produces output in under 120 seconds (GPU)
- [ ] RAG pipeline answers questions from a 100-page PDF document
- [ ] All services accessible from n8n workflows

---

## Phase 5 — MCP Server Ecosystem (Future)

**Status:** Concept  
**Goal:** Extend AI tools with Model Context Protocol servers

### What is MCP?

Model Context Protocol is an open standard allowing AI assistants to interact with external tools and data sources in a structured way. Claude Code and compatible tools use MCP servers for filesystem access, database queries, and custom integrations.

### Planned MCP Servers

| Server | Function | Deployment |
|--------|----------|-----------|
| Filesystem MCP | AI reads/writes local files | Python pip |
| SQLite MCP | AI queries local databases | Python pip |
| PostgreSQL MCP | AI queries Postgres (Docker) | Docker |
| Custom domain MCP | Project-specific tools | Python pip |

### New Scripts

- `12-Deploy-MCP-Servers.ps1` — deploy and configure MCP servers
- `13-Configure-MCP-Claude.ps1` — register servers with Claude Code

### Success Metrics

- [ ] Claude Code can read and write files via MCP Filesystem server
- [ ] Claude Code can query SQLite database via MCP
- [ ] MCP server configuration persisted in `~/.claude.json`

---

## Technical Debt and Continuous Improvement

These improvements apply across all phases:

### Testing

- [ ] Add Pester test suite for all 5 modules (`tests/` directory)
- [ ] Unit tests for `System.psm1` hardware tier logic
- [ ] Integration tests for validation functions
- [ ] Mock-based tests for Docker module (works without Docker installed)

### Reliability

- [ ] Automatic version update checking on script start
- [ ] Retry logic for network downloads (exponential backoff)
- [ ] Rollback support for failed installations

### Usability

- [ ] Simple HTML dashboard showing all component statuses
- [ ] WinGet manifest for reproducible, repeatable installs
- [ ] GUI wrapper using PowerShell + WPF for non-technical users
- [ ] One-command full install: `.\Install-All.ps1`

### Cross-Platform

- [ ] Linux variant of key scripts (bash versions)
- [ ] macOS variant (brew-based)
- [ ] Common configuration format shared across platforms

---

## Version History

| Version | Date | Phase |
|---------|------|-------|
| 1.0.0 | 2026-09-06 | Phase 1 complete |
| 2.0.0 | TBD | Phase 2: n8n |
| 3.0.0 | TBD | Phase 3: AI workflows |
| 4.0.0 | TBD | Phase 4: Additional services |
| 5.0.0 | TBD | Phase 5: MCP ecosystem |
