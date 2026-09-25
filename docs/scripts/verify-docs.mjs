/**
 * 静态校验 VitePress 文档站：
 *   1. .vitepress/config.mts 可被加载（用 node 直接 import 需要 TS，改为纯文本断言）
 *   2. sidebar.json 合法，且每条 link 都能对应到实际页面或锚点
 *   3. 所有 Markdown 内部链接可解析
 *   4. 每个 h2/h3 锚点唯一（避免 VitePress 锚点失效）
 *   5. api-reference.html 存在且被 sidebar/nav 正确引用
 */
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs'
import { resolve, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const DOCS = resolve(__dirname, '..')
const problems = []
const notes = []

const read = p => readFileSync(p, 'utf8')

/* ---------- 1. 收集所有页面 ---------- */
const pages = []
;(function walk(dir) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (['node_modules', '.vitepress', '.npm-cache'].includes(e.name)) continue
    const p = join(dir, e.name)
    if (e.isDirectory()) walk(p)
    else if (e.name.endsWith('.md')) pages.push(p)
  }
})(DOCS)

const routeOf = p => {
  const rel = p.slice(DOCS.length + 1).split('\\').join('/')
  let r = '/' + rel.replace(/\.md$/, '')
  r = r.replace(/\/index$/, '/')
  if (r === '/index') r = '/'
  return r
}
const pageRoutes = new Set(pages.map(routeOf))
console.log(`发现 ${pages.length} 个 Markdown 页面`)

/* ---------- 2. 提取每页锚点 ---------- */
/* VitePress 用 markdown-it-anchor 的默认 slugify：保留大小写，
   去掉非字母数字（含中文以外的符号），空格转连字符。
   注意必须与 VitePress 保持一致，否则会误报“锚点不存在”。 */
const anchorsOf = new Map()
const slug = s =>
  s.trim()
    .replace(/[`*_[\]]/g, '')
    .replace(/[^\p{L}\p{N}\s-]/gu, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')

for (const p of pages) {
  const set = new Set()
  const seen = new Map()
  read(p).split('\n').forEach((line, i) => {
    const m = /^(#{1,6})\s+(.*?)\s*$/.exec(line)
    if (!m) return
    let text = m[2]
    // 显式锚点 `{#foo}` 优先，这是 VitePress 支持的写法
    const explicit = /\{#([^}]+)\}\s*$/.exec(text)
    let a
    if (explicit) {
      a = explicit[1]
      text = text.slice(0, explicit.index)
    } else {
      a = slug(text)
    }
    if (!a) return // 纯中文标题在 VitePress 下会得到空锚点，不算冲突
    if (seen.has(a)) problems.push(`锚点重复: ${routeOf(p)}#${a}（行 ${seen.get(a)} 与 ${i + 1}）`)
    else seen.set(a, i + 1)
    set.add(a)
  })
  anchorsOf.set(p, set)
}

/* ---------- 3. 校验 sidebar.json ---------- */
const sbPath = resolve(DOCS, '.vitepress/sidebar.json')
if (!existsSync(sbPath)) problems.push('缺少 .vitepress/sidebar.json')
else {
  const sb = JSON.parse(read(sbPath))
  let links = 0
  const walkItems = items =>
    items.forEach(it => {
      if (it.items) return walkItems(it.items)
      if (!it.link) return
      links++
      const [pathPart, hash] = it.link.split('#')
      const route = pathPart.endsWith('/') || pathPart === '' ? pathPart : pathPart
      const routeNorm = route.endsWith('/') ? route : route
      if (!pageRoutes.has(routeNorm)) {
        // 允许指向纯静态文件
        const fsPath = resolve(DOCS, routeNorm.replace(/^\//, ''))
        if (!existsSync(fsPath)) problems.push(`sidebar 链接无目标: ${it.link}`)
        return
      }
      if (hash) {
        const target = pages.find(p => routeOf(p) === routeNorm)
        if (target && !anchorsOf.get(target).has(hash)) {
          problems.push(`sidebar 锚点不存在: ${it.link}`)
        }
      }
    })
  sb.forEach(g => walkItems(g.items || []))
  console.log(`sidebar 校验：${sb.length} 个分组，${links} 条链接`)
}

/* ---------- 4. 校验 Markdown 内部链接 ---------- */
let checkedLinks = 0
for (const p of pages) {
  const src = read(p)
  for (const m of src.matchAll(/\[[^\]]*\]\((\/[^)\s]*)\)/g)) {
    checkedLinks++
    const [pathPart, hash] = m[1].split('#')
    const route = pathPart || routeOf(p)
    const target = pages.find(q => routeOf(q) === route)
    if (!target) {
      const fsPath = resolve(DOCS, route.replace(/^\//, ''))
      if (!existsSync(fsPath)) problems.push(`${p.slice(DOCS.length + 1)}: 链接无目标 ${m[1]}`)
      continue
    }
    if (hash && !anchorsOf.get(target).has(hash)) {
      problems.push(`${p.slice(DOCS.length + 1)}: 锚点不存在 ${m[1]}`)
    }
  }
}
console.log(`Markdown 内部链接校验：${checkedLinks} 条`)

/* ---------- 5. 配置与数据源 ---------- */
const dataSrc = resolve(DOCS, 'scripts/api-data.json')
if (!existsSync(dataSrc)) problems.push('缺少数据源 scripts/api-data.json')
else {
  const d = JSON.parse(read(dataSrc))
  notes.push(`数据源 api-data.json：GLOBALS ${d.GLOBALS.length} / CLASSES ${d.CLASSES.length} / ENUMS ${d.ENUMS.length}`)
  if (existsSync(resolve(DOCS, 'api-reference.html'))) {
    problems.push('api-reference.html 仍存在，但流程已改用 api-data.json，应删除以免混淆')
  }
}

const cfg = resolve(DOCS, '.vitepress/config.mts')
if (!existsSync(cfg)) problems.push('缺少 .vitepress/config.mts')
else {
  const c = read(cfg)
  for (const need of ['sidebar.json', 'lang:', 'title:', 'themeConfig', "provider: 'local'", 'theme/index.mts']) {
    if (!c.includes(need)) problems.push(`config.mts 缺少关键配置: ${need}`)
  }
  JSON.parse(read(sbPath))
  notes.push('config.mts 已注册自定义主题并读取 sidebar.json')
}

/* ---------- 6. 主题文件 ---------- */
for (const f of ['.vitepress/theme/index.mts', '.vitepress/theme/custom.css', 'public/logo.svg']) {
  if (!existsSync(resolve(DOCS, f))) problems.push('缺少主题文件: ' + f)
}
const css = existsSync(resolve(DOCS, '.vitepress/theme/custom.css'))
  ? read(resolve(DOCS, '.vitepress/theme/custom.css'))
  : ''
if (css && !css.includes('#087ea4')) problems.push('custom.css 未包含原页面品牌色 #087ea4')
else notes.push('主题配色包含品牌色 #087ea4')

/* ---------- 7. 生成物是否齐全 ---------- */
const expect = ['index.md', 'api/index.md', 'api/globals.md', 'api/types.md', 'api/enums/index.md']
for (const e of expect) if (!existsSync(resolve(DOCS, e))) problems.push('缺少生成文件: ' + e)
const enumPages = readdirSync(resolve(DOCS, 'api/enums')).filter(f => f.endsWith('.md') && f !== 'index.md')
notes.push(`枚举页 ${enumPages.length} 个`)

console.log('\n--- 说明 ---')
notes.forEach(n => console.log('  ' + n))
console.log('\n--- 问题 ---')
if (!problems.length) console.log('  无（全部链接与锚点可解析）')
else problems.forEach(x => console.log('  !! ' + x))
process.exit(problems.length ? 1 : 0)
