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
  // 自定义主题：仅覆盖配色，布局沿用默认主题
  theme: resolve(__dirname, 'theme/index.mts'),
  cleanUrls: true,
  lastUpdated: true,
  ignoreDeadLinks: true,

  // 代码块使用深色主题，与原单文件页面一致
  markdown: {
    theme: 'dark-plus'
  },

  // 原页面代码块为深色，整体也以深色呈现更协调
  appearance: 'force-dark',

  head: [
    ['meta', { name: 'theme-color', content: '#087ea4' }]
  ],

  themeConfig: {
    logo: '/logo.svg',

    nav: [
      { text: '概述', link: '/api/' },
      { text: '全局对象', link: '/api/globals' },
      { text: '类型', link: '/api/types' },
      { text: '枚举', link: '/api/enums/' }
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
      message: '由 docs/scripts 从 scripts/api-data.json 自动生成',
      copyright: 'MIT Licensed'
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/HarukaTea/Genshin-Miliastra-Lua-Lsp' }
    ]
  }
})
