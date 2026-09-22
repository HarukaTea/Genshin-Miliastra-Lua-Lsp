local util = require 'utility'
local defaultlibs

local m = {}

-- 把父类的成员合并进子类（千星控件继承自 ClientUIBaseControl）
local function addSuperMembers(class, superClass, mark)
    if not m.object[superClass] then
        return
    end
    if not mark then
        mark = {}
        for _, child in ipairs(m.object[class].child) do
            mark[child.name] = true
        end
    end
    for _, child in ipairs(m.object[superClass].child) do
        if not mark[child.name] then
            mark[child.name] = true
            table.insert(m.object[class].child, child)
        end
    end
    addSuperMembers(class, m.ClassNames[superClass], mark)
end

function m.isA(class, super)
    if not class then
        return
    end
    if class == super then
        return true
    elseif m.ClassNames[class] then
        if m.ClassNames[class] == super then
            return true
        else
            return m.isA(m.ClassNames[class], super)
        end
    end
    return false
end

local function loadMeta()
    local state = require("parser"):compile(util.loadFile(ROOT / "def" / "meta.luau"), "lua")
    if state then
        for _, object in ipairs(state.ast.types[1].value) do
            if m.object[object.key[1]] then
                m.object[object.key[1]].meta = {
                    type = "metatable",
                    value = object.value
                }
            end
        end
    end
end

function m.init()
    defaultlibs = require("library.defaultlibs")
    defaultlibs.init()

    m.global = util.deepCopy(defaultlibs.global)
    m.object = util.deepCopy(defaultlibs.object)

    local miliastra = require("library.miliastra")
    local ok, err = xpcall(miliastra.apply, function (e)
        return debug.traceback(e, 2)
    end, m)
    if not ok then
        log.error('miliastra apply failed: ' .. tostring(err))
    end
    m.ClassNames = miliastra.ClassNames
    for class, superClass in pairs(m.ClassNames) do
        if m.object[class] then
            addSuperMembers(class, superClass)
        end
    end
    loadMeta()

    require("vm").flushCache()
end

return m
