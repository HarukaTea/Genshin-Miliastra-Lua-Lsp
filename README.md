# 千星奇域 LSP

为《千星奇域》脚本开发提供智能提示的 Lua / Luau 语言服务器（Visual Studio Code 扩展）

## 简介

**千星奇域 LSP**（扩展 ID：`miliastraLsp`）是一个基于 Lua 语言服务器实现的 VS Code 扩展，为《千星奇域》脚本开发提供完整的语言智能功能。扩展由 TypeScript 编写的客户端与 Lua 编写的语言服务器两部分组成：

- **客户端**（`client/`）：注册语言 ID `lua`（支持 `.lua` 与 `.luau` 扩展名）、提供语法高亮，并按工作区拉起语言服务器进程。
- **服务端**（`server/`）：语言服务器本体，负责解析、类型推导、补全、诊断等全部语言能力，并内置了《千星奇域》的 API 定义。

本项目的 API 层基于 [RobloxLsp](https://github.com/NightrainsRbx/RobloxLsp) 改造，将原 Roblox 的运行时环境替换为《千星奇域》的脚本环境；底层语言服务器源自 [sumneko/lua-language-server](https://github.com/sumneko/lua-language-server)。

![预览](docs/Snipaste_2026-09-23_21-31-32.png)

## 功能特性

| 功能 | 说明 |
| --- | --- |
| 智能补全 | 全局变量、库函数、字段、方法与关键词语法片段补全 |
| 悬停提示 | 显示类型、参数说明、字段预览与枚举列表 |
| 签名帮助 | 参数列表与文档提示 |
| 跳转与查找 | 转到定义、转到类型定义、查找引用、工作区符号 |
| 重命名 | 基于语义分析的符号重命名 |
| 语义着色 | 语义高亮（可切换为语法着色） |
| 内联提示 | 参数名、参数类型、变量类型、赋值类型、返回类型提示 |
| 诊断检查 | 语法错误检查 + 30 余项代码诊断规则，支持自定义严重级别 |
| 代码操作 | 快速修复建议 |
| 其他 | 文档符号、代码折叠、颜色选择器、模块跳转链接 |

### 诊断规则

服务端内置的诊断规则（可在 `miliastraLsp.diagnostics.neededFileStatus` 与 `miliastraLsp.diagnostics.severity` 中逐项配置），按用途大致分为：

- **文档注释相关**：`undefined-doc-class`、`undefined-doc-name`、`undefined-doc-param`、`undefined-doc-module`、`doc-field-no-class`、`circle-doc-class`、`duplicate-doc-class`、`duplicate-doc-field`、`duplicate-doc-param`
- **类型与赋值相关**：`undefined-type`、`redefined-type`、`no-implicit-any`、`unbalanced-assignments`、`redundant-value`、`duplicate-index`、`duplicate-set-field`
- **作用域与引用相关**：`undefined-global`、`undefined-env-child`、`global-in-nil-env`、`redefined-local`、`unused-local`、`unused-function`、`unused-vararg`、`deprecated`
- **代码规范相关**：`empty-block`、`trailing-space`、`newfield-call`、`newline-call`、`redundant-parameter`、`unknown-diag-code`

### 千星奇域 API 支持

`server/script/library/` 下的 `miliastra.lua` 与 `api.lua` 提供《千星奇域》运行时的类型定义，包含：

- **全局对象**：`script`（当前脚本实例）、`game`（客户端运行时全局表）、`Color`（颜色构造与转换）
- **类型**：`Script`、`Game`、`ColorValue`、`Tween`、`TweenSequence`、`ServerSignal`、`EnumItem` 等
- **控件类型**：`ClientUIBaseControl` 及其派生控件（`ClientUIImageControl`、`ClientUITextBoxControl`、`ClientUITextWindowControl`、`ClientUIPresetButtonControl`、`ClientUICursorEventAreaControl`、`ClientUIGridScrollerControl`、`ClientUIKeyHintControl`、`ClientUIAnimationControl`、`ClientUIFullscreenAnimationControl`、`ClientUIContainerControl`、`ClientUIReferenceControl`），子类会自动继承父类成员
- **枚举**：`EaseType`、`Device`、`StageMode`、`LanguageType`、`ParamType`、`CustomVariableEntityType` 等

`server/def/env.luau` 定义语言基础环境（`string`、`table`、`math`、`utf8`、`debug` 等标准库），`server/def/meta.luau` 定义元表信息。

## 安装

### 从 VSIX 安装

仓库根目录提供了打包好的扩展包：

1. 在 VS Code 中打开扩展面板，点击右上角 `...` → **从 VSIX 安装...**
2. 选择 `miliastraLsp-0.0.1.vsix`

也可以使用命令行安装：

```bash
code --install-extension miliastraLsp-0.0.1.vsix
```

### 环境要求

- VS Code `^1.60.0`
- 需与扩展冲突的插件 **Lua（`sumneko.lua`）** 处于禁用状态，二者同时启用会弹出冲突提示

## 配置

所有配置项均以 `miliastraLsp.` 为前缀，可在 `settings.json` 中设置：

```json
{
    "miliastraLsp.color.mode": "Semantic",
    "miliastraLsp.completion.enable": true,
    "miliastraLsp.diagnostics.enable": true,
    "miliastraLsp.hint.enable": true,
    "miliastraLsp.runtime.path": [
        "?.lua",
        "?/init.lua",
        "?/?.lua",
        "?.luau",
        "?/init.luau",
        "?/?.luau"
    ]
}
```

主要配置分组：

| 配置项 | 默认值 | 说明 |
| --- | --- | --- |
| `miliastraLsp.color.mode` | `Semantic` | 颜色模式：`Grammar`（语法）/ `Semantic`（语义） |
| `miliastraLsp.completion.*` | — | 补全开关、函数括号补全、参数显示、关键字片段、`end` 自动补全、工作区单词等 |
| `miliastraLsp.diagnostics.enable` | `true` | 启用诊断与语法错误检查 |
| `miliastraLsp.diagnostics.disable` | — | 按诊断代码禁用指定诊断 |
| `miliastraLsp.diagnostics.globals` | — | 声明额外的全局变量，避免 `undefined-global` 误报 |
| `miliastraLsp.diagnostics.neededFileStatus` | — | 每条诊断的检查范围：`Any` / `Opened` / `None` |
| `miliastraLsp.diagnostics.severity` | — | 每条诊断的严重级别：`Error` / `Warning` / `Information` / `Hint` |
| `miliastraLsp.hint.*` | — | 内联提示：参数名、参数类型、变量类型、赋值类型、返回类型 |
| `miliastraLsp.hover.*` | — | 悬停显示：字段数量上限、字符串/数字内容、枚举数量上限 |
| `miliastraLsp.typeChecking.mode` | `Disabled` | 类型检查模式：`Disabled` / `Non Strict` / `Strict` |
| `miliastraLsp.workspace.library` | — | 额外加载的外部函数库目录 |
| `miliastraLsp.workspace.ignoreDir` | `.vscode`、`**/_Index/**` | 忽略的文件与目录（`.gitignore` 语法） |
| `miliastraLsp.runtime.path` | 见上 | `package.path` 搜索模板 |
| `miliastraLsp.runtime.plugin` | `.vscode/lua/plugin.lua` | 插件定义路径 |
| `miliastraLsp.runtime.fileEncoding` | `utf8` | 文件编码（`ansi` 仅 Windows 可用） |
| `miliastraLsp.develop.enable` | `false` | 启用开发模式（调试语言服务器） |

## 项目结构

```
MLSP/
├── client/                  # VS Code 扩展客户端（TypeScript）
│   ├── src/
│   │   ├── extension.ts     # 扩展入口，检测 sumneko.lua 冲突
│   │   └── languageserver.ts# 语言客户端启动、状态栏、内联提示渲染
│   └── out/                 # 编译产物（扩展 main 入口）
├── server/                  # 语言服务器（Lua）
│   ├── main.lua             # 服务端入口
│   ├── platform.lua         # 平台与 package.path 初始化
│   ├── def/
│   │   ├── env.luau         # 语言基础环境定义
│   │   └── meta.luau        # 元表定义
│   ├── locale/              # 多语言文案
│   ├── script/
│   │   ├── core/            # 补全、诊断、悬停、语义着色等核心能力
│   │   ├── library/         # 千星奇域 API 定义（api.lua / miliastra.lua）
│   │   ├── parser/          # Lua / Luau 词法、语法与文档注释解析
│   │   ├── provider/        # LSP 协议层（能力注册、请求分发）
│   │   ├── service/         # 服务主循环
│   │   ├── vm/              # 类型推导与语义分析
│   │   └── workspace/       # 工作区文件与模块解析
│   └── bin/                 # 各平台可执行文件（未随仓库提供）
├── syntaxes/                # TextMate 语法高亮
├── images/                  # 图标资源
├── docs/                    # 截图与 API 文档
└── package.json             # 扩展清单与配置项声明
```

## 开发与构建

### 客户端

客户端为 TypeScript 项目，依赖 `vscode-languageclient`：

```bash
cd client
npm install
npm run compile   # 编译一次
npm run watch     # 监听模式
```

编译产物输出到 `client/out/`，对应 `package.json` 中的 `main: ./client/out/extension`。

### 服务端

服务端为纯 Lua 实现，直接修改 `server/script/` 下的脚本后重启扩展即可生效。运行时通过 `package.json` 指向的可执行文件启动：

```
server/bin/{Windows,Linux,macOS}/lua-language-server -E server/main.lua
```

> `server/bin` 目录已被 `.gitignore` 忽略，仓库中不包含平台二进制，需要自行准备与平台匹配的 `lua-language-server` 可执行文件。

### 调试语言服务器

1. 开启开发模式并确认调试端口：

```json
{
    "miliastraLsp.develop.enable": true,
    "miliastraLsp.develop.debuggerPort": 11413,
    "miliastraLsp.develop.debuggerWait": false
}
```

2. 使用 [server/.vscode/launch.json](server/.vscode/launch.json) 中的 `附加` 配置连接调试器（默认地址 `127.0.0.1:11413`，需与 `debuggerPort` 保持一致）。

### 打包扩展

```bash
npx vsce package
```

## 相关文档

- [千星奇域 API 文档（本地生成版）](千星奇域API文档%5BDS生成%5D.html)

## 致谢

- [RobloxLsp](https://github.com/NightrainsRbx/RobloxLsp)：本项目的直接来源
- [sumneko/lua-language-server](https://github.com/sumneko/lua-language-server)：底层 Lua 语言服务器
