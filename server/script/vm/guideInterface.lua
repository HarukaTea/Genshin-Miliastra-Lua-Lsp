---@type vm
local vm      = require 'vm.vm'
local files   = require 'files'
local ws      = require 'workspace'
local guide   = require 'core.guide'
local await   = require 'await'
local config  = require 'config'
local fs      = require 'bee.filesystem'
local furi    = require 'file-uri'
local proto   = require 'proto.proto'
local util    = require 'utility'

local m = {}

--- require 解析失败时只能从 `server/log` 里看出来，而用户通常看不到日志。
--- 这里把解析失败的原因直接弹到编辑器里，便于自查。
--- 每个模块只弹一次，且总量设上限，避免在遗留代码库里刷屏。
local notifiedRequire = {}
local notifiedCount = 0
local NOTIFY_LIMIT = 5

local function notifyOnce(key, message)
    if notifiedRequire[key] then
        return
    end
    notifiedRequire[key] = true
    if notifiedCount >= NOTIFY_LIMIT then
        return
    end
    notifiedCount = notifiedCount + 1
    -- 诊断代码可能在管道尚未就绪时被触发，弹窗失败绝不能影响类型推断本身
    pcall(proto.notify, 'window/showMessage', {
        type    = 2, -- Warning
        message = message,
    })
end

local function describeRequireFailure(reqScript)
    if type(reqScript) ~= 'string' then
        return
    end
    if #reqScript > 200 then
        return
    end

    local uris = ws.findUrisByRequirePath(reqScript)
    if not uris or #uris == 0 then
        -- 连文件都没定位到：说明路径与 runtime.path 模板不匹配，
        -- 或者文件落在忽略目录 / .gitignore 内
        notifyOnce('nomatch:' .. reqScript, table.concat({
            ('无法解析 require("%s")：找不到对应文件。'):format(reqScript),
            '请检查 miliastraLsp.runtime.path 是否覆盖该路径，',
            '以及该文件是否被 .gitignore、ignoreDir 或 files.exclude 忽略。',
        }, '\n'))
        return
    end

    -- 定位到了但取不到 AST：最常见的原因是文件超过 preloadFileSize 被跳过。
    -- 注意 bee.filesystem 没有 stat/file_size，这里沿用 files.lua 判断跳过时使用的同一条路径，
    -- 保证「报出来的大小」与「实际决定跳过的大小」完全一致。
    local uri = uris[1]
    local path = furi.decode(uri)
    local text = util.loadFile(path)
    local size = type(text) == 'string' and #text or nil
    local limit = config.config.workspace.preloadFileSize

    if size and size >= limit * 1000 then
        notifyOnce('toolarge:' .. reqScript, table.concat({
            ('require("%s") 的目标文件超过大小上限，没有被解析，因此无法补全其成员：'):format(reqScript),
            ('%s（%.1f KB，上限 %d KB）'):format(path, size / 1000.0, limit),
            '请调高 miliastraLsp.workspace.preloadFileSize，或直接打开该文件。',
        }, '\n'))
    else
        notifyOnce('noast:' .. reqScript, table.concat({
            ('require("%s") 的目标文件未能解析：%s'):format(reqScript, path),
            '可能是该文件存在语法错误，或尚未加载完成。',
        }, '\n'))
    end
end

function m.searchFileReturn(results, ast, index)
    local returns = ast.returns
    if not returns then
        return
    end
    for _, ret in ipairs(returns) do
        local exp = ret[index]
        if exp then
            vm.mergeResults(results, { exp })
        end
    end
end

--- 按 require 路径模板把模块名解析成目标文件的返回值。
---
--- 注意：不能沿用 guide.searchRefs(status, 字符串节点, 'def')。
--- 字符串字面量节点既没有 uri，guide.getStepRef 也没有 string 分支，
--- 因此那条路径必然返回空结果，require(...) 会被推断成 any，
--- 导致 `local M = require('x')` 之后 M 的成员无法补全。
--- 这里改用与 vm.interface.module（服务 ---@module 注解）相同、已验证可用的路径。
---@param moduleName string
---@param index integer
---@param myUri string|nil
local function resolveByRequirePath(moduleName, index, myUri)
    local results = {}
    local uris = ws.findUrisByRequirePath(moduleName)
    for _, uri in ipairs(uris) do
        if not myUri or not files.eq(myUri, uri) then
            local ast = files.getAst(uri)
            if not ast then
                -- 只被预加载扫描过、从未打开的文件在这里还没有 AST，
                -- 必须显式 load 一次，否则 require 仍然解析不出返回值。
                ws.load(uri)
                ast = files.getAst(uri)
            end
            if ast then
                m.searchFileReturn(results, ast.ast, index)
            end
        end
    end
    return results
end

function m.require(status, args, index)
    local reqScript = args and args[1]
    if not reqScript then
        return nil
    end
    local myUri = guide.getUri(reqScript)

    -- 首选：按 runtime.path 模板解析模块文件，取它的 return 表达式
    if reqScript.type == 'string' and type(reqScript[1]) == 'string' then
        local results = resolveByRequirePath(reqScript[1], index, myUri)
        if #results > 0 then
            return results
        end
    end

    -- 回退：走定义搜索，用于 ---@module 之类的显式模块声明
    local results = {}
    local newStatus = guide.status(status)
    guide.searchRefs(newStatus, reqScript, "def")
    local found = false
    for _, def in ipairs(newStatus.results) do
        if def.uri then
            if not files.eq(myUri, def.uri) then
                found = true
                if not files.exists(def.uri) then
                    ws.load(def.uri)
                end
                local ast = files.getAst(def.uri)
                if ast then
                    m.searchFileReturn(results, ast.ast, index)
                    break
                end
                -- 已定位到文件但取不到 AST：把原因浮到界面上
                describeRequireFailure(reqScript)
            end
        end
    end
    if not found then
        -- 两条路径都没解析出来，把原因浮到界面上
        describeRequireFailure(reqScript)
    end
    return results
end

vm.interface = {}

-- 向前寻找引用的层数限制，一般情况下都为0
-- 在自动完成/漂浮提示等情况时设置为5（需要清空缓存）
-- 在查找引用时设置为10（需要清空缓存）
vm.interface.searchLevel = 0

function vm.interface.call(status, func, args, index)
    if func.special == 'require' and index == 1 then
        await.delay()
        return m.require(status, args, index)
    end
end

function vm.interface.module(obj)
    local results = {}
    local myUri = guide.getUri(obj)
    local uris = ws.findUrisByRequirePath(obj.path)
    if #uris == 0 then
        local input = obj.path:gsub('%.', '/'):gsub('%%', '%%%%')
        for _, luapath in ipairs(config.config.runtime.path) do
            local path = fs.path(ws.normalize(luapath:gsub('%?', input)))
            if fs.exists(path) then
                local uri = furi.encode(fs.absolute(path):string())
                if uri then
                    ws.load(uri)
                    uris[#uris+1] = uri
                end
                break
            end
        end
    end
    for _, uri in ipairs(uris) do
        if not files.eq(myUri, uri) then
            local ast = files.getAst(uri)
            if ast then
                m.searchFileReturn(results, ast.ast, 1)
            end
        end
    end
    return results
end

function vm.interface.global(name, onlyDef, uri)
    await.delay()
    if onlyDef then
        return vm.getGlobalSets(name, uri)
    else
        return vm.getGlobals(name, uri)
    end
end

function vm.interface.docType(name)
    await.delay()
    return vm.getDocTypes(name)
end

function vm.interface.link(reqUri)
    await.delay()
    local links = {}
    local requires = files.getRequiring(reqUri)
    for _, uri in ipairs(requires) do
        links[#links+1] = requires[uri]
    end
    return links
end

function vm.interface.cache(options)
    await.delay()
    return vm.getCache('cache', options)
end

function vm.interface.getSearchDepth()
    return config.config.intelliSense.searchDepth
end

function vm.interface.pulse()
    await.delay()
end
