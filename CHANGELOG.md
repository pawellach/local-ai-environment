# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-09-06

### Added

#### Core Modules
- `modules/Logging.psm1` — structured log to console + file with colored output
- `modules/System.psm1` — OS, CPU, RAM, GPU, disk detection; hardware tier classification
- `modules/Docker.psm1` — Docker audit, running state detection, markdown report generation
- `modules/Validation.psm1` — port/HTTP endpoint testing, standardised PASS/WARNING/FAIL results
- `modules/Configuration.psm1` — config loading, JSON/MD report saving, safe confirmation prompts

#### Configuration
- `config/environment.psd1` — project-wide settings (ports, paths, runtime requirements)
- `config/models.psd1` — tiered LLM model recommendations (Low / Medium / High hardware)

#### Scripts
- `scripts/00-System-Check.ps1` — full hardware and software audit with LLM recommendation
- `scripts/01-Docker-Audit.ps1` — non-destructive Docker environment snapshot
- `scripts/02-Docker-Clean.ps1` — Docker cleanup with AUDIT / SAFE / FULL modes
- `scripts/03-Install-OpenWebUI.ps1` — Open-WebUI installation via pip with idempotency check
- `scripts/04-Install-Ollama.ps1` — Ollama installation via winget/direct download
- `scripts/05-Configure-Local-LLM.ps1` — hardware-aware model selection and ollama pull
- `scripts/06-Configure-OpenWebUI.ps1` — connect Open-WebUI to local Ollama instance
- `scripts/07-Validate-Environment.ps1` — end-to-end validation with PASS/WARNING/FAIL table
- `scripts/99-Generate-Report.ps1` — compile FINAL-ENVIRONMENT-REPORT.md from all reports

#### Documentation
- `docs/ARCHITECTURE.md`
- `docs/INSTALLATION.md`
- `docs/OPERATIONS.md`
- `docs/TROUBLESHOOTING.md`
- `docs/ROADMAP.md`
- `docs/DOCKER-N8N-PLAN.md`
- `PROJECT-REVIEW.md`
