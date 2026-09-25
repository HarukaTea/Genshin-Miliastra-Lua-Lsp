/**
 * 把 api-reference.html 中的 API 数据快照为 JSON。
 *
 * 目的：让生成流程不再依赖那个归档 HTML 文件。
 * 快照产物就是文档站的数据源，之后修改 API 直接编辑 JSON 即可。
 *
 * 运行：node scripts/snapshot-api.mjs [输入html] [输出json]
 */
import { writeFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { extractApiData } from './extract-api.mjs'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..')

const inPath = process.argv[2] || resolve(ROOT, 'api-reference.html')
const outPath = process.argv[3] || resolve(__dirname, 'api-data.json')

const data = extractApiData(inPath)

// 稳定输出：固定键顺序，便于 diff
const ordered = {
  $comment: '本文件由 scripts/snapshot-api.mjs 从 api-reference.html 生成，是文档站的数据源。修改 API 请直接编辑本文件，然后运行 npm run gen。',
  GLOBALS: data.GLOBALS,
  CLASSES: data.CLASSES,
  ENUMS: data.ENUMS,
  INHERIT: data.INHERIT,
  KEY_NAMES: data.KEY_NAMES,
  CONTROLLER_NAMES: data.CONTROLLER_NAMES,
  KEY_EVENT_TYPES: data.KEY_EVENT_TYPES
}

writeFileSync(outPath, JSON.stringify(ordered, null, 2) + '\n', 'utf8')

let props = 0
let methods = 0
for (const c of data.CLASSES) {
  props += (c.props || []).length
  methods += (c.methods || []).length
}
let enumVals = 0
for (const e of data.ENUMS) enumVals += (e.values || []).length

console.log('已生成数据快照：' + outPath.replace(ROOT + '\\', '').replace(ROOT + '/', ''))
console.log(`  GLOBALS  ${data.GLOBALS.length}`)
console.log(`  CLASSES  ${data.CLASSES.length}  (属性 ${props} / 方法 ${methods})`)
console.log(`  ENUMS    ${data.ENUMS.length}  (枚举值 ${enumVals})`)
console.log(`  INHERIT  ${data.INHERIT.length}`)
