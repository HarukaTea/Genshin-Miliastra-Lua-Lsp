local util = require 'utility'

local m = {}

-- ============ 辅助构造器 ============

local function setParent(obj)
    util.setTypeParent(obj)
    return obj
end

-- 类型名
local function tp(name, extra)
    local t = { type = "type.name", [1] = name }
    if extra then
        for k, v in pairs(extra) do
            t[k] = v
        end
    end
    return t
end

-- 数组类型  T[]
local function arr(name)
    return {
        type = "type.table",
        tp(name)
    }
end

-- 参数
local function param(name, typeName, extra)
    local p = { type = "type.name", [1] = typeName, paramName = { name } }
    if extra then
        for k, v in pairs(extra) do
            p[k] = v
        end
    end
    return p
end

-- 函数类型
local function fn(args, returns)
    local f = {
        type = "type.function",
        args = { type = "type.list", funcargs = true },
        returns = returns or { type = "type.list" },
    }
    for _, a in ipairs(args or {}) do
        f.args[#f.args + 1] = a
    end
    return f
end

-- 多返回值列表
local function rets(...)
    local r = { type = "type.list" }
    for _, name in ipairs({ ... }) do
        r[#r + 1] = name == "number" and tp("number") or tp(name)
    end
    return r
end

-- 类型对象（m.object[X]）
local function typeObject(members)
    return { child = members or {} }
end

-- 属性成员
local function property(name, typeName, opts)
    local p = {
        name = name,
        type = "type.library",
        kind = "property",
        description = opts and opts.desc,
        readOnly = opts and opts.readOnly,
        value = tp(typeName),
    }
    return setParent(p)
end

-- 方法成员
local function method(name, value, desc)
    -- 对象方法需带 self 占位参数：
    -- 引擎在冒号调用（oop）显示签名/补全时会移除 args[1]，
    -- 无 self 占位会导致真实参数被误删（如 Tween:SetEase() 参数丢失）。
    if value and value.args and value.args.type == "type.list" then
        table.insert(value.args, 1, {
            type = "type.name",
            [1] = "any",
            paramName = { "self" },
        })
    end
    local x = {
        name = name,
        type = "type.library",
        method = true,
        description = desc,
        value = value,
        readOnly = true,
    }
    return setParent(x)
end

-- 点号函数成员（全局表成员，如 game.Tween）
local function fieldFunction(name, value, desc)
    local x = {
        name = name,
        type = "type.library",
        kind = "field",
        description = desc,
        value = value,
        readOnly = true,
    }
    return setParent(x)
end

-- ============ 全局变量 ============

m.globals = {}

-- script: Script
m.globals.script = {
    name = "script",
    kind = "global",
    type = "type.library",
    description = "当前脚本实例。",
    value = tp("Script"),
}
setParent(m.globals.script)

-- game: Game（客户端运行时全局表，点号调用）
m.globals.game = {
    name = "game",
    kind = "global",
    type = "type.library",
    description = "客户端运行时提供的全局表。以下函数均使用点号调用。",
    value = tp("Game"),
}
setParent(m.globals.game)

-- Color：构造函数 + 函数
local colorValue = {
    type = "type.table",
    fieldFunction("FromRGB", fn({
        param("r", "number"),
        param("g", "number"),
        param("b", "number"),
    }, tp("ColorValue")), "由 0-255 RGB 创建颜色。"),
    fieldFunction("FromRGBA", fn({
        param("r", "number"),
        param("g", "number"),
        param("b", "number"),
        param("a", "number", { optional = true }),
    }, tp("ColorValue")), "由 0-255 RGBA 创建颜色，a 传 nil。"),
    fieldFunction("ToRGBA", fn({
        param("colorValue", "ColorValue"),
    }, rets("number", "number", "number", "number")), "将颜色拆分为四个分量。"),
}
m.globals.Color = {
    name = "Color",
    kind = "global",
    type = "type.library",
    description = "颜色构造与转换。",
    value = {
        type = "type.table",
        args = fn({
            param("r", "number"),
            param("g", "number"),
            param("b", "number"),
            param("a", "number", { optional = true }),
        }, tp("ColorValue")),
        [1] = colorValue[1],
        [2] = colorValue[2],
        [3] = colorValue[3],
    },
}
for _, c in ipairs(colorValue) do
    c.key = { c.name }
    c.type = "type.field"
    c.name = nil
end
setParent(m.globals.Color)

-- ============ 类型 ============

m.objects = {}

-- Script
m.objects.Script = typeObject({
    property("alive", "boolean", { readOnly = true, desc = "脚本实例是否仍然存活。" }),
    property("id", "number", { readOnly = true, desc = "脚本实例 ID。" }),
    property("prefabId", "number", { readOnly = true, desc = "脚本元件 ID。" }),
    property("object", "any", { readOnly = true, desc = "脚本所挂载的宿主对象。" }),
    property("path", "string", { readOnly = true, desc = "脚本路径。" }),
    property("enabled", "boolean", { desc = "脚本启用状态。" }),
    method("GetParam", fn({
        param("paramName", "string"),
    }, tp("any")), "按名称读取当前脚本参数。"),
    method("Invoke", fn({
        param("funcName", "string"),
        { type = "type.variadic", value = tp("any") },
    }), "按名称调用当前脚本方法，应使用运行时支持的签名。"),
    method("EnableUpdate", fn({
        param("enabled", "boolean"),
    }), "控制当前脚本的 Tick 开关，true 重新启用。"),
    method("RegisterServerSignalHandler", fn({
        param("signalName", "string"),
        {
            type = "type.function",
            args = { type = "type.list", funcargs = true },
            returns = { type = "type.list" },
            paramName = { "callback" },
        },
    }, nil), "注册服务器信号监听。"),
    method("UnregisterServerSignalHandler", fn({
        param("signalName", "string"),
    }), "移除指定名称的服务器信号监听。"),
    method("RegisterCustomVariableChangedHandler", fn({
        param("entityType", "Enum.CustomVariableEntityType"),
        param("customVariableName", "string"),
        {
            type = "type.function",
            args = { type = "type.list", funcargs = true },
            paramName = { "callback" },
        },
    }), "监听全局自定义变量变化。"),
    method("UnregisterCustomVariableChangedHandler", fn({
        param("entityType", "Enum.CustomVariableEntityType"),
        param("customVariableName", "string"),
    }), "移除指定实体类型和变量名的监听。"),
})

-- Game（game 全局的类型）
m.objects.Game = typeObject({
    -- UI 与层级
    fieldFunction("InstantiateClientUIControl", fn({
        param("uiPrefabId", "number"),
        param("parent", "ClientUIBaseControl"),
    }, tp("ClientUIBaseControl")), "根据已配置的 UI 元件创建控件实例。"),
    fieldFunction("DestroyClientUIControl", fn({
        param("control", "ClientUIBaseControl"),
    }), "销毁指定客户端控件。"),
    fieldFunction("GetClientUIControl", fn({
        param("controlId", "number"),
    }, tp("ClientUIBaseControl")), "按运行时客户端控件 ID 获取控件。"),
    fieldFunction("FindClientUIRoot", fn({
        param("nodeName", "string"),
    }, tp("ClientUIBaseControl")), "按名称查找 UI 根控件。"),
    fieldFunction("GetClientUIRoots", fn({}, arr("ClientUIBaseControl")), "获取全部 UI 根控件。"),
    fieldFunction("GetUICanvasSize", fn({}, rets("number", "number")), "获取 UI 画布宽高。"),
    fieldFunction("GetCursorUIPos", fn({}, rets("number", "number")), "获取光标 UI 坐标。"),
    -- 输入与聚焦
    fieldFunction("GetDevice", fn({}, tp("Enum.Device")), "获取当前输入设备类型。"),
    fieldFunction("SetControllerFocus", fn({
        param("control", "ClientUIBaseControl"),
    }), "设置手柄聚焦控件。"),
    fieldFunction("GetControllerFocus", fn({}, tp("ClientUIBaseControl")), "获取当前手柄聚焦控件。"),
    fieldFunction("GetControllerLeftStickAxis", fn({}, rets("number", "number")), "获取左摇杆轴值。"),
    fieldFunction("GetControllerRightStickAxis", fn({}, rets("number", "number")), "获取右摇杆轴值。"),
    -- Tween、信号与自定义变量
    fieldFunction("Tween", fn({
        param("object", "any"),
        param("tweenDataTable", "table"),
        param("duration", "number"),
    }, tp("Tween")), "为对象的 Tweenable 字段创建补间动画。"),
    fieldFunction("TweenSequence", fn({}, tp("TweenSequence")), "创建空的补间动画序列。"),
    fieldFunction("ServerSignal", fn({
        param("signalName", "string"),
    }, tp("ServerSignal")), "按 signalName 创建服务器信号。"),
    fieldFunction("GetGlobalCustomVariableValue", fn({
        param("entityType", "Enum.CustomVariableEntityType"),
        param("customVariableName", "string"),
    }, tp("any")), "读取服务器指定实体的全局自定义变量。"),
    -- 关卡、音频与本地化
    fieldFunction("PauseLevelTime", fn({
        param("pause", "boolean"),
    }), "单人模式下暂停/恢复关卡时间。"),
    fieldFunction("IsLevelTimePaused", fn({}, tp("boolean")), "查询关卡时间是否暂停。"),
    fieldFunction("PlayAudio2D", fn({
        param("audioId", "number"),
    }, tp("number")), "按已配置的音效 ID 播放 2D 音效，返回音效实例 ID。"),
    fieldFunction("StopAudio", fn({
        param("audioInstanceId", "number"),
    }), "停止指定音效实例。"),
    fieldFunction("IsAudioAlive", fn({
        param("audioInstanceId", "number"),
    }, tp("boolean")), "查询音效实例是否存活。"),
    fieldFunction("GetLanguageType", fn({}, tp("Enum.LanguageType")), "获取当前语言。"),
    fieldFunction("GetStageMode", fn({}, tp("Enum.StageMode")), "获取当前关卡模式。"),
    fieldFunction("IsTestPlay", fn({}, tp("boolean")), "查询当前是否处于测试游玩。"),
    fieldFunction("GetText", fn({
        param("textMapId", "string"),
    }, tp("string")), "按已配置的文本 ID 获取文本。"),
    -- Debug
    fieldFunction("PrintClientUITree", fn({}), "将当前客户端控件树输出到控制台。"),
})

-- ColorValue
m.objects.ColorValue = typeObject({})

-- Tween
local tweenControls = {
    SetEase      = { "easeType", "Enum.EaseType", "设置缓动类型并返回自身。" },
    SetRelative  = { "relative", "boolean", "设置目标值解释为相对值，true 表示相对。", },
    SetOnComplete = { "onComplete", nil, "设置全部循环完成回调。" },
    SetOnStepComplete = { "onStepComplete", nil, "设置步骤完成回调。" },
    SetLoops     = { "times", "number", "设置循环次数，-1 无限循环。" },
}
local tweenMembers = {}
local tweenNoArg = {
    Play = "开始播放并返回自身。",
    Pause = "暂停并保留当前进度。",
    Resume = "从暂停处继续播放。",
    Restart = "回到开始状态并重新播放。",
    Complete = "立即切换到结束状态。",
}
local tweenKill = { param("complete", "boolean") }
for name, desc in pairs(tweenNoArg) do
    tweenMembers[#tweenMembers + 1] = method(name, fn({}, tp("Tween")), desc)
end
tweenMembers[#tweenMembers + 1] = method("Kill", fn(tweenKill, tp("Tween")), "销毁实例；true 立即结束并触发完成回调，false 保持当前状态结束且不触发。")
for name, conf in pairs(tweenControls) do
    local args = { param(conf[1], conf[2]) }
    if conf[1] == "onComplete" or conf[1] == "onStepComplete" then
        args[1] = { type = "type.function", args = { type = "type.list", funcargs = true }, paramName = { conf[1] } }
    end
    tweenMembers[#tweenMembers + 1] = method(name, fn(args, tp("Tween")), conf[3])
end
m.objects.Tween = typeObject(tweenMembers)

-- TweenSequence
local tweenSeqMembers = {
    method("Append", fn({ param("tween", "Tween") }, tp("TweenSequence")), "在序列末尾接入一个 Tween。"),
    method("AppendInterval", fn({ param("interval", "number") }, tp("TweenSequence")), "在序列末尾接入等待间隔。"),
    method("AppendCallback", fn({ { type = "type.function", args = { type = "type.list", funcargs = true }, paramName = { "callback" } } }, tp("TweenSequence")), "在序列末尾接入回调。"),
    method("Join", fn({ param("tween", "Tween") }, tp("TweenSequence")), "与当前队尾步骤并行，结束以较晚者为准。"),
    method("Insert", fn({ param("time", "number"), param("tween", "Tween") }, tp("TweenSequence")), "在指定时间点插入 Tween。"),
    method("InsertCallback", fn({ param("time", "number"), { type = "type.function", args = { type = "type.list", funcargs = true }, paramName = { "callback" } } }, tp("TweenSequence")), "在指定时间点插入回调。"),
    method("Play", fn({}, tp("TweenSequence")), "开始播放并返回自身。"),
    method("Pause", fn({}, tp("TweenSequence")), "暂停序列。"),
    method("Resume", fn({}, tp("TweenSequence")), "继续播放序列。"),
    method("Restart", fn({}, tp("TweenSequence")), "回到初始状态并重新播放。"),
    method("Complete", fn({}, tp("TweenSequence")), "立即完成整个序列。"),
    method("Kill", fn({ param("complete", "boolean") }, tp("TweenSequence")), "销毁序列；true 立即结束，false 保持当前状态结束。"),
    method("SetOnComplete", fn({ { type = "type.function", args = { type = "type.list", funcargs = true }, paramName = { "onComplete" } } }, tp("TweenSequence")), "设置整个序列完成回调。"),
    method("SetOnStepComplete", fn({ { type = "type.function", args = { type = "type.list", funcargs = true }, paramName = { "onStepComplete" } } }, tp("TweenSequence")), "设置步骤完成回调。"),
    method("SetLoops", fn({ param("times", "number") }, tp("TweenSequence")), "设置循环次数，-1 无限循环。"),
}
m.objects.TweenSequence = typeObject(tweenSeqMembers)

-- ServerSignal
local signalAdd = {
    AddInt = { "intValue", "number", "添加整数参数。" },
    AddIntList = { "intListValue", "number", "添加整数列表参数。" },
    AddFloat = { "floatValue", "number", "添加浮点数参数。" },
    AddFloatList = { "floatListValue", "number", "添加浮点数列表参数。" },
    AddString = { "stringValue", "string", "添加字符串参数。" },
    AddStringList = { "stringListValue", "string", "添加字符串列表参数。" },
    AddVector3 = { "vector3Value", "table", "添加三维向量参数。" },
    AddVector3List = { "vector3ListValue", "table", "添加三维向量列表参数。" },
    AddBool = { "boolValue", "boolean", "添加布尔值参数。" },
    AddBoolList = { "boolListValue", "boolean", "添加布尔值列表参数。" },
    AddGuid = { "guidValue", "number", "添加 GUID 参数。" },
    AddGuidList = { "guidListValue", "number", "添加 GUID 列表参数。" },
    AddEntity = { "entityValue", "number", "添加实体参数。" },
    AddEntityList = { "entityListValue", "number", "添加实体列表参数。" },
    AddPrefabId = { "prefabIdValue", "number", "添加元件 ID 参数。" },
    AddPrefabIdList = { "prefabIdListValue", "number", "添加元件 ID 列表参数。" },
    AddConfigId = { "configIdValue", "number", "添加配置 ID 参数。" },
    AddConfigIdList = { "configIdListValue", "number", "添加配置 ID 列表参数。" },
}
local signalMembers = {
    method("AddParam", fn({
        param("paramType", "Enum.ParamType"),
        param("paramValue", "any"),
    }), "按显式类型添加参数。"),
    method("SendSignal", fn({}), "向服务器发送已编排好的信号。"),
}
for name, conf in pairs(signalAdd) do
    signalMembers[#signalMembers + 1] = method(name, fn({
        param(conf[1], conf[2]),
    }), conf[3])
end
m.objects.ServerSignal = typeObject(signalMembers)

-- EnumItem
m.objects.EnumItem = typeObject({
    property("Name", "string", { readOnly = true, desc = "枚举值名称。" }),
    property("FullName", "string", { readOnly = true, desc = "枚举值完整名称。" }),
    property("EnumType", "string", { readOnly = true, desc = "枚举类型名称。" }),
})

-- ============ 客户端控件 ============

-- ClientUIBaseControl（基类）
local baseControlMembers = {
    property("alive", "boolean", { readOnly = true, desc = "控件是否存活。" }),
    property("id", "number", { readOnly = true, desc = "控件实例 ID。" }),
    property("prefabId", "number", { readOnly = true, desc = "控件元件 ID。" }),
    property("active", "boolean", { readOnly = true, desc = "控件激活状态。" }),
    property("activeInHierarchy", "boolean", { readOnly = true, desc = "控件在层级中是否激活。" }),
    property("visible", "boolean", { readOnly = true, desc = "控件可见状态。" }),
    property("name", "string", { desc = "控件名称。" }),
    property("parent", "ClientUIBaseControl", { desc = "父控件。" }),
    property("anchoredPositionX", "number", { desc = "X 锚点位置（可 Tween）。" }),
    property("anchoredPositionY", "number", { desc = "Y 锚点位置（可 Tween）。" }),
    property("sizeDeltaX", "number", { desc = "宽度（可 Tween）。" }),
    property("sizeDeltaY", "number", { desc = "高度（可 Tween）。" }),
    property("anchorMinX", "number", { desc = "最小锚点 X（可 Tween）。" }),
    property("anchorMinY", "number", { desc = "最小锚点 Y（可 Tween）。" }),
    property("anchorMaxX", "number", { desc = "最大锚点 X（可 Tween）。" }),
    property("anchorMaxY", "number", { desc = "最大锚点 Y（可 Tween）。" }),
    property("pivotX", "number", { desc = "轴心 X（可 Tween）。" }),
    property("pivotY", "number", { desc = "轴心 Y（可 Tween）。" }),
    property("localScaleX", "number", { desc = "缩放 X（可 Tween）。" }),
    property("localScaleY", "number", { desc = "缩放 Y（可 Tween）。" }),
    property("localScaleZ", "number", { desc = "缩放 Z（可 Tween）。" }),
    property("localRotationX", "number", { desc = "旋转 X（可 Tween）。" }),
    property("localRotationY", "number", { desc = "旋转 Y（可 Tween）。" }),
    property("localRotationZ", "number", { desc = "旋转 Z（可 Tween）。" }),
    property("canControllerFocus", "boolean", { desc = "是否可被手柄聚焦。" }),
    -- 层级与可见性
    method("GetChildren", fn({}, arr("ClientUIBaseControl")), "获取直接子控件。"),
    method("GetChild", fn({ param("name", "string") }, tp("ClientUIBaseControl")), "按名称获取直接子控件。"),
    method("FindChild", fn({ param("path", "string") }, tp("ClientUIBaseControl")), "按路径查找子控件。"),
    method("SetActive", fn({ param("active", "boolean") }), "设置激活状态；false 时脚本逻辑停止运行。"),
    method("SetVisible", fn({ param("visible", "boolean") }), "仅设置可见性，不停止脚本逻辑。"),
    method("GetSiblingIndex", fn({}, tp("number")), "获取同级排序索引。"),
    method("SetSiblingIndex", fn({ param("index", "number") }, tp("boolean")), "设置同级排序索引。"),
    method("SetAsFirstSibling", fn({}, tp("boolean")), "移到同级首位。"),
    method("SetAsLastSibling", fn({}, tp("boolean")), "移到同级末位。"),
    -- 布局与变换
    method("GetAnchoredPosition", fn({}, rets("number", "number")), "获取位置。"),
    method("SetAnchoredPosition", fn({ param("x", "number"), param("y", "number") }), "设置位置。"),
    method("GetSizeDelta", fn({}, rets("number", "number")), "获取大小。"),
    method("SetSizeDelta", fn({ param("x", "number"), param("y", "number") }), "设置大小。"),
    method("GetAnchorMin", fn({}, rets("number", "number")), "获取最小锚点。"),
    method("SetAnchorMin", fn({ param("x", "number"), param("y", "number") }), "设置最小锚点。"),
    method("GetAnchorMax", fn({}, rets("number", "number")), "获取最大锚点。"),
    method("SetAnchorMax", fn({ param("x", "number"), param("y", "number") }), "设置最大锚点。"),
    method("GetPivot", fn({}, rets("number", "number")), "获取轴心。"),
    method("SetPivot", fn({ param("x", "number"), param("y", "number") }), "设置轴心。"),
    method("GetLocalScale", fn({}, rets("number", "number", "number")), "获取缩放。"),
    method("SetLocalScale", fn({ param("x", "number"), param("y", "number"), param("z", "number") }), "设置缩放。"),
    method("GetLocalRotation", fn({}, rets("number", "number", "number")), "获取旋转。"),
    method("SetLocalRotation", fn({ param("x", "number"), param("y", "number"), param("z", "number") }), "设置旋转。"),
    -- 脚本访问
    method("GetScriptByPath", fn({ param("scriptPath", "string") }, tp("Script")), "按路径获取挂载的脚本。"),
    method("GetScript", fn({ param("scriptPrefabId", "number") }, tp("Script")), "按脚本元件 ID 获取脚本。"),
    method("GetScripts", fn({}, arr("Script")), "获取控件上全部脚本。"),
    -- 键盘/手柄按键事件
    method("AddKeyEventListener", fn({
        param("eventType", "Enum.KeyEventType"),
        { type = "type.function", args = { type = "type.list", funcargs = true }, paramName = { "callback" } },
    }), "注册指定按键事件监听。"),
    method("RemoveKeyEventListener", fn({
        param("eventType", "Enum.KeyEventType"),
        { type = "type.function", args = { type = "type.list", funcargs = true }, paramName = { "callback" } },
    }), "移除单个按键事件监听。"),
    method("RemoveKeyEventListeners", fn({ param("eventType", "Enum.KeyEventType") }), "移除指定事件的全部监听。"),
    method("RemoveAllKeyEventListeners", fn({}), "移除全部按键事件监听。"),
    -- 手柄导航事件
    method("AddNavigationEventListener", fn({
        param("eventType", "Enum.ControllerNavigationEventType"),
        { type = "type.function", args = { type = "type.list", funcargs = true }, paramName = { "callback" } },
    }), "注册手柄导航事件监听。"),
    method("RemoveNavigationEventListener", fn({
        param("eventType", "Enum.ControllerNavigationEventType"),
        { type = "type.function", args = { type = "type.list", funcargs = true }, paramName = { "callback" } },
    }), "移除指定手柄导航事件和回调。"),
    method("RemoveNavigationEventListeners", fn({ param("eventType", "Enum.ControllerNavigationEventType") }), "移除指定导航事件的全部监听。"),
    method("RemoveAllNavigationEventListeners", fn({}), "移除全部手柄导航事件监听。"),
    -- 手柄导航配置
    method("SetControllerNavigation", fn({
        param("navigationDir", "Enum.ControllerNavigationDir"),
        param("navigationMode", "Enum.ControllerNavigationMode"),
        param("navigationTarget", "ClientUIBaseControl", { optional = true }),
    }), "设置指定方向的手柄导航；目标可以为 nil。"),
    method("GetControllerNavigation", fn({
        param("navigationDir", "Enum.ControllerNavigationDir"),
    }, rets("Enum.ControllerNavigationMode", "ClientUIBaseControl")), "返回指定方向的手柄导航配置。"),
}
m.objects.ClientUIBaseControl = typeObject(baseControlMembers)

-- ClientUIImageControl
m.objects.ClientUIImageControl = typeObject({
    property("imageSource", "Enum.ImageSource", { readOnly = true, desc = "图片来源。" }),
    property("imageId", "number", { readOnly = true, desc = "图片 ID。" }),
    property("imageColor", "ColorValue", { desc = "图片颜色（可 Tween）。" }),
    property("imageType", "Enum.ImageType", { desc = "图片类型。" }),
    property("enableMask", "boolean", { desc = "是否启用遮罩。" }),
    property("enableSoftEdge", "boolean", { desc = "是否启用边缘羽化。" }),
    property("softEdgeMode", "Enum.ImageMaskSoftEdgeMode", { desc = "边缘羽化模式。" }),
    property("softEdgeWidthX", "number", { desc = "边缘羽化宽度 X（可 Tween）。" }),
    property("softEdgeWidthY", "number", { desc = "边缘羽化宽度 Y（可 Tween）。" }),
    property("horizontalSoftRange", "number", { desc = "水平羽化范围（可 Tween）。" }),
    property("verticalSoftRange", "number", { desc = "垂直羽化范围（可 Tween）。" }),
    property("reverseMaskArea", "boolean", { desc = "是否反转遮罩区域。" }),
    property("fillType", "Enum.ImageFillType", { desc = "填充类型。" }),
    property("fillHorizontalType", "Enum.ImageFillHorizontalType", { desc = "水平填充类型。" }),
    property("fillVerticalType", "Enum.ImageFillVerticalType", { desc = "垂直填充类型。" }),
    property("fillRadial90Type", "Enum.ImageFillRadial90Type", { desc = "90 度径向填充类型。" }),
    property("fillRadialType", "Enum.ImageFillRadialType", { desc = "180/360 度径向填充类型。" }),
    property("fillAmount", "number", { desc = "填充进度（可 Tween）。" }),
    method("SetImage", fn({
        param("imageSource", "Enum.ImageSource"),
        param("imageId", "number"),
    }), "设置图片来源与 ID。"),
    method("SetSoftEdgeWidth", fn({
        param("widthX", "number"),
        param("widthY", "number"),
    }), "设置水平与垂直边缘羽化宽度。"),
    method("SetFillUnused", fn({}), "关闭填充裁切。"),
    method("SetFillHorizontal", fn({
        param("fillHorizontalType", "Enum.ImageFillHorizontalType"),
        param("fillAmount", "number"),
    }), "设置水平填充。"),
    method("SetFillVertical", fn({
        param("fillVerticalType", "Enum.ImageFillVerticalType"),
        param("fillAmount", "number"),
    }), "设置垂直填充。"),
    method("SetFillRadial90", fn({
        param("fillRadial90Type", "Enum.ImageFillRadial90Type"),
        param("fillAmount", "number"),
    }), "设置 90 度径向填充。"),
    method("SetFillRadial180", fn({
        param("fillRadialType", "Enum.ImageFillRadialType"),
        param("fillAmount", "number"),
    }), "设置 180 度径向填充。"),
    method("SetFillRadial360", fn({
        param("fillRadialType", "Enum.ImageFillRadialType"),
        param("fillAmount", "number"),
    }), "设置 360 度径向填充。"),
})

-- 文本类控件共享字段
local function textFields(extra)
    local fields = {
        property("text", "string", { desc = "显示文本。" }),
        property("fontSize", "number", { desc = "字号（可 Tween）。" }),
        property("fontColor", "ColorValue", { desc = "字色（可 Tween）。" }),
        property("bgColor", "ColorValue", { desc = "背景色（可 Tween）。" }),
        property("enableOutline", "boolean", { desc = "是否启用描边。" }),
        property("outlineColor", "ColorValue", { desc = "描边色（可 Tween）。" }),
        property("horizontalAlignment", "Enum.TextHorizontalAlignment", { desc = "水平对齐。" }),
        property("verticalAlignment", "Enum.TextVerticalAlignment", { desc = "垂直对齐。" }),
        property("adaptiveFontSize", "boolean", { desc = "字号自适应。" }),
        property("minimumFontSize", "number", { desc = "字号自适应的最小字号。" }),
    }
    for _, f in ipairs(extra or {}) do
        fields[#fields + 1] = f
    end
    return fields
end

-- ClientUITextBoxControl
m.objects.ClientUITextBoxControl = typeObject(textFields())

-- ClientUITextWindowControl
m.objects.ClientUITextWindowControl = typeObject(textFields({
    property("interactable", "boolean", { desc = "是否可交互；false 时手柄无法聚焦。" }),
    property("showScrollBar", "boolean", { desc = "是否显示滚动条。" }),
}))

-- 光标事件监听成员（PresetButton / CursorEventArea 共用）
local function cursorEventMembers()
    return {
        method("AddCursorEventListener", fn({
            param("eventType", "Enum.CursorEventType"),
            { type = "type.function", args = { type = "type.list", funcargs = true, { type = "type.name", [1] = "CursorEventData", paramName = { "data" } } }, paramName = { "callback" } },
        }), "注册光标事件监听。"),
        method("RemoveCursorEventListener", fn({
            param("eventType", "Enum.CursorEventType"),
            { type = "type.function", args = { type = "type.list", funcargs = true }, paramName = { "callback" } },
        }), "移除指定事件和回调。"),
        method("RemoveCursorEventListeners", fn({ param("eventType", "Enum.CursorEventType") }), "移除指定光标事件的全部监听。"),
        method("RemoveAllCursorEventListeners", fn({}), "移除全部光标事件监听。"),
        method("SimulateCursorClick", fn({}, tp("CursorEventData")), "按顺序模拟一次光标点击。"),
    }
end

-- ClientUIPresetButtonControl
m.objects.ClientUIPresetButtonControl = typeObject({
    property("interactable", "boolean", { desc = "是否可交互。" }),
    property("clickAudioId", "number", { desc = "点击音效 ID。" }),
    property("raycastTarget", "boolean", { desc = "可被光标射线检测。" }),
    table.unpack(cursorEventMembers()),
})

-- ClientUICursorEventAreaControl
m.objects.ClientUICursorEventAreaControl = typeObject({
    property("raycastTarget", "boolean", { desc = "可被光标射线检测。" }),
    table.unpack(cursorEventMembers()),
})

-- CursorEventData
m.objects.CursorEventData = typeObject({
    property("dragging", "boolean", { readOnly = true, desc = "是否拖拽中。" }),
    property("touchId", "number", { readOnly = true, desc = "触摸 ID。" }),
    method("GetUIPos", fn({}, rets("number", "number")), "获取当前 UI 坐标。"),
    method("GetPressUIPos", fn({}, rets("number", "number")), "获取按下时的 UI 坐标。"),
    method("GetUIPosDelta", fn({}, rets("number", "number")), "获取本次事件的坐标变化。"),
})

-- ClientUIGridScrollerControl
m.objects.ClientUIGridScrollerControl = typeObject({
    property("itemCount", "number", { readOnly = true, desc = "条目数量。" }),
    property("itemPrefabId", "number", { desc = "条目元件 ID。" }),
    property("raycastTarget", "boolean", { desc = "可被光标射线检测。" }),
    property("showScrollBar", "boolean", { desc = "是否显示滚动条。" }),
    property("interactable", "boolean", { desc = "是否可交互。" }),
    property("scrollDirection", "Enum.ScrollDirection", { readOnly = true, desc = "滚动方向。" }),
    property("layoutConstraint", "Enum.ScrollLayoutConstraint", { readOnly = true, desc = "布局约束。" }),
    property("layoutConstraintFixedCount", "number", { readOnly = true, desc = "固定行数或列数。" }),
    property("scrollProgress", "number", { desc = "滚动进度（可 Tween）。" }),
    method("RefreshItems", fn({
        param("itemCount", "number"),
        { type = "type.function", args = { type = "type.list", funcargs = true, { type = "type.name", [1] = "ClientUIBaseControl", paramName = { "control" } }, { type = "type.name", [1] = "number", paramName = { "index" } } }, paramName = { "refreshCallback" } },
    }), "刷新条目并逐项回调控件和条目序号。"),
    method("GetItemIndex", fn({ param("control", "ClientUIBaseControl") }, tp("number")), "获取条目控件的序号。"),
    method("GetItemSize", fn({}, rets("number", "number")), "获取条目宽度与高度。"),
    method("GetItemSpacing", fn({}, rets("number", "number")), "获取条目的水平与垂直间距。"),
    method("GetPadding", fn({}, rets("number", "number", "number", "number")), "获取内容区域的上下左右内边距。"),
    method("ScrollToItemAt", fn({
        param("index", "number"),
        param("scrollAlignType", "Enum.ScrollAlignType"),
    }), "滚动到指定序号条目。"),
    method("GetContentLength", fn({}, tp("number")), "获取滚动内容在滚动方向上的长度。"),
})

-- ClientUIKeyHintControl
m.objects.ClientUIKeyHintControl = typeObject({
    property("keyboardKeyCode", "Enum.KeyboardKeyCode", { desc = "键鼠按键枚举值。" }),
    property("controllerKeyCode", "Enum.ControllerKeyCode", { desc = "手柄按键枚举值。" }),
})

-- ClientUIAnimationControl
m.objects.ClientUIAnimationControl = typeObject({
    property("animationId", "number", { desc = "动效 ID。" }),
    property("playSoundEffect", "boolean", { desc = "是否播放动效音效。" }),
    property("layer", "Enum.UIAnimationLayer", { desc = "动效层级。" }),
    method("PlayAnimation", fn({}), "播放界面动效。"),
    method("StopAnimation", fn({}), "停止界面动效。"),
})

-- ClientUIFullscreenAnimationControl
m.objects.ClientUIFullscreenAnimationControl = typeObject({
    property("animationId", "number", { desc = "动效 ID。" }),
    property("playSoundEffect", "boolean", { desc = "是否播放动效音效。" }),
})

-- ClientUIContainerControl
m.objects.ClientUIContainerControl = typeObject({
    property("isolateNavigation", "boolean", { desc = "是否隔离手柄导航。" }),
    property("disableKeyEventPassthrough", "boolean", { desc = "是否屏蔽按键事件穿透。" }),
    property("disableCursorEventPassthrough", "boolean", { desc = "是否屏蔽区域内点击事件穿透。" }),
    property("showCursor", "boolean", { desc = "是否显示常驻光标。" }),
})

-- ClientUIReferenceControl
m.objects.ClientUIReferenceControl = typeObject({
    property("referencedPrefabId", "number", { readOnly = true, desc = "引用的界面元件 ID。" }),
})

-- ============ 继承关系 ============

m.ClassNames = {
    ClientUIImageControl = "ClientUIBaseControl",
    ClientUITextBoxControl = "ClientUIBaseControl",
    ClientUITextWindowControl = "ClientUIBaseControl",
    ClientUIPresetButtonControl = "ClientUIBaseControl",
    ClientUICursorEventAreaControl = "ClientUIBaseControl",
    ClientUIGridScrollerControl = "ClientUIBaseControl",
    ClientUIKeyHintControl = "ClientUIBaseControl",
    ClientUIAnimationControl = "ClientUIBaseControl",
    ClientUIFullscreenAnimationControl = "ClientUIBaseControl",
    ClientUIContainerControl = "ClientUIBaseControl",
    ClientUIReferenceControl = "ClientUIBaseControl",
}

-- ============ 枚举 ============

local function enumDef(desc, values)
    local def = { desc = desc, values = values }
    return def
end

m.enums = {
    EaseType = enumDef("缓动类型", {
        "Linear", "InSine", "OutSine", "InOutSine", "InQuad", "OutQuad", "InOutQuad",
        "InCubic", "OutCubic", "InOutCubic", "InQuart", "OutQuart", "InOutQuart",
        "InQuint", "OutQuint", "InOutQuint", "InExpo", "OutExpo", "InOutExpo",
        "InCirc", "OutCirc", "InOutCirc", "InBack", "OutBack", "InOutBack",
        "InElastic", "OutElastic", "InOutElastic", "InBounce", "OutBounce", "InOutBounce",
    }),
    CustomVariableEntityType = enumDef("自定义变量实体类型", { "Level", "PlayerSelf", "AvatarSelf" }),
    Device = enumDef("输入设备类型", { "KeyboardAndMouse", "Mobile", "Controller", "MobileController" }),
    StageMode = enumDef("关卡模式", { "Beyond", "Classic" }),
    LanguageType = enumDef("语言类型", {
        "LanguageNone", "LanguageEng", "LanguageChs", "LanguageCht", "LanguageFra",
        "LanguageDeu", "LanguageSpa", "LanguagePor", "LanguageRus", "LanguageJpn",
        "LanguageKor", "LanguageTha", "LanguageVie", "LanguageInd", "LanguageTur", "LanguageIta",
    }),
    ParamType = enumDef("信号参数类型", {
        "Entity", "EntityList", "Int", "IntList", "Bool", "BoolList",
        "Float", "FloatList", "String", "StringList", "Vector3", "Vector3List",
        "Guid", "GuidList", "ConfigId", "ConfigIdList", "PrefabId", "PrefabIdList",
    }),
    CursorEventType = enumDef("光标事件类型", {
        "CursorDown", "CursorUp", "CursorEnter", "CursorExit", "CursorDrag",
        "CursorBeginDrag", "CursorEndDrag", "CursorClick",
    }),
    ScrollDirection = enumDef("滚动方向", { "Horizontal", "Vertical" }),
    ScrollLayoutConstraint = enumDef("滚动布局约束", { "AutoWrap", "Fixed" }),
    ScrollAlignType = enumDef("滚动对齐类型", { "Bottom", "Center", "Top" }),
    ControllerNavigationDir = enumDef("手柄导航方向", { "Up", "Down", "Left", "Right" }),
    ControllerNavigationEventType = enumDef("手柄导航事件类型", {
        "Confirm", "Cancel", "Focus", "LostFocus",
        "RightStickUp", "RightStickDown", "RightStickRight", "RightStickLeft",
        "LeftStickUp", "LeftStickDown", "LeftStickRight", "LeftStickLeft",
    }),
    ControllerNavigationMode = enumDef("手柄导航模式", { "None", "NearestControl", "Specified" }),
    TextHorizontalAlignment = enumDef("文本水平对齐", { "Left", "Middle", "Right" }),
    TextVerticalAlignment = enumDef("文本垂直对齐", { "Top", "Middle", "Bottom" }),
    ImageType = enumDef("图片类型", { "Basic", "Stretch" }),
    ImageSource = enumDef("图片来源", {
        "StaticReference", "Item", "Equipment", "Skill", "UnitStatus", "Faction", "Currency", "Prefab",
    }),
    ImageFillType = enumDef("图片填充类型", { "Unused", "Horizontal", "Vertical", "Radial90", "Radial180", "Radial360" }),
    ImageFillHorizontalType = enumDef("水平填充起始", { "Left", "Right" }),
    ImageFillVerticalType = enumDef("垂直填充起始", { "Bottom", "Top" }),
    ImageFillRadial90Type = enumDef("90 度径向填充起始", { "BottomLeft", "TopLeft", "TopRight", "BottomRight" }),
    ImageFillRadialType = enumDef("径向填充起始", { "Bottom", "Left", "Top", "Right" }),
    ImageMaskSoftEdgeMode = enumDef("边缘羽化模式", { "Percentage", "Pixel" }),
    UIAnimationLayer = enumDef("动效层级", { "AboveAllControls", "BelowAllControls" }),
}

-- 按键枚举（程序化生成）
do
    local keyNames = {}
    for i = 1, 43 do
        keyNames[#keyNames + 1] = "CraftspersonKey" .. i
    end
    for _, n in ipairs({
        "MoveForwardKey", "MoveBackwardKey", "MoveLeftKey", "MoveRightKey",
        "SwitchToWalkOrRunKey", "SprintKey", "JumpKey", "DropKey",
        "OpenShortcutWheelKey", "InteractKey", "NormalAttackKey",
        "CharacterSkill1Key", "CharacterSkill2Key", "CharacterSkill3Key", "CharacterSkill4Key",
    }) do
        keyNames[#keyNames + 1] = n
    end
    keyNames[#keyNames + 1] = "None"
    m.enums.KeyboardKeyCode = enumDef("键盘按键码", keyNames)

    local controllerNames = {}
    for i = 1, 14 do
        controllerNames[#controllerNames + 1] = "CraftspersonKey" .. i
    end
    for _, n in ipairs({
        "SprintKey", "JumpKey", "InteractKey", "NormalAttackKey",
        "CharacterSkill1Key", "CharacterSkill2Key", "CharacterSkill3Key", "CharacterSkill4Key",
        "MenuConfirmKey", "MenuBackKey", "None",
    }) do
        controllerNames[#controllerNames + 1] = n
    end
    m.enums.ControllerKeyCode = enumDef("手柄按键码", controllerNames)

    -- KeyEventType：Keyboard/Controller × Down/Up
    local eventNames = {}
    local function push(prefix, baseNames)
        for _, n in ipairs(baseNames) do
            eventNames[#eventNames + 1] = prefix .. n .. "Down"
            eventNames[#eventNames + 1] = prefix .. n .. "Up"
        end
    end
    push("Keyboard", keyNames)
    push("Controller", controllerNames)
    m.enums.KeyEventType = enumDef("按键事件类型", eventNames)
end

-- ============ 应用 ============

function m.apply(api)
    -- 合并全局
    for name, def in pairs(m.globals) do
        api.global[name] = def
    end
    -- 合并类型
    for name, def in pairs(m.objects) do
        api.object[name] = def
    end
    -- 构建枚举
    local enumRoot = {
        name = "Enums",
        type = "type.library",
        kind = "field",
        value = {
            [1] = "Enum",
            type = "type.name",
            child = {},
        },
    }
    for enumName, def in pairs(m.enums) do
        local items = {
            {
                name = "GetEnumItems",
                type = "type.library",
                value = {
                    type = "type.function",
                    args = {
                        type = "type.list",
                        funcargs = true,
                        {
                            [1] = "Enum",
                            type = "type.name",
                            paramName = { "self" },
                        },
                    },
                    returns = {
                        type = "type.table",
                        { type = "type.name", [1] = "Enum." .. enumName },
                    },
                },
            },
        }
        local child = {
            name = enumName,
            type = "type.library",
            kind = "field",
            value = {
                [1] = "Enum",
                type = "type.name",
                child = items,
            },
        }
        for _, item in ipairs(def.values) do
            items[#items + 1] = {
                name = item,
                type = "type.library",
                kind = "field",
                value = {
                    [1] = "Enum." .. enumName,
                    type = "type.name",
                },
            }
            api.object["Enum." .. enumName] = {
                ref = {
                    {
                        name = "EnumType",
                        type = "type.library",
                        value = child.value,
                    },
                },
                child = api.object["EnumItem"].child,
            }
        end
        util.setTypeParent(child)
        enumRoot.value.child[#enumRoot.value.child + 1] = child
    end
    api.object["Enums"] = typeObject(enumRoot.value.child)
    api.global["Enum"] = {
        name = "Enum",
        kind = "global",
        type = "type.library",
        description = "所有枚举的命名空间。",
        value = tp("Enums"),
    }
    util.setTypeParent(api.global["Enum"])

    -- typeof()/type() 校验枚举（原 parseEnums 职责，缺失会导致 invalid-class-name 诊断崩溃）
    local typeEnums = {}
    for name in pairs(api.object) do
        if name ~= "any" and not m.ClassNames[name] then
            typeEnums[#typeEnums + 1] = {
                text = "\"" .. name .. "\"",
                label = "\"" .. name .. "\"",
            }
        end
    end
    api.global["typeof"].value.enums = typeEnums
    api.global["type"].value.enums = {}
    for _, name in ipairs({
        "table", "string", "number", "boolean", "function", "nil", "thread", "userdata",
    }) do
        api.global["type"].value.enums[#api.global["type"].value.enums + 1] = {
            text = "\"" .. name .. "\"",
            label = "\"" .. name .. "\"",
        }
    end

    -- Color 构造函数的颜色预览支持（color-picker 依赖 special）
    local colorGlobal = api.global["Color"]
    if colorGlobal and colorGlobal.value then
        for _, field in ipairs(colorGlobal.value) do
            if field.key then
                local n = field.key[1]
                if n == "FromRGB" or n == "FromRGBA" then
                    field.value.special = "Color." .. n
                end
            end
        end
    end
end

return m
