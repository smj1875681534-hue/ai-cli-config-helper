[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = "Backup")]
param(
    [Parameter(ParameterSetName = "Backup")]
    [Parameter(ParameterSetName = "List")]
    [string]$Path,

    [Parameter(ParameterSetName = "Backup")]
    [Parameter(ParameterSetName = "List")]
    [string]$ProjectPath,

    [Parameter(ParameterSetName = "Backup")]
    [Parameter(ParameterSetName = "List")]
    [string]$BackupDirectory,

    [Parameter(ParameterSetName = "List")]
    [switch]$ListBackups,

    [Parameter(ParameterSetName = "Backup")]
    [ValidateRange(1, 999)]
    [int]$KeepLast,

    [Parameter(ParameterSetName = "Backup")]
    [Parameter(ParameterSetName = "List")]
    [switch]$Json
)

function Get-DefaultConfigPath {
    Join-Path $env:USERPROFILE ".codex\config.toml"
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

function Get-BackupDirectory {
    param([string]$SourcePath)

    if (-not [string]::IsNullOrWhiteSpace($BackupDirectory)) {
        return $BackupDirectory
    }
    return (Split-Path -Parent $SourcePath)
}

function Get-BackupFileName {
    param([string]$SourcePath)

    $name = Split-Path -Leaf $SourcePath
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    return "$name.bak-$timestamp"
}

function Get-AvailableBackupPath {
    param(
        [string]$Directory,
        [string]$FileName
    )

    $candidate = Join-Path $Directory $FileName
    if (-not (Test-Path -LiteralPath $candidate)) {
        return $candidate
    }

    for ($index = 1; $index -le 999; $index += 1) {
        $suffix = "-{0:D3}" -f $index
        $candidate = Join-Path $Directory "$FileName$suffix"
        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw "Could not find an available backup file name in $Directory."
}

function Get-BackupPattern {
    param([string]$SourcePath)

    $name = [regex]::Escape((Split-Path -Leaf $SourcePath))
    return "^$name\.bak-\d{8}-\d{6}(?:-\d{3})?$"
}

function Get-BackupFiles {
    param(
        [string]$SourcePath,
        [string]$Directory
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return @()
    }

    $pattern = Get-BackupPattern $SourcePath
    return @(Get-ChildItem -LiteralPath $Directory -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $pattern } |
        Sort-Object LastWriteTime -Descending)
}

try {
    $configPath = Get-ConfigPath
    $fileFound = Test-Path -LiteralPath $configPath -PathType Leaf
    $resolvedSourcePath = if ($fileFound) { (Resolve-Path -LiteralPath $configPath).Path } else { $configPath }
    $backupDir = Get-BackupDirectory $resolvedSourcePath
    $backupDirectoryCreated = $false

    if ($ListBackups) {
        $backups = Get-BackupFiles -SourcePath $resolvedSourcePath -Directory $backupDir
        $report = [ordered]@{
            source_path = $resolvedSourcePath
            backup_directory = $backupDir
            backup_count = $backups.Count
            backups = @($backups | ForEach-Object {
                [ordered]@{
                    path = $_.FullName
                    size_bytes = $_.Length
                    last_write_time = $_.LastWriteTime.ToString("o")
                }
            })
        }

        if ($Json) {
            $report | ConvertTo-Json -Depth 6
        }
        else {
            "Codex Config Backups"
            ""
            "Source: $resolvedSourcePath"
            "Backup directory: $backupDir"
            "Backup count: $($backups.Count)"
            if ($backups.Count -gt 0) {
                ""
                "Backups:"
                foreach ($backup in $backups) {
                    "- $($backup.FullName)"
                }
            }
        }
        exit 0
    }

    if (-not $fileFound) {
        $report = [ordered]@{
            source_path = $resolvedSourcePath
            backup_path = $null
            backup_directory = $backupDir
            file_found = $false
            created = $false
            backup_directory_created = $false
            removed_old_backups = @()
            message = "Config file not found. Nothing was backed up."
        }

        if ($Json) {
            $report | ConvertTo-Json -Depth 6
        }
        else {
            "Codex Config Backup"
            ""
            "Source: $resolvedSourcePath"
            "Status: Not found"
            "Message: $($report.message)"
        }
        exit 0
    }

    if (-not (Test-Path -LiteralPath $backupDir -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($backupDir, "Create backup directory")) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            $backupDirectoryCreated = $true
        }
    }

    $backupName = Get-BackupFileName $resolvedSourcePath
    $backupPath = Get-AvailableBackupPath -Directory $backupDir -FileName $backupName
    $created = $false
    if ($PSCmdlet.ShouldProcess($resolvedSourcePath, "Back up to $backupPath")) {
        Copy-Item -LiteralPath $resolvedSourcePath -Destination $backupPath -ErrorAction Stop
        $created = $true
    }

    $removedOldBackups = New-Object System.Collections.Generic.List[string]
    if ($created -and $KeepLast -gt 0) {
        $backups = Get-BackupFiles -SourcePath $resolvedSourcePath -Directory $backupDir
        $oldBackups = @($backups | Select-Object -Skip $KeepLast)
        foreach ($oldBackup in $oldBackups) {
            if ($PSCmdlet.ShouldProcess($oldBackup.FullName, "Remove old backup")) {
                Remove-Item -LiteralPath $oldBackup.FullName -Force -ErrorAction Stop
                $removedOldBackups.Add($oldBackup.FullName)
            }
        }
    }

    $report = [ordered]@{
        source_path = $resolvedSourcePath
        backup_path = $backupPath
        backup_directory = $backupDir
        file_found = $true
        created = $created
        backup_directory_created = $backupDirectoryCreated
        removed_old_backups = @($removedOldBackups)
        message = if ($created) { "Backup created." } else { "Backup was not created." }
    }

    if ($Json) {
        $report | ConvertTo-Json -Depth 6
    }
    else {
        "Codex Config Backup"
        ""
        "Source: $resolvedSourcePath"
        "Backup: $backupPath"
        "Status: $(if ($created) { 'Created' } else { 'Not created' })"
        if ($backupDirectoryCreated) {
            "Backup directory created: $backupDir"
        }
        if ($removedOldBackups.Count -gt 0) {
            "Removed old backups: $($removedOldBackups.Count)"
        }
    }
}
catch {
    Write-Error $_
    exit 1
}
