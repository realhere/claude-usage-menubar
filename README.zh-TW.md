# Claude Usage（選單列）

[English](README.md) · **繁體中文**

一個小巧的 macOS 選單列 app，讓你一眼看到目前的 Claude 訂閱用量 —— 不用再打開設定選單。

![Claude 用量選單列 app](screenshot.png)

選單列會顯示精簡摘要，點開看完整明細：

```
▮▮▮ 5H 20% | W 12% | F 10%
```

點開後有彩色進度條與重置時間：

- **5 小時**用量（滾動的短時段限制）
- **週**用量（整體）
- 各模型的週用量（例如 **Fable**），在 API 有回報時顯示

進度條顏色：綠（< 50%）、橙（50–79%）、紅（≥ 80%）。每 5 分鐘自動更新。app 只存在於選單列（不佔 Dock），並會在登入時自動啟動。介面雙語:會依你的 macOS 系統語言自動顯示英文或繁體中文。

## 系統需求

- **macOS 12 以上**
- **Xcode Command Line Tools**（提供 `swiftc`）：`xcode-select --install`
- 已安裝並**登入**的**桌面版 Claude app**（本程式會讀取它在本機的登入狀態來驗證 —— 見下方「運作原理」）

## 安裝

### 方式 A — 下載 app（最快）

1. 從 [最新 release](https://github.com/realhere/claude-usage-menubar/releases/latest) 下載 `ClaudeUsage-v1.0-macos.zip` 並解壓縮。
2. 把 `ClaudeUsage.app` 移到 `/Applications`。
3. 首次開啟：**在 app 上按右鍵 → 打開 → 打開**。（本程式開源但未經 Apple 公證，所以 macOS Gatekeeper 會問一次。或到「系統設定 → 隱私權與安全性 → 仍要打開」。）
4. 它會出現在選單列。想要登入時自動啟動，到「系統設定 → 一般 → 登入項目」加入它 —— 或改用方式 B。

### 方式 B — 從原始碼建置（推薦；完整設定）

```bash
git clone https://github.com/realhere/claude-usage-menubar.git
cd claude-usage-menubar
./install.sh
```

腳本會建置一個小巧的 `.app`、安裝到 `~/Applications`，並設定 LaunchAgent 讓它在登入時自動啟動、當機時自動重啟。首次啟動時 macOS 可能會要求鑰匙圈存取權（用來讀取 Claude app 的 cookie）—— 按**允許**即可。

## 解除安裝

```bash
./uninstall.sh
```

## 運作原理

Claude 沒有公開的用量 API，所以本程式讀取和 Claude 網頁版相同的資料：

1. 從 `~/Library/Application Support/Claude/Cookies`（本機的 SQLite 檔）讀取桌面版 Claude app 的 **cookie**，並用 macOS **登入鑰匙圈**裡的 *「Claude Safe Storage」* 金鑰解密 —— 這和 Chrome／Electron app 處理自己 cookie 的機制相同。
2. 帶著這些 cookie 呼叫**官方的** `claude.ai` 用量端點（`/api/organizations/{org}/usage`，正是網頁版使用的那個），取回你的用量百分比。

## 隱私與安全

- 你的 session key **只會**送往 `claude.ai` 官方端點，**絕不**存到磁碟、**絕不**送往其他任何地方。
- 本機只會寫入一份「最後一次各模型百分比」的小快取（`~/ClaudeUsage/model_cache.json`）與一個選用的除錯 log —— 不含任何憑證。
- 這個 app 做的每一件事都在這個 repo 裡。讀一下 `usage_helper.py`（約 150 行）—— 很短、可自行審閱。

## 限制與已知問題

- **僅支援 macOS。**
- **需要安裝並登入桌面版 Claude app。**
- 使用的是**未公開**的 `claude.ai` 端點，隨時可能改版或失效 —— 這是非官方工具的本質。若用量讀不到，可能是 API 改了；可對照網頁版的開發者工具 Network 分頁確認端點。
- 驗證依賴桌面版 app 維持它的 Cloudflare clearance cookie。如果你長時間完全關閉桌面版 Claude app，選單列可能短暫顯示錯誤，重新打開它即可恢復。
- `usage_helper.py` 裡寫死的 **User-Agent** 對應某個桌面版 app 版本。桌面版大版本更新後，你可能需要更新 `usage_helper.py` 最上方的 `UA` 字串。

## 自訂

- 更新頻率：改 `main.swift` 裡的 `refreshInterval`。
- 選單列圖示：改 `main.swift` 裡的 `chart.bar.xaxis`（SF Symbol 名稱）。
- 改完後重新建置：`./install.sh`。

## 授權

MIT —— 見 [LICENSE](LICENSE)。

## 免責聲明

本專案與 Anthropic 無關，未經其授權或背書。「Claude」是 Anthropic 的商標。這是一個非官方、供個人使用的工具，只從你自己的機器讀取你自己帳號的用量。使用風險自負；你必須自行遵守 Anthropic 的服務條款。
