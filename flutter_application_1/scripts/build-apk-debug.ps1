# Build debug APK with Supabase/API keys from the same .env as web deploy.
# Default env file: repo root backend/.env (same as deploy-web-cloudflare.ps1).
#
# Usage (from repo):
#   .\flutter_application_1\scripts\build-apk-debug.ps1
#
# Without backend/.env + SUPABASE_ANON_KEY the app shows "Missing Supabase configuration".

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
    Write-Error "Env file not found: $EnvFile`nCopy backend/.env.example to backend/.env and set SUPABASE_URL and SUPABASE_ANON_KEY."
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
    Write-Error "SUPABASE_URL is missing in $EnvFile"
}

$supabaseAnon = $values["SUPABASE_ANON_KEY"]
if ([string]::IsNullOrWhiteSpace($supabaseAnon)) {
    Write-Error "SUPABASE_ANON_KEY is missing in $EnvFile"
}

$googleWebClientId = ""
if ($values.ContainsKey("GOOGLE_WEB_CLIENT_ID") -and ![string]::IsNullOrWhiteSpace($values["GOOGLE_WEB_CLIENT_ID"])) {
    $googleWebClientId = $values["GOOGLE_WEB_CLIENT_ID"]
}

Write-Host "==> flutter build apk --debug (with dart-define from $EnvFile)..." -ForegroundColor Cyan
& (Join-Path $scriptRoot "build-debug.ps1") `
    -ApiBaseUrl $ApiBaseUrl `
    -SupabaseUrl $supabaseUrl `
    -SupabaseAnonKey $supabaseAnon `
    -GoogleWebClientId $googleWebClientId `
    -AppEnv "development"

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$built = Join-Path $flutterRoot "build\app\outputs\flutter-apk\app-debug.apk"
$copyTo = Join-Path $flutterRoot "app-debug.apk"
if (Test-Path -LiteralPath $built) {
    Copy-Item -LiteralPath $built -Destination $copyTo -Force
    Write-Host ""
    Write-Host "Copied: $copyTo" -ForegroundColor Green
}
