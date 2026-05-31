[CmdletBinding()]
param(
    [string]$Path,
    [string]$ProjectPath,
    [string]$Profile,
    [switch]$CheckEnv,
    [switch]$IncludeRawRedacted,
    [switch]$Json
)

function Protect-SecretValue {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    $trimmed = $Value.Trim()
    if ($trimmed.Length -lt 12) {
        return "[REDACTED]"
    }
    if ($trimmed.StartsWith("sk-") -and $trimmed.Length -ge 8) {
        return "sk-..." + $trimmed.Substring($trimmed.Length - 4)
    }
    return $trimmed.Substring(0, 4) + "..." + $trimmed.Substring($trimmed.Length - 4)
}

function Test-SecretLikeValue {
    param([AllowEmptyString()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $trimmed = $Value.Trim().Trim('"', "'")
    return (
        $trimmed -match '^sk-[A-Za-z0-9_\-]{8,}$' -or
        $trimmed -match '^[A-Za-z0-9_\-]{24,}$' -or
        $trimmed -match '^[A-Za-z0-9+/]{32,}={0,2}$'
    )
}

function Redact-Text {
    param([AllowEmptyString()][string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    $result = $Text
    $result = [regex]::Replace($result, '(?im)(\bAuthorization\s*:\s*Bearer\s+)([^\s"'']+)', {
        param($m)
        $m.Groups[1].Value + (Protect-SecretValue $m.Groups[2].Value)
    })
    $result = [regex]::Replace($result, '(?im)(^|[\s,{])((?:api[_-]?key|token|access[_-]?token|refresh[_-]?token|bearer[_-]?token|experimental_bearer_token|secret|client[_-]?secret|password|passwd|pwd)\s*[:=]\s*)(["'']?)([^"'',\r\n#\s]+)(["'']?)', {
        param($m)
        $m.Groups[1].Value + $m.Groups[2].Value + $m.Groups[3].Value + (Protect-SecretValue $m.Groups[4].Value) + $m.Groups[5].Value
    })
    $result = [regex]::Replace($result, '(?<![A-Za-z0-9_\-])(sk-[A-Za-z0-9_\-]{12,})(?![A-Za-z0-9_\-])', {
        param($m)
        Protect-SecretValue $m.Groups[1].Value
    })
    return $result
}

function Convert-TomlValue {
    param([AllowEmptyString()][string]$Value)

    $v = $Value.Trim()
    $commentIndex = $v.IndexOf('#')
    if ($commentIndex -ge 0) {
        $v = $v.Substring(0, $commentIndex).Trim()
    }
    if ($v.Length -ge 2) {
        $first = $v.Substring(0, 1)
        $last = $v.Substring($v.Length - 1, 1)
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
            return $v.Substring(1, $v.Length - 2)
        }
    }
    return $v
}

function Normalize-TomlTablePart {
    param([AllowEmptyString()][string]$Value)

    if ($null -eq $Value) {
        return $Value
    }

    $trimmed = $Value.Trim()
    if ($trimmed.Length -ge 2) {
        $first = $trimmed.Substring(0, 1)
        $last = $trimmed.Substring($trimmed.Length - 1, 1)
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
            return $trimmed.Substring(1, $trimmed.Length - 2)
        }
    }
    return $trimmed
}

function ConvertFrom-SimpleCodexToml {
    param([string]$Text)

    $top = [ordered]@{}
    $providers = [ordered]@{}
    $profiles = [ordered]@{}
    $profileProviders = [ordered]@{}
    $currentSection = "top"
    $currentProvider = $null
    $currentProfile = $null
    $parseWarnings = New-Object System.Collections.Generic.List[string]
    $lineNumber = 0

    foreach ($line in ($Text -split "`r?`n")) {
        $lineNumber += 1
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) {
            continue
        }

        if ($trimmed -match '[\u2018\u2019\u201C\u201D]' -or $trimmed -match ([string][char]0x9225)) {
            $parseWarnings.Add("Line $lineNumber contains smart quotes or mojibake quote markers. TOML requires straight quotes.")
        }

        if ($trimmed -match '^\[profiles\.([^\]]+)\.model_providers\.([^\]]+)\]\s*$') {
            $currentSection = "profile_provider"
            $currentProfile = Normalize-TomlTablePart $Matches[1]
            $currentProvider = Normalize-TomlTablePart $Matches[2]
            if (-not $profileProviders.Contains($currentProfile)) {
                $profileProviders[$currentProfile] = [ordered]@{}
            }
            if (-not $profileProviders[$currentProfile].Contains($currentProvider)) {
                $profileProviders[$currentProfile][$currentProvider] = [ordered]@{}
            }
            continue
        }

        if ($trimmed -match '^\[profiles\.([^\]]+)\]\s*$') {
            $currentSection = "profile"
            $currentProfile = Normalize-TomlTablePart $Matches[1]
            $currentProvider = $null
            if (-not $profiles.Contains($currentProfile)) {
                $profiles[$currentProfile] = [ordered]@{}
            }
            continue
        }

        if ($trimmed -match '^\[model_providers\.([^\]]+)\]\s*$') {
            $currentSection = "provider"
            $currentProvider = Normalize-TomlTablePart $Matches[1]
            $currentProfile = $null
            if (-not $providers.Contains($currentProvider)) {
                $providers[$currentProvider] = [ordered]@{}
            }
            continue
        }

        if ($trimmed -match '^\[(.+)\]\s*$') {
            $currentSection = "other"
            $currentProvider = $null
            $currentProfile = $null
            continue
        }

        if ($trimmed -match '^([A-Za-z0-9_\-\.]+)\s*=\s*(.+)$') {
            $key = $Matches[1]
            $value = Convert-TomlValue $Matches[2]
            if ($currentSection -eq "provider" -and $null -ne $currentProvider) {
                $providers[$currentProvider][$key] = $value
            }
            elseif ($currentSection -eq "profile" -and $null -ne $currentProfile) {
                $profiles[$currentProfile][$key] = $value
            }
            elseif ($currentSection -eq "profile_provider" -and $null -ne $currentProfile -and $null -ne $currentProvider) {
                $profileProviders[$currentProfile][$currentProvider][$key] = $value
            }
            else {
                $top[$key] = $value
            }
        }
        elseif ($trimmed -match '=') {
            $parseWarnings.Add("Line $lineNumber may not be parsed correctly: $trimmed")
        }
    }

    [pscustomobject]@{
        top = $top
        providers = $providers
        profiles = $profiles
        profile_providers = $profileProviders
        parse_warnings = @($parseWarnings)
    }
}

function Merge-OrderedTable {
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )

    $merged = [ordered]@{}
    if ($null -ne $Base) {
        foreach ($key in $Base.Keys) {
            $merged[$key] = $Base[$key]
        }
    }
    if ($null -ne $Override) {
        foreach ($key in $Override.Keys) {
            $merged[$key] = $Override[$key]
        }
    }
    return $merged
}

function Get-DefaultConfigPath {
    Join-Path $env:USERPROFILE ".codex\config.toml"
}

function Get-EnvStatus {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return "not_configured"
    }

    $sessionValue = [Environment]::GetEnvironmentVariable($Name, "Process")
    if (-not [string]::IsNullOrEmpty($sessionValue)) {
        return "set_in_current_session_redacted"
    }

    $userValue = [Environment]::GetEnvironmentVariable($Name, "User")
    if (-not [string]::IsNullOrEmpty($userValue)) {
        return "set_at_user_scope_not_visible_in_current_session"
    }

    $machineValue = [Environment]::GetEnvironmentVariable($Name, "Machine")
    if (-not [string]::IsNullOrEmpty($machineValue)) {
        return "set_at_machine_scope_not_visible_in_current_session"
    }

    return "not_set"
}

function Get-BaseUrlWarnings {
    param([AllowEmptyString()][string]$BaseUrl)

    $warnings = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        $warnings.Add("selected provider has no base_url.")
        return @($warnings)
    }

    if ($BaseUrl -notmatch '^https?://') {
        $warnings.Add("base_url does not start with http:// or https://.")
    }
    if ($BaseUrl -match '/v1/v1(?:/|$)') {
        $warnings.Add("base_url contains duplicated /v1/v1.")
    }
    if ($BaseUrl -match '(dashboard|console|login|docs|documentation)') {
        $warnings.Add("base_url looks like a web page or documentation URL, not an API endpoint.")
    }
    if ($BaseUrl -match '^https?://[^/]+/?$') {
        $warnings.Add("base_url has no path. Some OpenAI-compatible providers require /v1; verify with provider docs.")
    }
    return @($warnings)
}

function Test-OpenAIBaseUrl {
    param([AllowEmptyString()][string]$BaseUrl)

    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        return $false
    }
    return ($BaseUrl -match '^https?://api\.openai\.com(?:/|$)')
}

function Test-RelayLikeText {
    param([AllowEmptyString()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    return ($Value -match '(?i)(relay|proxy|openrouter|oneapi|newapi|gateway|router|中转|代理)')
}

function Test-OfficialOpenAIEnvKey {
    param([AllowEmptyString()][string]$EnvKey)

    if ([string]::IsNullOrWhiteSpace($EnvKey)) {
        return $false
    }
    return ($EnvKey -match '^(OPENAI_API_KEY|OPENAI_KEY)$')
}

function Test-OfficialLookingOpenAIModel {
    param([AllowEmptyString()][string]$Model)

    if ([string]::IsNullOrWhiteSpace($Model)) {
        return $false
    }
    return ($Model -match '^(gpt|o[0-9]|text-|tts-|whisper-|dall-e)')
}

function Get-ProviderConsistencyWarnings {
    param(
        [AllowEmptyString()][string]$ProviderId,
        [AllowEmptyString()][string]$ProviderName,
        [AllowEmptyString()][string]$BaseUrl,
        [AllowEmptyString()][string]$EnvKey,
        [AllowEmptyString()][string]$Model
    )

    $warnings = New-Object System.Collections.Generic.List[string]
    $relayLike = (Test-RelayLikeText $ProviderId) -or (Test-RelayLikeText $ProviderName) -or (Test-RelayLikeText $BaseUrl) -or (Test-RelayLikeText $EnvKey)
    $officialOpenAIBase = Test-OpenAIBaseUrl $BaseUrl
    $officialOpenAIEnv = Test-OfficialOpenAIEnvKey $EnvKey

    if ($officialOpenAIBase -and (Test-RelayLikeText $EnvKey)) {
        $warnings.Add("base_url points to the official OpenAI API, but env_key looks relay/proxy-specific. Verify the API key belongs to this base_url.")
    }

    if (-not $officialOpenAIBase -and $relayLike -and $officialOpenAIEnv) {
        $warnings.Add("provider looks like a relay/proxy, but env_key is OPENAI_API_KEY. Verify whether this relay expects its own API key or an official OpenAI key.")
    }

    if (-not $officialOpenAIBase -and $relayLike -and (Test-OfficialLookingOpenAIModel $Model)) {
        $warnings.Add("provider looks like a relay/proxy, but model uses an official-looking OpenAI model name. Verify the relay's exact model alias.")
    }

    return @($warnings)
}

function Get-ConfigPath {
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }
    if (-not [string]::IsNullOrWhiteSpace($ProjectPath)) {
        return (Join-Path $ProjectPath ".codex\config.toml")
    }
    return Get-DefaultConfigPath
}

function Get-ExtensionWarnings {
    param([string]$ConfigPath)

    $warnings = New-Object System.Collections.Generic.List[string]
    $folder = Split-Path -Parent $ConfigPath
    if (Test-Path -LiteralPath $folder -PathType Container) {
        $similar = Get-ChildItem -Force -LiteralPath $folder -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^config\.toml\.' }
        foreach ($item in $similar) {
            $warnings.Add("Found similar file '$($item.Name)'. Codex expects config.toml exactly, not $($item.Name).")
        }
    }
    return @($warnings)
}

try {
    $configPath = Get-ConfigPath
    $resolvedPath = $null
    $warnings = New-Object System.Collections.Generic.List[string]

    $fileFound = Test-Path -LiteralPath $configPath -PathType Leaf
    foreach ($warning in @(Get-ExtensionWarnings $configPath)) {
        $warnings.Add($warning)
    }

    if (-not $fileFound) {
        $report = [ordered]@{
            config_path = $configPath
            file_found = $false
            parse_status = "not_read"
            message = "Config file not found. Codex may be using defaults, a different profile, or another config path."
            warnings = @($warnings)
        }
        if ($Json) {
            $report | ConvertTo-Json -Depth 6
        }
        else {
            "Codex Config Inspection"
            ""
            "Config path: $configPath"
            "File status: Not found"
            "Message: $($report.message)"
            if ($warnings.Count -gt 0) {
                ""
                "Warnings:"
                foreach ($warning in $warnings) { "- $warning" }
            }
        }
        exit 0
    }

    $resolvedPath = (Resolve-Path -LiteralPath $configPath).Path
    $raw = Get-Content -Raw -LiteralPath $resolvedPath
    $parsed = ConvertFrom-SimpleCodexToml $raw

    foreach ($warning in $parsed.parse_warnings) {
        $warnings.Add($warning)
    }

    $activeProfile = $null
    $effectiveTop = $parsed.top
    $effectiveProviders = $parsed.providers

    if (-not [string]::IsNullOrWhiteSpace($Profile)) {
        $activeProfile = $Profile
    }
    elseif (-not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable("CODEX_PROFILE", "Process"))) {
        $activeProfile = [Environment]::GetEnvironmentVariable("CODEX_PROFILE", "Process")
    }

    if (-not [string]::IsNullOrWhiteSpace($activeProfile)) {
        if ($parsed.profiles.Contains($activeProfile)) {
            $effectiveTop = Merge-OrderedTable -Base $parsed.top -Override $parsed.profiles[$activeProfile]
        }
        else {
            $warnings.Add("Active profile '$activeProfile' was requested, but [profiles.$activeProfile] was not found in this config.")
        }

        if ($parsed.profile_providers.Contains($activeProfile)) {
            $effectiveProviders = Merge-OrderedTable -Base $parsed.providers -Override $parsed.profile_providers[$activeProfile]
        }
    }

    $model = $effectiveTop["model"]
    $modelProvider = $effectiveTop["model_provider"]
    $selectedProvider = $null

    if (-not [string]::IsNullOrWhiteSpace($modelProvider)) {
        if ($effectiveProviders.Contains($modelProvider)) {
            $providerData = $effectiveProviders[$modelProvider]
            $envKey = $providerData["env_key"]
            $envStatus = if (Test-SecretLikeValue $envKey) { "not_checked_env_key_looks_like_secret" } elseif ($CheckEnv) { Get-EnvStatus $envKey } else { "not_checked" }
            $envKeyForReport = if (Test-SecretLikeValue $envKey) { Protect-SecretValue $envKey } else { $envKey }
            $selectedProvider = [ordered]@{
                id = $modelProvider
                source = if (-not [string]::IsNullOrWhiteSpace($activeProfile) -and $parsed.profile_providers.Contains($activeProfile) -and $parsed.profile_providers[$activeProfile].Contains($modelProvider)) { "profile" } else { "top_level" }
                name = $providerData["name"]
                base_url = $providerData["base_url"]
                env_key = $envKeyForReport
                env_value_status = $envStatus
            }
            foreach ($warning in @(Get-BaseUrlWarnings $providerData["base_url"])) {
                $warnings.Add($warning)
            }
            foreach ($warning in @(Get-ProviderConsistencyWarnings -ProviderId $modelProvider -ProviderName $providerData["name"] -BaseUrl $providerData["base_url"] -EnvKey $envKey -Model $model)) {
                $warnings.Add($warning)
            }
        }
        else {
            $warnings.Add("model_provider points to '$modelProvider', but [model_providers.$modelProvider] was not found.")
        }
    }
    else {
        $warnings.Add("model_provider is not set in the inspected top-level config.")
    }

    foreach ($providerId in $effectiveProviders.Keys) {
        $providerData = $effectiveProviders[$providerId]
        if ($providerData.Contains("base_url")) {
            foreach ($warning in @(Get-BaseUrlWarnings $providerData["base_url"])) {
                $prefix = if ($providerId -eq $modelProvider) { "" } else { "model_providers.${providerId}: " }
                $message = "$prefix$warning"
                if (-not $warnings.Contains($message)) {
                    $warnings.Add($message)
                }
            }
        }
        if ($providerData.Contains("env_key") -and (Test-SecretLikeValue $providerData["env_key"])) {
            $message = "model_providers.$providerId.env_key appears to contain a raw secret. env_key should usually be an environment variable name, not the key value itself."
            if (-not $warnings.Contains($message)) {
                $warnings.Add($message)
            }
        }
    }

    $rawSecretDetected = $false
    $secretFields = New-Object System.Collections.Generic.List[string]
    foreach ($key in $effectiveTop.Keys) {
        if ($key -match '(api[_-]?key|token|secret|password|passwd|pwd)' -and (Test-SecretLikeValue $effectiveTop[$key])) {
            $rawSecretDetected = $true
            $secretFields.Add($key)
        }
    }
    foreach ($providerId in $effectiveProviders.Keys) {
        foreach ($key in $effectiveProviders[$providerId].Keys) {
            if (($key -match '(api[_-]?key|token|secret|password|passwd|pwd)' -or $key -eq "env_key") -and (Test-SecretLikeValue $effectiveProviders[$providerId][$key])) {
                $rawSecretDetected = $true
                $secretFields.Add("model_providers.$providerId.$key")
            }
        }
    }
    if ($rawSecretDetected) {
        $warnings.Add("Raw secret-like value detected in config. Prefer env_key and environment variables instead of storing secrets directly.")
    }

    $report = [ordered]@{
        config_path = $resolvedPath
        file_found = $true
        parse_status = "basic_parse_succeeded"
        active_profile = $activeProfile
        profile_ids = @($parsed.profiles.Keys)
        model = $model
        model_provider = $modelProvider
        provider_ids = @($effectiveProviders.Keys)
        selected_provider = $selectedProvider
        raw_secret_detected = $rawSecretDetected
        raw_secret_fields = @($secretFields)
        warnings = @($warnings)
    }

    if ($IncludeRawRedacted) {
        $report["raw_redacted"] = Redact-Text $raw
    }

    if ($Json) {
        $report | ConvertTo-Json -Depth 8
    }
    else {
        "Codex Config Inspection"
        ""
        "Config path: $resolvedPath"
        "File status: Found"
        "Parsed: Basic parse succeeded"
        ""
        "Current settings:"
        "active_profile: $(if ($activeProfile) { $activeProfile } else { '(not set)' })"
        "model: $(if ($model) { $model } else { '(not set)' })"
        "model_provider: $(if ($modelProvider) { $modelProvider } else { '(not set)' })"
        ""
        "Profiles found:"
        if ($parsed.profiles.Keys.Count -gt 0) {
            foreach ($profileId in $parsed.profiles.Keys) { "- $profileId" }
        }
        else {
            "- (none)"
        }
        ""
        "Providers found:"
        if ($effectiveProviders.Keys.Count -gt 0) {
            foreach ($providerId in $effectiveProviders.Keys) { "- $providerId" }
        }
        else {
            "- (none)"
        }
        ""
        "Selected provider:"
        if ($null -ne $selectedProvider) {
            "id: $($selectedProvider.id)"
            "source: $($selectedProvider.source)"
            "name: $(if ($selectedProvider.name) { $selectedProvider.name } else { '(not set)' })"
            "base_url: $(if ($selectedProvider.base_url) { $selectedProvider.base_url } else { '(not set)' })"
            "env_key: $(if ($selectedProvider.env_key) { $selectedProvider.env_key } else { '(not set)' })"
            "env_value: $($selectedProvider.env_value_status)"
        }
        else {
            "(not resolved)"
        }
        ""
        "Safety:"
        "raw secret in config: $(if ($rawSecretDetected) { 'detected, value redacted' } else { 'not detected' })"
        if ($secretFields.Count -gt 0) {
            "raw secret fields: $($secretFields -join ', ')"
        }
        ""
        "Warnings:"
        if ($warnings.Count -gt 0) {
            foreach ($warning in $warnings) { "- $warning" }
        }
        else {
            "- None"
        }
        if ($IncludeRawRedacted) {
            ""
            "Raw config, redacted:"
            Redact-Text $raw
        }
    }
}
catch {
    Write-Error $_
    exit 1
}
