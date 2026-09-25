/**
 * 收尾整体校验：
 *   1. 旧文件名是否还有残留引用
 *   2. README / CONTRIBUTING 的相对链接目标是否存在
 *   3. docs 生成物齐全
 *   4. 扩展清单未被文档改动污染（package.json 关键字段）
 */
import { readFileSync, existsSync, readdirSync } from 'node:fs'
import { resolve, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { verifyWorkflow } from './verify-workflow.mjs'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..', '..')   // 仓库根目录（本脚本位于 docs/scripts/）
let bad = 0
const fail = m => { console.log('  !! ' + m); bad++ }

const read = p => readFileSync(p, 'utf8')
const exists = p => existsSync(resolve(ROOT, p))

console.log('=== 1. 旧文件名残留引用 ===')
const docFiles = ['README.md', 'README.en.md', 'CONTRIBUTING.md', '.vscodeignore', '.gitignore']
const oldName = '千星奇域API文档'
for (const f of docFiles) {
  const p = resolve(ROOT, f)
  if (!existsSync(p)) continue
  const src = read(p)
  if (src.includes(oldName)) fail(`${f} 仍引用旧文件名 ${oldName}`)
  else console.log(`  ${f}: 无残留`)
}
// 全仓库（排除 node_modules / .git / 生成目录）扫一遍
const scan = []
;(function walk(d, rel) {
  for (const e of readdirSync(d, { withFileTypes: true })) {
    if (['node_modules', '.git', '.npm-cache', 'dist', 'cache'].includes(e.name)) continue
    const p = join(d, e.name)
    const r = rel ? rel + '/' + e.name : e.name
    if (e.isDirectory()) walk(p, r)
    else if (/\.(md|json|html|txt|yml)$/.test(e.name)) scan.push([r, p])
  }
})(ROOT, '')
for (const [r, p] of scan) {
  if (read(p).includes(oldName)) fail(`全仓扫描: ${r} 仍引用旧文件名`)
}
console.log(`  全仓扫描 ${scan.length} 个文本文件完成`)

console.log('\n=== 2. README / CONTRIBUTING 相对链接 ===')
let checked = 0
for (const f of docFiles.slice(0, 3)) {
  const p = resolve(ROOT, f)
  if (!existsSync(p)) continue
  for (const m of read(p).matchAll(/\]\(([^)\s]+)\)/g)) {
    const t = m[1]
    if (/^(https?:|#|mailto:)/.test(t)) continue
    checked++
    if (!exists(resolve(ROOT, decodeURIComponent(t)))) fail(`${f}: 链接无目标 ${t}`)
  }
}
console.log(`  共校验 ${checked} 条相对链接`)

console.log('\n=== 3. docs 生成物 ===')
const need = [
  'docs/package.json',
  'docs/.vitepress/config.mts',
  'docs/.vitepress/sidebar.json',
  'docs/.vitepress/theme/index.mts',
  'docs/.vitepress/theme/custom.css',
  'docs/public/logo.svg',
  'docs/index.md',
  'docs/scripts/api-data.json',
  'docs/scripts/extract-api.mjs',
  'docs/scripts/snapshot-api.mjs',
  'docs/scripts/build-api-docs.mjs',
  'docs/scripts/verify-docs.mjs',
  'docs/scripts/verify-integration.mjs',
  'docs/api/index.md',
  'docs/api/globals.md',
  'docs/api/types.md',
  'docs/api/enums/index.md',
  '.github/workflows/deploy-docs.yml'
]
for (const n of need) { if (!exists(n)) fail('缺少 ' + n) }
const enumN = existsSync(resolve(ROOT, 'docs/api/enums'))
  ? readdirSync(resolve(ROOT, 'docs/api/enums')).filter(f => f.endsWith('.md') && f !== 'index.md').length
  : 0
console.log(`  枚举页 ${enumN} 个`)
if (enumN !== 27) fail(`枚举页数量应为 27，实际 ${enumN}`)

console.log('\n=== 4. 扩展清单完整性（文档改造不应影响） ===')
const pkg = JSON.parse(read(resolve(ROOT, 'package.json')))
console.log(`  name=${pkg.name} version=${pkg.version} main=${pkg.main}`)
console.log(`  配置项 ${Object.keys(pkg.contributes.configuration.properties).length} 个`)
if (pkg.dependencies && Object.keys(pkg.dependencies).length) fail('根 package.json 被写入了 dependencies（会污染扩展包）')
if (pkg.devDependencies && Object.keys(pkg.devDependencies).length) fail('根 package.json 被写入了 devDependencies（会污染扩展包）')
if (pkg.main !== './client/out/extension') fail('main 字段被改动')
if (!exists('client/out/extension.js')) fail('main 指向的产物缺失')
if (!pkg.contributes.languages) fail('contributes.languages 丢失')
console.log('  根清单未被文档依赖污染 ✓')

console.log('\n=== 5. docs 与扩展包隔离 ===')
const vscodeignore = read(resolve(ROOT, '.vscodeignore'))
if (!/^docs\/\*\*$/m.test(vscodeignore)) fail('.vscodeignore 未排除 docs/**')
else console.log('  .vscodeignore 已排除 docs/** ✓')
const docsPkg = JSON.parse(read(resolve(ROOT, 'docs/package.json')))
if (!docsPkg.private) fail('docs/package.json 应标记 private')
if (!docsPkg.devDependencies?.vitepress) fail('docs/package.json 缺少 vitepress 依赖')
console.log(`  docs 子包: ${docsPkg.name} (private=${docsPkg.private}) ✓`)

console.log('\n=== 6. GitHub Actions 工作流 ===')
// 直接调用，避免子进程（部分沙箱环境禁止 spawn）
bad += verifyWorkflow(ROOT)

console.log('\n' + (bad ? `发现 ${bad} 个问题` : '全部通过'))
process.exit(bad ? 1 : 0)
