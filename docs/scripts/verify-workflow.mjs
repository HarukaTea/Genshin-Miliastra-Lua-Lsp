// 校验 Actions 工作流：YAML 语法 + 关键字段 + 与 package.json 脚本名一致
import { readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..', '..')

/**
 * @param {string} root 仓库根目录
 * @returns {number} 问题数量
 */
export function verifyWorkflow(root = ROOT) {
  const wf = resolve(root, '.github/workflows/deploy-docs.yml')
  const src = readFileSync(wf, 'utf8')

  let bad = 0
  const fail = m => { console.log('  !! ' + m); bad++ }
  const ok = m => console.log('  ✓ ' + m)

  // 1. 结构检查（不引第三方 yaml 依赖，做关键行断言）
  console.log('=== 工作流结构 ===')
  for (const [re, label] of [
    [/^name:\s*\S/m, 'name 字段'],
    [/^on:/m, 'on 触发器'],
    [/^  push:/m, 'push 触发'],
    [/^  workflow_dispatch:/m, '手动触发'],
    [/^concurrency:/m, 'concurrency 分组'],
    [/^permissions:/m, 'permissions'],
    [/^  pages:\s*write/m, 'pages: write 权限'],
    [/^  id-token:\s*write/m, 'id-token: write 权限（OIDC 部署必需）'],
    [/actions\/checkout@v4/, 'checkout'],
    [/actions\/setup-node@v4/, 'setup-node'],
    [/actions\/configure-pages@v5/, 'configure-pages'],
    [/actions\/upload-pages-artifact@v3/, 'upload-pages-artifact'],
    [/actions\/deploy-pages@v4/, 'deploy-pages'],
    [/working-directory:\s*docs/, 'working-directory 指向 docs'],
    [/cache-dependency-path:\s*docs\/package-lock\.json/, 'npm 缓存指向 docs lock'],
    [/npm ci/, 'npm ci'],
    [/npm run gen/, 'npm run gen'],
    [/npm run verify/, 'npm run verify'],
    [/npm run build -- --base/, '构建时注入 base'],
    [/fetch-depth:\s*0/, 'fetch-depth 0（lastUpdated 需要）']
  ]) {
    if (re.test(src)) ok(label)
    else fail('缺少 ' + label)
  }

  // 2. YAML 缩进基本合法性：不允许 tab
  console.log('\n=== YAML 格式 ===')
  if (/\t/.test(src)) fail('包含制表符（YAML 不允许）')
  else ok('无制表符')
  const trailing = src.split('\n').findIndex(l => /\s+$/.test(l) && l.trim() !== '')
  if (trailing >= 0) console.log(`  ~ 第 ${trailing + 1} 行有行尾空格（不影响解析）`)
  else ok('无行尾空格')

  // 3. 引用的 scripts 必须真实存在于 docs/package.json
  console.log('\n=== 脚本名一致性 ===')
  const pkg = JSON.parse(readFileSync(resolve(root, 'docs/package.json'), 'utf8'))
  for (const s of ['gen', 'verify', 'build', 'dev']) {
    if (!pkg.scripts[s]) fail(`docs/package.json 缺少脚本 ${s}`)
    else ok(`docs/package.json 有 ${s} -> ${pkg.scripts[s]}`)
  }
  for (const m of src.matchAll(/npm run (\w+)/g)) {
    if (!pkg.scripts[m[1]]) fail(`工作流调用了不存在的脚本: npm run ${m[1]}`)
  }

  // 4. upload 路径与 VitePress 默认输出目录一致
  console.log('\n=== 产物路径 ===')
  const uploadPath = /path:\s*(docs\/\.vitepress\/dist)/.exec(src)
  if (uploadPath) ok('上传路径 ' + uploadPath[1] + '（VitePress 默认输出目录）')
  else fail('上传路径不是 docs/.vitepress/dist')

  // 5. base 注入方式
  const baseOk = /--base\s+"\$\{\{\s*steps\.pages\.outputs\.base_path\s*\}\}\/"/.test(src)
  if (baseOk) ok('base 使用 configure-pages 的 base_path（子路径部署可用）')
  else fail('base 注入方式可疑，子路径部署可能 404')

  console.log('\n' + (bad ? `发现 ${bad} 个问题` : '工作流校验通过'))
  return bad
}

// 直接执行时作为 CLI 运行
if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  process.exit(verifyWorkflow() ? 1 : 0)
}
