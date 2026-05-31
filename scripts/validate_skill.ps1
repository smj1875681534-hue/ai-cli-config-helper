[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$FailOnWarning,
    [switch]$SkipSmoke
)

$ErrorActionPreference = "Stop"

$SkillRoot = Split-Path -Parent $PSScriptRoot
$script:Checks = New-Object System.Collections.Generic.List[object]

function Add-CheckResult {
    param(
        [ValidateSet("pass", "warn", "fail")]
        [string]$Level,
        [string]$Id,
        [string]$Message
    )

    $script:Checks.Add([pscustomobject]@{
        level = $Level
        id = $Id
        message = $Message
    }) | Out-Null
}

function Get-SkillPath {
    param([string]$RelativePath)
    return (Join-Path $SkillRoot $RelativePath)
}

function Read-SkillText {
    param([string]$RelativePath)

    $path = Get-SkillPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return $null
    }

    return Get-Content -Raw -LiteralPath $path
}

function Test-RequiredPaths {
    $requiredDirectories = @(
        "agents",
        "references",
        "scripts",
        "tests",
        "tests\fixtures"
    )

    $requiredFiles = @(
        "SKILL.md",
        "README.md",
        "README.zh-CN.md",
        "LICENSE",
        ".gitignore",
        "examples\inspect-valid-output.json",
        "examples\inspect-dashboard-url-output.json",
        "examples\inspect-secret-redaction-output.json",
        "agents\openai.yaml",
        "references\ai-cli-concepts.md",
        "references\codex-config.md",
        "references\common-errors.md",
        "references\windows-paths.md",
        "references\verification-checklist.md",
        "scripts\inspect_codex_config.ps1",
        "scripts\redact_secret.ps1",
        "scripts\backup_codex_config.ps1",
        "scripts\restore_codex_config.ps1",
        "scripts\smoke_test.ps1",
        "scripts\test_openai_endpoint.js",
        "tests\forward-testing.md"
    )

    foreach ($directory in $requiredDirectories) {
        if (Test-Path -LiteralPath (Get-SkillPath $directory) -PathType Container) {
            Add-CheckResult "pass" "required_directory.$directory" "Required directory exists: $directory"
        }
        else {
            Add-CheckResult "fail" "required_directory.$directory" "Missing required directory: $directory"
        }
    }

    foreach ($file in $requiredFiles) {
        if (Test-Path -LiteralPath (Get-SkillPath $file) -PathType Leaf) {
            Add-CheckResult "pass" "required_file.$file" "Required file exists: $file"
        }
        else {
            Add-CheckResult "fail" "required_file.$file" "Missing required file: $file"
        }
    }
}

function Test-SkillFrontmatter {
    $content = Read-SkillText "SKILL.md"
    if ($null -eq $content) {
        Add-CheckResult "fail" "skill.frontmatter.read" "Cannot inspect SKILL.md because it is missing."
        return
    }

    if ($content -notmatch '(?s)^---\s*(.*?)\s*---') {
        Add-CheckResult "fail" "skill.frontmatter.present" "SKILL.md is missing YAML frontmatter."
        return
    }

    Add-CheckResult "pass" "skill.frontmatter.present" "SKILL.md has YAML frontmatter."
    $frontmatter = $Matches[1]

    $name = $null
    if ($frontmatter -match '(?m)^name:\s*([^\r\n]+)\s*$') {
        $name = $Matches[1].Trim().Trim('"', "'")
    }

    $description = $null
    if ($frontmatter -match '(?ms)^description:\s*(.+?)\s*(?:\r?\n[A-Za-z0-9_-]+:|\z)') {
        $description = $Matches[1].Trim().Trim('"', "'")
    }

    if ($name -eq "ai-cli-config-helper") {
        Add-CheckResult "pass" "skill.frontmatter.name" "SKILL.md name is ai-cli-config-helper."
    }
    else {
        Add-CheckResult "fail" "skill.frontmatter.name" "SKILL.md name should be ai-cli-config-helper."
    }

    if (-not [string]::IsNullOrWhiteSpace($description) -and $description.Length -ge 80) {
        Add-CheckResult "pass" "skill.frontmatter.description_length" "SKILL.md description is present and long enough."
    }
    else {
        Add-CheckResult "fail" "skill.frontmatter.description_length" "SKILL.md description is missing or too short."
    }

    $triggerTerms = @("Codex", "config.toml", "base URL", "base_url", "API key", "OpenAI-compatible")
    foreach ($term in $triggerTerms) {
        if ($description -and $description.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            Add-CheckResult "pass" "skill.description_term.$term" "Description contains trigger term: $term"
        }
        else {
            Add-CheckResult "warn" "skill.description_term.$term" "Description may be missing trigger term: $term"
        }
    }

    $requiredSections = @("Safety Rules", "Workflow", "Output Contract", "Scripts")
    foreach ($section in $requiredSections) {
        $pattern = "(?m)^##\s+$([regex]::Escape($section))\s*$"
        if ($content -match $pattern) {
            Add-CheckResult "pass" "skill.section.$section" "SKILL.md contains section: $section"
        }
        else {
            Add-CheckResult "warn" "skill.section.$section" "SKILL.md may be missing section: $section"
        }
    }
}

function Test-ReadmeQuality {
    $content = Read-SkillText "README.md"
    if ($null -eq $content) {
        Add-CheckResult "fail" "readme.present" "README.md is missing."
        return
    }

    if ($content.Trim().Length -gt 0) {
        Add-CheckResult "pass" "readme.non_empty" "README.md is not empty."
    }
    else {
        Add-CheckResult "fail" "readme.non_empty" "README.md is empty."
    }

    $mojibakePatterns = @(
        [char]0x951B,
        [char]0x5713,
        [char]0x9286,
        [char]0x20AC,
        [char]0xFFFD
    )
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $mojibakePatterns) {
        if ($content.Contains([string]$pattern)) {
            $found.Add(("U+{0:X4}" -f [int][char]$pattern)) | Out-Null
        }
    }

    if ($found.Count -gt 0) {
        Add-CheckResult "warn" "readme.mojibake" "README.md contains likely mojibake markers: $($found -join ', ')"
    }
    else {
        Add-CheckResult "pass" "readme.mojibake" "README.md has no common mojibake markers."
    }

    $expectations = @(
        @{ id = "structure"; pattern = "Directory|Structure|```text|ai-cli-config-helper/"; message = "README.md mentions structure or shows a tree." },
        @{ id = "scripts"; pattern = "scripts|PowerShell|node|smoke_test|inspect_codex_config"; message = "README.md mentions script usage." },
        @{ id = "safety"; pattern = "Safety|API key|secret|redact|redacted|env_key"; message = "README.md mentions safety or secret handling." }
    )

    foreach ($item in $expectations) {
        if ($content -match $item.pattern) {
            Add-CheckResult "pass" "readme.$($item.id)" $item.message
        }
        else {
            Add-CheckResult "warn" "readme.$($item.id)" "README.md may be missing expected content: $($item.id)"
        }
    }
}

function Test-KeywordCoverage {
    param(
        [string]$RelativePath,
        [string[]]$Keywords,
        [switch]$RequireHeading
    )

    $content = Read-SkillText $RelativePath
    if ($null -eq $content) {
        Add-CheckResult "fail" "coverage.$RelativePath.present" "Cannot inspect missing file: $RelativePath"
        return
    }

    if ($content.Trim().Length -gt 0) {
        Add-CheckResult "pass" "coverage.$RelativePath.non_empty" "$RelativePath is not empty."
    }
    else {
        Add-CheckResult "fail" "coverage.$RelativePath.non_empty" "$RelativePath is empty."
        return
    }

    if ($RequireHeading) {
        if ($content -match '(?m)^#\s+') {
            Add-CheckResult "pass" "coverage.$RelativePath.heading" "$RelativePath has a top-level heading."
        }
        else {
            Add-CheckResult "warn" "coverage.$RelativePath.heading" "$RelativePath may be missing a top-level heading."
        }
    }

    foreach ($keyword in $Keywords) {
        if ($content.IndexOf($keyword, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            Add-CheckResult "pass" "coverage.$RelativePath.keyword.$keyword" "$RelativePath contains keyword: $keyword"
        }
        else {
            Add-CheckResult "warn" "coverage.$RelativePath.keyword.$keyword" "$RelativePath may be missing keyword: $keyword"
        }
    }
}

function Test-ReferenceCoverage {
    Test-KeywordCoverage "references\ai-cli-concepts.md" @("base_url", "api_key", "model", "provider") -RequireHeading
    Test-KeywordCoverage "references\codex-config.md" @("config.toml", "model_provider", "model_providers", "env_key") -RequireHeading
    Test-KeywordCoverage "references\common-errors.md" @("401", "403", "404", "429", "timeout") -RequireHeading
    Test-KeywordCoverage "references\windows-paths.md" @("USERPROFILE", "PowerShell", "config.toml") -RequireHeading
    Test-KeywordCoverage "references\verification-checklist.md" @("backup", "network test", "verification", "rollback") -RequireHeading
}

function Test-ScriptContracts {
    $contracts = @(
        @{ path = "scripts\inspect_codex_config.ps1"; terms = @('$Path', '$ProjectPath', '$Profile', '$CheckEnv', '$Json', "raw_secret_detected") },
        @{ path = "scripts\redact_secret.ps1"; terms = @('$Text', '$Path', "redacted", "api", "token", "password") },
        @{ path = "scripts\backup_codex_config.ps1"; terms = @('$Path', '$BackupDirectory', '$Json', "bak") },
        @{ path = "scripts\restore_codex_config.ps1"; terms = @('$BackupPath', '$ConfirmRestore', "restored") },
        @{ path = "scripts\test_openai_endpoint.js"; terms = @("--base-url", "--env-key", "--route", "never printed") }
    )

    foreach ($contract in $contracts) {
        Test-KeywordCoverage $contract.path $contract.terms
    }
}

function Test-Fixtures {
    $requiredFixtures = @(
        "config-valid.toml",
        "config-missing-v1.toml",
        "config-duplicate-v1.toml",
        "config-provider-mismatch.toml",
        "config-secret-in-env-key.toml",
        "config-profile-provider-override.toml",
        "config-profile-missing.toml",
        "config-env-key-not-set.toml",
        "config-dashboard-url.toml",
        "config-invalid-smart-quotes.toml",
        "project-override\.codex\config.toml",
        "config-non-http-base-url.toml",
        "config-raw-top-level-secret.toml",
        "config-official-url-relay-key.toml",
        "config-relay-url-official-key.toml",
        "config-model-alias-mismatch.toml",
        "duplicate-file-extension\config.toml.txt"
    )

    $suggestedFixtures = @()

    foreach ($fixture in $requiredFixtures) {
        $relativePath = "tests\fixtures\$fixture"
        if (Test-Path -LiteralPath (Get-SkillPath $relativePath) -PathType Leaf) {
            Add-CheckResult "pass" "fixture.required.$fixture" "Required fixture exists: $fixture"
        }
        else {
            Add-CheckResult "fail" "fixture.required.$fixture" "Missing required fixture: $fixture"
        }
    }

    foreach ($fixture in $suggestedFixtures) {
        $relativePath = "tests\fixtures\$fixture"
        if (Test-Path -LiteralPath (Get-SkillPath $relativePath) -PathType Leaf) {
            Add-CheckResult "pass" "fixture.suggested.$fixture" "Suggested fixture exists: $fixture"
        }
        else {
            Add-CheckResult "warn" "fixture.suggested.$fixture" "Consider adding fixture: $fixture"
        }
    }
}

function Invoke-SmokeTest {
    if ($SkipSmoke) {
        Add-CheckResult "warn" "smoke.skipped" "Smoke test skipped by -SkipSmoke."
        return
    }

    $scriptPath = Get-SkillPath "scripts\smoke_test.ps1"
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Add-CheckResult "fail" "smoke.present" "Cannot run smoke test because scripts\smoke_test.ps1 is missing."
        return
    }

    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            Add-CheckResult "fail" "smoke.result" "smoke_test.ps1 failed with exit code $exitCode."
            return
        }

        $report = ($output | Out-String) | ConvertFrom-Json
        if ($report.status -eq "passed") {
            Add-CheckResult "pass" "smoke.result" "smoke_test.ps1 passed: $($report.assertions) assertions."
        }
        else {
            Add-CheckResult "fail" "smoke.result" "smoke_test.ps1 returned status: $($report.status)"
        }
    }
    catch {
        Add-CheckResult "fail" "smoke.result" "smoke_test.ps1 could not be completed: $($_.Exception.Message)"
    }
}

function Get-NextActions {
    $actions = New-Object System.Collections.Generic.List[string]
    $readmeMojibakeIssue = @($script:Checks | Where-Object {
        $_.id -eq "readme.mojibake" -and $_.level -ne "pass"
    }).Count -gt 0
    $suggestedFixtureIssue = @($script:Checks | Where-Object {
        $_.id -like "fixture.suggested.*" -and $_.level -eq "warn"
    }).Count -gt 0

    if ($readmeMojibakeIssue) {
        $actions.Add("Rewrite README.md as UTF-8 Chinese/English documentation.") | Out-Null
    }
    if ($suggestedFixtureIssue) {
        $actions.Add("Consider adding advanced fixtures for provider/key mismatch, relay model aliases, and config.toml.txt extension mistakes.") | Out-Null
    }
    if (($script:Checks | Where-Object { $_.id -eq "smoke.result" -and $_.level -eq "fail" }).Count -gt 0) {
        $actions.Add("Fix smoke_test.ps1 regressions before release.") | Out-Null
    }
    if (($script:Checks | Where-Object { $_.level -eq "fail" }).Count -gt 0) {
        $actions.Add("Fix failed validation checks before publishing this skill.") | Out-Null
    }
    if ($actions.Count -eq 0) {
        $actions.Add("No required release-blocking actions detected.") | Out-Null
    }

    return @($actions)
}

function Get-ValidationReport {
    $failures = @($script:Checks | Where-Object { $_.level -eq "fail" })
    $warnings = @($script:Checks | Where-Object { $_.level -eq "warn" })
    $passes = @($script:Checks | Where-Object { $_.level -eq "pass" })

    $status = "passed"
    if ($failures.Count -gt 0) {
        $status = "failed"
    }
    elseif ($warnings.Count -gt 0) {
        $status = "passed_with_warnings"
    }

    return [pscustomobject]@{
        status = $status
        passed = $passes.Count
        warnings = $warnings.Count
        failures = $failures.Count
        checks = @($script:Checks.ToArray())
        next_actions = @(Get-NextActions)
    }
}

function Write-TextReport {
    param([object]$Report)

    "AI CLI Config Helper Validation"
    ""
    "Status: $($Report.status)"
    ""
    "Checks:"
    foreach ($check in $Report.checks) {
        "[$($check.level)] $($check.message)"
    }
    ""
    "Summary:"
    "Failures: $($Report.failures)"
    "Warnings: $($Report.warnings)"
    "Passed: $($Report.passed)"
    ""
    "Next Actions:"
    foreach ($action in $Report.next_actions) {
        "- $action"
    }
}

Test-RequiredPaths
Test-SkillFrontmatter
Test-ReadmeQuality
Test-ReferenceCoverage
Test-ScriptContracts
Test-Fixtures
Invoke-SmokeTest

$report = Get-ValidationReport

if ($Json) {
    $report | ConvertTo-Json -Depth 8
}
else {
    Write-TextReport $report
}

if ($report.failures -gt 0 -or ($FailOnWarning -and $report.warnings -gt 0)) {
    exit 1
}
