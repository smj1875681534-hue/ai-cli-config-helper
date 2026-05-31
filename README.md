# AI CLI Config Helper

`ai-cli-config-helper` is a Codex skill and standalone local diagnostics toolkit for inspecting and troubleshooting AI coding CLI configuration problems. It focuses on Codex `config.toml`, Windows paths, OpenAI-compatible API providers, proxy or relay services, API key safety, `base_url`, `model`, `model_provider`, and common connection errors.

The skill works like a small configuration doctor:

1. Inspect the current configuration.
2. Redact secrets before reporting anything.
3. Identify likely provider, URL, model, or key mismatches.
4. Recommend the smallest safe fix.
5. Back up before edits.
6. Verify locally first, then run optional endpoint tests only with user approval.

## When To Use The Skill Vs Scripts

This project has two usage modes:

- Use it as a Codex skill when Codex can already start and load skills.
- Use the `scripts/` tools directly from PowerShell when Codex is not configured enough to start or load skills yet.

In other words, the skill is convenient after Codex can run, but the local scripts are the bootstrap path for beginners who are still fixing their first `config.toml`.

Beginner flow:

```text
1. Download or clone this repository.
2. Open PowerShell in the ai-cli-config-helper folder.
3. Run scripts/inspect_codex_config.ps1 against your config.toml.
4. Fix the reported config issues.
5. Start Codex.
6. Use $ai-cli-config-helper for guided troubleshooting inside Codex.
```

Minimal local inspection command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\inspect_codex_config.ps1 -Path "$env:USERPROFILE\.codex\config.toml" -CheckEnv
```

## Quick Start

Run the release-readiness validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_skill.ps1
```

Run the local regression tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke_test.ps1
```

Current validation status:

```text
validate_skill.ps1: passed, 116 checks
smoke_test.ps1: passed, 58 assertions
```

## Use Cases

Use this skill when a user asks about:

- Codex not connecting to an API provider.
- `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, `404 model not found`, `429 Too Many Requests`, timeout, DNS, or TLS errors.
- Whether an OpenAI-compatible `base_url` should include `/v1`.
- Whether a proxy or relay endpoint is compatible with Codex.
- Why `model_provider` does not match a `[model_providers.<id>]` table.
- Whether `env_key` is set correctly.
- How to inspect `config.toml` without exposing an API key.
- How to back up or restore Codex configuration safely.

This skill intentionally does not prioritize full automation for Claude Code, Gemini, Anthropic, CC Switch, shell profile editing, certificate changes, system proxy changes, or paid endpoint benchmarking.

## Directory Structure

```text
ai-cli-config-helper/
  SKILL.md
  README.md
  agents/
    openai.yaml
  references/
    ai-cli-concepts.md
    codex-config.md
    common-errors.md
    windows-paths.md
    verification-checklist.md
  scripts/
    inspect_codex_config.ps1
    redact_secret.ps1
    backup_codex_config.ps1
    restore_codex_config.ps1
    smoke_test.ps1
    test_openai_endpoint.js
    validate_skill.ps1
  examples/
    inspect-valid-output.json
    inspect-dashboard-url-output.json
    inspect-secret-redaction-output.json
  tests/
    forward-testing.md
    fixtures/
      config-valid.toml
      config-missing-v1.toml
      config-duplicate-v1.toml
      config-provider-mismatch.toml
      config-profile-provider-override.toml
      config-secret-in-env-key.toml
      config-profile-missing.toml
      config-env-key-not-set.toml
      config-dashboard-url.toml
      config-invalid-smart-quotes.toml
      config-non-http-base-url.toml
      config-raw-top-level-secret.toml
      config-official-url-relay-key.toml
      config-relay-url-official-key.toml
      config-model-alias-mismatch.toml
      duplicate-file-extension/
        config.toml.txt
      project-override/
        .codex/
          config.toml
```

## File Guide

- `SKILL.md`: Codex skill entry point. Defines the trigger description, scope, safety rules, workflow, output contract, references, scripts, and network-test consent rules.
- `README.md`: Human-facing project overview and usage guide.
- `agents/openai.yaml`: UI metadata for Codex, including display name, short description, and default prompt.
- `references/ai-cli-concepts.md`: Plain-language explanations for `api_key`, `base_url`, `model`, `provider`, OpenAI-compatible endpoints, and `/v1`.
- `references/codex-config.md`: Codex-specific notes for `config.toml`, `model_provider`, `model_providers`, profiles, `env_key`, and config precedence.
- `references/common-errors.md`: Error diagnosis map for HTTP status codes, network errors, TLS errors, route compatibility problems, quota issues, and model availability errors.
- `references/windows-paths.md`: Windows path and PowerShell guidance for `%USERPROFILE%`, `$env:USERPROFILE`, hidden folders, file extensions, and environment variables.
- `references/verification-checklist.md`: Final QA checklist for local checks, redaction, backup, endpoint test consent, verification, rollback, and final responses.
- `scripts/inspect_codex_config.ps1`: Read-only Codex config inspector. Reports model, selected provider, `base_url`, `env_key`, profile information, warnings, and secret-safety signals.
- `scripts/redact_secret.ps1`: Redacts API keys, bearer tokens, passwords, and other secret-like values from text or files.
- `scripts/backup_codex_config.ps1`: Creates timestamped backups of Codex `config.toml` before edits.
- `scripts/restore_codex_config.ps1`: Restores a config file from backup. It previews by default and writes only with `-ConfirmRestore`.
- `scripts/smoke_test.ps1`: Local regression test covering fixtures, inspection, redaction, backup, restore, and endpoint no-key safety behavior.
- `scripts/test_openai_endpoint.js`: Optional network validator for OpenAI-compatible endpoints. It must only be used after explicit user approval.
- `scripts/validate_skill.ps1`: Release-readiness check for required files, frontmatter, README quality, reference coverage, script contracts, fixtures, and smoke tests.
- `examples/*.json`: Sample diagnostic outputs generated from fixture configs. These let readers see what the tool reports without running it first.
- `tests/fixtures/*.toml`: Example Codex configs used by the smoke tests and release checks.
- `tests/forward-testing.md`: Scenario-based test notes for realistic user troubleshooting prompts.

## Examples

Sample diagnostic outputs are available in `examples/`:

- `examples/inspect-valid-output.json`: clean config with no warnings.
- `examples/inspect-dashboard-url-output.json`: `base_url` points to a dashboard-like URL.
- `examples/inspect-secret-redaction-output.json`: raw secret-like value is detected and redacted.

## Safety Principles

- Never print full API keys, bearer tokens, passwords, cookies, session tokens, or proxy credentials.
- Treat API keys as secrets that may spend quota or expose an account.
- Prefer `env_key` pointing to an environment variable instead of storing raw keys in `config.toml`.
- Some fixtures intentionally contain fake `sk-test...` values to test secret redaction. They are not real API keys.
- Inspect before editing.
- Back up before modifying `config.toml`.
- Change only the smallest necessary field.
- Do not run network tests or paid API calls without explicit user approval.
- If a user pasted a real key into chat or committed it to disk, recommend rotating it.

## Typical Troubleshooting Flow

1. Identify the tool and symptom.
   Capture the CLI surface, command, raw error, config path, active profile, and recent changes.

2. Inspect local config.
   Use `inspect_codex_config.ps1` to summarize `model`, `model_provider`, provider IDs, selected provider, `base_url`, `env_key`, warnings, and secret-safety signals.

3. Classify the likely endpoint type.
   Check whether the provider looks OpenAI-compatible, Anthropic-compatible, Gemini-compatible, relay-specific, or a dashboard URL.

4. Compare configuration fields.
   Confirm that `model`, `model_provider`, `[model_providers.<id>]`, `base_url`, and `env_key` all point to the same intended provider or relay.

5. Recommend a minimal fix.
   Examples: add `/v1`, remove duplicated `/v1/v1`, change `model_provider` to a defined provider ID, move a raw key out of `env_key`, or use the provider's exact model alias.

6. Verify.
   Start with local checks. If useful, ask before running endpoint tests.

7. Provide rollback.
   If an edit was made, tell the user which backup can restore the previous state.

## Script Usage

Run commands from the `ai-cli-config-helper` directory unless you pass explicit paths.

### Inspect Codex Config

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\inspect_codex_config.ps1
```

Inspect a specific file and check environment variable visibility:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\inspect_codex_config.ps1 -Path "C:\Users\me\.codex\config.toml" -CheckEnv
```

Emit JSON:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\inspect_codex_config.ps1 -Path "C:\Users\me\.codex\config.toml" -CheckEnv -Json
```

Inspect a profile:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\inspect_codex_config.ps1 -Profile proxy -CheckEnv
```

### Redact Secrets

Redact text:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\redact_secret.ps1 -Text 'api_key = "sk-example1234567890"'
```

Redact a file and emit JSON:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\redact_secret.ps1 -Path "C:\Users\me\.codex\config.toml" -Json
```

### Back Up Config

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\backup_codex_config.ps1 -Path "C:\Users\me\.codex\config.toml"
```

List backups:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\backup_codex_config.ps1 -Path "C:\Users\me\.codex\config.toml" -ListBackups
```

### Restore Config

Preview a restore without writing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\restore_codex_config.ps1 -BackupPath "C:\Users\me\.codex\config.toml.bak-20260531-010000"
```

Confirm restore:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\restore_codex_config.ps1 -BackupPath "C:\Users\me\.codex\config.toml.bak-20260531-010000" -Path "C:\Users\me\.codex\config.toml" -ConfirmRestore
```

### Run Smoke Tests

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke_test.ps1
```

Keep temporary files for debugging:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke_test.ps1 -KeepTemp
```

### Validate Skill Readiness

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_skill.ps1
```

JSON output:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_skill.ps1 -Json
```

Fail on warnings:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_skill.ps1 -FailOnWarning
```

Skip smoke tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_skill.ps1 -SkipSmoke
```

### Test an OpenAI-Compatible Endpoint

Use `test_openai_endpoint.js` only after the user explicitly approves a network test.

The script:

- Contacts the configured `base_url`.
- Reads the API key only from the environment variable named by `--env-key`.
- Does not print the full key.
- Can test `/models`, `/chat/completions`, or `/responses`.
- May consume a very small amount of quota for chat or responses tests.

Models route only:

```powershell
node .\scripts\test_openai_endpoint.js --base-url "https://api.example.com/v1" --model "provider-model" --env-key "MY_PROVIDER_API_KEY" --route models
```

Auto route:

```powershell
node .\scripts\test_openai_endpoint.js --base-url "https://api.example.com/v1" --model "provider-model" --env-key "MY_PROVIDER_API_KEY" --route auto
```

JSON output:

```powershell
node .\scripts\test_openai_endpoint.js --base-url "https://api.example.com/v1" --model "provider-model" --env-key "MY_PROVIDER_API_KEY" --route models --json
```

## Example Codex Config

```toml
model = "provider-model-name"
model_provider = "my-proxy"

[model_providers.my-proxy]
name = "My Proxy"
base_url = "https://api.example.com/v1"
env_key = "MY_PROXY_API_KEY"
```

Field meaning:

- `model`: model name or relay alias supported by the selected provider.
- `model_provider`: provider ID Codex should use.
- `[model_providers.my-proxy]`: provider table selected by `model_provider`.
- `base_url`: API entry point, often ending in `/v1` for OpenAI-compatible services.
- `env_key`: environment variable name that stores the real API key.

## Common Problems

### `env_key` contains a raw key

Problem:

```toml
env_key = "sk-real-secret..."
```

Safer pattern:

```toml
env_key = "MY_PROXY_API_KEY"
```

Then store the real key in the environment variable. If the key was exposed in chat, logs, or a repository, rotate it.

### `model_provider` does not match a provider table

Problem:

```toml
model_provider = "relay"

[model_providers.other-relay]
base_url = "https://relay.example.com/v1"
```

Fix either the selected provider ID or the table name so they match.

### `base_url` is missing `/v1`

Some OpenAI-compatible providers expect:

```toml
base_url = "https://relay.example.com/v1"
```

But this is provider-specific. Check the provider docs or run an approved endpoint test.

### `base_url` has duplicated `/v1/v1`

Problem:

```toml
base_url = "https://relay.example.com/v1/v1"
```

This usually causes `404 Not Found`. Use the provider's API base URL once.

### Dashboard URL used as API URL

Dashboard, console, login, or docs URLs are for humans. Codex needs an API endpoint.

## Development Status

Current MVP coverage:

- Codex config inspection.
- Secret redaction.
- Backup and restore workflows.
- OpenAI-compatible endpoint testing after consent.
- Smoke tests with fixture configs.
- Release-readiness validation.

Recommended next improvements:

- Add more forward-testing scenarios based on real user troubleshooting prompts.
- Keep provider/key mismatch heuristics conservative because relay behavior varies by service.

## License

Add a `LICENSE` file before public distribution if this skill will be published as an open-source project.
