---@type vm
local config      = require 'config'
local defaultlibs = require 'library.defaultlibs'
local files       = require 'files'
local guide       = require 'core.guide'
local api     = require 'library.api'
local vm          = require 'vm.vm'

function vm.getGlobals(key, uri, onlySet)
    local globals = {}
    for _, lib in pairs(api.global) do
        if key == "*" or lib.name == key then
            globals[#globals+1] = lib
        end
    end
    local dummyCache = vm.getCache 'globalDummy'
    for name in pairs(config.config.diagnostics.globals) do
        if key == '*' or name == key then
            if not dummyCache[key] then
                dummyCache[key] = {
                    type   = 'dummy',
                    start  = 0,
                    finish = 0,
                    [1]    = key
                }
            end
            globals[#globals+1] = dummyCache[key]
        end
    end
    if not uri or not files.exists(uri) then
        return globals
    end
    local ast = files.getAst(uri)
    if not ast then
        return globals
    end
    local fileGlobals = guide.findGlobals(ast.ast)
    local mark = {}
    for _, res in ipairs(fileGlobals) do
        if mark[res] then
            goto CONTINUE
        end
        if not onlySet or vm.isSet(res) then
            mark[res] = true
            if key == "*" or guide.getSimpleName(res) == key then
                globals[#globals+1] = res
            end
        end
        ::CONTINUE::
    end
    return globals
end

function vm.getGlobalSets(key, uri)
    return vm.getGlobals(key, uri, true)
end