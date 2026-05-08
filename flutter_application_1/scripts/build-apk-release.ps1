# Build release APK with Supabase/API keys from backend/.env (same as web deploy).
# Without android/key.properties, release uses debug keystore (see android/app/build.gradle.kts).
#
# Usage:
#   .\flutter_application_1\scripts\build-apk-release.ps1
# If release keystore passwords are wrong locally, use -UseDebugSigning (sideload / QA only).

param(
    [string]$EnvFile = "",
    [string]$ApiBaseUrl = "https://api.caloriesguard.com",
    [switch]$UseDebugSigning
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

$keyProps = Join-Path $flutterRoot "android\key.properties"
$keyPropsOff = Join-Path $flutterRoot "android\key.properties.off-build"
if ($UseDebugSigning -and (Test-Path -LiteralPath $keyProps)) {
    Write-Host "==> -UseDebugSigning: temporarily renaming android\key.properties" -ForegroundColor Yellow
    if (Test-Path -LiteralPath $keyPropsOff) { Remove-Item -LiteralPath $keyPropsOff -Force }
    Rename-Item -LiteralPath $keyProps -NewName "key.properties.off-build"
}

try {
    Write-Host "==> flutter build apk --release (with dart-define from $EnvFile)..." -ForegroundColor Cyan
    & (Join-Path $scriptRoot "build-release.ps1") `
        -ApiBaseUrl $ApiBaseUrl `
        -SupabaseUrl $supabaseUrl `
        -SupabaseAnonKey $supabaseAnon `
        -GoogleWebClientId $googleWebClientId `
        -AppEnv "production"

    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    if ($UseDebugSigning -and (Test-Path -LiteralPath $keyPropsOff)) {
        Rename-Item -LiteralPath $keyPropsOff -NewName "key.properties"
        Write-Host "==> Restored android\key.properties" -ForegroundColor Green
    }
}

$built = Join-Path $flutterRoot "build\app\outputs\flutter-apk\app-release.apk"
$copyTo = Join-Path $flutterRoot "app-release.apk"
if (Test-Path -LiteralPath $built) {
    Copy-Item -LiteralPath $built -Destination $copyTo -Force
    Write-Host ""
    Write-Host "Copied: $copyTo" -ForegroundColor Green
}
