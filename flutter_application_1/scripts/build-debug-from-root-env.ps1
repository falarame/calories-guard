param(
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

& (Join-Path $scriptRoot "build-debug.ps1") `
    -ApiBaseUrl $ApiBaseUrl `
    -SupabaseUrl $values["SUPABASE_URL"] `
    -SupabaseAnonKey $values["SUPABASE_ANON_KEY"] `
    -GoogleWebClientId $values["GOOGLE_WEB_CLIENT_ID"]
