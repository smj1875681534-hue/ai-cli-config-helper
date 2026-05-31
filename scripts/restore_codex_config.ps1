[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,

    [string]$Path,

    [string]$ProjectPath,

    [string]$PreRestoreBackupDirectory,

    [switch]$ConfirmRestore,

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

function Get-PreRestoreBackupDirectory {
    param([string]$TargetPath)

    if (-not [string]::IsNullOrWhiteSpace($PreRestoreBackupDirectory)) {
        return $PreRestoreBackupDirectory
    }
    return (Split-Path -Parent $TargetPath)
}

function Get-PreRestoreBackupFileName {
    param([string]$TargetPath)

    $name = Split-Path -Leaf $TargetPath
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    return "$name.pre-restore-$timestamp"
}

function Get-AvailablePath {
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

    throw "Could not find an available pre-restore backup file name in $Directory."
}

try {
    $backupFound = Test-Path -LiteralPath $BackupPath -PathType Leaf
    $targetPath = Get-ConfigPath
    $targetExists = Test-Path -LiteralPath $targetPath -PathType Leaf
    $resolvedBackupPath = if ($backupFound) { (Resolve-Path -LiteralPath $BackupPath).Path } else { $BackupPath }
    $resolvedTargetPath = if ($targetExists) { (Resolve-Path -LiteralPath $targetPath).Path } else { $targetPath }
    $targetDirectory = Split-Path -Parent $resolvedTargetPath
    $preRestoreDirectory = Get-PreRestoreBackupDirectory $resolvedTargetPath
    $preRestoreBackupPath = $null
    $preRestoreBackupCreated = $false
    $targetDirectoryCreated = $false
    $preRestoreDirectoryCreated = $false
    $restored = $false

    if (-not $backupFound) {
        $report = [ordered]@{
            backup_path = $resolvedBackupPath
            target_path = $resolvedTargetPath
            backup_found = $false
            target_existed = $targetExists
            pre_restore_backup_path = $null
            pre_restore_backup_created = $false
            restored = $false
            confirm_restore = [bool]$ConfirmRestore
            message = "Backup file not found. Nothing was restored."
        }

        if ($Json) {
            $report | ConvertTo-Json -Depth 6
        }
        else {
            "Codex Config Restore"
            ""
            "Backup: $resolvedBackupPath"
            "Target: $resolvedTargetPath"
            "Status: Backup not found"
            "Message: $($report.message)"
        }
        exit 0
    }

    if (-not $ConfirmRestore) {
        $report = [ordered]@{
            backup_path = $resolvedBackupPath
            target_path = $resolvedTargetPath
            backup_found = $true
            target_existed = $targetExists
            pre_restore_backup_path = $null
            pre_restore_backup_created = $false
            restored = $false
            confirm_restore = $false
            message = "Restore not performed. Re-run with -ConfirmRestore to overwrite the target config."
        }

        if ($Json) {
            $report | ConvertTo-Json -Depth 6
        }
        else {
            "Codex Config Restore"
            ""
            "Backup: $resolvedBackupPath"
            "Target: $resolvedTargetPath"
            "Status: Not restored"
            "Message: $($report.message)"
        }
        exit 0
    }

    if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($targetDirectory, "Create target directory")) {
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
            $targetDirectoryCreated = $true
        }
    }

    if ($targetExists) {
        if (-not (Test-Path -LiteralPath $preRestoreDirectory -PathType Container)) {
            if ($PSCmdlet.ShouldProcess($preRestoreDirectory, "Create pre-restore backup directory")) {
                New-Item -ItemType Directory -Path $preRestoreDirectory -Force | Out-Null
                $preRestoreDirectoryCreated = $true
            }
        }

        $preRestoreBackupName = Get-PreRestoreBackupFileName $resolvedTargetPath
        $preRestoreBackupPath = Get-AvailablePath -Directory $preRestoreDirectory -FileName $preRestoreBackupName
        if ($PSCmdlet.ShouldProcess($resolvedTargetPath, "Back up current config to $preRestoreBackupPath before restore")) {
            Copy-Item -LiteralPath $resolvedTargetPath -Destination $preRestoreBackupPath -ErrorAction Stop
            $preRestoreBackupCreated = $true
        }
    }

    if ($PSCmdlet.ShouldProcess($resolvedTargetPath, "Restore from $resolvedBackupPath")) {
        Copy-Item -LiteralPath $resolvedBackupPath -Destination $resolvedTargetPath -Force -ErrorAction Stop
        $restored = $true
    }

    $report = [ordered]@{
        backup_path = $resolvedBackupPath
        target_path = $resolvedTargetPath
        backup_found = $true
        target_existed = $targetExists
        target_directory_created = $targetDirectoryCreated
        pre_restore_backup_path = $preRestoreBackupPath
        pre_restore_backup_created = $preRestoreBackupCreated
        pre_restore_backup_directory_created = $preRestoreDirectoryCreated
        restored = $restored
        confirm_restore = [bool]$ConfirmRestore
        message = if ($restored) { "Config restored from backup." } else { "Restore was not performed." }
    }

    if ($Json) {
        $report | ConvertTo-Json -Depth 6
    }
    else {
        "Codex Config Restore"
        ""
        "Backup: $resolvedBackupPath"
        "Target: $resolvedTargetPath"
        "Status: $(if ($restored) { 'Restored' } else { 'Not restored' })"
        if ($targetExists) {
            "Pre-restore backup: $preRestoreBackupPath"
        }
        if ($targetDirectoryCreated) {
            "Target directory created: $targetDirectory"
        }
        if ($preRestoreDirectoryCreated) {
            "Pre-restore backup directory created: $preRestoreDirectory"
        }
    }
}
catch {
    Write-Error $_
    exit 1
}
