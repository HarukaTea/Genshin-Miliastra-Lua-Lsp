"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deactivate = exports.activate = void 0;
const vscode = require("vscode");
const languageserver = require("./languageserver");
function activate(context) {
    try {
        if (vscode.extensions.getExtension("sumneko.lua") != undefined) {
            vscode.window.showErrorMessage("插件 [Lua](https://marketplace.visualstudio.com/items?itemName=sumneko.lua) 已启用，这个插件与千星LSP冲突了");
        }
    }
    catch (err) {
        vscode.window.showErrorMessage(err);
    }
    languageserver.activate(context);
}
exports.activate = activate;
function deactivate() {
    languageserver.deactivate();
}
exports.deactivate = deactivate;
//# sourceMappingURL=extension.js.map