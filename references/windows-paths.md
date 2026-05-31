# Windows Paths

Use this reference when troubleshooting Codex or AI CLI config paths, environment variables, PowerShell commands, hidden folders, file extensions, or Windows-specific path issues. Keep explanations in the user's language, but preserve paths, commands, and environment variable names exactly.

## Purpose

Handle Windows-specific problems that commonly break AI CLI configuration:

- Finding `~\.codex\config.toml`.
- Understanding `%USERPROFILE%`, `$env:USERPROFILE`, and `~`.
- Checking whether `.codex` exists.
- Avoiding `config.toml.txt`.
- Quoting paths with spaces, Chinese characters, or special characters.
- Checking whether an `env_key` environment variable is set.
- Explaining why newly set environment variables may not be visible until the terminal, app, or IDE restarts.

Use `references/codex-config.md` for Codex config fields. Use `references/common-errors.md` for raw API or network errors.

## Language Rule

- Reply in the same language the user used.
- Keep commands, file paths, environment variable names, and config keys unchanged.
- Explain beginner-unfriendly terms in the user's language the first time they appear.
- Never print full API keys or bearer tokens.

## Windows Home Directory

Windows has several ways to refer to the current user's home folder:

```text
~                          PowerShell shortcut for the user's home folder
%USERPROFILE%              CMD-style environment variable
$env:USERPROFILE           PowerShell environment variable
C:\Users\<username>         Typical expanded path
```

These often point to the same place.

Examples:

```text
~\.codex\config.toml
%USERPROFILE%\.codex\config.toml
$env:USERPROFILE\.codex\config.toml
C:\Users\Alice\.codex\config.toml
```

Beginner explanation:

```text
`~` 可以理解为“当前 Windows 用户的主目录”。例如用户叫 Alice 时，通常就是 `C:\Users\Alice`。
```

## Codex Config Paths On Windows

Common user-level Codex config:

```text
C:\Users\<username>\.codex\config.toml
%USERPROFILE%\.codex\config.toml
$env:USERPROFILE\.codex\config.toml
```

Common project-level Codex config:

```text
<project>\.codex\config.toml
```

If `config.toml` does not exist, it does not always mean Codex is broken. It may mean:

- Codex has not created a config file yet.
- The user is relying on built-in defaults.
- The config is in a different Windows user profile.
- The user is running a wrapper or app with a different config path.
- A project-level `.codex\config.toml` is being used for project-specific settings.

## Hidden Folders

The `.codex` folder may be hard to notice in File Explorer.

Key points:

- A folder name starting with `.` is common for tool configuration folders.
- File Explorer may hide some files or extensions depending on settings.
- The user can paste this directly into the File Explorer address bar:

```text
%USERPROFILE%\.codex
```

Safe PowerShell check:

```powershell
Test-Path -LiteralPath "$env:USERPROFILE\.codex"
```

List the folder:

```powershell
Get-ChildItem -Force -LiteralPath "$env:USERPROFILE\.codex"
```

## File Extension Pitfalls

Windows may hide file extensions. A file that appears as `config.toml` in File Explorer may actually be:

```text
config.toml.txt
config.toml.md
config.toml.bak
```

Codex expects:

```text
config.toml
```

Safe check:

```powershell
Get-ChildItem -Force -LiteralPath "$env:USERPROFILE\.codex"
```

Look at the exact `Name` column. If the file is `config.toml.txt`, Codex will not read it as `config.toml`.

Beginner explanation:

```text
Windows 有时会隐藏扩展名，所以你看到的 `config.toml` 可能真实文件名是 `config.toml.txt`。这会导致 Codex 找不到配置。
```

## Path Quoting Rules

Use quotes around paths. This matters when paths contain spaces, Chinese characters, parentheses, brackets, or other special characters.

Prefer `-LiteralPath` in PowerShell because it treats the path exactly as written.

Good:

```powershell
Get-Content -Raw -LiteralPath "$env:USERPROFILE\.codex\config.toml"
```

Good for paths with spaces:

```powershell
Get-ChildItem -Force -LiteralPath "D:\My Projects\demo\.codex"
```

Avoid unquoted paths:

```powershell
Get-Content C:\Users\Alice Smith\.codex\config.toml
```

The unquoted example may fail because the space in `Alice Smith` splits the path.

## PowerShell Environment Variables

Codex configs often use `env_key` to point to an environment variable that stores the real API key.

Example:

```toml
env_key = "MY_PROVIDER_API_KEY"
```

This means Codex should read the actual secret from an environment variable named `MY_PROVIDER_API_KEY`.

### Reading Variables

Read a variable in the current PowerShell session:

```powershell
$env:MY_PROVIDER_API_KEY
```

Read a user-level variable:

```powershell
[Environment]::GetEnvironmentVariable("MY_PROVIDER_API_KEY", "User")
```

Read a machine-level variable:

```powershell
[Environment]::GetEnvironmentVariable("MY_PROVIDER_API_KEY", "Machine")
```

Safety rule:

Do not print the raw value in final responses. Report only whether it exists:

```text
MY_PROVIDER_API_KEY: set, value redacted
```

or:

```text
MY_PROVIDER_API_KEY: not set
```

### Setting Variables For Current Session

Set a variable only for the current PowerShell window:

```powershell
$env:MY_PROVIDER_API_KEY = "sk-..."
```

This disappears when the PowerShell window closes. It may not be visible to Codex if Codex was launched from a different app, terminal, or already-running session.

### Setting User Variables Permanently

Set a user-level variable:

```powershell
[Environment]::SetEnvironmentVariable("MY_PROVIDER_API_KEY", "sk-...", "User")
```

This stores the variable for the current Windows user. Already-open terminals, Codex apps, or IDEs may not see it until restarted.

### When To Restart

After setting a permanent environment variable, ask the user to restart the relevant process:

- Close and reopen PowerShell.
- Restart Codex CLI if it was already running.
- Restart Codex app or IDE extension if launched from a desktop app.
- In some cases, sign out/in or restart Windows if the environment remains stale.

Beginner explanation:

```text
环境变量像程序启动时读到的一张配置表。程序已经打开后，你再修改这张表，它通常不会自动刷新，所以需要重启终端或应用。
```

## Checking Whether `env_key` Is Set

If config contains:

```toml
env_key = "MY_PROVIDER_API_KEY"
```

Check whether the variable exists without printing its value.

PowerShell:

```powershell
[string]::IsNullOrEmpty($env:MY_PROVIDER_API_KEY)
```

This returns:

```text
True
```

if the current session cannot see the variable, and:

```text
False
```

if it can see some value.

Safer summary wording:

```text
MY_PROVIDER_API_KEY: set, value redacted
```

or:

```text
MY_PROVIDER_API_KEY: not visible in the current PowerShell session
```

Important distinction:

```text
set, value redacted
```

does not mean the key is missing. It means the key exists but is intentionally hidden for safety.

## Current Session vs User Variable

A variable can exist in one place but not another.

Current session:

```powershell
$env:MY_PROVIDER_API_KEY
```

User-level:

```powershell
[Environment]::GetEnvironmentVariable("MY_PROVIDER_API_KEY", "User")
```

Machine-level:

```powershell
[Environment]::GetEnvironmentVariable("MY_PROVIDER_API_KEY", "Machine")
```

Common confusing case:

```text
The User variable is set, but the current PowerShell session does not see it because the terminal was opened before the variable was created.
```

Safe fix:

```text
Restart the terminal, Codex app, or IDE and check again.
```

## Common Windows Path Mistakes

- Editing `C:\Users\OtherUser\.codex\config.toml` while running Codex under a different Windows user.
- Saving the file as `config.toml.txt`.
- Creating `.codex` under the project when the user meant the global user config.
- Editing global config while project config or profile overrides are active.
- Forgetting quotes around paths containing spaces or Chinese characters.
- Using CMD syntax in PowerShell without understanding expansion differences.
- Setting `$env:MY_KEY` in one PowerShell window, then starting Codex from another app that cannot see it.
- Setting a User environment variable but not restarting Codex or the terminal.
- Typing `env_key = "MY_PROVIDER_APIKEY"` while the actual variable is `MY_PROVIDER_API_KEY`.
- Having both User and Machine variables with the same name and not knowing which one the process sees.
- Copying curly quotes like `“value”` into TOML instead of normal quotes `"value"`.
- Saving TOML in a strange encoding or with invisible characters.

## Safe PowerShell Commands

These commands are read-only or low-risk.

Check whether user config exists:

```powershell
Test-Path -LiteralPath "$env:USERPROFILE\.codex\config.toml"
```

List the `.codex` folder:

```powershell
Get-ChildItem -Force -LiteralPath "$env:USERPROFILE\.codex"
```

Read config file:

```powershell
Get-Content -Raw -LiteralPath "$env:USERPROFILE\.codex\config.toml"
```

Check whether an environment variable is visible in the current session:

```powershell
[string]::IsNullOrEmpty($env:MY_PROVIDER_API_KEY)
```

Read user-level variable presence:

```powershell
[Environment]::GetEnvironmentVariable("MY_PROVIDER_API_KEY", "User")
```

Do not paste the raw API key value into final responses. If command output includes a secret, redact it before summarizing.

## Safer Variable Presence Check

When writing scripts, prefer a presence check that does not print the secret:

```powershell
if ([string]::IsNullOrEmpty($env:MY_PROVIDER_API_KEY)) {
  "MY_PROVIDER_API_KEY: not set"
} else {
  "MY_PROVIDER_API_KEY: set, value redacted"
}
```

For user-level variables:

```powershell
$value = [Environment]::GetEnvironmentVariable("MY_PROVIDER_API_KEY", "User")
if ([string]::IsNullOrEmpty($value)) {
  "MY_PROVIDER_API_KEY: not set at User scope"
} else {
  "MY_PROVIDER_API_KEY: set at User scope, value redacted"
}
```

## Troubleshooting Questions

Ask only the minimum needed questions:

- Are you using PowerShell, CMD, Git Bash, Codex app, or an IDE extension?
- What Windows user is Codex running under?
- Which config path did you edit?
- Does `config.toml` really have that exact name, or is it `config.toml.txt`?
- Did you restart the terminal, Codex app, or IDE after setting environment variables?
- Does `env_key` exactly match the environment variable name?
- Is the environment variable set in the same session where Codex runs?
- Is the path affected by spaces, Chinese characters, OneDrive, or a different user folder?

Do not ask the user to paste full secrets. Ask for redacted values or inspect locally with redaction.
