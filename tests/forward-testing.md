# Forward Testing Report

Date: 2026-05-31
Skill: `ai-cli-config-helper`
Mode: local simulation with bundled fixtures; no network requests; no live config edits.

## Scope

This pass checks whether the skill workflow can handle realistic troubleshooting prompts after MVP validation and smoke-test coverage.

## Scenario 1: 401 / secret safety

User-like prompt:

```text
Codex reports 401 Unauthorized. Please inspect my config but do not expose my key.
```

Fixture: `tests/fixtures/config-secret-in-env-key.toml`

Observed signals from `inspect_codex_config.ps1`:

- `parse_status`: `basic_parse_succeeded`
- `model_provider`: `relay`
- `base_url`: `https://relay.example.com/v1`
- `env_key`: redacted as `sk-...3456`
- `env_value_status`: `not_checked_env_key_looks_like_secret`
- `raw_secret_detected`: `true`
- warning: `env_key` appears to contain a raw secret

Expected skill behavior:

- Do not repeat the full key.
- Explain that `env_key` should normally be an environment variable name, not the secret value itself.
- Recommend moving the key to an environment variable and updating `env_key` to that variable name.
- Advise rotating the key if it was pasted into chat or committed to disk.
- Back up before editing and verify after the change.

Result: pass.

## Scenario 2: OpenAI-compatible base URL missing `/v1`

User-like prompt:

```text
My relay URL is https://relay.example.com and Codex cannot connect. Should base_url include /v1?
```

Fixture: `tests/fixtures/config-missing-v1.toml`

Observed signals:

- `model_provider`: `relay`
- `base_url`: `https://relay.example.com`
- warning: base URL has no path and some OpenAI-compatible providers require `/v1`

Expected skill behavior:

- Avoid claiming `/v1` is always required.
- Explain that many OpenAI-compatible providers expect a `/v1` API base.
- Recommend checking provider docs or trying the minimal config change to `https://relay.example.com/v1` after backup.
- Ask for consent before running `test_openai_endpoint.js`.

Result: pass.

## Scenario 3: `model_provider` mismatch

User-like prompt:

```text
Codex says provider/model not found. Please check my config.
```

Fixture: `tests/fixtures/config-provider-mismatch.toml`

Observed signals:

- `model_provider`: `missing-provider`
- configured provider IDs: `relay`
- `selected_provider`: `null`
- warning: `[model_providers.missing-provider]` was not found

Expected skill behavior:

- Identify `model_provider` as pointing to a missing provider table.
- Recommend changing `model_provider` to `relay` or adding `[model_providers.missing-provider]`, depending on user intent.
- Preserve unrelated config.
- Back up before editing and verify after the change.

Result: pass.

## Findings

- The MVP workflow is sufficient for these three common troubleshooting cases.
- The bundled `inspect_codex_config.ps1` emits the right safe signals for each scenario.
- No immediate `SKILL.md` changes are required for these scenarios.

## Follow-ups

- Add fixtures for profile-specific providers and environment variable checks.
- Run an independent subagent-style forward test if delegation is explicitly requested.
- Consider adding a short “forward testing” section to `README.md` if reports should be preserved for release QA.
