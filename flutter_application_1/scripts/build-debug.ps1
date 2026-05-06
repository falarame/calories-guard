param(
    [string]$ApiBaseUrl = "https://api.caloriesguard.com",
    [string]$SupabaseUrl,
    [string]$SupabaseAnonKey,
    [string]$GoogleWebClientId
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
    throw "Missing -SupabaseUrl"
}

if ([string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
    throw "Missing -SupabaseAnonKey"
}

if ([string]::IsNullOrWhiteSpace($GoogleWebClientId)) {
    throw "Missing -GoogleWebClientId"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
$env:DEBUG = ""

$flutterApk = Join-Path $projectRoot "android\app\build\outputs\flutter-apk\app-debug.apk"
$gradleApk = Join-Path $projectRoot "android\app\build\outputs\apk\debug\app-debug.apk"
$expectedFlutterPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-debug.apk"

$args = @(
    "build",
    "apk",
    "--debug",
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=SUPABASE_URL=$SupabaseUrl",
    "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey",
    "--dart-define=GOOGLE_WEB_CLIENT_ID=$GoogleWebClientId"
)

& flutter @args
$exitCode = $LASTEXITCODE

if (Test-Path $flutterApk) {
    $expectedDir = Split-Path -Parent $expectedFlutterPath
    if (!(Test-Path $expectedDir)) {
        New-Item -ItemType Directory -Path $expectedDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $flutterApk -Destination $expectedFlutterPath -Force
    Write-Host ""
    Write-Host "APK ready:"
    Write-Host "  $flutterApk"
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
    Write-Host "  $gradleApk"
    exit 0
}

exit $exitCode
