# Codex Config

Use this reference when troubleshooting Codex `config.toml`, model providers, profiles, `base_url`, API key handling, project config, or Windows path issues. Keep explanations in the user's language, but preserve Codex field names exactly.

## Purpose

Connect general AI CLI concepts to real Codex configuration. Use this file to answer questions like:

- Where is Codex `config.toml`?
- How do `model` and `model_provider` relate?
- Where should `base_url` be configured?
- How should API keys be handled safely?
- Why did changing `config.toml` not affect the current run?
- How should an OpenAI-compatible proxy be configured for Codex?

For basic concepts, use `references/ai-cli-concepts.md`. For raw error messages, use `references/common-errors.md`.

## Source Freshness Note

Codex configuration can change between versions. Prefer official Codex documentation and the user's installed Codex version when exact field behavior matters. If a field, profile behavior, or provider setting seems version-sensitive, say so and verify from the user's local config or current docs.

## Config File Locations

Common user-level config:

```text
~/.codex/config.toml
```

Common Windows path:

```text
%USERPROFILE%\.codex\config.toml
C:\Users\<username>\.codex\config.toml
```

Common project-level config:

```text
<project>\.codex\config.toml
```

Beginner explanation:

```text
On Windows, `~` usually means the user's home folder, such as `C:\Users\Alice`.
```

When troubleshooting, check which config file the user edited. A user may edit the global config while Codex is also reading project-level config or command-line overrides.

## Config Precedence

Codex may combine settings from multiple places. Exact precedence can vary by version and launch method, but the practical troubleshooting order is:

```text
CLI flags / explicit overrides
active profile settings
project .codex/config.toml
user ~/.codex/config.toml
built-in defaults
```

Use this as a diagnostic model, not as a permanent guarantee.

Common symptom:

```text
The user edits ~/.codex/config.toml, but Codex still uses a different model or provider.
```

Likely causes:

- The command used `--profile`.
- A project `.codex/config.toml` overrides some behavior.
- CLI flags or app settings override the file.
- The user edited a different Windows account's config.
- Codex needs to be restarted or the session reloaded.

## User Config vs Project Config

User config is usually the right place for personal provider settings:

- `model`
- `model_provider`
- `model_providers`
- provider `base_url`
- provider `env_key`
- personal defaults

Project config is usually better for project-specific behavior:

- approval preferences
- sandbox preferences
- project instructions or local behavior when supported
- settings that should apply only inside that repository

Be careful with provider and authentication settings in project config. They may not behave the way the user expects across Codex versions or launch surfaces. When provider configuration is confusing, inspect the user-level config first.

## Core Codex Fields

### `model`

`model` is the model name Codex should request.

Example:

```toml
model = "gpt-5"
```

Rules:

- The model name must be supported by the selected `model_provider`.
- If using a relay or proxy, use the relay's documented model name or alias.
- `model` is not an API key and not a URL.

### `model_provider`

`model_provider` selects which provider configuration Codex should use.

Example:

```toml
model_provider = "my-proxy"
```

The value should match a provider id under `model_providers`.

Example:

```toml
model_provider = "my-proxy"

[model_providers.my-proxy]
name = "My Proxy"
base_url = "https://api.example.com/v1"
env_key = "MY_PROXY_API_KEY"
```

Common mistake:

```toml
model_provider = "my-proxy"

[model_providers.other-proxy]
base_url = "https://api.example.com/v1"
```

In this case, `model_provider` points to `my-proxy`, but only `other-proxy` is defined.

### `model_providers.<id>`

`model_providers.<id>` defines a provider entry. The `<id>` is the name Codex uses internally to select this provider.

Example:

```toml
[model_providers.my-openai-compatible]
name = "My OpenAI Compatible Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
```

Key checks:

- Does `model_provider` point to this exact id?
- Does `base_url` point to an API endpoint?
- Does `env_key` name an environment variable that actually exists?
- Does `model` match a model supported by this provider?

### `model_providers.<id>.base_url`

`base_url` is the API service entry address for that provider.

Example:

```toml
base_url = "https://api.example.com/v1"
```

Check:

- It should usually be an API URL, not a dashboard page.
- It often starts with `https://`.
- For OpenAI-compatible APIs, it often ends in `/v1`, but verify with the provider's docs.
- Avoid duplicated `/v1/v1`.

### `model_providers.<id>.env_key`

`env_key` is the name of the environment variable that stores the API key. It is not usually the API key itself.

Example:

```toml
env_key = "MY_PROVIDER_API_KEY"
```

This means Codex should read the actual secret from an environment variable named `MY_PROVIDER_API_KEY`.

Beginner explanation:

```text
`env_key` 不是密钥本身，而是“去哪个环境变量里找密钥”的名字。
```

Common mistake:

```toml
env_key = "sk-actual-secret-key..."
```

This is unsafe and likely wrong. The value should normally be a variable name, not the secret.

### `model_providers.<id>.name`

`name` is a human-readable provider display name.

Example:

```toml
name = "My Proxy"
```

It helps identify the provider but usually does not determine the API behavior by itself.

### `model_reasoning_effort`

`model_reasoning_effort` controls reasoning effort for models that support it. It is usually unrelated to authentication, `base_url`, or provider connection errors.

If the user cannot connect to an API, do not focus on this field first.

### `approval_policy`

`approval_policy` affects whether Codex asks before running commands or taking actions. It is not an API credential field.

Use this when the user asks why Codex asks for confirmation or refuses certain actions.

### `sandbox_mode`

`sandbox_mode` affects filesystem/network command permissions. It does not normally decide which model/provider Codex uses.

Use this when the user asks why Codex cannot read/write files, access network, or run certain commands.

## OpenAI-Compatible Provider Pattern

Generic pattern:

```toml
model = "provider-model-name"
model_provider = "my-openai-compatible"

[model_providers.my-openai-compatible]
name = "My OpenAI Compatible Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
```

Explain it like this:

- `model` is the model name supported by the provider or relay.
- `model_provider` selects a provider entry.
- `[model_providers.my-openai-compatible]` defines that provider entry.
- `base_url` is the provider's API base URL.
- `env_key` is the environment variable name that stores the real API key.

Do not assume every OpenAI-compatible provider supports every OpenAI route. Some support `/v1/chat/completions` but not `/v1/responses`; others support only a subset of features.

## API Key Handling

Prefer storing API keys in environment variables instead of writing raw secrets into `config.toml`.

Safe behavior:

- Never print the full API key.
- If a key is detected, say it was detected and redacted.
- Explain that the key is hidden to protect the user's account, quota, and billing.
- Show only a safe form such as `sk-...abcd`, or say `[REDACTED]`.
- If the key was pasted into chat or stored in an unsafe file, recommend rotating it.

Recommended wording:

```text
I detected an API key value, but I am not printing it in full. This is intentional: API keys can spend your quota or expose your account if leaked. I will show it only as `sk-...abcd` or `[REDACTED]`.
```

Chinese wording:

```text
我检测到了 API key，但不会完整打印出来。这是为了保护你的账号、额度和账单安全。下面只会用 `sk-...abcd` 或 `[REDACTED]` 这种形式显示。
```

Important distinction:

```text
Key detected and redacted
```

does not mean:

```text
Key missing
```

When summarizing config, be explicit:

```text
api_key: detected via env_key MY_PROVIDER_API_KEY, value redacted
```

or:

```text
api_key: not found in the inspected config/environment
```

## Environment Variable Checks

If `env_key = "MY_PROVIDER_API_KEY"` is configured, verify whether that environment variable exists in the shell/session Codex uses.

Do not print the value. Report only presence:

```text
MY_PROVIDER_API_KEY: set, value redacted
```

or:

```text
MY_PROVIDER_API_KEY: not set
```

Common Windows issue:

- The user sets an environment variable in one terminal, but starts Codex from another session.
- The user sets a User variable but the app needs restart.
- The user sets a PowerShell session variable that disappears after closing the terminal.
- Variable name differs by one character from `env_key`.

## Profile Handling

Profiles allow different configuration sets. The exact syntax and behavior may vary by Codex version, so inspect the actual config before assuming.

Troubleshooting points:

- Did the user run Codex with `--profile`?
- Is the selected profile overriding `model` or `model_provider`?
- Did the user edit the default config but run a named profile?
- Is the same provider id defined differently in profile-specific config?

Safe phrasing:

```text
The config you edited looks reasonable, but Codex may be running under a different profile. We should confirm the active profile before changing the provider settings again.
```

## Common Codex Config Mistakes

- `model_provider` points to an id that is not defined under `model_providers`.
- A provider entry exists, but `model_provider` still points somewhere else.
- `base_url` is a dashboard URL instead of an API URL.
- `base_url` is missing required `/v1`.
- `base_url` has duplicated `/v1/v1`.
- `env_key` contains the actual secret instead of the environment variable name.
- `env_key` is correct, but the environment variable is not set in the Codex runtime session.
- `model` is not supported by the selected provider.
- The user configured a relay `base_url` but used an official provider key.
- The user configured an official provider `base_url` but used a relay key.
- The user edited project config but provider settings are coming from user config.
- The user edited one profile but launched another.
- TOML syntax is invalid: duplicate keys, wrong table indentation, smart quotes, missing quotes.
- The config file is saved with the wrong extension, such as `config.toml.txt`.

## Safe Inspection Workflow

1. Confirm the Codex surface.
   - Codex CLI, Codex app, IDE extension, or another wrapper.

2. Find config files.
   - User config: `~/.codex/config.toml`.
   - Windows user config: `%USERPROFILE%\.codex\config.toml`.
   - Project config: `.codex/config.toml` in the current repo if present.

3. Confirm active profile or overrides.
   - Ask whether the user used `--profile` or app-level model settings.

4. Read config safely.
   - Redact any full key, bearer token, or secret-like value.
   - Distinguish between "detected but redacted" and "not found".

5. Summarize important fields.
   - `model`
   - `model_provider`
   - provider id under `model_providers`
   - provider `name`
   - provider `base_url`
   - provider `env_key`
   - whether the environment variable is set, if checked

6. Compare fields.
   - Does `model_provider` match a defined provider id?
   - Does `base_url` match the provider that issued the key?
   - Does `model` belong to that provider?
   - Does the endpoint likely need `/v1`?

## Safe Edit Workflow

1. Explain the proposed change.
2. Back up the config file before editing.
3. Change only the necessary field.
4. Preserve unrelated settings and comments when possible.
5. Do not print secrets.
6. Verify with a minimal request.
7. If it fails, roll back or make the next smallest change.

Example backup naming:

```text
config.toml.bak-YYYYMMDD-HHMMSS
```

## Example Config Snippets

### OpenAI-Compatible Proxy

```toml
model = "provider-model-name"
model_provider = "my-proxy"

[model_providers.my-proxy]
name = "My Proxy"
base_url = "https://api.example.com/v1"
env_key = "MY_PROXY_API_KEY"
```

### Multiple Providers

```toml
model = "gpt-5"
model_provider = "openai"

[model_providers.my-proxy]
name = "My Proxy"
base_url = "https://api.example.com/v1"
env_key = "MY_PROXY_API_KEY"

[model_providers.local]
name = "Local Model Server"
base_url = "http://localhost:11434/v1"
env_key = "LOCAL_MODEL_API_KEY"
```

This defines multiple providers, but Codex uses the one selected by `model_provider`.

## Troubleshooting Questions

Ask only the minimum needed questions:

- Are you using Codex CLI, Codex app, an IDE extension, or a wrapper?
- Which config file did you edit?
- Are you running with `--profile` or any command-line overrides?
- What is the exact error message?
- What is your `model_provider`?
- Is there a matching `[model_providers.<id>]` entry?
- Is your `base_url` an API URL or a dashboard URL?
- Does your provider documentation say the endpoint is OpenAI-compatible?
- Did the provider give you the `model` name, or did you choose it yourself?
- Is the environment variable named by `env_key` set in the Codex runtime session?

Do not ask the user to paste a full `api_key`. Ask for redacted values or inspect locally with redaction.
