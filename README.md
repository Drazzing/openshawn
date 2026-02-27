# OpenClaw — My Docker & Skills

This repo holds **your** secure Docker setup and **custom skills** (e.g. HCM agent), separate from the main [OpenClaw](https://github.com/openclaw/openclaw) repo. Version control your changes here.

## Contents

| Path | Purpose |
|------|---------|
| `docker-compose.secure.yml` | Hardened Compose; mounts `./skills` as managed skills |
| `.env.secure` | Template for secrets → copy to `.env` |
| `openclaw.secure.json` | Gateway config → copy to `~/.openclaw/openclaw.json` |
| `openclaw.developer.json` | **Developer-optimized config** (Claude primary, 2h timeout, coding/cursor skills). Used automatically when `OPENCLAW_CONFIG_DIR` is this repo’s `data/`. |
| `secure-setup.sh` | One-time setup (WSL2/Linux/macOS) |
| `docker-start-secure.ps1` | Start gateway (Windows PowerShell) |
| `scripts/docker-start-secure.sh` | Start gateway (WSL2/Linux/macOS) |
| `skills/` | Your custom skills (e.g. `hcm-agent`) |

The OpenClaw **image** is built from the main OpenClaw repo. On first run, the start script builds it automatically if the repo is at `../openclaw` (sibling directory) or you set `OPENCLAW_REPO` in `.env`. No manual `docker build` step needed.

## Quick start

### 1. Setup and run (from this repo)

**Windows (PowerShell):** Run from the repo directory (e.g. `cd C:\sandpit\openclaw-docker`). The script builds the OpenClaw image automatically on first run (expects OpenClaw repo at `..\openclaw`, or set `OPENCLAW_REPO` in `.env`).
```powershell
Copy-Item .env.secure .env
# Edit .env: set OPENCLAW_GATEWAY_TOKEN (e.g. a random hex string), CURSOR_API_KEY

New-Item -ItemType Directory -Force $env:USERPROFILE\.openclaw\workspace
Copy-Item openclaw.secure.json $env:USERPROFILE\.openclaw\openclaw.json

.\docker-start-secure.ps1
```

**WSL2/Linux/macOS:** The script builds the OpenClaw image automatically on first run (expects repo at `../openclaw`, or set `OPENCLAW_REPO` in `.env`).
```bash
cd path/to/openclaw-docker
cp .env.secure .env
# Edit .env: set OPENCLAW_GATEWAY_TOKEN (e.g. openssl rand -hex 32), CURSOR_API_KEY

mkdir -p ~/.openclaw/workspace
cp openclaw.secure.json ~/.openclaw/openclaw.json

./scripts/docker-start-secure.sh
# Or one-time full setup: OPENCLAW_REPO=/path/to/openclaw ./secure-setup.sh
```

### 2. Custom skills

Skills in `skills/` (e.g. `skills/hcm-agent/`) are mounted into the container as **managed skills**. Edit them here and restart the gateway to pick up changes. No need to rebuild the OpenClaw image.

## Start / stop

**Windows (PowerShell):** From the repo directory (e.g. `C:\sandpit\openclaw-docker`):
```powershell
.\docker-start-secure.ps1
# Optional: rebuild image (e.g. after pulling openclaw changes)
$env:OPENCLAW_REPO = "C:\sandpit\openclaw"
.\docker-start-secure.ps1 -Rebuild
```

**WSL2/Linux/macOS:**
```bash
./scripts/docker-start-secure.sh
# Optional: REBUILD=1 OPENCLAW_REPO=/path/to/openclaw ./scripts/docker-start-secure.sh
```

## Useful commands

**PowerShell (from repo directory):**
```powershell
docker compose -f docker-compose.secure.yml logs -f openclaw-gateway
docker compose -f docker-compose.secure.yml run --rm openclaw-cli doctor
docker compose -f docker-compose.secure.yml run --rm openclaw-cli skills list
docker compose -f docker-compose.secure.yml down
```

**Bash (WSL2/Linux/macOS):** Same commands; use `./scripts/docker-start-secure.sh` to start.

## Control UI: "pairing required"

If the dashboard shows **disconnected (1008): pairing required**, the gateway is requiring device pairing. For local use (http://127.0.0.1) with token-only auth, the template enables `gateway.controlUi.allowInsecureAuth: true` so pairing is skipped.

- **New setup:** Copy `openclaw.secure.json` into your config dir (e.g. `data\openclaw.json` when using `OPENCLAW_CONFIG_DIR=...\data`).
- **Existing setup:** Copy the updated `openclaw.secure.json` over `data\openclaw.json` (or edit `data\openclaw.json` and set `gateway.controlUi.allowInsecureAuth` to `true`), then restart the gateway.

## Authentication

Same approach as [OpenClaw Authentication](https://docs.openclaw.ai/gateway/authentication): put API keys on the **gateway host**. Here the host is the container, so we use `.env` and the compose file injects them.

1. **Edit `.env`** and set the keys you need (never commit `.env`).
2. **Restart the gateway** so it picks up changes: `.\docker-start-secure.ps1` (or `./scripts/docker-start-secure.sh`).

| Use case | Env var | Notes |
|----------|---------|--------|
| Gateway token | `OPENCLAW_GATEWAY_TOKEN` | Required; used by Control UI / Cursor to connect. |
| Cursor CLI / Codex | `CURSOR_API_KEY` | For Cursor models and skills that need it. |
| Anthropic (Claude) | `ANTHROPIC_API_KEY` | Or use `openclaw models auth setup-token --provider anthropic` inside the container. |
| Google (Gemini) | `GEMINI_API_KEY` | For chat and memory-search embeddings. |
| xAI (Grok) | `XAI_API_KEY` | **Required for Grok.** Set in `.env` and restart; the gateway reads it from the container env. [Console](https://console.x.ai/) |
| OpenAI | `OPENAI_API_KEY` | For OpenAI models. |

**Grok shows "No API key" or `XAI_API_KEY` is empty in the container?** Put the key in **`.env.local`** (one line, no spaces): `XAI_API_KEY=your_key`. Get a key at [console.x.ai](https://console.x.ai/). Then run `.\docker-start-secure.ps1`. `.env.local` is loaded after `.env` and works when `.env` values don't reach the container on Windows.

To check model auth from the host:  
`docker compose -f docker-compose.secure.yml run --rm openclaw-cli models status`

## Security

- Never commit `.env`.
- Keep `OPENCLAW_GATEWAY_TOKEN` and API keys secret.
- Gateway binds to 127.0.0.1 only.

## Reference

- [OpenClaw docs](https://docs.openclaw.ai)
- [Cursor CLI](https://cursor.com/cli)
- [ClawHub](https://clawhub.ai) — discover more skills
