// 自定义主题：仅扩展默认主题的样式，保持 VitePress 的默认布局与交互。
// 配色取自改造前的单文件页面（docs/api-reference.html 的 CSS）。
import DefaultTheme from 'vitepress/theme'
import './custom.css'

export default DefaultTheme
