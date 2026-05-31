[CmdletBinding()]
param(
    [switch]$KeepTemp
)

$ErrorActionPreference = "Stop"

$SkillRoot = Split-Path -Parent $PSScriptRoot
$FixturesDir = Join-Path $SkillRoot "tests\fixtures"
$TempDir = Join-Path $SkillRoot "tests\.tmp-smoke"
$InspectScript = Join-Path $PSScriptRoot "inspect_codex_config.ps1"
$RedactScript = Join-Path $PSScriptRoot "redact_secret.ps1"
$BackupScript = Join-Path $PSScriptRoot "backup_codex_config.ps1"
$RestoreScript = Join-Path $PSScriptRoot "restore_codex_config.ps1"
$EndpointScript = Join-Path $PSScriptRoot "test_openai_endpoint.js"

$script:Passed = 0

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
    $script:Passed += 1
}

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "Assertion failed: $Message. Expected '$Expected', got '$Actual'."
    }
    $script:Passed += 1
}

function Expand-Arguments {
    param([object[]]$Items)

    $expanded = New-Object System.Collections.Generic.List[string]
    foreach ($item in $Items) {
        if ($null -eq $item) {
            continue
        }
        if ($item -is [array]) {
            foreach ($inner in $item) {
                if ($null -ne $inner) {
                    $expanded.Add([string]$inner)
                }
            }
        }
        else {
            $expanded.Add([string]$item)
        }
    }
    return $expanded.ToArray()
}

function Invoke-JsonPowerShellScript {
    param(
        [string]$ScriptPath,
        [object[]]$Arguments
    )

    $expandedArguments = Expand-Arguments $Arguments
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @expandedArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Script failed: $ScriptPath $($expandedArguments -join ' ')"
    }
    return ($output | Out-String | ConvertFrom-Json)
}

function Invoke-JsonNodeScript {
    param([object[]]$Arguments)

    $expandedArguments = Expand-Arguments $Arguments
    $output = & node $EndpointScript @expandedArguments
    $exitCode = $LASTEXITCODE
    $json = $output | Out-String | ConvertFrom-Json
    if ($exitCode -ne 0 -and $json.api_key_status -ne "not_set") {
        throw "Node script failed: $($expandedArguments -join ' ')"
    }
    return $json
}

function Get-FixturePath {
    param([string]$Name)
    $path = Join-Path $FixturesDir $Name
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Fixture exists: $Name"
    return $path
}

function Reset-TempDir {
    if (Test-Path -LiteralPath $TempDir) {
        $resolvedRoot = (Resolve-Path -LiteralPath $SkillRoot).Path
        $resolvedTemp = (Resolve-Path -LiteralPath $TempDir).Path
        Assert-True $resolvedTemp.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase) "Temp directory stays inside skill root"
        Remove-Item -LiteralPath $TempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
}

function Test-InspectFixtures {
    $valid = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-valid.toml"), "-Json")
    Assert-Equal $valid.parse_status "basic_parse_succeeded" "Valid fixture parses"
    Assert-Equal $valid.selected_provider.base_url "https://api.openai.com/v1" "Valid fixture selects expected base_url"
    Assert-Equal @($valid.warnings).Count 0 "Valid fixture has no warnings"

    $missingV1 = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-missing-v1.toml"), "-Json")
    Assert-True ((@($missingV1.warnings) -join " ") -match "no path") "Missing /v1 fixture warns about empty path"

    $duplicateV1 = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-duplicate-v1.toml"), "-Json")
    Assert-True ((@($duplicateV1.warnings) -join " ") -match "duplicated /v1/v1") "Duplicate /v1 fixture warns"

    $mismatch = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-provider-mismatch.toml"), "-Json")
    Assert-Equal $mismatch.selected_provider $null "Provider mismatch has no selected provider"
    Assert-True ((@($mismatch.warnings) -join " ") -match "was not found") "Provider mismatch warns"

    $profileOverride = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-profile-provider-override.toml"), "-Profile", "proxy", "-Json")
    Assert-Equal $profileOverride.active_profile "proxy" "Profile override records active profile"
    Assert-Equal $profileOverride.model "relay-model" "Profile override selects profile model"
    Assert-Equal $profileOverride.selected_provider.id "relay" "Profile override selects profile provider"
    Assert-Equal $profileOverride.selected_provider.source "profile" "Profile provider source is reported"
    Assert-Equal $profileOverride.selected_provider.base_url "https://relay.example.com/v1" "Profile provider overrides base_url"

    $secret = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-secret-in-env-key.toml"), "-Json")
    Assert-Equal $secret.raw_secret_detected $true "Raw secret is detected"
    Assert-True ($secret.selected_provider.env_key -notmatch "abcdefghijklmnopqrstuvwxyz") "Secret-like env_key is redacted"

    $missingProfile = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-profile-missing.toml"), "-Profile", "missing-profile", "-Json")
    Assert-Equal $missingProfile.active_profile "missing-profile" "Missing profile records requested profile"
    Assert-True ((@($missingProfile.warnings) -join " ") -match "Active profile 'missing-profile' was requested") "Missing profile warns"

    $envName = "MISSING_API_KEY"
    Remove-Item -Path "Env:\$envName" -ErrorAction SilentlyContinue
    $missingEnv = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-env-key-not-set.toml"), "-CheckEnv", "-Json")
    Assert-Equal $missingEnv.selected_provider.env_key $envName "Missing env fixture reports env_key name"
    Assert-Equal $missingEnv.selected_provider.env_value_status "not_set" "Missing env fixture reports not_set"

    $dashboardUrl = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-dashboard-url.toml"), "-Json")
    Assert-True ((@($dashboardUrl.warnings) -join " ") -match "web page or documentation URL") "Dashboard URL fixture warns"

    $smartQuotes = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-invalid-smart-quotes.toml"), "-Json")
    Assert-True ((@($smartQuotes.warnings) -join " ") -match "smart quotes|mojibake quote") "Smart quote fixture warns"

    $projectPath = Join-Path $FixturesDir "project-override"
    Assert-True (Test-Path -LiteralPath (Join-Path $projectPath ".codex\config.toml") -PathType Leaf) "Project override fixture exists"
    $projectOverride = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-ProjectPath", $projectPath, "-Json")
    Assert-Equal $projectOverride.model "project-relay-model" "ProjectPath fixture selects project-style config"
    Assert-Equal $projectOverride.selected_provider.base_url "https://project-relay.example.com/v1" "ProjectPath fixture selects expected provider"

    $nonHttp = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-non-http-base-url.toml"), "-Json")
    Assert-True ((@($nonHttp.warnings) -join " ") -match "does not start with http:// or https://") "Non-http base_url fixture warns"

    $topLevelSecret = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-raw-top-level-secret.toml"), "-Json")
    Assert-Equal $topLevelSecret.raw_secret_detected $true "Top-level raw secret is detected"
    Assert-True ((@($topLevelSecret.raw_secret_fields) -join " ") -match "api_key") "Top-level raw secret field is reported"

    $officialUrlRelayKey = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-official-url-relay-key.toml"), "-Json")
    Assert-True ((@($officialUrlRelayKey.warnings) -join " ") -match "official OpenAI API.*relay/proxy-specific") "Official URL with relay key warns"

    $relayUrlOfficialKey = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-relay-url-official-key.toml"), "-Json")
    Assert-True ((@($relayUrlOfficialKey.warnings) -join " ") -match "relay/proxy.*OPENAI_API_KEY") "Relay URL with official key warns"

    $modelAliasMismatch = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", (Get-FixturePath "config-model-alias-mismatch.toml"), "-Json")
    Assert-True ((@($modelAliasMismatch.warnings) -join " ") -match "official-looking OpenAI model name") "Relay with official-looking model warns"

    $extensionTrapPath = Join-Path $FixturesDir "duplicate-file-extension\config.toml"
    $extensionTrap = Invoke-JsonPowerShellScript -ScriptPath $InspectScript -Arguments @("-Path", $extensionTrapPath, "-Json")
    Assert-Equal $extensionTrap.file_found $false "Duplicate extension fixture reports missing config.toml"
    Assert-True ((@($extensionTrap.warnings) -join " ") -match "config.toml.txt") "Duplicate extension fixture warns about config.toml.txt"
}

function Test-Redaction {
    $secret = "sk-testabcdefghijklmnopqrstuvwxyz123456"
    $result = Invoke-JsonPowerShellScript -ScriptPath $RedactScript -Arguments @("-Text", "api_key=$secret", "-Json")
    Assert-True ($result.redacted_text -notmatch [regex]::Escape($secret)) "Redaction removes full secret"
    Assert-True ($result.redaction_count -ge 1) "Redaction count is reported"
}

function Test-BackupAndRestore {
    $source = Get-FixturePath "config-valid.toml"
    $target = Join-Path $TempDir "config.toml"
    Copy-Item -LiteralPath $source -Destination $target

    $backup = Invoke-JsonPowerShellScript -ScriptPath $BackupScript -Arguments @("-Path", $target, "-BackupDirectory", $TempDir, "-Json")
    Assert-Equal $backup.created $true "Backup is created"
    Assert-True (Test-Path -LiteralPath $backup.backup_path -PathType Leaf) "Backup file exists"

    Set-Content -LiteralPath $target -Value "model = `"changed-model`"" -Encoding UTF8

    $preview = Invoke-JsonPowerShellScript -ScriptPath $RestoreScript -Arguments @("-BackupPath", $backup.backup_path, "-Path", $target, "-Json")
    Assert-Equal $preview.restored $false "Restore preview does not write"
    Assert-True ((Get-Content -Raw -LiteralPath $target) -match "changed-model") "Preview preserves current config"

    $restore = Invoke-JsonPowerShellScript -ScriptPath $RestoreScript -Arguments @("-BackupPath", $backup.backup_path, "-Path", $target, "-ConfirmRestore", "-Json")
    Assert-Equal $restore.restored $true "Restore writes after ConfirmRestore"
    Assert-True ((Get-Content -Raw -LiteralPath $target) -match "gpt-4.1") "Restored file contains backup content"
    Assert-True (Test-Path -LiteralPath $restore.pre_restore_backup_path -PathType Leaf) "Pre-restore backup exists"
}

function Test-EndpointNoKeyNoNetwork {
    $envName = "AI_CLI_CONFIG_HELPER_SMOKE_MISSING_KEY"
    Remove-Item -Path "Env:\$envName" -ErrorAction SilentlyContinue
    $result = Invoke-JsonNodeScript -Arguments @("--base-url", "https://example.com/v1", "--env-key", $envName, "--route", "models", "--json")
    Assert-Equal $result.api_key_status "not_set" "Endpoint test reports missing key"
    Assert-Equal $result.routes.models.tested $false "Endpoint test skips network when key is missing"
}

try {
    Reset-TempDir
    Test-InspectFixtures
    Test-Redaction
    Test-BackupAndRestore
    Test-EndpointNoKeyNoNetwork

    [pscustomobject]@{
        status = "passed"
        assertions = $script:Passed
        fixtures = (Get-ChildItem -LiteralPath $FixturesDir -Filter "*.toml" | Select-Object -ExpandProperty Name)
        temp_dir = if ($KeepTemp) { $TempDir } else { $null }
    } | ConvertTo-Json -Depth 4
}
finally {
    if (-not $KeepTemp -and (Test-Path -LiteralPath $TempDir)) {
        $resolvedRoot = (Resolve-Path -LiteralPath $SkillRoot).Path
        $resolvedTemp = (Resolve-Path -LiteralPath $TempDir).Path
        if ($resolvedTemp.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $TempDir -Recurse -Force
        }
    }
}
