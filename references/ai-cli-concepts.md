# AI CLI Concepts

Use this reference when the user is confused about API keys, base URLs, model names, providers, endpoint compatibility, or `/v1` URL formatting. Keep explanations beginner-friendly, but preserve the original technical field names so users can match them to their config files.

## Purpose

Explain the core concepts behind AI CLI configuration before diagnosing specific errors. This file should help the agent answer questions like:

- What is `base_url`?
- What is `api_key`?
- What is `model`?
- What does `OpenAI-compatible` mean?
- Should the URL include `/v1`?
- Why does `model not found` happen?

For specific error codes such as `401`, `403`, `404`, `429`, or `timeout`, use `references/common-errors.md` when it exists.

## Language Rule

- Reply in the same language the user used.
- Keep technical names unchanged: `base_url`, `api_key`, `model`, `provider`, `config.toml`, `/v1`.
- When a beginner may not understand a technical term, explain it in the user's language the first time it appears.
- Do not translate configuration keys, command names, file paths, HTTP status codes, or API route names.

Example in Chinese:

```text
`base_url` 可以理解为“API 服务入口地址”。CLI 会把请求发到这里，所以它应该是 API 地址，而不是网页登录后台地址。
```

Example in English:

```text
`base_url` is the API service entry point. The CLI sends requests there, so it should be an API URL, not a dashboard page.
```

## Mental Model

Use this simple model:

```text
AI CLI tool = client
base_url = service entry point
api_key = access credential
model = model name to call
provider = API format / provider type
```

Plain explanation:

- The CLI is the app making the request.
- `base_url` tells the CLI where to send the request.
- `api_key` proves the user is allowed to use that service.
- `model` tells the service which model the user wants.
- `provider` tells the CLI what request format to use.

If any of these do not match the same service, the request may fail even if each field looks valid by itself.

## Core Fields

### `api_key`

`api_key` is a secret credential used to authenticate API requests. It is not the same as a password, but it can often spend quota or money if leaked.

Key points:

- Never print the full key back to the user.
- Redact it as `sk-...abcd` or `[REDACTED]`.
- A key usually only works with the service that issued it.
- A key for one provider may not work with another provider or relay.

Beginner explanation:

```text
`api_key` 像一张调用 API 的通行证。服务商用它判断你是谁、有没有权限、能不能调用某个模型。
```

### `base_url`

`base_url` is the API entry address. It tells the CLI where the API server is.

Key points:

- It should usually be an API endpoint, not a dashboard or documentation page.
- It often starts with `https://`.
- It may need to end with `/v1`, depending on the tool and provider.
- A wrong `base_url` can cause `404`, `timeout`, or endpoint compatibility errors.

Beginner explanation:

```text
`base_url` 不是模型名，也不是密钥。它是 CLI 要访问的“服务入口地址”。
```

### `model`

`model` is the model name sent to the provider, such as `gpt-4.1`, `gpt-4o`, or a relay-specific alias.

Key points:

- The model name must be recognized by the configured endpoint.
- Official model names and proxy model aliases may differ.
- Do not guess model names when a proxy provider gives its own model list.
- `404 model not found` often means the endpoint does not recognize the configured model.

Beginner explanation:

```text
`model` 就是“你想调用哪一个模型”。它必须是当前服务商支持的名字，不是所有平台都用同一套名字。
```

### `provider`

`provider` describes the API type or service family the CLI should speak to. Some tools use explicit provider names; others infer the behavior from config.

Key points:

- `provider` is about request format and routing, not only brand name.
- If the provider type is wrong, the request body may be sent in the wrong shape.
- An OpenAI-compatible endpoint usually cannot be treated as Anthropic-compatible unless the service explicitly supports both.

Beginner explanation:

```text
`provider` 可以理解为“这个服务要用哪种接口格式说话”。格式不对，即使 URL 和 key 看起来对，也可能请求失败。
```

### `profile`

`profile` is a named configuration set. Not every CLI uses this term, but many tools support multiple profiles or provider entries.

Key points:

- Profiles let users switch between different models, providers, or keys.
- A user may edit one profile but run another.
- When troubleshooting, confirm which profile the command is actually using.

Beginner explanation:

```text
`profile` 像一套配置方案。你可能有“OpenAI 官方”“中转 API”“本地模型”几套配置，运行时要确认用的是哪一套。
```

## Endpoint Compatibility

Endpoint compatibility means whether the API server understands the request format that the CLI sends.

### `OpenAI-compatible`

`OpenAI-compatible` means the service imitates OpenAI API formats closely enough that OpenAI-style clients can call it.

Common routes include:

- `/v1/models`
- `/v1/chat/completions`
- `/v1/responses`

Important:

- `OpenAI-compatible` does not always mean the service is OpenAI.
- A proxy or relay can be OpenAI-compatible.
- The provider may still use custom model names.
- Some services support only part of the OpenAI API.

Beginner explanation:

```text
`OpenAI-compatible` 的意思是“这个服务尽量按 OpenAI API 的格式接收请求”。它不一定是 OpenAI 官方服务。
```

### `Anthropic-compatible`

`Anthropic-compatible` means the service follows Anthropic/Claude-style API behavior.

Common route:

- `/v1/messages`

Important:

- A Claude API URL is not automatically usable in an OpenAI-compatible client.
- Claude model names may not work in OpenAI-compatible endpoints unless a relay maps them.
- Request body fields can differ from OpenAI-style APIs.

### `Gemini-compatible`

`Gemini-compatible` usually refers to Google Gemini API behavior.

Important:

- Gemini APIs often use different URL paths, auth styles, and model names.
- A Gemini key or endpoint usually cannot be pasted directly into an OpenAI-compatible config unless a proxy provides compatibility.

### Proxy or Relay Services

A proxy or relay service sits between the CLI and the actual model provider. It may provide one unified API format for many models.

Key points:

- The relay may give a custom `base_url`.
- The relay may require a relay-issued `api_key`, not the original provider key.
- The relay may use custom model aliases.
- Some relays are OpenAI-compatible; others are Anthropic-compatible or custom.
- Always prefer the relay's own documentation for URL and model names.

Beginner explanation:

```text
中转服务像一个“转发站”。你的 CLI 先请求中转站，中转站再去请求真正的模型服务，所以 URL、key 和模型名通常要按中转站的规则填写。
```

## The `/v1` Rule

`/v1` is commonly an API version path. It often means "version 1 of this API".

Why it matters:

- Some providers expect `base_url` to include `/v1`.
- Some tools automatically append `/v1`.
- If both the user and the tool add `/v1`, the final URL may become `/v1/v1`.
- If `/v1` is missing when required, routes such as `/models` may become invalid.
- A dashboard URL such as `https://example.com/dashboard` is not the same as an API URL such as `https://api.example.com/v1`.

Useful checks:

- Does the provider documentation show an OpenAI-compatible API base?
- Does the example curl command include `/v1`?
- Does the tool ask for `base_url`, `api_base`, `endpoint`, or `host`?
- Does a model-list route such as `/v1/models` exist?
- Is `/v1` duplicated?

Safe phrasing:

```text
For OpenAI-compatible APIs, `base_url` often ends in `/v1`, but this depends on the tool and provider. Check the provider docs or test the model-list endpoint before editing config.
```

## Model Name Rules

Model names are provider-specific.

Rules:

- Use the model name exactly as the configured provider or relay documents it.
- Do not assume an official model name works through every proxy.
- Do not assume a proxy alias works on the official provider.
- If the service offers a `/models` endpoint, use it to confirm available names.
- If the error is `model not found`, check the configured endpoint and model list before blaming the key.

Examples:

```text
Official provider model: gpt-4.1
Relay alias: openai/gpt-4.1
Another relay alias: gpt-4.1-all
```

These may point to similar models, but they are not interchangeable unless the provider says so.

## Common Misunderstandings

- "This is an OpenAI-compatible API, so it must be OpenAI official."
  - Not necessarily. It only means the API format is OpenAI-like.

- "The dashboard URL is my `base_url`."
  - Usually false. A dashboard is for humans; an API endpoint is for tools.

- "If the key is valid, any model name should work."
  - False. The model must be available under the configured endpoint.

- "`/v1` should always be added."
  - False. It depends on the tool and provider. Duplicated `/v1/v1` is also a common mistake.

- "A Claude model name can be pasted into an OpenAI-compatible config."
  - Usually false unless a relay explicitly maps that model name.

- "A `401` error means the network is broken."
  - Usually false. `401` usually means authentication failed.

- "It is safe to paste my full `api_key` into chat for debugging."
  - Unsafe. Share only redacted keys or let the tool inspect locally with redaction.

## Beginner Explanation Patterns

Use patterns like these when the user seems new to AI CLI configuration.

### Explaining `base_url`

```text
`base_url` 可以理解为“API 服务入口地址”。CLI 会把请求发到这个地址，所以它应该是服务商提供的 API 地址，而不是网页后台地址。
```

### Explaining `api_key`

```text
`api_key` 是调用 API 的身份凭证。它需要保密，因为别人拿到后可能会消耗你的额度。
```

### Explaining `model`

```text
`model` 是你要调用的模型名字。它必须和当前 `base_url` 对应的服务商支持的模型名一致。
```

### Explaining `OpenAI-compatible`

```text
`OpenAI-compatible` 表示这个服务按 OpenAI API 的格式接收请求，但它不一定是 OpenAI 官方服务。
```

### Explaining `/v1`

```text
`/v1` 通常是 API 的版本路径。有些服务商要求加，有些工具会自动加，所以要避免漏加或重复加成 `/v1/v1`。
```

## What To Preserve In English

Preserve these technical names exactly:

- `api_key`
- `base_url`
- `model`
- `provider`
- `profile`
- `config.toml`
- `OpenAI-compatible`
- `Anthropic-compatible`
- `Gemini-compatible`
- `/v1`
- `/v1/models`
- `/v1/chat/completions`
- `/v1/responses`
- `/v1/messages`
- `401 Unauthorized`
- `403 Forbidden`
- `404 Not Found`
- `404 model not found`
- `429 Too Many Requests`
- `timeout`
- `ENOTFOUND`
- `ECONNREFUSED`

## Quick Diagnosis Questions

Ask only the minimum needed questions. Prefer one to three questions at a time.

Useful questions:

- Which CLI are you using: Codex, Claude Code, CC Switch, or another tool?
- What is the exact error message?
- What `base_url` are you using? Redact private domains or tokens if needed.
- Is your endpoint documented as `OpenAI-compatible`?
- Did the provider give you the `model` name, or did you choose it yourself?
- Does the provider's example URL include `/v1`?
- Are you sure the command is using the profile you edited?

If the user gives a config file, inspect it locally when possible and redact secrets before summarizing.
