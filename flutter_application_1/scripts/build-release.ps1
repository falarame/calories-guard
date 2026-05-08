param(
    [string]$ApiBaseUrl = "https://api.caloriesguard.com",
    [string]$SupabaseUrl,
    [string]$SupabaseAnonKey,
    [string]$GoogleWebClientId = "",
    [string]$AppEnv = "production"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
    throw "Missing -SupabaseUrl"
}

if ([string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
    throw "Missing -SupabaseAnonKey"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
$env:DEBUG = ""

$flutterBuildApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
$legacyFlutterApk = Join-Path $projectRoot "android\app\build\outputs\flutter-apk\app-release.apk"
$gradleApk = Join-Path $projectRoot "android\app\build\outputs\apk\release\app-release.apk"
$expectedFlutterPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"

$args = @(
    "build",
    "apk",
    "--release",
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=SUPABASE_URL=$SupabaseUrl",
    "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey",
    "--dart-define=APP_ENV=$AppEnv"
)
if (-not [string]::IsNullOrWhiteSpace($GoogleWebClientId)) {
    $args += "--dart-define=GOOGLE_WEB_CLIENT_ID=$GoogleWebClientId"
}

& flutter @args
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    exit $exitCode
}

if (Test-Path $flutterBuildApk) {
    Write-Host ""
    Write-Host "APK ready:"
    Write-Host "  $flutterBuildApk"
    exit 0
}

if (Test-Path $legacyFlutterApk) {
    $expectedDir = Split-Path -Parent $expectedFlutterPath
    if (!(Test-Path $expectedDir)) {
        New-Item -ItemType Directory -Path $expectedDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $legacyFlutterApk -Destination $expectedFlutterPath -Force
    Write-Host ""
    Write-Host "APK ready:"
    Write-Host "  $expectedFlutterPath"
    exit 0
}

if (Test-Path $gradleApk) {
    $expectedDir = Split-Path -Parent $expectedFlutterPath
    if (!(Test-Path $expectedDir)) {
        New-Item -ItemType Directory -Path $expectedDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $gradleApk -Destination $expectedFlutterPath -Force
    Write-Host ""
    Write-Host "APK ready:"
    Write-Host "  $expectedFlutterPath"
    exit 0
}

exit $exitCode
