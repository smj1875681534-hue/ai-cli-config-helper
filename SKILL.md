---
name: ai-cli-config-helper
description: Help users configure, inspect, and troubleshoot AI coding CLI tools such as Codex, Claude Code, CC Switch, and OpenAI-compatible API proxies. Use when the user asks about API keys, base URLs, base_url, model names, provider settings, Codex config.toml, OpenAI-compatible endpoints, /v1 URL formatting, relay/proxy services, or errors such as 401, 403, 404, 429, timeout, model not found, unsupported endpoint, or authentication failure. For the MVP, focus on Codex config.toml, Windows paths, OpenAI-compatible APIs, safe config inspection, secret redaction, backups before edits, and clear verification steps.
---

# AI CLI Config Helper

Diagnose AI CLI configuration problems and guide users to a safe fix. Treat this skill as a configuration doctor: inspect first, redact secrets, identify the likely provider/API mismatch, recommend a minimal correction, and verify the result.

This project can be used in two modes. If Codex cannot start or cannot load skills, tell the user to run the bundled `scripts/` tools directly from PowerShell first, especially `scripts/inspect_codex_config.ps1`. If Codex can start but the user is troubleshooting provider, API, model, `base_url`, `env_key`, or profile issues, use `$ai-cli-config-helper` for guided diagnosis. If Codex works normally and the user is not changing providers, models, profiles, or endpoints, they do not need this skill.

## MVP Scope

Prioritize:

- Codex `config.toml` on Windows.
- OpenAI-compatible API endpoints and proxy/relay services.
- `base_url`, `/v1`, `api_key`, `model`, and provider/model routing issues.
- Read-only inspection, secret redaction, backup-before-edit workflows, and user-approved changes.

Defer unless the user explicitly asks:

- Full Claude Code, Anthropic, Gemini, or CC Switch automation.
- Multi-provider config migration.
- Editing shell profiles, system proxy settings, certificates, or global environment variables.
- Benchmarking model quality or recommending paid services.

## Safety Rules

- Never print full API keys, bearer tokens, session tokens, cookies, or proxy credentials.
- Redact secrets as `prefix...suffix` when useful, or `[REDACTED]` when uncertain.
- Inspect configuration before proposing edits.
- Back up any config file before modifying it.
- Ask for explicit permission before changing a config file, deleting files, rotating keys, or running network tests that call a paid API.
- Prefer explaining the exact proposed change instead of rewriting unrelated config.
- If a user pastes a secret, avoid repeating it and tell them to rotate it if exposure is meaningful.

## Language Policy

- Reply in the same language the user used for the request.
- Explain the diagnosis, cause, fix, and verification steps in that same language.
- Keep configuration field names, command names, file paths, model names, HTTP status codes, and API route names in their original technical form, such as `base_url`, `api_key`, `model`, `config.toml`, `/v1`, `401 Unauthorized`, and `model not found`.
- When a beginner-unfriendly technical term first appears, briefly explain it in the user's language while preserving the original technical term.
- If the user explicitly asks for English, bilingual output, or another language, follow that preference.

## Workflow

1. Identify the tool and symptom.
   - Determine whether the user is using Codex, Claude Code, CC Switch, another CLI, or a proxy dashboard.
   - Capture the exact error text, command, config path, and what changed recently.

2. Locate and inspect configuration.
   - For Codex on Windows, check likely paths such as `%USERPROFILE%\.codex\config.toml`.
   - If the user gives a path, read that file directly.
   - Summarize only non-secret fields: provider, model, base URL, auth key presence, and relevant profiles.
   - When the task is Codex-specific, read `references/codex-config.md` for config paths, field meanings, precedence, and safe key handling.

3. Classify the endpoint.
   - OpenAI-compatible URLs often expose `/v1/models`, `/v1/chat/completions`, or `/v1/responses`.
   - Anthropic-style services often use `/v1/messages`.
   - Gemini-style services usually use Google API paths and model names.
   - Proxy/relay services may imitate one of these formats while using custom model names.

4. Diagnose the likely failure.
   - Compare tool expectations with endpoint type, URL shape, model name, and auth placement.
   - Map the raw error to a user-friendly cause.
   - Prefer one or two likely causes over a long generic list.
   - When the user provides an error code or raw error message, read `references/common-errors.md` for the expanded diagnosis map.

5. Recommend a safe fix.
   - Give the smallest config change that could solve the problem.
   - Preserve existing unrelated settings.
   - Include backup and rollback steps when editing files.

6. Verify.
   - Suggest a low-cost verification command or a minimal model-list/chat test.
   - If network access is unavailable or not approved, explain how the user can verify locally.

## Common Diagnosis Map

Use these as starting hypotheses, not final proof:

- `401 Unauthorized`: missing, wrong, expired, or service-mismatched API key.
- `403 Forbidden`: account lacks permission, model not enabled, quota/billing restriction, or proxy blocked access.
- `404 Not Found`: wrong endpoint path, missing `/v1`, unsupported route, or model name not recognized by that provider.
- `404 model not found`: service uses custom model aliases, model is unavailable, or the selected provider is wrong.
- `429 Too Many Requests`: rate limit, quota exhaustion, overloaded relay, or unpaid/insufficient plan.
- `timeout`, `ENOTFOUND`, `ECONNREFUSED`: network, DNS, proxy, firewall, typo in host, or service outage.
- `unsupported endpoint` or schema errors: using an Anthropic/Gemini endpoint where the tool expects OpenAI-compatible JSON, or the reverse.

## URL Heuristics

When inspecting `base_url`, check:

- Does the CLI expect the root URL or a versioned URL?
- Does the provider documentation require `/v1`?
- Is `/v1` duplicated, such as `https://host/v1/v1`?
- Is the URL a dashboard page instead of an API endpoint?
- Is the scheme `https://` present?
- Does the host belong to the service that issued the key?

For Codex with an OpenAI-compatible provider, a common safe hypothesis is that `base_url` should point to the provider's OpenAI-compatible API base, often ending in `/v1`, but always verify against the provider's docs when possible.

## Output Contract

Use this structure for troubleshooting responses:

```text
Current Configuration:
Detected Provider Type:
Likely Problem:
Safe Fix:
Commands or UI Steps:
Verification:
```

If config was not inspected, say so clearly:

```text
Current Configuration:
Not inspected. Diagnosis is based only on the error text and user description.
```

## Example User Requests

```text
Use $ai-cli-config-helper to check why Codex cannot connect to my API.
```

```text
My Codex config reports 404 model not found. Does my base_url need /v1?
```

```text
Help me inspect C:\Users\me\.codex\config.toml, but do not expose my key.
```

```text
This proxy works in another app but not in Codex. Tell me whether it is OpenAI-compatible.
```

## References

Keep `SKILL.md` lean and load these files only when needed:

- `references/ai-cli-concepts.md` for plain-language explanations of API keys, base URLs, providers, and model names.
- `references/common-errors.md` for expanded error mappings, provider mismatch patterns, safe fixes, and verification steps.
- `references/codex-config.md` for Codex-specific config paths, field patterns, provider configuration, profiles, environment variables, and safe API key reporting.
- `references/windows-paths.md` for Windows path discovery and PowerShell examples.
- `references/verification-checklist.md` for local checks, network-test consent, endpoint verification, and final response QA.
- `scripts/redact_secret.ps1` for deterministic secret redaction.
- `scripts/inspect_codex_config.ps1` for read-only config summaries.
- `scripts/backup_codex_config.ps1` for timestamped backups.
- `scripts/restore_codex_config.ps1` for explicit rollback from a backup.
- `scripts/smoke_test.ps1` for local-only regression checks during skill development.
- `scripts/test_openai_endpoint.js` for optional OpenAI-compatible endpoint checks after explicit user approval.

## Scripts

Use bundled scripts to make fragile or safety-sensitive operations deterministic:

- `scripts/inspect_codex_config.ps1`: read-only Codex `config.toml` inspection. Use before proposing edits. Supports `-Path`, `-ProjectPath`, `-Profile`, `-CheckEnv`, `-IncludeRawRedacted`, and `-Json`.
- `scripts/redact_secret.ps1`: read-only secret redaction for pasted config, logs, or command output. Use when a user provides raw text that may contain API keys, tokens, passwords, or bearer credentials.
- `scripts/backup_codex_config.ps1`: timestamped backup before editing Codex config. Use before any config modification. Supports `-Path`, `-ProjectPath`, `-BackupDirectory`, `-ListBackups`, `-KeepLast`, `-Json`, and PowerShell `-WhatIf`.
- `scripts/restore_codex_config.ps1`: restore Codex config from a backup only after explicit confirmation. Without `-ConfirmRestore`, it previews the target and backup paths without writing.
- `scripts/smoke_test.ps1`: local-only development regression test for fixtures, inspection, redaction, backup, restore, and missing-key endpoint safety. Use after changing scripts or fixtures.
- `scripts/test_openai_endpoint.js`: optional network validation for OpenAI-compatible endpoints. Run only after explicit user approval. Supports `--base-url`, `--model`, `--env-key`, `--route`, `--no-chat`, `--timeout-ms`, and `--json`.

Do not run endpoint tests or paid API calls unless the user explicitly approves. `scripts/test_openai_endpoint.js` must report only status, endpoint compatibility, model availability, and redacted key presence.

## Network Test Consent

Before running `scripts/test_openai_endpoint.js`, explain the network request clearly and ask for explicit permission. Tell the user:

- It will send requests to the configured `base_url`.
- `/models` usually checks model listing and is typically low cost, but still contacts the provider.
- `/chat/completions` sends a minimal `ping` message and may consume a very small amount of API quota.
- `/responses` sends a minimal `ping` request and may consume a very small amount of API quota.
- The script reads the API key from `env_key` only and must not print the full key.
- If the user declines, continue with local-only inspection such as `scripts/inspect_codex_config.ps1`.

Use wording like:

```text
I can run an optional network test. It will contact your configured base_url to check whether /models and, if you allow it, a tiny chat ping works. The chat/responses test may consume a very small amount of API quota. Do you want me to run it?
```


