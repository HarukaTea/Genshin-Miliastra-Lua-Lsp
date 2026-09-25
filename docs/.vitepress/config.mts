import { defineConfig } from 'vitepress'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const __dirname = dirname(fileURLToPath(import.meta.url))

// 侧边栏由 scripts/build-api-docs.mjs 生成，保证与 API 数据始终一致
const sidebar = JSON.parse(
  readFileSync(resolve(__dirname, 'sidebar.json'), 'utf8')
)

export default defineConfig({
  lang: 'zh-CN',
  title: '千星奇域 Lua API',
  description: '千星奇域客户端脚本 Lua API 参考文档',
  cleanUrls: true,
  lastUpdated: true,
  ignoreDeadLinks: true,

  head: [
    ['meta', { name: 'theme-color', content: '#087ea4' }]
  ],

  themeConfig: {
    nav: [
      { text: '概述', link: '/api/' },
      { text: '全局对象', link: '/api/globals' },
      { text: '类型', link: '/api/types' },
      { text: '枚举', link: '/api/enums/' },
      { text: '旧版单页', link: '/api-reference.html', target: '_blank' }
    ],

    sidebar,

    outline: { level: [2, 3], label: '本页目录' },

    search: {
      provider: 'local',
      options: {
        translations: {
          button: {
            buttonText: '搜索文档',
            buttonAriaLabel: '搜索文档'
          },
          modal: {
            displayDetails: '显示详细列表',
            resetButtonTitle: '清除查询条件',
            backButtonTitle: '返回',
            noResultsText: '无法找到相关结果',
            footer: {
              selectText: '选择',
              selectKeyAriaLabel: '回车',
              navigateText: '切换',
              navigateUpKeyAriaLabel: '上箭头',
              navigateDownKeyAriaLabel: '下箭头',
              closeText: '关闭',
              closeKeyAriaLabel: 'Esc'
            }
          }
        }
      }
    },

    outlineTitle: '本页目录',
    darkModeSwitchLabel: '主题',
    lightModeSwitchTitle: '切换到浅色模式',
    darkModeSwitchTitle: '切换到深色模式',
    sidebarMenuLabel: '目录',
    returnToTopLabel: '回到顶部',
    docFooter: { prev: '上一篇', next: '下一篇' },

    footer: {
      message: '本页内容基于项目内置的 API 定义整理',
      copyright: 'MIT Licensed'
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/HarukaTea/Genshin-Miliastra-Lua-Lsp' }
    ]
  }
})
