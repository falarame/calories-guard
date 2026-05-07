param(
    [string]$DeviceId = "",
    [string]$RootEnvPath = "..\.env",
    [string]$ApiBaseUrl = "https://api.caloriesguard.com"
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$resolvedEnvPath = Resolve-Path -Path (Join-Path $projectRoot $RootEnvPath)

$values = @{}
Get-Content -LiteralPath $resolvedEnvPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#") -or !$line.Contains("=")) {
        return
    }

    $parts = $line -split "=", 2
    $key = $parts[0].Trim()
    $value = $parts[1].Trim()
    $values[$key] = $value.Trim('"').Trim("'")
}

if ($values.ContainsKey("API_BASE_URL") -and ![string]::IsNullOrWhiteSpace($values["API_BASE_URL"])) {
    $ApiBaseUrl = $values["API_BASE_URL"]
}

if ($ApiBaseUrl -and !$ApiBaseUrl.StartsWith("http://") -and !$ApiBaseUrl.StartsWith("https://")) {
    $ApiBaseUrl = "https://$ApiBaseUrl"
}

Set-Location $projectRoot
$env:DEBUG = ""
adb forward --remove-all

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    $devices = flutter devices --machine | ConvertFrom-Json
    $androidDevice = $devices | Where-Object {
        $_.targetPlatform -like "android*" -or $_.id -like "emulator-*"
    } | Select-Object -First 1

    if ($null -eq $androidDevice) {
        throw "No Android device/emulator found. Start an emulator or pass -DeviceId explicitly."
    }

    $DeviceId = $androidDevice.id
    Write-Host "Using Android device: $DeviceId"
}

& flutter run `
    -d $DeviceId `
    --debug `
    --dart-define=API_BASE_URL=$ApiBaseUrl `
    --dart-define=SUPABASE_URL=$($values["SUPABASE_URL"]) `
    --dart-define=SUPABASE_ANON_KEY=$($values["SUPABASE_ANON_KEY"]) `
    --dart-define=GOOGLE_WEB_CLIENT_ID=$($values["GOOGLE_WEB_CLIENT_ID"])
