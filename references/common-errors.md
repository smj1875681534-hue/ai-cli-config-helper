# Common Errors

Use this reference when the user provides an AI CLI, API, proxy, relay, or model-provider error message. Diagnose the error in the user's language, preserve technical terms exactly, and give a safe, minimal verification path.

This file is a broad troubleshooting map, not a promise that every provider uses the same wording. Always combine the error message with the actual `base_url`, `provider`, `model`, `api_key` source, selected profile, and recent config changes.

## Purpose

Turn raw errors into useful explanations and safe next steps.

Use this file for:

- HTTP status codes such as `400`, `401`, `403`, `404`, `408`, `409`, `413`, `415`, `422`, `429`, `500`, `502`, `503`, `504`.
- Network errors such as `timeout`, `ETIMEDOUT`, `ENOTFOUND`, `ECONNREFUSED`, `ECONNRESET`, `EAI_AGAIN`, `socket hang up`.
- TLS/certificate errors such as `CERT_HAS_EXPIRED`, `UNABLE_TO_VERIFY_LEAF_SIGNATURE`, `SELF_SIGNED_CERT_IN_CHAIN`.
- API compatibility errors such as `unsupported endpoint`, `invalid request body`, `schema validation failed`, `non-JSON response`.
- Model and quota errors such as `model not found`, `insufficient_quota`, `rate_limit_exceeded`, `context length exceeded`.

Use `references/ai-cli-concepts.md` when the user is mainly confused about concepts like `base_url`, `api_key`, `model`, `provider`, `OpenAI-compatible`, or `/v1`.

## Diagnosis Principles

- Do not diagnose from the status code alone. Inspect the surrounding message and config.
- Prefer the most likely one or two causes first.
- Distinguish authentication, authorization, routing, model availability, quota, network, and provider-format problems.
- Check whether `base_url`, `api_key`, and `model` all belong to the same service or relay.
- Check whether the user edited one `profile` but ran another.
- Never ask the user to paste a full `api_key`.
- If a key was pasted into chat or logs, avoid repeating it and recommend rotation when exposure is meaningful.
- Suggest the lowest-cost verification first, such as a model-list endpoint, dry-run, or minimal request.
- If a network test may call a paid API or external service, ask before running it.

## Fast Triage

Use this quick grouping before deeper diagnosis:

```text
400/422/schema errors -> request body, provider format, unsupported parameters
401 -> authentication: missing/wrong/expired key or wrong auth header
403 -> authorization: key valid but not allowed to use resource/model/account
404 -> wrong URL route, missing/duplicate /v1, wrong endpoint, model not found
408/timeout/ETIMEDOUT -> slow service, network, proxy, firewall, DNS, region
409 -> conflict, duplicate job, concurrent operation, provider state issue
413/context length -> request too large or context window exceeded
415 -> wrong content type
429 -> rate limit, quota, relay overload, plan restriction
500/502/503/504 -> provider or relay server-side failure, gateway, overload
ENOTFOUND/EAI_AGAIN -> DNS or host resolution
ECONNREFUSED -> host reachable but port/service refused connection
ECONNRESET/socket hang up -> connection dropped by server/proxy/network
TLS/CERT errors -> certificate, corporate proxy, system clock, MITM proxy
```

## HTTP Status Errors

### `400 Bad Request`

Meaning:

The server received the request but rejected its shape or values.

Likely causes:

- Wrong provider format, such as sending OpenAI-style JSON to an Anthropic-style endpoint.
- Unsupported parameter such as `temperature`, `stream`, `tools`, `response_format`, or `max_tokens`.
- Invalid message structure.
- Empty or malformed request body.
- Model does not support a requested feature.

Check:

- Does the `provider` match the endpoint compatibility?
- Does the request use the provider's expected route, such as `/v1/chat/completions`, `/v1/responses`, or `/v1/messages`?
- Did the CLI add parameters the relay does not support?
- Is the configured model capable of the requested mode, such as tools or vision?

Safe fix:

- Switch to the correct provider type.
- Remove unsupported optional parameters if the CLI allows it.
- Use a simpler minimal request for verification.
- Check the relay documentation for supported fields.

Beginner explanation:

```text
`400 Bad Request` 通常表示“请求格式不对”。服务已经收到了请求，但里面的字段、路径或参数不符合它的规则。
```

### `401 Unauthorized`

Meaning:

Authentication failed. The service did not accept the credential.

Likely causes:

- Missing `api_key`.
- Wrong `api_key`.
- Expired, revoked, or disabled key.
- `api_key` belongs to a different provider than `base_url`.
- Proxy/relay requires its own key, but the user used the official provider key.
- Extra spaces, quotes, invisible characters, or truncated key.
- Wrong auth header format, such as missing `Bearer`.

Check:

- Is `api_key` present in the active config/profile?
- Was the key copied from the same service as `base_url`?
- Is the key redacted in logs, not exposed?
- Did the provider require an organization/project header in addition to the key?

Safe fix:

- Replace the key with a valid key from the same provider or relay as `base_url`.
- Remove accidental whitespace.
- If the key was exposed, rotate it in the provider dashboard.
- Do not paste the full key into chat.

Verification:

- Use a low-cost model-list request if supported.
- Run a minimal request with the intended active profile.

### `402 Payment Required` or billing-related errors

Meaning:

The service rejected the request because billing, balance, subscription, or credits are insufficient.

Likely causes:

- No payment method.
- Free credits expired.
- Balance depleted.
- Plan does not include the selected model.
- Relay account has no quota even if the upstream provider account is valid.

Check:

- Provider billing dashboard.
- Relay balance or plan.
- Whether the selected model requires a paid tier.

Safe fix:

- Add credits or change to an allowed model.
- Confirm the key belongs to the account with active billing.

### `403 Forbidden`

Meaning:

The key may be recognized, but this account/key is not allowed to perform the requested action.

Likely causes:

- Model not enabled for the account.
- Region, organization, project, or workspace restriction.
- Key has limited scope.
- Provider blocked the relay or client.
- Account requires additional verification.
- Policy restriction for the requested content or feature.

Check:

- Can the same key list models?
- Is the model available to this account/provider?
- Does the provider require project, organization, or workspace selection?
- Is the request blocked by policy or region?

Safe fix:

- Use a model available to the account.
- Enable the model or project in provider settings.
- Generate a key with the required scope.
- Contact the provider if the account requires verification.

Beginner explanation:

```text
`403 Forbidden` 通常表示“我知道你是谁，但你没有权限做这件事”。它和 `401` 不一样，`401` 更像是身份没通过。
```

### `404 Not Found`

Meaning:

The requested route or resource does not exist at that URL.

Likely causes:

- Wrong `base_url`.
- Missing `/v1`.
- Duplicated `/v1/v1`.
- Dashboard/documentation URL used as API URL.
- Using an OpenAI route on an Anthropic/Gemini/custom endpoint.
- Provider does not support the route the CLI calls.

Check:

- What final URL is the CLI calling?
- Does provider documentation show `/v1` in examples?
- Is `base_url` an API endpoint rather than a dashboard page?
- Does the endpoint support `/v1/models`, `/v1/chat/completions`, `/v1/responses`, or `/v1/messages`?

Safe fix:

- Correct `base_url` to the provider's API base.
- Add or remove `/v1` according to provider and CLI expectations.
- Switch to the correct provider type.

### `404 model not found` or `model_not_found`

Meaning:

The endpoint was reached, but the configured `model` is not recognized or available there.

Likely causes:

- Typo in `model`.
- Official model name used on a relay that requires custom aliases.
- Relay alias used on the official provider.
- Model unavailable to the account.
- Wrong `base_url`, so the request reached a different provider than expected.
- Wrong active profile.

Check:

- Does the configured endpoint expose a model list?
- Is the model name copied exactly from the provider/relay docs?
- Is the command using the profile that contains this model?
- Does the provider require names like `openai/gpt-4.1`, `anthropic/claude...`, or another alias format?

Safe fix:

- Replace `model` with an exact supported name from the current provider.
- If using a relay, use the relay's model alias rather than the official provider name unless documented.
- Verify with a model-list endpoint or provider dashboard.

Beginner explanation:

```text
`model not found` 经常不是网络问题，而是“这个 API 地址不认识你填的模型名”。模型名必须和当前 `base_url` 对应的服务商匹配。
```

### `405 Method Not Allowed`

Meaning:

The route exists, but the HTTP method is wrong.

Likely causes:

- The CLI sent `GET` where the endpoint expects `POST`, or the reverse.
- User tested a `POST` endpoint in a browser address bar.
- Proxy rewrote the method.

Check:

- Provider docs for the route method.
- Whether the test command uses the right method.

Safe fix:

- Use the provider's example `curl` command.
- Do not test `POST` chat routes by pasting them into a browser.

### `408 Request Timeout`

Meaning:

The server timed out waiting for the request.

Likely causes:

- Slow network.
- Proxy delay.
- Provider overload.
- Very large prompt or file.
- Streaming connection interrupted.

Safe fix:

- Retry once.
- Use a smaller request.
- Increase timeout if the CLI supports it.
- Check provider status or relay status.

### `409 Conflict`

Meaning:

The request conflicts with the current server state.

Likely causes:

- Duplicate job or operation.
- Concurrent request with the same idempotency key.
- Fine-tune, batch, or upload resource is in a state that cannot accept the action.

Safe fix:

- Wait and retry.
- Avoid submitting the same operation twice.
- Check provider job/resource status.

### `413 Payload Too Large` or `context length exceeded`

Meaning:

The request is too large for the endpoint or model.

Likely causes:

- Prompt exceeds model context window.
- Attached file too large.
- Too much conversation history.
- Tool output or repo content inserted into the request is too large.
- Provider/relay imposes a smaller limit than the official model.

Check:

- Prompt size, conversation history, file sizes.
- Selected model's context limit.
- Relay-specific maximum request size.

Safe fix:

- Reduce pasted content.
- Summarize long logs before sending.
- Use a model with a larger context window if available.
- Split the task into smaller requests.

### `415 Unsupported Media Type`

Meaning:

The server does not accept the request content type.

Likely causes:

- Missing or wrong `Content-Type`, such as not using `application/json`.
- Upload endpoint expects multipart form data but received JSON.
- CLI or proxy transformed the request incorrectly.

Safe fix:

- Use the provider's documented request format.
- Avoid manually editing headers unless necessary.

### `422 Unprocessable Entity`

Meaning:

The request is valid JSON but semantically invalid for the API.

Likely causes:

- Invalid enum value.
- Required field missing.
- Wrong field type.
- Message content format not accepted.
- Tool/function schema invalid.
- Model does not support the requested feature.

Safe fix:

- Compare the failing payload against provider docs.
- Remove optional advanced fields.
- Test with a minimal prompt and no tools.

### `429 Too Many Requests`, `rate_limit_exceeded`, or quota errors

Meaning:

The service is throttling or rejecting usage due to rate or quota limits.

Likely causes:

- Too many requests per minute.
- Too many tokens per minute.
- Daily/monthly quota exhausted.
- Free-tier or relay limit reached.
- Provider or relay is overloaded.
- Multiple tools share the same key.

Check:

- Provider dashboard for rate limits and quota.
- Whether several apps use the same key.
- Whether the selected model has stricter limits.
- Relay balance and throttle rules.

Safe fix:

- Wait and retry with backoff.
- Reduce parallel requests.
- Use a smaller model or smaller prompts.
- Upgrade quota or add balance if appropriate.
- Avoid rapid automatic retries.

Beginner explanation:

```text
`429 Too Many Requests` 通常表示“请求太多或额度不够”。它不一定是配置错了，也可能是频率或余额限制。
```

### `500 Internal Server Error`

Meaning:

The provider or relay failed internally.

Likely causes:

- Temporary provider issue.
- Relay bug.
- Unsupported edge-case request crashed the route.
- Upstream model service failed.

Safe fix:

- Retry once after a short wait.
- Test with a minimal request.
- If minimal request also fails, check provider/relay status.
- Avoid changing config unless the error consistently points to a wrong endpoint.

### `502 Bad Gateway`

Meaning:

A gateway or relay could not get a valid response from the upstream service.

Likely causes:

- Proxy/relay upstream failure.
- Provider outage.
- Network path issue between relay and upstream.
- Wrong upstream model mapping in relay.

Safe fix:

- Retry later.
- Check relay status.
- Try a different model supported by the same relay.
- If using an official endpoint, check provider status.

### `503 Service Unavailable`

Meaning:

The service is temporarily unavailable or overloaded.

Likely causes:

- Provider outage.
- Model overloaded.
- Relay capacity exhausted.
- Maintenance.

Safe fix:

- Wait and retry.
- Use a different model or endpoint if available.
- Do not rotate keys or rewrite config unless other evidence points to auth/config.

### `504 Gateway Timeout`

Meaning:

A gateway waited too long for upstream response.

Likely causes:

- Provider slow response.
- Relay timeout.
- Large prompt or long generation.
- Streaming blocked by network/proxy.

Safe fix:

- Reduce prompt size.
- Disable expensive options if possible.
- Increase timeout if supported.
- Retry later or switch endpoint/model.

## Network And DNS Errors

### `timeout`, `ETIMEDOUT`, or `Request timed out`

Meaning:

The request did not complete within the allowed time.

Likely causes:

- Network instability.
- Provider or relay slow.
- Corporate/school firewall.
- Proxy/VPN issue.
- Very large request.
- Region connectivity problem.

Check:

- Can the host be reached in a browser or with a simple request?
- Does DNS resolve?
- Is a proxy/VPN required?
- Did the same request work earlier?

Safe fix:

- Retry once.
- Reduce request size.
- Check proxy/VPN settings.
- Increase timeout if the CLI supports it.
- Try a model-list request before a long chat request.

### `ENOTFOUND` or `getaddrinfo ENOTFOUND`

Meaning:

The hostname cannot be resolved by DNS.

Likely causes:

- Typo in host.
- Missing or wrong domain.
- Local DNS problem.
- VPN/proxy DNS issue.
- User pasted a path instead of a host.

Safe fix:

- Check spelling in `base_url`.
- Confirm it starts with a valid host such as `https://api.example.com`.
- Try a different DNS/network if appropriate.
- Check whether VPN/proxy is required.

### `EAI_AGAIN`

Meaning:

Temporary DNS resolution failure.

Likely causes:

- DNS server timeout.
- Network instability.
- VPN/proxy DNS issue.

Safe fix:

- Retry after a short wait.
- Check network/VPN.
- If persistent, inspect DNS settings.

### `ECONNREFUSED`

Meaning:

The connection reached a host/port, but nothing accepted the connection.

Likely causes:

- Wrong port.
- Local server not running.
- HTTP used where HTTPS is required, or the reverse.
- Firewall blocked the service.
- Provider host is not an API server.

Safe fix:

- Confirm `https://` and host/port.
- If using local model server, start the server.
- Use the provider's documented API URL.

### `ECONNRESET`, `socket hang up`, or `connection reset by peer`

Meaning:

The connection was opened but then dropped.

Likely causes:

- Server/proxy closed the connection.
- Streaming response interrupted.
- Firewall, VPN, or corporate proxy interference.
- Provider overload.
- Request too large.

Safe fix:

- Retry with a smaller request.
- Disable streaming if the CLI supports it.
- Try another network or proxy.
- Check relay/provider status.

### `EHOSTUNREACH` or `Network is unreachable`

Meaning:

The host cannot be reached from the current network.

Likely causes:

- No internet.
- VPN/proxy required.
- Firewall blocks route.
- Region/network restrictions.

Safe fix:

- Check network connectivity.
- Confirm VPN/proxy requirements.
- Try a known reachable endpoint before changing AI config.

## TLS And Certificate Errors

### `CERT_HAS_EXPIRED`

Meaning:

The certificate is expired, or the local system clock is wrong.

Likely causes:

- Provider/relay certificate expired.
- Local system date/time incorrect.
- Corporate proxy presenting an expired certificate.

Safe fix:

- Check system date/time.
- Check provider status.
- Avoid disabling certificate verification as a first fix.

### `UNABLE_TO_VERIFY_LEAF_SIGNATURE`, `SELF_SIGNED_CERT_IN_CHAIN`, or certificate verify failed

Meaning:

The client cannot verify the server certificate chain.

Likely causes:

- Corporate/school proxy intercepting HTTPS.
- Self-signed certificate from a private relay.
- Missing root certificate.
- Outdated certificate bundle.

Safe fix:

- Use a properly trusted certificate for private relay.
- Install the organization's root CA if appropriate.
- Avoid setting insecure global certificate bypass unless the user understands the risk.

### `SSL wrong version number` or `EPROTO`

Meaning:

TLS negotiation failed.

Likely causes:

- Using `https://` against an HTTP-only local server.
- Using `http://` where the service expects HTTPS.
- Proxy protocol mismatch.

Safe fix:

- Confirm whether the endpoint expects `http://` or `https://`.
- For public APIs, prefer `https://`.
- For local servers, check the server's advertised scheme and port.

## API Compatibility And Format Errors

### `unsupported endpoint`

Meaning:

The service does not support the route or API style the CLI is trying to use.

Likely causes:

- OpenAI-compatible CLI pointed at Anthropic/Gemini/custom endpoint.
- CLI uses `/v1/responses`, but relay only supports `/v1/chat/completions`.
- CLI uses chat completions, but provider only supports another route.

Safe fix:

- Switch provider type if the CLI supports it.
- Use an endpoint documented as compatible with the route the CLI needs.
- If relay supports only partial OpenAI compatibility, configure the CLI to use a supported route if possible.

### `invalid request body`, `schema validation failed`, or `unknown field`

Meaning:

The endpoint received JSON but does not accept one or more fields.

Likely causes:

- Provider mismatch.
- Relay does not support advanced OpenAI fields.
- Tool/function calling schema invalid.
- CLI version sends newer fields than relay supports.

Safe fix:

- Update the CLI if the provider requires newer behavior.
- Remove advanced features if possible.
- Use a simpler model or endpoint.
- Check relay support for tools, JSON mode, streaming, and reasoning fields.

### `invalid JSON`, `Unexpected token`, or `non-JSON response`

Meaning:

The client expected JSON but received malformed JSON, HTML, plain text, or an empty response.

Likely causes:

- `base_url` points to a dashboard, login page, WAF page, or error page.
- Proxy returned HTML.
- Provider outage returned non-JSON error.
- Wrong path or missing `/v1`.

Check:

- Does the response start with `<html>`?
- Is the URL an API URL?
- Is a login page or anti-bot page being returned?

Safe fix:

- Correct `base_url`.
- Use the API endpoint from docs.
- Avoid browser-only dashboard URLs.

### `stream error`, `SSE error`, or incomplete streaming response

Meaning:

The streaming connection broke or the stream format was not accepted.

Likely causes:

- Relay does not support streaming.
- Network/proxy interrupts long-lived connections.
- Provider sends a stream format the CLI does not parse.
- Timeout during long generation.

Safe fix:

- Disable streaming if possible.
- Try a shorter request.
- Test non-streaming request.
- Check whether relay documents streaming support.

## Model, Feature, And Token Errors

### `context_length_exceeded`, `maximum context length`, or token limit errors

Meaning:

The request exceeds the model's context window or provider token limits.

Likely causes:

- Too much conversation history.
- Large pasted logs or files.
- Tool output included in prompt.
- Selected model has smaller context than expected.
- Relay enforces a lower limit.

Safe fix:

- Summarize or trim input.
- Split task into smaller chunks.
- Clear old conversation context if appropriate.
- Use a model with larger context if available.

### `unsupported model`, `model does not support`, or feature not available

Meaning:

The selected model exists but does not support the requested feature.

Likely causes:

- Vision requested on text-only model.
- Tool calling requested on a model that lacks tool support.
- JSON mode or structured output unsupported.
- Reasoning or image/audio features unsupported by relay.

Safe fix:

- Choose a model that supports the feature.
- Disable the unsupported feature.
- Check provider capability table.

### `content policy`, `safety`, or `moderation` errors

Meaning:

The provider blocked the request or response because of policy/safety rules.

Likely causes:

- Request content violates provider policy.
- Provider or relay applies stricter filters.
- Account/workspace policy blocks the topic.

Safe fix:

- Revise the request to comply with policy.
- Do not try to bypass safety systems.
- If the request is benign, clarify context and reduce ambiguous wording.

## Provider Mismatch Patterns

Use these patterns when the error is vague:

- Official `api_key` + relay `base_url`: likely `401` or `403`.
- Relay `api_key` + official provider `base_url`: likely `401`.
- OpenAI-compatible CLI + Anthropic endpoint: likely `400`, `404`, `unsupported endpoint`, or schema error.
- OpenAI-compatible CLI + Gemini endpoint: likely route/schema/auth error.
- Claude model name + OpenAI-compatible endpoint: likely `model not found`, unless relay maps the name.
- Official model name + relay endpoint: may fail if relay requires aliases.
- Dashboard URL as `base_url`: likely HTML/non-JSON response or `404`.
- Missing `/v1`: likely `404` or unsupported route.
- Duplicated `/v1/v1`: likely `404`.
- Wrong active profile: config looks fixed but CLI still fails.

## Safe Fix Patterns

Prefer these repair moves:

- Back up config before editing.
- Change only one field at a time.
- Match `base_url`, `api_key`, `model`, and `provider` to the same provider or relay.
- Use model names copied from the current provider's docs/model list.
- Avoid printing full secrets.
- Avoid disabling TLS verification unless the user explicitly understands the risk.
- Avoid broad rewrites of config when a single URL/model/key is wrong.
- After each change, verify with the smallest useful request.

## Verification Patterns

Use the least expensive verification that proves the diagnosis:

- Model list:
  - OpenAI-compatible: `GET /v1/models` when supported.
  - If unsupported, use provider dashboard or docs.
- Minimal chat:
  - One short message.
  - No tools, no files, no streaming, no advanced output mode.
- Route check:
  - Confirm whether the CLI calls `/v1/chat/completions`, `/v1/responses`, or `/v1/messages`.
- Profile check:
  - Confirm the command is using the profile the user edited.
- URL check:
  - Confirm no dashboard path, missing `/v1`, or duplicated `/v1/v1`.
- Quota check:
  - Confirm account balance, plan, or relay quota when seeing `402`, `403`, or `429`.

## Response Template

Use this structure when the user provides an error:

```text
Current Configuration:
Detected Error:
Likely Meaning:
Most Likely Causes:
Safe Fix:
Verification:
```

If the config was not inspected:

```text
Current Configuration:
Not inspected. This diagnosis is based only on the error text.
```

For beginner users, add one short explanation of the technical term that matters most, in the user's language.

## Chinese Response Pattern

When the user asks in Chinese, a concise response can follow this pattern:

```text
当前配置：
检测到的报错：
这个报错通常表示：
最可能的原因：
安全修复：
验证方式：
```

Keep technical terms unchanged, for example `base_url`, `api_key`, `model`, `/v1`, `401 Unauthorized`, and `model not found`.
