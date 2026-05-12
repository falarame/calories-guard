# Build Flutter Web (production) and deploy static assets to Cloudflare Workers
# via wrangler.toml in flutter_application_1/.
#
# Prerequisites:
#   - Flutter SDK on PATH
#   - Node.js (for npx wrangler)
#   - `npx wrangler login` once on this machine (or CLOUDFLARE_API_TOKEN in env)
#
# Secrets are read from a local .env file (default: repo backend/.env).
# Never commit real .env files.

param(
    [string]$EnvFile = "",
    [string]$ApiBaseUrl = "https://api.caloriesguard.com"
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterRoot = Split-Path -Parent $scriptRoot
$repoRoot = Split-Path -Parent $flutterRoot

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path $repoRoot "backend\.env"
} elseif (-not [System.IO.Path]::IsPathRooted($EnvFile)) {
    $EnvFile = Join-Path $repoRoot $EnvFile
}

if (-not (Test-Path -LiteralPath $EnvFile)) {
    Write-Error "Env file not found: $EnvFile`nCopy .env.example and fill SUPABASE_ANON_KEY (and optional GOOGLE_WEB_CLIENT_ID)."
}

$values = @{}
Get-Content -LiteralPath $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#") -or !$line.Contains("=")) {
        return
    }
    $parts = $line -split "=", 2
    $key = $parts[0].Trim()
    $value = $parts[1].Trim().Trim('"').Trim("'")
    $values[$key] = $value
}

if ($values.ContainsKey("API_BASE_URL") -and ![string]::IsNullOrWhiteSpace($values["API_BASE_URL"])) {
    $ApiBaseUrl = $values["API_BASE_URL"]
}
if ($ApiBaseUrl -and !$ApiBaseUrl.StartsWith("http://") -and !$ApiBaseUrl.StartsWith("https://")) {
    $ApiBaseUrl = "https://$ApiBaseUrl"
}

$supabaseUrl = $values["SUPABASE_URL"]
if ([string]::IsNullOrWhiteSpace($supabaseUrl)) {
    $supabaseUrl = $values["SUPABASE_PROJECT_URL"]
}
if ([string]::IsNullOrWhiteSpace($supabaseUrl)) {
    Write-Error "SUPABASE_URL (or SUPABASE_PROJECT_URL) is missing in $EnvFile"
}

$supabaseAnon = $values["SUPABASE_ANON_KEY"]
if ([string]::IsNullOrWhiteSpace($supabaseAnon)) {
    Write-Error "SUPABASE_ANON_KEY is missing in $EnvFile (required for Flutter web; see main.dart missing-config gate)."
}

$googleWebClientId = $values["GOOGLE_WEB_CLIENT_ID"]
if ([string]::IsNullOrWhiteSpace($googleWebClientId)) {
    $googleWebClientId = ""
}

Write-Host "==> flutter build web (release)..." -ForegroundColor Cyan
Push-Location $flutterRoot
try {
    $dartDefines = @(
        "--dart-define=API_BASE_URL=$ApiBaseUrl",
        "--dart-define=SUPABASE_URL=$supabaseUrl",
        "--dart-define=SUPABASE_ANON_KEY=$supabaseAnon",
        "--dart-define=APP_ENV=production"
    )
    if ($googleWebClientId) {
        $dartDefines += "--dart-define=GOOGLE_WEB_CLIENT_ID=$googleWebClientId"
    }
    & flutter build web --release @dartDefines
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    Pop-Location
}

Write-Host "==> npx wrangler deploy (Worker: app-caloriesguard)..." -ForegroundColor Cyan
Push-Location $flutterRoot
try {
    $env:NODE_TLS_REJECT_UNAUTHORIZED = "0"
    npx --yes wrangler@4 deploy
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    Pop-Location
}

Write-Host "Done. Smoke: https://app.caloriesguard.com/`n       or workers.dev URL from wrangler output." -ForegroundColor Green
