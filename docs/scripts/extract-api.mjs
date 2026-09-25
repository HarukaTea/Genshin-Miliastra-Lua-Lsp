/**
 * 从「千星奇域API文档[DS生成].html」中提取 API 数据。
 *
 * 原页面把全部 API 以 JS 字面量形式内联在 <script> 中，再客户端渲染成 HTML。
 * 这里逐个截取顶层 `const NAME = …;` 声明并在沙箱中求值，得到结构化数据，
 * 供 build-api-docs.mjs 生成 VitePress 的 Markdown 页面。
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..')

/** 需要提取的顶层常量（顺序即声明顺序，后者可引用前者） */
const WANTED = ['GLOBALS', 'CLASSES', 'KEY_NAMES', 'CONTROLLER_NAMES', 'KEY_EVENT_TYPES', 'ENUMS', 'INHERIT']

/** 工具函数：原页面里用于构造数据的小助手，需一并注入沙箱 */
const HELPERS = `
const a = (n,t,d,opt) => ({n, t, d: d||"", opt: !!opt});
const P = (n,t,d,ro) => ({n, t, d: d||"", ro: !!ro});
const R = s => ({r:s});
const M = (recv,n,args,ret,d,dot) => ({recv, n, args: args||[], r: ret||"", d: d||"", dot: !!dot});
`

/** 从 script 源码中取出 `const name = …;` 的右值源码（按括号配平，忽略字符串与注释） */
function takeInitializer(src, name) {
  const decl = new RegExp(`^const\\s+${name}\\s*=\\s*`, 'm').exec(src)
  if (!decl) return null
  let i = decl.index + decl[0].length
  let depth = 0
  let inStr = null
  let esc = false
  let inLine = false
  let inBlock = false
  for (; i < src.length; i++) {
    const ch = src[i]
    const next = src[i + 1]
    if (inLine) { if (ch === '\n') inLine = false; continue }
    if (inBlock) { if (ch === '*' && next === '/') { inBlock = false; i++ } continue }
    if (inStr) {
      if (esc) { esc = false; continue }
      if (ch === '\\') { esc = true; continue }
      if (ch === inStr) inStr = null
      continue
    }
    if (ch === '/' && next === '/') { inLine = true; i++; continue }
    if (ch === '/' && next === '*') { inBlock = true; i++; continue }
    if (ch === '"' || ch === "'" || ch === '`') { inStr = ch; continue }
    if (ch === '(' || ch === '[' || ch === '{') depth++
    else if (ch === ')' || ch === ']' || ch === '}') depth--
    else if (ch === ';' && depth === 0) return src.slice(decl.index + decl[0].length, i).trim()
  }
  return null
}

export function extractApiData(htmlPath) {
  const html = readFileSync(htmlPath, 'utf8')
  const open = html.indexOf('<script>')
  const close = html.lastIndexOf('</script>')
  if (open < 0 || close < 0) throw new Error('未找到 <script> 数据块：' + htmlPath)
  const script = html.slice(open + '<script>'.length, close)

  const parts = []
  const exported = []
  for (const name of WANTED) {
    const init = takeInitializer(script, name)
    if (!init) throw new Error(`数据常量缺失或无法解析：${name}`)
    parts.push(`const ${name} = ${init};`)
    exported.push(name)
  }

  // 在沙箱中求值：只跑数据声明，不触碰 DOM 渲染代码
  const factory = new Function(
    `"use strict";\n${HELPERS}\n${parts.join('\n')}\nreturn { ${exported.join(', ')} };`
  )
  return factory()
}

/** 把签名里的参数数组渲染成 `name: type` / `[name: type]` */
export function argList(args) {
  return (args || []).map(x => (x.opt ? `[${x.n}: ${x.t}]` : `${x.n}: ${x.t}`)).join(', ')
}

/** 生成完整签名；dot 表示用点号调用（game.Foo(...)），否则用冒号（obj:Foo(...)） */
export function buildSignature(m) {
  const pre = m.dot ? 'game.' : (m.recv ? m.recv + ':' : '')
  return `${pre}${m.n}(${argList(m.args)})`
}

/**
 * 生成与 VitePress 完全一致的标题锚点。
 *
 * VitePress 的 markdown-it-anchor 默认 slugify：
 *   1. 先把标题做 markdown 内联解析（行内 `code` 的反引号被去掉）
 *   2. 转为小写
 *   3. 去除非 [\w] 字符（\w = 字母数字下划线，**中文与标点都会被移除**）
 *   4. 连续空白转为单个连字符，并去掉首尾连字符
 * 注意：纯中文标题会得到空锚点，因此不要依赖中文标题做深链接。
 */
export function anchorOf(text) {
  return String(text)
    .trim()
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
}

/** 读取 API 数据：优先使用 JSON 快照，回退到原始 HTML */
export function loadApiData(root) {
  const jsonPath = resolve(root, 'scripts/api-data.json')
  if (existsSync(jsonPath)) {
    const d = JSON.parse(readFileSync(jsonPath, 'utf8'))
    delete d.$comment
    return d
  }
  return extractApiData(resolve(root, 'api-reference.html'))
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  // 自检模式：只提取并打印统计，不写任何文件
  const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
  const d = loadApiData(root)
  let props = 0
  let methods = 0
  for (const c of d.CLASSES) {
    props += (c.props || []).length
    methods += (c.methods || []).length
  }
  let enumVals = 0
  for (const e of d.ENUMS) enumVals += (e.values || []).length
  const src = existsSync(resolve(root, 'scripts/api-data.json')) ? 'scripts/api-data.json' : 'api-reference.html'
  console.log('数据源：' + src)
  console.log(`  GLOBALS  ${d.GLOBALS.length}`)
  console.log(`  CLASSES  ${d.CLASSES.length}  (属性 ${props} / 方法 ${methods})`)
  console.log(`  ENUMS    ${d.ENUMS.length}  (枚举值 ${enumVals})`)
  console.log(`  INHERIT  ${d.INHERIT.length}`)
  console.log(`  KEY_NAMES ${d.KEY_NAMES.length} / CONTROLLER_NAMES ${d.CONTROLLER_NAMES.length} / KEY_EVENT_TYPES ${d.KEY_EVENT_TYPES.length}`)
}
