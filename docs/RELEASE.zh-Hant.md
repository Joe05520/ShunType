# ShunType 0.1.0-preview.2

Fixes input-method packaging and a startup crash found during local installation. The app editor and text recovery remain available. System input is experimental; physical-keyboard input across apps still needs acceptance testing.

- Write the required InputMethodKit metadata into the packaged input method. Earlier bundles omitted these fields and were classified under English.
- Use bundle-based IMKServer initialization. The controller-class initializer crashed inside _IMKServerLegacy on the tested macOS 27 host.
- Check both signed, packaged executables before creating the DMG. The input-method check covers server startup and text delivery to a synthetic client without selecting an input source.
- Replace interface slogans with functional labels. Put English first in the README, followed by Traditional Chinese.
- Mark system input as experimental and confirm before selecting it. Keep the return-to-ABC control.

Build number 3. Apple Silicon (arm64), macOS 14 deployment target; tested on macOS 27. Ad-hoc signed, not notarized by Apple. Gatekeeper may block downloaded copies. No security settings need to be disabled.

Open the DMG, drag ShunType.app to Applications, and use the app's typing editor or text recovery. Keep your existing input methods for daily typing. The startup and synthetic-client checks do not prove that the earlier inability to type has been resolved in real apps. See the [validation record](https://github.com/Joe05520/ShunType/blob/main/docs/VALIDATION.zh-Hant.md) for the scope.

## 繁體中文

修正本機安裝時發現的輸入法封裝錯誤與啟動崩潰。App 內試打與文字還原可用；系統輸入仍為實驗功能，跨 App 的實體鍵盤驗收尚未完成。

- 將必要的 InputMethodKit 設定寫入輸入法封裝。舊包漏寫設定，被系統列在英文分類。
- 改回依 bundle identifier 初始化 IMKServer；明確控制器初始化方式在已測 macOS 27 主機會崩潰。
- 建立 DMG 前，對已簽署的 App 與輸入法執行檢查。輸入法檢查包含啟動及模擬文字框輸出，不切換系統輸入來源。
- 介面改用功能名稱；README 改為英文在前、繁體中文在後。
- 標示系統輸入仍在測試，選用前需確認；保留「切回 ABC」。

Build number 為 3。Apple Silicon（arm64），部署目標 macOS 14，實測 macOS 27。採 ad-hoc 簽署，尚未 Apple 公證，下載版可能被 Gatekeeper 阻擋。無需關閉系統安全防護。

開啟 DMG，將 ShunType.app 拖到「應用程式」，先使用 App 內試打或文字還原。日常打字請保留原本輸入法。啟動及模擬文字框檢查通過，不代表已完整修復真實 App 中無法打字的情境；已測與未測範圍見驗證紀錄。
