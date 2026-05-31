# Verification Checklist（验证检查清单）

Use this checklist when verifying Codex `config.toml`（Codex 配置文件）, OpenAI-compatible endpoint（OpenAI 兼容接口端点）, API key（接口密钥）, `base_url`（API 基础地址）, `model`（模型名）, `model_provider`（模型提供方）, or proxy/relay（代理/中转）configuration issues.

This file is not a full error dictionary and not a config reference. Use it as the final QA（质量检查）and verification flow before recommending or applying a fix.

## Purpose（用途）

Use this checklist to decide:

- whether local-only checks（仅本地检查）are enough;
- whether secret redaction（敏感信息脱敏）is required;
- whether a config backup（配置备份）is required before edits;
- whether a network test（网络测试）is useful and allowed;
- whether the final response（最终回复）contains diagnosis, safe fix, verification, and rollback（回滚）details.

Prioritize safety, minimal changes, and reversibility.

## Default Verification Order（默认验证顺序）

Follow this order unless the user explicitly asks for a narrower task:

1. Identify symptom（确认症状）: tool, command, raw error, config path, and recent changes.
2. Redact secrets（脱敏敏感信息）: never repeat full API keys, bearer tokens, passwords, cookies, or proxy credentials.
3. Inspect config（检查配置）: use local-only inspection before suggesting edits.
4. Check config consistency（检查配置一致性）: compare `model`, `model_provider`, provider table, `base_url`, `env_key`, and active profile（当前配置档案）.
5. Back up before edits（修改前备份）: create a timestamped backup before modifying config.
6. Apply smallest fix（应用最小修复）: change only the field needed to test the hypothesis.
7. Ask before network test（网络测试前询问）: explain what the request does and ask for explicit permission.
8. Verify result（验证结果）: use local inspection and, if approved, minimal endpoint checks.
9. Provide rollback（提供回滚方式）: mention backup path and how to revert if a config edit was made.

## Local-Only Checks（仅本地检查）

These checks do not require network access and should usually happen first:

- Confirm `config.toml`（Codex 配置文件）exists at the expected path.
- Check for file-extension mistakes such as `config.toml.txt`（错误扩展名）.
- Check whether project config（项目配置）or user config（用户配置）is being inspected.
- Check whether a `profile`（配置档案）or active profile may override top-level settings.
- Check whether `model`（模型名）is present.
- Check whether `model_provider`（模型提供方）points to an existing `[model_providers.xxx]`（模型提供方配置表）.
- Check whether `base_url`（API 基础地址） starts with `http://` or `https://`.
- Check whether `base_url` duplicates `/v1/v1`（重复版本路径）.
- Check whether `base_url` looks like a dashboard, console, login, docs, or documentation URL instead of an API endpoint（接口端点）.
- Check whether `env_key`（环境变量名） is a variable name, not a raw API key（接口密钥）.
- If allowed by the user/task, check whether the environment variable named by `env_key` is set, but never print its value.

Useful scripts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\inspect_codex_config.ps1 -CheckEnv
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\redact_secret.ps1 -Path "C:\Users\me\.codex\config.toml"
```

## Config Consistency Checks（配置一致性检查）

Check these relationships before blaming the provider（提供方）or the model（模型）:

- `model_provider`（模型提供方）must match a provider id（提供方 ID）under `[model_providers.xxx]`（模型提供方配置表）.
- `model`（模型名）must be supported by the selected provider（提供方）or proxy/relay（代理/中转）.
- `base_url`（API 基础地址）should belong to the same service that issued the API key（接口密钥）.
- `env_key`（环境变量名）should name an environment variable, not contain the actual key value.
- If `profiles`（配置档案）exist, inspect the active profile before deciding which `model` or `model_provider` is effective.
- If both user config（用户配置）and project config（项目配置）exist, state which file was inspected and that precedence can vary by Codex version or launch surface.
- If CLI flags（命令行参数）or app settings（应用设置）may override the file, mention this before editing config again.

## Secret Safety Checks（密钥安全检查）

Never disclose secrets while troubleshooting:

- Do not print full API keys（接口密钥）, bearer tokens（Bearer 令牌）, session tokens（会话令牌）, passwords（密码）, cookies（浏览器凭证）, or proxy credentials（代理凭证）.
- Do not ask users to paste full secrets unless absolutely necessary; prefer environment variable presence checks.
- Do not pass API keys directly as command-line arguments, because they may remain in shell history（命令历史）.
- Do not write secrets into generated docs, logs, or backup reports.
- If a user pasted a real secret into chat or an unsafe file, recommend key rotation（轮换密钥）.

Recommended wording:

```text
API key detected and redacted. I will not print the full key.
检测到 API key（接口密钥），已脱敏。我不会打印完整密钥。
```

## Backup Checks（备份检查）

Before modifying `config.toml`（Codex 配置文件）:

- Run `backup_codex_config.ps1`（Codex 配置备份脚本） or otherwise create a timestamped backup（带时间戳的备份）.
- Record the backup path（备份路径） in the final response if edits are made.
- Do not delete old backups unless the user explicitly requested cleanup or `-KeepLast`（只保留最近 N 个备份） is intentionally used.
- Do not restore or overwrite config without a separate explicit confirmation.
- If the fix fails, tell the user which backup can be used for rollback（回滚）.

Useful command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\backup_codex_config.ps1 -Path "C:\Users\me\.codex\config.toml" -Json
```

## Network Test Consent（网络测试授权）

Network tests are optional and require explicit user approval.

Before running `test_openai_endpoint.js`（OpenAI 兼容端点测试脚本）, explain:

- It will send network requests（网络请求）to the configured `base_url`（API 基础地址）.
- `/models`（模型列表接口）usually checks endpoint availability, API key validity, and model listing. It is typically low cost, but still contacts the provider（提供方）.
- `/chat/completions`（聊天补全接口）sends a minimal `ping`（测试消息） and may consume a very small amount of API quota（接口额度）.
- `/responses`（Responses 接口）sends a minimal `ping`（测试消息） and may consume a very small amount of API quota（接口额度）.
- The script reads the API key（接口密钥） from `env_key`（环境变量名） only and must not print the full key.
- If the user declines, continue with local-only checks（仅本地检查）.

Suggested consent prompt:

```text
我可以运行一个可选的网络测试。它会访问你的 base_url（API 基础地址）来检查接口是否可用。/models（模型列表接口）通常成本较低；chat/responses 测试会发送一个很小的 ping（测试消息），可能消耗极少 API 额度。你允许我运行吗？
```

## Endpoint Checks（接口端点检查）

Use `test_openai_endpoint.js`（OpenAI 兼容端点测试脚本） only after consent.

Recommended commands:

```powershell
node .\scripts\test_openai_endpoint.js --base-url "https://api.example.com/v1" --model "provider-model" --env-key "MY_PROVIDER_API_KEY" --route models
```

```powershell
node .\scripts\test_openai_endpoint.js --base-url "https://api.example.com/v1" --model "provider-model" --env-key "MY_PROVIDER_API_KEY" --route auto
```

Route meaning:

- `--route models`: test `/models`（模型列表接口） only.
- `--route chat`: test `/chat/completions`（聊天补全接口） only with a minimal `ping`（测试消息）.
- `--route responses`: test `/responses`（Responses 接口） only with a minimal `ping`（测试消息）.
- `--route auto`: test `/models` first, then `/chat/completions` unless `--no-chat`（不发送聊天请求） is set.

Do not run endpoint checks if:

- API key environment variable（接口密钥环境变量） is not set.
- The user did not approve network access.
- `base_url` clearly points to a dashboard, login page, or docs page and the user has not confirmed it.
- The requested test would call a paid API and the user has not approved quota use.

## Error-Specific Verification（按错误类型验证）

Use raw error text, local config, and optional endpoint results together.

### `401 Unauthorized`（未授权）

Verify:

- API key（接口密钥） is set in the environment variable named by `env_key`（环境变量名）.
- The key belongs to the same provider（提供方） as `base_url`（API 基础地址）.
- The key is not expired, revoked, or copied from another relay（中转）.
- `env_key` is not accidentally set to the raw key value in `config.toml`（Codex 配置文件）.

### `403 Forbidden`（禁止访问）

Verify:

- Account permission（账号权限） allows this model or route.
- Billing（计费） or quota（额度） is enabled.
- Provider policy（提供方策略） or relay rules（中转规则） do not block the request.
- The selected model（模型） is enabled for the account.

### `404 Not Found`（未找到）

Verify:

- `base_url`（API 基础地址） is an API endpoint（接口端点）, not a dashboard URL.
- `/v1`（版本路径） is present if the provider requires it.
- `/v1/v1`（重复版本路径） is not present.
- The route（接口路由） is supported by this provider（提供方）.
- The user is not mixing Anthropic-style, Gemini-style, and OpenAI-compatible paths.

### `404 model not found`（模型未找到）

Verify:

- `model`（模型名） exactly matches the provider or relay's documented model name.
- `model_provider`（模型提供方） points to the intended provider table.
- The active profile（当前配置档案） is not overriding the expected model.
- If `/models`（模型列表接口） is available, check whether the model appears in the list.

### `429 Too Many Requests`（请求过多）

Verify:

- quota（额度） is available.
- rate limit（速率限制） has not been exceeded.
- relay/proxy（中转/代理） is not overloaded.
- Retrying immediately would not make the issue worse.

### timeout / DNS / connection errors（超时 / DNS / 连接错误）

Verify:

- Hostname（主机名） is spelled correctly.
- Local network, proxy, VPN, firewall, or DNS can reach the provider.
- The provider or relay service is not down.
- The URL scheme is `https://` or valid `http://` for local services.

### non-JSON response（非 JSON 响应）

Verify:

- The URL did not return HTML from a dashboard, docs page, login page, or proxy error page.
- The endpoint route is correct.
- The provider actually exposes OpenAI-compatible JSON routes.

## Final Response Checklist（最终回复检查清单）

Before replying to the user, confirm the response includes:

- `Current Configuration`（当前配置） or a clear statement that config was not inspected.
- `Detected Provider Type`（检测到的提供方类型） when inferable.
- `Likely Problem`（可能问题） with one or two strongest hypotheses.
- `Safe Fix`（安全修复） with the smallest recommended change.
- `Commands or UI Steps`（命令或界面步骤） if the user needs to act.
- `Verification`（验证方式） with local-only checks or approved network checks.
- Backup path（备份路径） if config was modified.
- Rollback（回滚） instructions if edits were made.
- No full secrets（完整敏感信息）.

If config was not inspected, say:

```text
Current Configuration:
Not inspected. Diagnosis is based only on the error text and user description.
```

## When To Stop（什么时候停止）

Stop and ask for user input or approval when:

- The user does not approve network testing.
- The needed config file cannot be found locally.
- The next action would modify system proxy, certificates, shell profiles, or global environment variables.
- The next action would overwrite or restore `config.toml`（Codex 配置文件）.
- The next action may expose, rotate, revoke, or permanently change an API key（接口密钥）.
- Network tests have already identified the likely issue and more requests would add cost without new information.
- A destructive or high-risk operation is required.
