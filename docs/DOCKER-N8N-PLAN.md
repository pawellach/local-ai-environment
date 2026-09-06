# Docker + n8n Plan

Planning document for Phase 2: deploying n8n locally using Docker.

> **Status: Planning — do not execute yet.**  
> This document records the intended architecture and prerequisites for Phase 2.  
> Implementation begins only after Phase 1 validation passes.

---

## What is n8n?

n8n (pronounced "n-eight-n") is an open-source workflow automation platform — self-hosted, like Zapier or Make but running entirely on your machine. It connects APIs, processes data, reacts to webhooks, and can trigger AI inference via HTTP calls.

Key properties:
- Free and open source (fair-code license for self-hosting)
- Visual workflow editor in the browser
- 400+ built-in integrations (HTTP, file system, email, databases, ...)
- Supports JavaScript expressions and code nodes for custom logic
- All data stays local — nothing sent to cloud

---

## Why n8n + Local AI?

| Benefit | Detail |
|---------|--------|
| No API costs | Calls your local Ollama instead of OpenAI API |
| Privacy | Data never leaves your machine |
| Automation | Trigger AI processing from files, webhooks, schedules |
| Chaining | Chain multiple LLM calls in a single workflow |
| Integration | Connect AI output to files, databases, email, Slack, etc. |

Example use cases:
- Summarize a folder of documents on a schedule
- Classify incoming webhook payloads with a local LLM
- Extract structured JSON from free-text files
- Auto-tag and organize files using AI
- Trigger n8n workflows from Open-WebUI conversations

---

## Prerequisites Before Starting Phase 2

Complete this checklist before running `08-Deploy-N8N.ps1`:

- [ ] **Phase 1 complete**: `07-Validate-Environment.ps1` shows all PASS
- [ ] **Ollama running**: http://localhost:11434 is accessible
- [ ] **Open-WebUI running**: http://localhost:3000 is accessible
- [ ] **Docker Desktop installed**: download from https://www.docker.com/products/docker-desktop/
- [ ] **Docker Desktop running**: look for whale icon in system tray
- [ ] **Docker engine healthy**: `docker ps` returns without error
- [ ] **Enough free RAM**: at least 8GB (4GB for n8n + 4GB for model during inference)
- [ ] **Port 5678 free**: `Test-NetConnection -Port 5678 -ComputerName localhost` returns `TcpTestSucceeded: False`
- [ ] **Disk space**: at least 2GB free for n8n image and volume data

### Verify Docker is Ready

```powershell
# Check Docker is installed
docker --version

# Check Docker engine is running
docker ps

# Check available disk
docker system df

# Check host.docker.internal resolves (needed for Ollama access from container)
docker run --rm --add-host=host.docker.internal:host-gateway alpine nslookup host.docker.internal
```

---

## Recommended docker-compose.yml

Save this as `docker-compose.n8n.yml` in the project root. Script `08-Deploy-N8N.ps1` will create this automatically.

```yaml
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n-local
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=Europe/Warsaw
      - N8N_LOG_LEVEL=info
      # Disable telemetry
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
    volumes:
      - n8n_data:/home/node/.n8n
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"

volumes:
  n8n_data:
    driver: local
```

### Key Configuration Explained

| Setting | Value | Reason |
|---------|-------|--------|
| `ports: 5678:5678` | localhost:5678 only | No external exposure |
| `extra_hosts` | host-gateway | Allows container to call Ollama on the host |
| `n8n_data` volume | Persistent | Workflows survive container restarts |
| `N8N_DIAGNOSTICS_ENABLED=false` | Disabled | Privacy — no telemetry |
| `GENERIC_TIMEZONE` | Europe/Warsaw | Correct cron scheduling |

---

## Network Architecture

```
Windows 11 Host
  │
  ├─ Ollama service
  │    └─ listens on  127.0.0.1:11434
  │
  ├─ Open-WebUI (Python)
  │    └─ listens on  127.0.0.1:3000
  │
  └─ Docker Desktop
       │
       └─ n8n container
            │
            ├─ accessible from host at   localhost:5678
            │
            ├─ calls Ollama via          http://host.docker.internal:11434
            │   (host.docker.internal resolves to Windows host IP from inside container)
            │
            └─ calls Open-WebUI via      http://host.docker.internal:3000
```

> **Important:** From inside the n8n container, `localhost` refers to the container itself, not the Windows host. Always use `host.docker.internal` to reach Ollama and Open-WebUI.

---

## Calling Ollama from n8n

### HTTP Request Node — Generate Endpoint

- **Method:** POST  
- **URL:** `http://host.docker.internal:11434/api/generate`  
- **Content-Type:** `application/json`

**Body (JSON):**
```json
{
  "model": "qwen2.5:7b",
  "prompt": "{{ $json.input_text }}",
  "stream": false
}
```

**Response field:** `response` contains the generated text.

### HTTP Request Node — Chat Endpoint (OpenAI-compatible)

- **Method:** POST  
- **URL:** `http://host.docker.internal:11434/api/chat`

**Body (JSON):**
```json
{
  "model": "qwen2.5:7b",
  "messages": [
    { "role": "user", "content": "{{ $json.user_message }}" }
  ],
  "stream": false
}
```

**Response field:** `message.content`

---

## Calling Open-WebUI API from n8n

Open-WebUI exposes an OpenAI-compatible API.

- **Method:** POST  
- **URL:** `http://host.docker.internal:3000/api/chat/completions`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer <your-open-webui-api-key>
```

Get an API key: Open-WebUI → Settings → Account → API Keys.

**Body (JSON):**
```json
{
  "model": "qwen2.5:7b",
  "messages": [
    { "role": "user", "content": "{{ $json.input }}" }
  ]
}
```

**Response field:** `choices[0].message.content`

---

## Data Persistence

n8n stores all state in the Docker volume `n8n_data`:

- Workflow definitions
- Execution history
- Credentials (encrypted)
- User accounts

**Volume location on host** (Docker-managed):
```powershell
docker volume inspect n8n_data
# Shows actual path under Docker's data directory
```

### Backup

```powershell
# Create backup archive
docker run --rm `
  -v n8n_data:/data `
  -v "${PWD}:/backup" `
  alpine `
  tar czf /backup/n8n-backup-$(Get-Date -Format "yyyyMMdd").tar.gz /data

# Restore from backup
docker run --rm `
  -v n8n_data:/data `
  -v "${PWD}:/backup" `
  alpine `
  tar xzf /backup/n8n-backup-20260906.tar.gz -C /
```

---

## Security Notes

- n8n is accessible only at `localhost:5678` — not from other machines on the network
- Do **not** add `0.0.0.0:5678:5678` port mapping (that would expose it externally)
- n8n credentials (for external services) are encrypted at rest in the Docker volume
- Ollama and Open-WebUI remain bound to localhost — n8n reaches them only via `host.docker.internal`
- n8n execution history may contain LLM prompts and responses — treat the volume as sensitive data

---

## Future Script: 08-Deploy-N8N.ps1

This script will be created in Phase 2. Planned steps:

1. Import modules (Logging, Validation, Configuration)
2. Check Docker is running (`Test-DockerRunning`)
3. Check port 5678 is free (`Test-PortListening 5678` should return false)
4. Check `host.docker.internal` resolves inside Docker
5. Create `docker-compose.n8n.yml` from embedded template
6. Run `docker compose -f docker-compose.n8n.yml up -d`
7. Wait up to 60 seconds for n8n health check (`/healthz` endpoint)
8. Verify n8n can reach Ollama:
   ```
   docker exec n8n-local wget -qO- http://host.docker.internal:11434
   ```
9. Print access URL and first-run instructions
10. Save `reports/n8n-deploy-report.json` and `.md`

Parameters will include `-DryRun`, `-NonInteractive`, `-N8nPort` (default 5678), `-Timezone`.

---

## Estimated Resource Usage

| Component | RAM | CPU (idle) | Disk |
|-----------|-----|-----------|------|
| n8n container | ~400MB | ~0% | ~300MB image |
| n8n volume data | — | — | ~50MB (grows with execution history) |
| Ollama (model loaded) | 4-10GB | ~0% | 2-10GB per model |
| Open-WebUI | ~200MB | ~0% | ~500MB |
| **Total (Phase 2)** | **~5-12GB** | **~0%** | **~3-11GB** |
