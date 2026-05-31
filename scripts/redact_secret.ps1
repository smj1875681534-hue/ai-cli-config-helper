[CmdletBinding(DefaultParameterSetName = "Text")]
param(
    [Parameter(ParameterSetName = "Text")]
    [string]$Text,

    [Parameter(ParameterSetName = "Path")]
    [string]$Path,

    [Parameter(ValueFromPipeline = $true, ParameterSetName = "Pipeline")]
    [string]$InputObject,

    [ValidateSet("Preserve", "Mask")]
    [string]$Mode = "Preserve",

    [switch]$Json
)

begin {
    $script:RedactionMode = $Mode
    <#
    Redacts API keys, bearer tokens, passwords, and other secret-like values from text.

    Examples:
      powershell -NoProfile -ExecutionPolicy Bypass -File .\redact_secret.ps1 -Text 'api_key = "sk-example1234567890"'
      powershell -NoProfile -ExecutionPolicy Bypass -File .\redact_secret.ps1 -Path "$env:USERPROFILE\.codex\config.toml" -Json

    The script is read-only when using -Path. It never modifies the input file.
    #>

    $pipelineParts = New-Object System.Collections.Generic.List[string]
    $script:RedactionCount = 0

    function Protect-SecretValue {
        param(
            [AllowEmptyString()]
            [string]$Value,

            [ValidateSet("Preserve", "Mask")]
            [string]$Mode = "Preserve"
        )

        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $Value
        }

        $trimmed = $Value.Trim()
        $quotePrefix = ""
        $quoteSuffix = ""

        if ($trimmed.Length -ge 2) {
            $first = $trimmed.Substring(0, 1)
            $last = $trimmed.Substring($trimmed.Length - 1, 1)
            if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
                $quotePrefix = $first
                $quoteSuffix = $last
                $trimmed = $trimmed.Substring(1, $trimmed.Length - 2)
            }
        }

        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            return "$quotePrefix[REDACTED]$quoteSuffix"
        }

        if ($Mode -eq "Mask" -or $trimmed.Length -lt 12) {
            return "$quotePrefix[REDACTED]$quoteSuffix"
        }

        if ($trimmed.StartsWith("sk-") -and $trimmed.Length -ge 8) {
            $tailLength = [Math]::Min(4, $trimmed.Length)
            $tail = $trimmed.Substring($trimmed.Length - $tailLength)
            return "$quotePrefix" + "sk-..." + $tail + "$quoteSuffix"
        }

        $prefixLength = [Math]::Min(4, $trimmed.Length)
        $suffixLength = [Math]::Min(4, $trimmed.Length - $prefixLength)
        $prefix = $trimmed.Substring(0, $prefixLength)
        $suffix = $trimmed.Substring($trimmed.Length - $suffixLength)
        return "$quotePrefix$prefix...$suffix$quoteSuffix"
    }

    function Invoke-RegexRedaction {
        param(
            [string]$InputText,
            [regex]$Pattern,
            [scriptblock]$Replacement
        )

        return $Pattern.Replace($InputText, {
            param($Match)
            $script:RedactionCount += 1
            return & $Replacement $Match
        })
    }

    function Redact-Secrets {
        param(
            [AllowEmptyString()]
            [string]$InputText,

            [ValidateSet("Preserve", "Mask")]
            [string]$Mode = "Preserve"
        )

        if ($null -eq $InputText) {
            return ""
        }

        $result = $InputText

        $authBearer = [regex]::new("(?im)(\bAuthorization\s*:\s*Bearer\s+)([^\s`"']+)")
        $result = Invoke-RegexRedaction $result $authBearer {
            param($m)
            return $m.Groups[1].Value + (Protect-SecretValue $m.Groups[2].Value $Mode)
        }

        $tomlJsonYamlFields = [regex]::new("(?im)(^|[\s,{])((?:api[_-]?key|token|access[_-]?token|refresh[_-]?token|bearer[_-]?token|experimental_bearer_token|secret|client[_-]?secret|password|passwd|pwd)\s*[:=]\s*)([`"']?)([^`"',\r\n#\s]+)([`"']?)")
        $result = Invoke-RegexRedaction $result $tomlJsonYamlFields {
            param($m)
            $secret = $m.Groups[4].Value
            return $m.Groups[1].Value + $m.Groups[2].Value + $m.Groups[3].Value + (Protect-SecretValue -Value $secret -Mode $script:RedactionMode) + $m.Groups[5].Value
        }

        $envAssignments = [regex]::new("(?im)(^|[\s;])([A-Z0-9_]*(?:API_KEY|ACCESS_TOKEN|REFRESH_TOKEN|BEARER_TOKEN|SECRET|PASSWORD|PASSWD|PWD)[A-Z0-9_]*\s*=\s*)([`"']?)([^`"',\r\n#\s]+)([`"']?)")
        $result = Invoke-RegexRedaction $result $envAssignments {
            param($m)
            $secret = $m.Groups[4].Value
            return $m.Groups[1].Value + $m.Groups[2].Value + $m.Groups[3].Value + (Protect-SecretValue -Value $secret -Mode $script:RedactionMode) + $m.Groups[5].Value
        }

        $openAiStyleKey = [regex]::new("(?<![A-Za-z0-9_\-])(sk-[A-Za-z0-9_\-]{12,})(?![A-Za-z0-9_\-])")
        $result = Invoke-RegexRedaction $result $openAiStyleKey {
            param($m)
            return Protect-SecretValue -Value $m.Groups[1].Value -Mode $script:RedactionMode
        }

        return $result
    }
}

process {
    if ($PSCmdlet.ParameterSetName -eq "Pipeline") {
        $pipelineParts.Add($InputObject)
    }
}

end {
    try {
        if ($PSCmdlet.ParameterSetName -eq "Path") {
            if ([string]::IsNullOrWhiteSpace($Path)) {
                throw "Missing -Path value."
            }
            if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
                throw "Input file not found: $Path"
            }
            $inputText = Get-Content -Raw -LiteralPath $Path
            $source = (Resolve-Path -LiteralPath $Path).Path
        }
        elseif ($PSCmdlet.ParameterSetName -eq "Pipeline") {
            if ($pipelineParts.Count -eq 0) {
                throw "No pipeline input received."
            }
            $inputText = ($pipelineParts -join [Environment]::NewLine)
            $source = "pipeline"
        }
        else {
            if ([string]::IsNullOrEmpty($Text)) {
                throw "Provide -Text, -Path, or pipeline input."
            }
            $inputText = $Text
            $source = "text"
        }

        $script:RedactionCount = 0
        $redacted = Redact-Secrets -InputText $inputText -Mode $Mode

        if ($Json) {
            [pscustomobject]@{
                source = $source
                mode = $Mode
                redaction_count = $script:RedactionCount
                redacted_text = $redacted
            } | ConvertTo-Json -Depth 4
        }
        else {
            $redacted
        }
    }
    catch {
        Write-Error $_
        exit 1
    }
}
