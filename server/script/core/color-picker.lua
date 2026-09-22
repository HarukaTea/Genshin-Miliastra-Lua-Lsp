local files = require 'files'
local guide = require 'core.guide'
local vm = require 'vm'

local COLOR_CONSTRUCTORS = {
    ["Color.FromRGB"] = true,
    ["Color.FromRGBA"] = true,
}

local function documentColor(uri)
    local ast = files.getAst(uri)
    if not ast then
        return
    end
    local results = {}
    guide.eachSourceType(ast.ast, "call", function(source)
        for _, def in ipairs(vm.getDefs(source.node)) do
            def = guide.getObjectValue(def) or def
            if def.special then
                if COLOR_CONSTRUCTORS[def.special] then
                    local rgb = {}
                    if source.args then
                        for i, arg in ipairs(source.args) do
                            if arg.type == "number" then
                                rgb[i] = arg[1]
                            elseif vm.getInferType(arg) == "number" then
                                rgb[i] = vm.getInferLiteral(arg) or 0
                            else
                                return
                            end
                        end
                    end
                    for i, num in pairs(rgb) do
                        rgb[i] = num / 255
                    end
                    results[#results+1] = {
                        range = files.range(uri, source.start, source.finish),
                        color = {
                            red = rgb[1] or 0,
                            green = rgb[2] or 0,
                            blue = rgb[3] or 0,
                            alpha = 1
                        }
                    }
                    break
                end
            end
        end
    end)
    if #results == 0 then
        return nil
    end
    return results
end

local function colorPresentation(params)
    local uri = params.textDocument.uri
    local ast = files.getAst(uri)
    if not ast then
        return
    end
    local offsetStart, offsetFinish = files.unrange(uri, params.range)
    local func = nil
    local source = guide.eachSourceBetween(ast.ast, offsetStart, offsetFinish, function(source)
        if source.type == "call" then
            for _, def in ipairs(vm.getDefs(source.node)) do
                def = guide.getObjectValue(def) or def
                if def.special and COLOR_CONSTRUCTORS[def.special] then
                    func = def
                    return source
                end
            end
        end
    end)
    if not source then
        return
    end
    local color = params.color
    for i, num in pairs(color) do
        color[i] = tostring(math.floor(num * 255))
    end
    local rgb, start, finish
    if source.args then
        rgb = ("%s, %s, %s"):format(color.red, color.green, color.blue)
        start = source.args.start + 1
        finish = source.args.finish - 1
    else
        rgb = ("(%s, %s, %s)"):format(color.red, color.green, color.blue)
        start = source.node.finish + 1
        finish = source.finish
    end
    return {
        {
            label = rgb,
            textEdit = {
                range = files.range(uri, start, finish),
                newText = rgb
            }
        }
    }
end

return {
    documentColor = documentColor,
    colorPresentation = colorPresentation
}
