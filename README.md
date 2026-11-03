# 順打 ShunType

**Mac＋標準注音的中英組字實驗。少切換，順著打。**

原生 macOS App，內含互動試打、注音亂碼還原，以及可另行安裝的 InputMethodKit 輸入法。MIT 開源，詞庫離線附帶，不需帳號、Python、API Key 或大型模型。

> **0.1 開發預覽，尚未 Apple 公證。** 已建置的 DMG 為 Apple Silicon / macOS 14+。本版仍需驗證系統輸入法的實際註冊與跨 App 相容性，不宣稱能在所有程式無痛取代既有輸入法。請保留系統 ABC 與原本的注音。

[下載開發預覽 DMG](https://github.com/Joe05520/ShunType/releases/tag/v0.1.0-preview.1) · [開發計畫](docs/PLAN.zh-Hant.md) · [驗證範圍](docs/VALIDATION.zh-Hant.md) · [發布說明](docs/RELEASE.zh-Hant.md)

![順打原生 App 互動試打畫面](docs/images/01-typing.png)

## 開始使用

1. 下載 DMG，把 **ShunType.app** 拖到 **Applications／應用程式**。
2. 開啟 App，在「試打」點一下輸入框，直接輸入按鍵。
3. 例如 `su3cl3` → 你好、`su3cl3a8` → 你好嗎、`5j/ eji6` → 中國。
4. Enter 確認組字；Esc 保留原始英數；↓ 或 Tab 換候選。
5. 需要在其他 App 使用時，閱讀「安裝與說明」，再決定是否新增原生輸入法。安裝後仍需到系統鍵盤設定加入、選用；部分系統可能需登出再登入。

開發預覽採 ad-hoc 簽署。從網路下載後 Gatekeeper 可能阻擋；若系統不允許開啟，請等待正式 Developer ID 簽署與公證版本，不需要關閉系統安全防護。開源碼可供有 Xcode 的開發者自行建置。

## 三種模式

| 模式 | 行為 |
|---|---|
| 自動中英 | 有完整注音與足夠線索才轉換；單音節與有歧義字串保守保留 |
| 注音優先 | 對有效注音顯示中文，適合單字輸入及歧義情況 |
| 純英文 | 直接輸出英數，暫時略過注音判斷 |

原生輸入法以 **Control + \\** 輪換三種模式，也可從輸入法選單選擇。這是每個輸入工作階段的狀態，0.1 尚未提供跨 App 的持久偏好。

「還原文字」則可貼入已打錯的文字，檢查結果後自行複製。程式不會追溯改寫其他 App 的文件。

## 隱私與限制

- 不建立全域鍵盤監聽，不要求 Accessibility、螢幕錄製或完整磁碟存取。
- 不呼叫雲端 API，不上傳輸入，不記錄使用者打字內容；0.1 無學習歷史。
- 不輪詢剪貼簿。只有使用者按「複製結果」才寫入剪貼簿。
- 詞庫／規則仍可能選錯同音字；不是完整語意理解，也不是準確率保證。
- 標準大千注音、ANSI 英數實體鍵位；其他注音配置、非標準鍵盤與重新映射須另測。
- 自動模式不積極處理缺少第一聲分隔空白、拼錯聲調、純英文字母的短字串。
- 中文與英文直接黏在同一連續組字內時，0.1 可能保留整段原文；目前以空白／Enter 結束組字後混打最可靠。
- 第一個 Enter 結束組字，不替使用者送出訊息；下一個 Enter 交給原 App。
- 選用順打才會處理輸入；切到 ABC 後順打不介入。密碼與安全輸入交由 macOS 控制。
- 系統原生候選面板、直排、遠端桌面及特定 App 的復原語意仍需更多接受測試。

## 從原始碼建置

開發者需要 macOS 14+、Xcode Command Line Tools（Swift 6.0+）、Python 3（僅用於打包腳本）。使用者開啟已建置的 App 不需要這些工具。

```sh
swift test
swift run ShunTypeCheck 'su3cl3'
python3 scripts/package.py
```

產物位於 `outputs/`：App、DMG、SHA-256 核對檔與 build manifest。建置不會安裝或啟用輸入法。

本專案不依賴第三方套件管理器；已將固定版本詞庫放入資源。開發者需重建詞庫時才執行：

```sh
python3 scripts/prepare_dictionary.py
```

## 目錄

```text
Sources/ShunTypeCore/         按鍵解析、候選解碼、組字狀態機、離線詞庫
Sources/ShunType/             原生 SwiftUI / AppKit App、試打與安裝介面
Sources/ShunTypeInputMethod/  InputMethodKit 系統輸入法
Sources/ShunTypeCheck/        可重現核心檢查與效能量測
Tests/                       核心及狀態機測試
scripts/                     資料來源固定、圖示、App / DMG 打包
docs/                        規劃、限制與驗證證據
```

## 授權與致謝

順打程式碼採 [MIT](LICENSE)。注音資料取自 [McBopomofo](https://github.com/openvanilla/McBopomofo)，保留 [上游 MIT 授權](Sources/ShunTypeCore/Resources/McBopomofo-LICENSE.txt)；固定來源 commit、輸入雜湊與產生後雜湊見 [dictionary-source.json](Sources/ShunTypeCore/Resources/dictionary-source.json)。

本專案尚未做與其他產品的正式比較測試；「少切換」是產品目標，不是已證實的優越性主張。
