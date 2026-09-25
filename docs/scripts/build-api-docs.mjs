/**
 * 由提取出的 API 数据生成 VitePress 的 Markdown 页面与侧边栏数据。
 *
 * 运行：node scripts/build-api-docs.mjs   （或在 docs/ 下执行 npm run gen）
 *
 * 产物：
 *   api/index.md           概述 + 快速示例
 *   api/globals.md         全局对象（script / game / Color）
 *   api/types.md           全部类型（含属性 / 方法）
 *   api/enums/index.md     枚举总览
 *   api/enums/<Name>.md    每个枚举一页
 *   .vitepress/sidebar.json 侧边栏数据（供 config.mts 读取）
 */
import { writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { extractApiData, buildSignature } from './extract-api.mjs'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..')
const OUT = resolve(ROOT, 'api')
const VP = resolve(ROOT, '.vitepress')

const data = extractApiData(resolve(ROOT, 'api-reference.html'))
const { GLOBALS, CLASSES, ENUMS, INHERIT } = data

/* ---------- 小工具 ---------- */

/** Markdown 表格单元格转义：竖线与换行都要处理 */
const cell = s => String(s ?? '').replace(/\|/g, '\\|').replace(/\n+/g, ' ').trim()

/** 行内代码：内容含反引号时退化为双反引号包裹 */
const code = s => {
  const t = String(s ?? '')
  if (!t) return ''
  return t.includes('`') ? '`` ' + t + ' ``' : '`' + t + '`'
}

const write = (rel, content) => {
  const p = resolve(OUT, rel)
  mkdirSync(dirname(p), { recursive: true })
  const banner =
    '<!-- 本文件由 docs/scripts/build-api-docs.mjs 自动生成，请勿手动修改。 -->\n' +
    '<!-- 重新生成：cd docs && npm run gen -->\n\n'
  writeFileSync(p, (banner + content).replace(/\r\n/g, '\n'), 'utf8')
  return rel
}

/**
 * 为类名 / 枚举名生成稳定锚点。
 * 类名是 PascalCase 且无重名，直接用原名即可，与旧页面的 #type-<id> 锚点也不冲突。
 */
const classAnchor = name => name

/* ---------- api/index.md ---------- */

const totalProps = CLASSES.reduce((n, c) => n + (c.props || []).length, 0)
const totalMethods = CLASSES.reduce((n, c) => n + (c.methods || []).length, 0)
const totalEnumValues = ENUMS.reduce((n, e) => n + (e.values || []).length, 0)

const indexMd = `# 千星奇域 Lua API

适用于千星奇域的客户端脚本 API 文档。

::: warning 运行时环境
运行时为 **Lua 5.3**。以下标准库**不可用**：\`io.*\`、\`string.dump\`、部分 \`os.*\`、\`debug.*\`。
:::

## 快速示例

\`\`\`lua
-- 获取控件并注册光标点击事件
local btn = game.FindClientUIRoot("Main"):GetChild("BtnStart")
btn:AddCursorEventListener(Enum.CursorEventType.CursorClick, function(data)
    print("clicked", data:GetUIPos())
end)

-- 创建补间动画（链式调用）
local tween = game.Tween(btn, { anchoredPositionY = 100 }, 0.5)
    :SetEase(Enum.EaseType.OutCubic)
    :SetLoops(-1)
    :Play()

-- 编排并发送服务器信号
local sig = game.ServerSignal("BuyItem")
sig:AddInt(100)
sig:AddString("gold")
sig:SendSignal()
\`\`\`

## 内容概览

| 分类 | 数量 | 入口 |
| --- | --- | --- |
| 全局对象 | ${GLOBALS.length} | [全局对象](/api/globals) |
| 类型 | ${CLASSES.length} | [类型](/api/types) |
| 枚举 | ${ENUMS.length} | [枚举](/api/enums/) |
| 属性 / 方法 | ${totalProps} / ${totalMethods} | — |
| 枚举值 | ${totalEnumValues} | — |

## 全部类型

${
  CLASSES.map(c => {
    const n = (c.props || []).length
    const m = (c.methods || []).length
    const inh = c.inherits ? `，继承自 ${code(c.inherits)}` : ''
    return `- [**${c.name}**](/api/types#${classAnchor(c.name)}) — ${cell(c.desc)}（属性 ${n} / 方法 ${m}${inh}）`
  }).join('\n')
}

## 全部枚举

枚举统一通过 \`Enum.类型名.值\` 访问。

${
  ENUMS.map(e => `- [**${e.name}**](/api/enums/${e.name}) — ${cell(e.desc)}（${(e.values || []).length} 个值）`).join('\n')
}

## 继承关系

所有客户端控件均继承自 ${code('ClientUIBaseControl')}，基类成员在子类页面中不重复列出。

| 子类 | 继承自 |
| --- | --- |
${INHERIT.map(([child, parent]) => `| ${code(child)} | ${code(parent)} |`).join('\n')}

## 历史版本

改造之前的单文件静态页面保留为归档：[api-reference.html](/api-reference.html)。
`

/* ---------- api/globals.md ---------- */

let globalsMd = `# 全局对象

脚本中可直接访问的全局变量。

`
for (const g of GLOBALS) {
  globalsMd += `## ${g.name}\n\n`
  globalsMd += `${cell(g.desc)}\n\n`
  globalsMd += `**类型**：${code(g.type)}\n\n`
  if (g.extra && g.extra.length) {
    globalsMd += `| 签名 | 说明 |\n| --- | --- |\n`
    for (const e of g.extra) globalsMd += `| ${code(e.sig)} | ${cell(e.d)} |\n`
    globalsMd += `\n`
  }
}

/* ---------- api/types.md ---------- */

let typesMd = `# 类型

客户端脚本可使用的对象类型、属性与方法。

::: tip 成员继承
带 \`继承自\` 标记的类型只列出自身新增的成员，未重复列出基类成员。公共基类为 ${code('ClientUIBaseControl')}。
:::

## 目录

${
  CLASSES.map(c => {
    const inh = c.inherits ? ` _（继承自 ${c.inherits}）_` : ''
    return `- [${c.name}](#${classAnchor(c.name)})${inh}`
  }).join('\n')
}

`
for (const c of CLASSES) {
  typesMd += `## ${c.name}\n\n`
  if (c.inherits) {
    typesMd += `::: info 继承\n继承自 ${code(c.inherits)}，其成员（属性 / 方法）不在此重复。\n:::\n\n`
  }
  typesMd += `${cell(c.desc)}\n\n`
  if (c.recv) typesMd += `**接收者**：${code(c.recv)}（实例方法使用 \`:\` 调用）\n\n`

  const props = c.props || []
  if (props.length) {
    // 小节标题带上类名：否则 19 个类会产生 19 个同名锚点 #属性 / #方法，互相冲突
    typesMd += `### ${c.name} 属性\n\n| 属性 | 类型 | 说明 |\n| --- | --- | --- |\n`
    for (const p of props) {
      const ro = p.ro ? ' :lock: 只读' : ''
      typesMd += `| ${code(p.n)}${ro} | ${code(p.t)} | ${cell(p.d)} |\n`
    }
    typesMd += `\n`
  }

  const methods = c.methods || []
  if (methods.length) {
    typesMd += `### ${c.name} 方法\n\n`
    for (const m of methods) {
      // 用 h4 而非 h3：避免锚点冲突，同时也不让方法挤满右侧大纲
      typesMd += `#### ${code(buildSignature(m))}\n\n`
      const ret = m.r ? `**返回**：${code(m.r)}\n\n` : ''
      typesMd += `${cell(m.d)}\n\n${ret}`
      if ((m.args || []).length) {
        typesMd += `| 参数 | 类型 | 说明 |\n| --- | --- | --- |\n`
        for (const a of m.args) {
          const name = a.opt ? `[${a.n}]` : a.n
          typesMd += `| ${code(name)} | ${code(a.t)} | ${cell(a.d)} |\n`
        }
        typesMd += `\n`
      }
    }
  }
}

/* ---------- api/enums/*.md ---------- */

let enumsIndexMd = `# 枚举

所有枚举均通过 \`Enum.类型名.值\` 访问。

| 枚举 | 说明 | 值数量 |
| --- | --- | --- |
${ENUMS.map(e => `| [${e.name}](/api/enums/${e.name}) | ${cell(e.desc)} | ${(e.values || []).length} |`).join('\n')}
`

const enumPages = []
const enumContents = []
for (const e of ENUMS) {
  const values = e.values || []
  let md = `# ${e.name}\n\n`
  md += `${cell(e.desc)}\n\n`
  md += `**访问方式**：\`Enum.${e.name}.<值>\`\n\n`
  md += `**值数量**：${values.length}\n\n`
  md += `| 值 |\n| --- |\n`
  for (const v of values) md += `| ${code(v)} |\n`
  enumPages.push(`enums/${e.name}.md`)
  enumContents.push([`enums/${e.name}.md`, md])
}

/* ---------- 写出（先清空，再统一写入，避免自删）---------- */

if (existsSync(OUT)) rmSync(OUT, { recursive: true, force: true })
mkdirSync(OUT, { recursive: true })

write('index.md', indexMd)
write('globals.md', globalsMd)
write('types.md', typesMd)
write('enums/index.md', enumsIndexMd)
for (const [rel, md] of enumContents) write(rel, md)

/* ---------- 侧边栏数据 ---------- */

const sidebar = [
  {
    text: '开始',
    items: [{ text: '概述', link: '/api/' }]
  },
  {
    text: 'API',
    items: [
      { text: '全局对象', link: '/api/globals' },
      { text: '类型', link: '/api/types' },
      { text: '枚举', link: '/api/enums/' }
    ]
  },
  {
    text: '类型索引',
    collapsed: true,
    items: CLASSES.map(c => ({ text: c.name, link: `/api/types#${classAnchor(c.name)}` }))
  },
  {
    text: '枚举索引',
    collapsed: true,
    items: ENUMS.map(e => ({ text: e.name, link: `/api/enums/${e.name}` }))
  }
]

mkdirSync(VP, { recursive: true })
writeFileSync(resolve(VP, 'sidebar.json'), JSON.stringify(sidebar, null, 2) + '\n', 'utf8')

/* ---------- 统计 ---------- */

const files = ['index.md', 'globals.md', 'types.md', 'enums/index.md', ...enumPages]
console.log('已生成 Markdown：')
console.log(`  api/index.md`)
console.log(`  api/globals.md        (${GLOBALS.length} 个全局对象)`)
console.log(`  api/types.md          (${CLASSES.length} 个类型 / ${totalProps} 属性 / ${totalMethods} 方法)`)
console.log(`  api/enums/index.md`)
console.log(`  api/enums/*.md        (${enumPages.length} 个枚举 / ${totalEnumValues} 个值)`)
console.log(`  .vitepress/sidebar.json`)
console.log(`合计 ${files.length + 1} 个文件`)