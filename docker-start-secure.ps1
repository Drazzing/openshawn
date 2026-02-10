# Start OpenClaw gateway with hardened Docker Compose (this repo).
# Stops existing containers, then starts. Image is built from the OpenClaw repo.
# Usage: .\docker-start-secure.ps1
#        .\docker-start-secure.ps1 -Rebuild   # build image from OPENCLAW_REPO first

param(
    [switch]$Rebuild   # Build openclaw:local from OPENCLAW_REPO before starting.
)

$ErrorActionPreference = "Stop"
$RootDir = $PSScriptRoot
Set-Location $RootDir

$envFile = Join-Path $RootDir ".env"
$envSecure = Join-Path $RootDir ".env.secure"
if (-not (Test-Path $envFile)) {
    if (Test-Path $envSecure) {
        Copy-Item $envSecure $envFile
        Write-Host "Created .env from .env.secure." -ForegroundColor Green
        Write-Host "Edit .env and set OPENCLAW_GATEWAY_TOKEN (replace CHANGE_ME_...) and any API keys, then run:" -ForegroundColor Yellow
        Write-Host "  .\docker-start-secure.ps1" -ForegroundColor Cyan
        exit 1
    }
    Write-Host ".env not found. Copy .env.secure to .env and set OPENCLAW_GATEWAY_TOKEN." -ForegroundColor Red
    exit 1
}
Get-Content $envFile -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if ($line -and $line -match '^\s*([^#][^=]+)=(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

# Set config/workspace paths — always use USERPROFILE on Windows (${HOME} is not set)
if (-not $env:OPENCLAW_CONFIG_DIR -or $env:OPENCLAW_CONFIG_DIR -match '^\$\{' -or $env:OPENCLAW_CONFIG_DIR -eq '') {
    $env:OPENCLAW_CONFIG_DIR = "$env:USERPROFILE\.openclaw"
}
if (-not $env:OPENCLAW_WORKSPACE_DIR -or $env:OPENCLAW_WORKSPACE_DIR -match '^\$\{' -or $env:OPENCLAW_WORKSPACE_DIR -eq '') {
    $env:OPENCLAW_WORKSPACE_DIR = "$env:USERPROFILE\.openclaw\workspace"
}
# Ensure directories exist
if (-not (Test-Path $env:OPENCLAW_CONFIG_DIR))   { New-Item -ItemType Directory -Force $env:OPENCLAW_CONFIG_DIR   | Out-Null }
if (-not (Test-Path $env:OPENCLAW_WORKSPACE_DIR)) { New-Item -ItemType Directory -Force $env:OPENCLAW_WORKSPACE_DIR | Out-Null }
# Optional .env.local for secrets that don't load from .env (e.g. XAI_API_KEY on Windows)
$envLocal = Join-Path $RootDir ".env.local"
if (-not (Test-Path $envLocal)) {
    Set-Content -Path $envLocal -Value "# Add secrets here (overrides .env). Example: XAI_API_KEY=your_key" -Encoding UTF8
    Write-Host "Created .env.local (add XAI_API_KEY=yourkey here if Grok key does not load from .env)." -ForegroundColor DarkGray
}
# Ensure gateway config exists (skills + allowInsecureAuth for token-only UI)
$configJson = Join-Path $env:OPENCLAW_CONFIG_DIR "openclaw.json"
$configTemplate = Join-Path $RootDir "openclaw.secure.json"
if (-not (Test-Path $configJson) -and (Test-Path $configTemplate)) {
    Copy-Item $configTemplate $configJson
    Write-Host "Created $configJson from openclaw.secure.json (skills + token-only UI)." -ForegroundColor Green
}
$tokenPlaceholder = "CHANGE_ME_GENERATE_A_STRONG_TOKEN"
if (-not $env:OPENCLAW_GATEWAY_TOKEN -or $env:OPENCLAW_GATEWAY_TOKEN -eq $tokenPlaceholder) {
    # Fallback: read token line directly from .env (handles encoding/parsing edge cases)
    $tokenLine = Get-Content $envFile -Encoding UTF8 | Where-Object { $_ -match '^\s*OPENCLAW_GATEWAY_TOKEN=(.+)$' } | Select-Object -First 1
    if ($tokenLine -match '^\s*OPENCLAW_GATEWAY_TOKEN=(.+)$') {
        $env:OPENCLAW_GATEWAY_TOKEN = $matches[1].Trim()
    }
}
if (-not $env:OPENCLAW_GATEWAY_TOKEN -or $env:OPENCLAW_GATEWAY_TOKEN -eq $tokenPlaceholder) {
    Write-Host "OPENCLAW_GATEWAY_TOKEN not set or still placeholder. Edit .env and set it to a strong random value (e.g. 32+ hex chars), then run:" -ForegroundColor Red
    Write-Host "  .\docker-start-secure.ps1" -ForegroundColor Cyan
    exit 1
}

$ComposeFile = "docker-compose.secure.yml"
$ComposePath = Join-Path $RootDir $ComposeFile
$ImageName = if ($env:OPENCLAW_IMAGE) { $env:OPENCLAW_IMAGE } else { "openclaw:local" }

# Default OPENCLAW_REPO to sibling openclaw directory so compose build context works
if (-not $env:OPENCLAW_REPO) {
    $env:OPENCLAW_REPO = Join-Path (Split-Path $RootDir -Parent) "openclaw"
}

# Build image if missing or -Rebuild requested
$imageExists = $false
$ErrorActionPreference = 'SilentlyContinue'
docker image inspect $ImageName 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { $imageExists = $true }
$ErrorActionPreference = 'Stop'

if (-not $imageExists -or $Rebuild) {
    if (-not (Test-Path $env:OPENCLAW_REPO)) {
        Write-Host "OPENCLAW_REPO path not found: $env:OPENCLAW_REPO" -ForegroundColor Red
        Write-Host "Set OPENCLAW_REPO in .env to your OpenClaw source repo (e.g. C:\sandpit\openclaw)." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "==> Building image from OpenClaw repo: $env:OPENCLAW_REPO" -ForegroundColor Cyan
    docker compose -f $ComposePath --env-file $envFile build openclaw-gateway
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "==> Stopping existing containers" -ForegroundColor Cyan
# Use cmd so stderr from "docker compose down" (e.g. "[+] down 0/1") doesn't surface as PowerShell NativeCommandError
$ErrorActionPreference = 'SilentlyContinue'
cmd /c "docker compose -f `"$ComposePath`" --env-file `"$envFile`" down 2>nul"
$ErrorActionPreference = 'Stop'

Write-Host "==> Starting OpenClaw gateway" -ForegroundColor Cyan
docker compose -f $ComposePath --env-file $envFile up -d openclaw-gateway
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$port = if ($env:OPENCLAW_GATEWAY_PORT) { $env:OPENCLAW_GATEWAY_PORT } else { "18789" }
Write-Host ""
Write-Host "Gateway is running. Dashboard: http://127.0.0.1:$port/" -ForegroundColor Green
Write-Host "Token: $env:OPENCLAW_GATEWAY_TOKEN"
Write-Host "  (Paste this token in Control UI / Cursor gateway settings to connect.)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Useful: docker compose -f $ComposeFile logs -f openclaw-gateway"
Write-Host "        docker compose -f $ComposeFile down"
