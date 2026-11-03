# 發布維護

## 開發預覽

先執行 `swift test` 與 `python3 scripts/check_dictionary.py`，再以 `python3 scripts/package.py` 產生本機架構 DMG。腳本預設 ad-hoc 簽署，明列尚未公證，不會啟用系統輸入法。

GitHub Actions 的 `Build and test macOS` 在 push / PR 執行；`Package preview DMG` 可手動執行，將產物附在 workflow artifact。Runner 架構決定 DMG 架構，不宣稱為 Universal 包。

公開 Release 應附 DMG、SHA256SUMS.txt、build-manifest.json 與明確的驗證／未驗證說明。0.1 使用 pre-release 標記。上傳後重新下載 DMG 並與本機 SHA-256 核對。

## 一般使用者版本的必要工作

1. 配置有效的 Developer ID Application 簽署身分。憑證與私鑰不可提交到儲存庫。
2. 使用 hardened runtime，從內層輸入法至外層 App 逐一簽署；打包腳本支援從 `SHUNTYPE_SIGN_IDENTITY` 讀取簽署身分，但仍需檢查實際簽署結果。
3. 依 Apple 文件以 `notarytool` 送審並等待 Accepted，為 App／DMG stapling 後再次驗證。更新 manifest 與 App／README 的簽署狀態，不能只改文字卻未完成公證。
4. 在下載含 quarantine 標記的真實檔案上測試 Gatekeeper，不只測本機自行建置的 App。
5. 完成 docs/VALIDATION.zh-Hant.md 列出的 IMK、跨 App、不同 macOS、安裝／升級／移除接受測試。

目前的 workflow 不保存或要求任何 Apple 憑證；它產生的是預覽包，不是自動公證的穩定版。
