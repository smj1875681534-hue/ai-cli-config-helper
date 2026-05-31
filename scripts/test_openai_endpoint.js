#!/usr/bin/env node
"use strict";

function usage() {
  return [
    "Usage:",
    "  node scripts/test_openai_endpoint.js --base-url <url> --model <model> --env-key <ENV_NAME> [options]",
    "",
    "Options:",
    "  --route <auto|models|chat|responses>  Route to test. Default: auto",
    "  --no-chat                           In auto mode, test /models only",
    "  --timeout-ms <ms>                   Request timeout. Default: 15000",
    "  --json                              Print JSON report",
    "  --help                              Show this help",
    "",
    "Safety:",
    "  The API key is read from --env-key and is never printed.",
    "  This script performs network requests and should only be run with user approval.",
  ].join("\n");
}

function parseArgs(argv) {
  const args = {
    route: "auto",
    timeoutMs: 15000,
    json: false,
    noChat: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (key === "--help" || key === "-h") {
      args.help = true;
      continue;
    }
    if (key === "--json") {
      args.json = true;
      continue;
    }
    if (key === "--no-chat") {
      args.noChat = true;
      continue;
    }

    const value = argv[index + 1];
    if (!key.startsWith("--") || !value || value.startsWith("--")) {
      throw new Error(`Missing value for option: ${key}\n\n${usage()}`);
    }
    index += 1;

    if (key === "--base-url") args.baseUrl = value;
    else if (key === "--model") args.model = value;
    else if (key === "--env-key") args.envKey = value;
    else if (key === "--route") args.route = value;
    else if (key === "--timeout-ms") args.timeoutMs = Number(value);
    else throw new Error(`Unknown option: ${key}\n\n${usage()}`);
  }

  if (args.help) return args;
  if (!args.baseUrl) throw new Error(`Missing --base-url.\n\n${usage()}`);
  if (!args.envKey) throw new Error(`Missing --env-key.\n\n${usage()}`);
  if (!Number.isFinite(args.timeoutMs) || args.timeoutMs <= 0) {
    throw new Error("--timeout-ms must be a positive number.");
  }
  if (!["auto", "models", "chat", "responses"].includes(args.route)) {
    throw new Error("--route must be one of: auto, models, chat, responses.");
  }
  if (["chat", "responses", "auto"].includes(args.route) && !args.model && !args.noChat) {
    throw new Error("Missing --model. A model is required for chat or responses tests.");
  }

  return args;
}

function redactSecret(value) {
  if (!value) return "";
  const trimmed = String(value).trim();
  if (trimmed.length < 12) return "[REDACTED]";
  if (trimmed.startsWith("sk-")) return `sk-...${trimmed.slice(-4)}`;
  return `${trimmed.slice(0, 4)}...${trimmed.slice(-4)}`;
}

function normalizeBaseUrl(input) {
  const warnings = [];
  let urlText = String(input || "").trim();

  if (!/^https?:\/\//i.test(urlText)) {
    throw new Error("base_url must start with http:// or https://.");
  }

  urlText = urlText.replace(/\/+$/, "");

  if (/\/v1\/v1(?:\/|$)/i.test(urlText)) {
    warnings.push("base_url contains duplicated /v1/v1.");
  }
  if (/\/(models|chat\/completions|responses)$/i.test(urlText)) {
    warnings.push("base_url appears to include a route. Use the API base URL, not /models, /chat/completions, or /responses.");
  }
  if (/(dashboard|console|login|docs|documentation)/i.test(urlText)) {
    warnings.push("base_url looks like a dashboard, login, or documentation page, not an API endpoint.");
  }
  if (/^https?:\/\/[^/]+$/i.test(urlText)) {
    warnings.push("base_url has no path. Some OpenAI-compatible providers require /v1; verify provider docs.");
  }

  return { baseUrl: urlText, warnings };
}

function getApiKey(envKey) {
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(envKey)) {
    return {
      value: "",
      status: "invalid_env_key_name",
      source: `env:${envKey}`,
      warning: "env_key should be an environment variable name, not a raw key or expression.",
    };
  }

  const value = process.env[envKey] || "";
  return {
    value,
    status: value ? "set_redacted" : "not_set",
    source: `env:${envKey}`,
    redacted: value ? redactSecret(value) : "",
  };
}

function routeUrl(baseUrl, route) {
  if (route === "models") return `${baseUrl}/models`;
  if (route === "chat") return `${baseUrl}/chat/completions`;
  if (route === "responses") return `${baseUrl}/responses`;
  throw new Error(`Unknown route: ${route}`);
}

async function requestJson({ url, method, apiKey, body, timeoutMs }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      method,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: controller.signal,
    });

    const text = await response.text();
    let data = null;
    let parseError = null;
    if (text) {
      try {
        data = JSON.parse(text);
      } catch (error) {
        parseError = error.message;
      }
    }

    return {
      ok: response.ok,
      status: response.status,
      statusText: response.statusText,
      data,
      parseError,
      bodyPreview: parseError ? text.slice(0, 160) : undefined,
    };
  } catch (error) {
    return {
      ok: false,
      status: null,
      statusText: null,
      networkError: error.name === "AbortError" ? "timeout" : error.message,
    };
  } finally {
    clearTimeout(timeout);
  }
}

function classifyFailure(result, route) {
  if (result.ok) return null;
  if (result.networkError === "timeout") return "Request timed out. Check network, proxy, firewall, or provider availability.";
  if (result.networkError) return `Network error: ${result.networkError}`;
  if (result.parseError) return "Non-JSON response received. The URL may be a dashboard, login page, documentation page, or non-API endpoint.";

  if (result.status === 400) return "400 Bad Request. Request shape may be unsupported by this provider.";
  if (result.status === 401) return "401 Unauthorized. API key may be missing, wrong, expired, or from a different provider.";
  if (result.status === 403) return "403 Forbidden. Account, model, billing, quota, or provider permission may block access.";
  if (result.status === 404 && route === "models") return "404 Not Found on /models. base_url may be wrong, missing /v1, duplicated /v1, or the route is unsupported.";
  if (result.status === 404) return "404 Not Found. The route may be unsupported or the model name may not exist for this provider.";
  if (result.status === 429) return "429 Too Many Requests. Rate limit, quota exhaustion, or relay overload is likely.";
  if (result.status >= 500) return "5xx server error. Provider or proxy service may be unavailable or overloaded.";
  return `${result.status} ${result.statusText || ""}`.trim();
}

function modelListed(data, model) {
  if (!model || !data || !Array.isArray(data.data)) return "unknown";
  return data.data.some((item) => item && item.id === model) ? "yes" : "no";
}

async function testModelsRoute({ baseUrl, apiKey, model, timeoutMs }) {
  const result = await requestJson({
    url: routeUrl(baseUrl, "models"),
    method: "GET",
    apiKey,
    timeoutMs,
  });

  return {
    tested: true,
    ok: result.ok,
    status: result.status,
    status_text: result.statusText,
    compatible: result.ok && result.data ? "likely" : "unknown",
    model_listed: result.ok ? modelListed(result.data, model) : "unknown",
    failure: classifyFailure(result, "models"),
    non_json_preview: result.bodyPreview,
  };
}

async function testChatRoute({ baseUrl, apiKey, model, timeoutMs }) {
  const result = await requestJson({
    url: routeUrl(baseUrl, "chat"),
    method: "POST",
    apiKey,
    timeoutMs,
    body: {
      model,
      messages: [{ role: "user", content: "ping" }],
      max_tokens: 1,
    },
  });

  const completionReceived = Boolean(result.data && Array.isArray(result.data.choices));
  return {
    tested: true,
    ok: result.ok,
    status: result.status,
    status_text: result.statusText,
    compatible: result.ok && completionReceived ? "yes" : "unknown",
    completion_received: completionReceived,
    failure: classifyFailure(result, "chat"),
    non_json_preview: result.bodyPreview,
  };
}

async function testResponsesRoute({ baseUrl, apiKey, model, timeoutMs }) {
  const result = await requestJson({
    url: routeUrl(baseUrl, "responses"),
    method: "POST",
    apiKey,
    timeoutMs,
    body: {
      model,
      input: "ping",
      max_output_tokens: 1,
    },
  });

  const responseReceived = Boolean(result.data && (result.data.id || result.data.output));
  return {
    tested: true,
    ok: result.ok,
    status: result.status,
    status_text: result.statusText,
    compatible: result.ok && responseReceived ? "yes" : "unknown",
    response_received: responseReceived,
    failure: classifyFailure(result, "responses"),
    non_json_preview: result.bodyPreview,
  };
}

function firstFailure(routes) {
  for (const name of ["models", "chat", "responses"]) {
    if (routes[name] && routes[name].tested && !routes[name].ok) {
      return routes[name].failure;
    }
  }
  return null;
}

function nextStep(report) {
  if (report.api_key_status !== "set_redacted") {
    return "Set the environment variable named by env_key, then run the test again.";
  }
  const failure = report.likely_problem;
  if (!failure) return "Use the same base_url, model, and env_key in Codex config.toml.";
  if (/401/.test(failure)) return "Check whether the API key belongs to this provider and is visible in the current shell session.";
  if (/404/.test(failure)) return "Verify base_url path, /v1 requirement, route support, and provider model name.";
  if (/429/.test(failure)) return "Check quota, billing, rate limits, or relay status before retrying.";
  return "Compare the error with provider docs and Codex config fields before changing config.";
}

function printTextReport(report) {
  console.log("OpenAI-Compatible Endpoint Test");
  console.log("");
  console.log(`Base URL: ${report.base_url}`);
  console.log(`Model: ${report.model || "(not set)"}`);
  console.log(`API key: ${report.api_key_status} via ${report.api_key_source}`);

  if (report.warnings.length) {
    console.log("");
    console.log("Warnings:");
    for (const warning of report.warnings) console.log(`- ${warning}`);
  }

  for (const [name, route] of Object.entries(report.routes)) {
    if (!route.tested) continue;
    console.log("");
    console.log(`${name} route:`);
    console.log(`Status: ${route.status || "network_error"} ${route.status_text || ""}`.trim());
    console.log(`OK: ${route.ok ? "yes" : "no"}`);
    console.log(`Compatible: ${route.compatible}`);
    if (route.model_listed) console.log(`Model listed: ${route.model_listed}`);
    if (typeof route.completion_received === "boolean") console.log(`Completion received: ${route.completion_received ? "yes" : "no"}`);
    if (typeof route.response_received === "boolean") console.log(`Response received: ${route.response_received ? "yes" : "no"}`);
    if (route.failure) console.log(`Failure: ${route.failure}`);
  }

  console.log("");
  console.log(`Likely Problem: ${report.likely_problem || "None detected by this minimal test."}`);
  console.log(`Next Step: ${report.next_step}`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(usage());
    return;
  }

  const { baseUrl, warnings } = normalizeBaseUrl(args.baseUrl);
  const keyInfo = getApiKey(args.envKey);
  if (keyInfo.warning) warnings.push(keyInfo.warning);

  const routes = {
    models: { tested: false },
    chat: { tested: false },
    responses: { tested: false },
  };

  if (keyInfo.status === "set_redacted") {
    if (args.route === "auto" || args.route === "models") {
      routes.models = await testModelsRoute({ baseUrl, apiKey: keyInfo.value, model: args.model, timeoutMs: args.timeoutMs });
    }
    if ((args.route === "auto" && !args.noChat) || args.route === "chat") {
      routes.chat = await testChatRoute({ baseUrl, apiKey: keyInfo.value, model: args.model, timeoutMs: args.timeoutMs });
    }
    if (args.route === "responses") {
      routes.responses = await testResponsesRoute({ baseUrl, apiKey: keyInfo.value, model: args.model, timeoutMs: args.timeoutMs });
    }
  }

  const report = {
    base_url: baseUrl,
    model: args.model || null,
    route: args.route,
    api_key_source: keyInfo.source,
    api_key_status: keyInfo.status,
    routes,
    warnings,
    likely_problem: keyInfo.status === "set_redacted" ? firstFailure(routes) : "API key environment variable is not set or env_key is invalid.",
  };
  report.next_step = nextStep(report);

  if (args.json) console.log(JSON.stringify(report, null, 2));
  else printTextReport(report);

  const hasFailedRoute = Object.values(routes).some((route) => route.tested && !route.ok);
  if (keyInfo.status !== "set_redacted" || hasFailedRoute) process.exitCode = 2;
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
