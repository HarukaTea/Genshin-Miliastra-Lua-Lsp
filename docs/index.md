---
layout: home

hero:
  name: 千星奇域 Lua API
  text: 客户端脚本 API 参考
  tagline: 全局对象、控件类型与枚举的完整签名与说明
  actions:
    - theme: brand
      text: 开始阅读
      link: /api/
    - theme: alt
      text: 类型索引
      link: /api/types
    - theme: alt
      text: 旧版单页
      link: /api-reference.html
      target: _blank

features:
  - title: 全局对象
    details: script、game 与 Color 三类全局入口，含全部点号调用函数与颜色构造方法。
    link: /api/globals
  - title: 控件类型
    details: 从 ClientUIBaseControl 派生的全部控件，属性与方法按类逐一列出，子类不重复基类成员。
    link: /api/types
  - title: 枚举参考
    details: EaseType、Device、ParamType、KeyEventType 等枚举的完整取值清单，统一通过 Enum.类型名.值 访问。
    link: /api/enums/
---

::: tip 关于本站
本站由 [`docs/scripts/build-api-docs.mjs`](./scripts/build-api-docs.mjs) 从项目内嵌的 API 定义自动生成，
运行 `npm run gen` 可重新生成，请勿直接手改 `docs/api/` 下的 Markdown。
:::

## 快速示例

```lua
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
```

## 本地运行

```bash
cd docs
npm install
npm run dev      # 本地预览
npm run build    # 构建静态站点到 docs/.vitepress/dist
```
