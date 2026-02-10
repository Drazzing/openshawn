---
name: hcm-agent
description: Build out and improve the HCM Platform repo (C:\sandpit\hcm) using Cursor CLI agent. User assists by reviewing PRs; agent works on feature branches and opens PRs.
metadata:
  {
    "openclaw": {
      "emoji": "🏢",
      "primaryEnv": "CURSOR_API_KEY",
    },
  }
---

# HCM Agent Skill

Use this skill when the user wants to **work on the HCM app**, **build out** features, or **finish development** on the HCM Platform repo. The agent implements changes; the user assists by reviewing and merging PRs.

## Target repo

- **In Docker container:** `/mnt/hcm` (mounted from host `C:\sandpit\hcm`)
- **Windows host:** `C:\sandpit\hcm`
- **WSL2:** `/mnt/c/sandpit/hcm`

Always set **workdir** to `/mnt/hcm` when running inside the Docker gateway.

## Context the agent must read

The HCM repo has at its root:

- **CONTEXT.md** — Stack, paths, run/test commands, PR workflow, definition of done.
- **AGENTS.md** — Operating principles, skills index (`.cursor/skills/`), docs pointers.
- **.cursor/rules/** — Implementation rules (start with `00-critical-quick-reference.mdc`, `hcm-project-rules.mdc`).

The coding agent **must** read CONTEXT.md and AGENTS.md before implementing. Use .cursor/rules and `instructions/` for task-specific rules.

## Stack (summary)

| Layer    | Tech        | Path in repo   |
|----------|-------------|----------------|
| Backend  | .NET 9      | `services/`    |
| Frontend | Next.js     | `web/`         |
| DB/Auth  | Supabase    | `supabase/`    |
| Config   | Centralized | `config/`      |

## Run and test

From repo root (PowerShell):

```powershell
# Full start
.\scripts\start-supabase.ps1
.\scripts\clean-start.ps1

# Or start services only
.\scripts\start.ps1
.\scripts\start.ps1 -Clean

# Backend tests
dotnet test

# Frontend (in web/)
cd web
npm run lint
npm test
npm run build
```

Logs: `logs/` at project root.

## PR workflow (user assists)

1. **Agent:** Create feature branch (`git checkout -b feature/<task-slug>`).
2. **Agent:** Implement; run `dotnet test` and in `web/` run `npm run lint` and `npm test`.
3. **Agent:** Commit, push branch, open PR with `gh pr create`. Do **not** push to main or merge.
4. **Agent:** Notify (e.g. `openclaw system event --text "Done: PR opened for <task>" --mode now`).
5. **User:** Review PR and merge.

## Pattern: one task with PR

```bash
# 1. Create feature branch
bash workdir:/mnt/hcm command:"git checkout -b feature/<task-slug>"

# 2. Run Cursor agent (read CONTEXT.md and AGENTS.md first; then do the task)
bash pty:true workdir:/mnt/hcm background:true command:"agent 'Read CONTEXT.md and AGENTS.md in this repo. Then: <user task>. Follow .cursor/rules and instructions/. When done: run dotnet test and (in web/) npm run lint and npm test; commit; push this branch; open a PR with gh pr create. Do NOT push to main or merge. Then run: openclaw system event --text \"Done: PR opened for <task>\" --mode now'"
```

On WSL2 use workdir `/mnt/c/sandpit/hcm`.

## Example: leave request API

```bash
bash workdir:/mnt/hcm command:"git checkout -b feature/leave-request-api"
bash pty:true workdir:/mnt/hcm background:true command:"agent 'Read CONTEXT.md and AGENTS.md. Implement the leave-request API per CONTEXT.md and existing patterns. When done: dotnet test, then in web/ npm run lint and npm test; commit; push; gh pr create --title \"feat: leave request API\" --body \"Implements leave request API\"; do NOT push to main or merge. Then: openclaw system event --text \"Done: PR opened for leave-request API\" --mode now'"
```

## Key rules

- **Always** workdir = `/mnt/hcm` (in Docker) or HCM host path; never run in OpenClaw workspace.
- **Always** feature branch; never push to main or merge.
- **Always** read CONTEXT.md and AGENTS.md before coding.
- **Always** run backend and frontend tests before opening PR.
- **Notify** user when PR is opened (e.g. via openclaw system event).
