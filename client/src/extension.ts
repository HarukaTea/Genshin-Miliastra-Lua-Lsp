import * as vscode from 'vscode'
import * as languageserver from './languageserver';

export function activate(context: vscode.ExtensionContext) {
    try {
        if (vscode.extensions.getExtension("sumneko.lua") != undefined) {
            vscode.window.showErrorMessage("插件 [Lua](https://marketplace.visualstudio.com/items?itemName=sumneko.lua) 已启用，这个插件与千星奇域LSP冲突了");
        }
    } catch (err) {
        vscode.window.showErrorMessage(err);
    }

    languageserver.activate(context);
}

export function deactivate() {
    languageserver.deactivate();
}
