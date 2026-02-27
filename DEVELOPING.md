# Best Setup for OpenClaw and Development

A concise guide from official docs and community best practices (2026).

---

## 1. Choose Your Workflow

| Scenario | Recommended setup |
|----------|-------------------|
| **Local dev on Mac** | Native install + `pnpm gateway:watch` for hot-reload; macOS app in Local mode. |
| **Stable daily use** | Native install or macOS app; config in `~/.openclaw/`. |
| **Reproducible / multi-instance / VPS** | **Docker** (this repo’s `docker-compose.secure.yml`). |
| **Contributing to OpenClaw** | Clone [openclaw/openclaw](https://github.com/openclaw/openclaw), `pnpm install`, `pnpm gateway:watch`; keep your config in `~/.openclaw/` so updates don’t overwrite it. |

**Rule of thumb:** Don’t run production OpenClaw on your personal machine—it has broad system access. Use a VPS, Docker, or a dedicated machine.

---

## 2. Where Your “Tailoring” Lives

Keep customization **outside** the OpenClaw repo so updates don’t clobber it:

- **Workspace (prompts, memory, skills):** `~/.openclaw/workspace/`  
  - Contains: `AGENTS.md`, `SOUL.md`, `TOOLS.md`, `USER.md`, `memory/`, etc.  
  - **Tip:** Make this folder a **private git repo** for backup and versioning.
- **Config:** `~/.openclaw/openclaw.json` (or `openclaw.json` in your data dir when using `OPENCLAW_CONFIG_DIR`).

In **this repo**, we use `OPENCLAW_CONFIG_DIR=./data` and `OPENCLAW_WORKSPACE_DIR=./data/workspace`, so “tailoring” lives under `./data/` (which is in `.gitignore`—back it up separately).

---

## 3. Security First (Do Before Connecting Channels)

OpenClaw’s security model: **Identity first** (who can talk to the bot) → **Scope next** (where it can act) → **Model last** (assume the model can be manipulated; limit blast radius).

- **Configure `AGENTS.md`** in your workspace **before** connecting channels. It’s your security control plane (DM pairing, allowlists, tool scope).
- **Gateway:** Use token auth (default), bind to `127.0.0.1` (not `0.0.0.0`), disable mDNS discovery on production.
- **Sandbox:** For group/channel sessions use `sandbox.mode: "non-main"` and tool allowlists so the agent can’t run arbitrary commands everywhere.
- **Credentials:** API keys and tokens in `.env` / `.env.local` only; never commit them. Restrict permissions: `chmod 600 ~/.openclaw/credentials/*` (or equivalent).

**Check:**  
`openclaw health` and `openclaw status --all` (or via Docker: `docker compose -f docker-compose.secure.yml run --rm openclaw-cli health`).

---

## 4. Development with the Gateway (From OpenClaw Source)

If you’re hacking on the OpenClaw gateway itself:

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
pnpm install
pnpm gateway:watch
```

- Gateway runs with hot reload on port **18789**.
- Point the macOS app at **Local** mode so it uses this gateway.
- Your config and workspace stay in `~/.openclaw/`; the repo only provides the binary.

**Prereqs:** Node ≥22, pnpm. Use **Node** (not Bun)—Bun has known issues with WhatsApp/Telegram. On Windows, use **WSL2**.

---

## 5. Docker Development (This Repo)

- **First run:** Copy `.env.secure` → `.env`, set `OPENCLAW_GATEWAY_TOKEN` and API keys. Copy `openclaw.secure.json` into your config dir (e.g. `data/openclaw.json` when using `OPENCLAW_CONFIG_DIR=./data`).
- **Start:** `.\docker-start-secure.ps1` (Windows) or `./scripts/docker-start-secure.sh` (WSL2/Linux/macOS). The script builds the image from `OPENCLAW_REPO` (default: `../openclaw`) on first run.
- **Custom skills:** Edit files under `skills/`; restart the gateway to pick up changes (no image rebuild).
- **Rebuild image** after pulling OpenClaw changes:  
  `.\docker-start-secure.ps1 -Rebuild` or `REBUILD=1 ./scripts/docker-start-secure.sh`.

**Useful commands:**

```powershell
docker compose -f docker-compose.secure.yml logs -f openclaw-gateway
docker compose -f docker-compose.secure.yml run --rm openclaw-cli doctor
docker compose -f docker-compose.secure.yml run --rm openclaw-cli skills list
```

---

## 6. Production / Remote Access

- **Never expose the gateway on `0.0.0.0`** without auth and TLS. Prefer **SSH port-forward** for remote access:
  ```bash
  ssh -N -L 18789:127.0.0.1:18789 user@your-vps
  ```
- **HTTPS:** Put Caddy (or nginx) in front with Let’s Encrypt; set `trustedProxies` in OpenClaw config.
- **Options:** DigitalOcean 1-Click, Docker Compose on a VPS, or Tailscale for private access without opening ports.

---

## 7. Skills and System Prompts

- Define **scope** clearly in skills: role, capabilities, tone, escalation.
- **Least privilege:** Grant only the tools a skill needs; test each skill alone before combining.
- Avoid dangerous skills (raw shell, DB write, email send) unless required, and document restrictions.

---

## 8. Maintenance

- **Health:** `openclaw health` / `openclaw gateway status` (or via Docker as above).
- **Updates:** Back up `~/.openclaw` (or `./data`) before upgrading; then `git pull` + rebuild image if from source.
- **Prune:** Periodically prune old sessions/memory so the agent doesn’t get confused.
- **Audit:** Review `AGENTS.md` and gateway config (token, bind address, discovery) regularly.

---

## Quick Links

- [OpenClaw Setup (official)](https://docs.openclaw.ai/setup)
- [Gateway CLI](https://docs.openclaw.ai/cli/gateway)
- [Security & credential storage](https://docs.openclaw.ai/gateway/security#credential-storage-map)
- [Global Builders Club: Best practices](https://www.globalbuilders.club/blog/openclaw-best-practices)
- [Docker guide (community)](https://aiopenclaw.org/blog/openclaw-docker-complete-guide)
