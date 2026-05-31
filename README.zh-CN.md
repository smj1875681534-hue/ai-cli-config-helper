# AI CLI Config Helper

一个用于诊断 AI 编程命令行工具配置问题的 Codex Skill，同时也可以作为独立的本地配置诊断脚本工具包使用。

它重点面向 Codex `config.toml`、OpenAI-compatible API、中转/代理服务、`base_url`、`model`、`model_provider`、`env_key`、API key 脱敏、配置备份与恢复等真实排障场景。

## 项目背景

很多人在配置 Codex、OpenAI-compatible API 或第三方中转服务时，经常会遇到这些问题：

- 不知道 `base_url` 是否应该带 `/v1`。
- 把后台网页地址当成 API 地址。
- `model_provider` 指向了不存在的 provider。
- `env_key` 写成了真实 API key。
- 电脑里没有设置对应的环境变量。
- 使用了错误的模型名或中转服务模型别名。
- 遇到 `401`、`403`、`404`、`model not found`、`timeout` 等错误时不知道从哪里排查。

这个项目的目标是把这些配置问题变成一套可检查、可解释、可验证、可回滚的诊断流程。

通俗说：它像一个“AI CLI 配置医生”，先做体检，再指出可能问题，最后给出安全修复建议。

## 什么时候用 skill，什么时候用 scripts

这个项目有两种用法：

- 如果 Codex 完全打不开，或者无法加载 skill，先直接运行 `scripts/` 里的 PowerShell 脚本。
- 如果 Codex 能打开，但正在排查中转 API、模型、`base_url`、`env_key`、profile 或 provider 相关问题，再使用 `$ai-cli-config-helper` 做更方便的诊断。
- 如果 Codex 已经正常工作，也不准备换模型、中转、profile 或 endpoint，就不需要使用这个 skill。

通俗说：

```text
Codex 完全打不开：先用 scripts，本地检查 config.toml。
Codex 能打开但配置相关功能出问题：用 skill，让 Codex 帮你解释和排查。
Codex 正常工作：不用特意运行这个 skill。
```

所以它不是只能在 Codex 里面用。对于小白来说，最开始可以先把它当成一个本地配置检查工具包。

小白使用流程：

```text
1. 下载或 clone 这个仓库。
2. 打开 PowerShell，进入 ai-cli-config-helper 文件夹。
3. 运行 inspect_codex_config.ps1 检查自己的 config.toml。
4. 根据报告修复 base_url、model_provider、env_key、环境变量等问题。
5. Codex 能启动后，如果还有中转 API、模型、profile 或 endpoint 问题，再使用 $ai-cli-config-helper 做更方便的诊断。
```

最小本地检查命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\inspect_codex_config.ps1 -Path "$env:USERPROFILE\.codex\config.toml" -CheckEnv
```

## 核心功能

- 检查 Codex `config.toml` 是否存在、是否能被基本解析。
- 汇总当前 `model`、`model_provider`、provider 表、`base_url` 和 `env_key`。
- 检查 `base_url` 是否缺少 `/v1`、重复 `/v1/v1`、不是 HTTP URL，或像 dashboard/login/docs 页面。
- 检查 `model_provider` 是否指向不存在的 provider。
- 检查 `env_key` 是否疑似写成了真实 API key。
- 检查环境变量是否在当前会话、User scope 或 Machine scope 中可见。
- 对 API key、token、password 等敏感信息进行脱敏。
- 修改配置前创建带时间戳的备份。
- 支持从备份恢复配置，并默认只预览、不直接覆盖。
- 支持在用户明确同意后，对 OpenAI-compatible endpoint 做最小网络验证。
- 提供 smoke test 和 release validation，保证 skill 本身可维护、可验证。

## 项目结构

```text
ai-cli-config-helper/
  SKILL.md
  README.md
  README.zh-CN.md
  LICENSE
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
      *.toml
```

## 每个部分是干什么的

### `SKILL.md`

Codex Skill 的入口文件。

它定义这个 skill 什么时候会被触发、应该做什么、不应该做什么、要遵守哪些安全规则，以及最终回答应该长什么样。

通俗说：这是这个 skill 的“总说明书”和“行为规则”。

### `references/`

放详细知识库。

里面包括 AI CLI 基础概念、Codex 配置说明、常见错误解释、Windows 路径问题、验证清单等。

通俗说：这是 skill 的“专业知识手册”。`SKILL.md` 保持简洁，细节放到这里。

### `scripts/`

放可以真实运行的工具脚本。

例如检查配置、脱敏密钥、备份配置、恢复配置、测试 endpoint、运行回归测试、做发布前检查。

通俗说：这是 skill 的“工具箱”。它不是只靠文字建议，而是能跑脚本做检查。

### `tests/fixtures/`

放测试用的配置样例。

这些样例模拟了真实用户容易写错的配置，例如缺少 `/v1`、重复 `/v1/v1`、profile 不存在、环境变量没设置、dashboard URL、智能引号、`config.toml.txt` 等。

通俗说：这是 skill 的“病例库”。每个错误配置都是一个病例，用来测试医生能不能看出来。

### `tests/forward-testing.md`

记录接近真实用户提问的测试场景。

通俗说：这是“模拟真实用户来问问题”的测试记录。

### `examples/`

放实际诊断输出示例。

别人不用先运行脚本，也能直接看到这个工具检查配置后会输出什么。

通俗说：这是项目的“结果展示区”。

## 关键脚本

### `inspect_codex_config.ps1`

只读检查 Codex 配置，不修改文件。

它会输出：

- 配置文件路径。
- 是否找到配置文件。
- 当前 `model`。
- 当前 `model_provider`。
- 找到的 provider ID。
- 选中的 provider。
- `base_url`。
- `env_key`。
- 环境变量是否可见。
- 是否检测到疑似原始密钥。
- 配置 warning。

通俗说：这是“体检报告生成器”。

### `redact_secret.ps1`

对文本或文件里的 API key、token、password 等敏感信息做脱敏。

通俗说：这是“打码工具”，防止把密钥完整打印出来。

### `backup_codex_config.ps1`

修改配置前创建备份。

通俗说：这是“存档工具”，改坏了还能回退。

### `restore_codex_config.ps1`

从备份恢复配置。

默认只预览，不会直接覆盖；必须加 `-ConfirmRestore` 才会真正恢复。

通俗说：这是“回滚工具”，但默认不会乱动文件。

### `test_openai_endpoint.js`

测试 OpenAI-compatible endpoint。

它可以检查 `/models`、`/chat/completions`、`/responses`，但必须在用户明确同意后运行，因为它会访问网络，chat/responses 测试可能消耗极少 API 额度。

通俗说：这是“最小联网验证工具”。

### `smoke_test.ps1`

本地回归测试。

它会跑一批测试样例，确认 inspect、redact、backup、restore、endpoint no-key safety 等功能没有坏。

当前结果：

```text
Status: passed
Assertions: 58
```

通俗说：这是“每次改完代码后跑一遍的自检”。

### `validate_skill.ps1`

发布前检查脚本。

它会检查：

- 必需文件是否存在。
- `SKILL.md` frontmatter 是否正确。
- README 是否有乱码。
- references 是否包含关键内容。
- scripts 是否包含关键参数和安全语义。
- fixtures 是否齐全。
- smoke test 是否通过。

当前结果：

```text
Status: passed
Failures: 0
Warnings: 0
Passed: 114
```

通俗说：这是“发布前门禁”。它通过了，说明项目结构比较完整。

## 覆盖的典型错误场景

这个项目已经用 fixture 覆盖了多种真实配置错误：

- 正常配置。
- `base_url` 缺少 `/v1`。
- `base_url` 重复 `/v1/v1`。
- `base_url` 写成 dashboard 页面。
- `base_url` 没有 `http://` 或 `https://`。
- `model_provider` 指向不存在的 provider。
- profile 不存在。
- profile 覆盖 provider。
- `env_key` 写成真实 API key。
- 环境变量没有设置。
- 顶层直接写了 `api_key`。
- TOML 使用智能引号或乱码引号。
- 项目级 `.codex/config.toml` 覆盖配置。
- 官方 OpenAI URL 搭配疑似中转 key。
- 中转 URL 搭配 `OPENAI_API_KEY`。
- 中转 provider 使用官方风格模型名，需要确认 relay 模型别名。
- Windows 下 `config.toml.txt` 扩展名陷阱。

## 快速开始

进入项目目录：

```powershell
cd ai-cli-config-helper
```

运行发布前检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_skill.ps1
```

运行本地回归测试：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke_test.ps1
```

检查某个 Codex 配置文件：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\inspect_codex_config.ps1 -Path "C:\Users\me\.codex\config.toml" -CheckEnv
```

输出 JSON：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\inspect_codex_config.ps1 -Path "C:\Users\me\.codex\config.toml" -CheckEnv -Json
```

## 示例输出

示例诊断结果放在 `examples/` 目录：

- `examples/inspect-valid-output.json`：正常配置，没有 warning。
- `examples/inspect-dashboard-url-output.json`：`base_url` 写成类似后台页面地址时的诊断结果。
- `examples/inspect-secret-redaction-output.json`：检测到疑似密钥并脱敏后的输出结果。

## 安全设计

这个项目非常重视密钥安全：

- 不打印完整 API key。
- 不打印完整 bearer token。
- 不打印 password、cookie、session token。
- 部分测试样例中故意包含 `sk-test...` 形式的假密钥，仅用于验证脱敏逻辑，不是真实 API key。
- 检测到疑似密钥时只输出脱敏结果。
- 建议使用环境变量保存真实 key。
- 修改配置前先备份。
- 恢复配置默认只预览，不直接覆盖。
- 网络测试必须得到用户明确同意。

通俗说：它不会为了排查问题，把用户的密钥暴露出来。

## 项目亮点

这个项目不只是一个提示词模板，而是一个带工程化结构的 Codex Skill：

- 有清晰的 skill 入口文件。
- 有分层 references 知识库。
- 有可运行的 PowerShell 和 Node.js 工具脚本。
- 有密钥脱敏、安全备份、恢复预览等安全设计。
- 有覆盖真实错误场景的 fixture 病例库。
- 有 58 条 smoke test 断言。
- 有 release validation，当前 114 项检查全部通过。
- 适合展示 AI 工具配置、自动化诊断、测试工程和安全意识。

## 简历描述参考

英文版：

```text
Built an open-source Codex skill for diagnosing AI CLI configuration issues, including safe config inspection, secret redaction, backup/restore workflows, endpoint validation, and a PowerShell-based regression test suite covering 58 assertions across realistic configuration fixtures.
```

中文版：

```text
开发 AI CLI 配置诊断 Codex Skill，支持 Codex config.toml 检查、密钥脱敏、配置备份与恢复、OpenAI-compatible endpoint 验证，并构建包含 58 条断言的本地回归测试体系，覆盖多类真实配置错误场景。
```

## License

MIT License. See [LICENSE](./LICENSE).
