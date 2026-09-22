---@type vm
local vm          = require 'vm.vm'
local api     = require 'library.api'

function vm.getLibraryName(source, deep)
    local defs = vm.getDefs(source, deep)
    for _, def in ipairs(defs) do
        if def.special then
            return def.special
        end
    end
    return nil
end

function vm.isGlobalLibraryName(name)
    if api.global[name] then
        return true
    end
end
