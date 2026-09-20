# Riftforge：瀏覽器遊玩版本

此專案的 `export_presets.cfg` 設定了 Godot 4.3 Web 匯出（單執行緒）。`.github/workflows/build-web.yml` 會在推送 `main` 後嘗試匯出網頁版本，並將 `riftforge-web` 上傳到 GitHub Actions 作為成品。

## 取得網頁版

1. 打開 GitHub 儲存庫的 **Actions → Build Godot Web**。
2. 如無執行紀錄，選 **Run workflow → Run workflow**。若 Actions 未啟用，先在 Settings → Actions 啟用。
3. 等待工作流程成功；若失敗，開啟失敗步驟取得日誌修正問題，請勿把失敗視為已可玩。
4. 在執行摘要最下方 **Artifacts** 下載 `riftforge-web`，解壓縮後應有 `index.html`、`.wasm`、`.pck` 等檔案。

## itch.io 網頁遊玩（不必公開 GitHub 原始碼）

1. 只將 Actions 取得的網頁輸出檔案打包成 ZIP：ZIP 的根目錄必須直接包含 `index.html`，不可多包一層資料夾。
2. 在 itch.io 建立新遊戲，Kind of project 選 **HTML**，上傳該 ZIP，啟用瀏覽器遊玩並儲存。
3. 可先設 Restricted / Draft 進行測試，確認載入、輸入、畫面、音效與存檔正常後再公開分享網址。

請勿把 Godot 專案原始 ZIP 當成 Web 版上傳：缺少匯出的 HTML、WebAssembly 與 PCK 就不能在瀏覽器執行。

## 另一選項：GitHub Pages

GitHub Free 帳號僅支援從公開儲存庫使用 GitHub Pages；GitHub Pro 等方案可從私人儲存庫發布網站。無論使用何種方案，發佈後網站內容通常可供任何人訪問。不要為了開 Pages 而未經確認就把此原始碼倉庫設為公開。另一選擇是部署匯出的 `index.html` 與其他 Web 檔案到支援靜態網站的服務。

注意：目前尚未完成瀏覽器實測，只有 Web 匯出與 CI 設定。遇到錯誤請保留 GitHub Actions 記錄或瀏覽器 F12 Console 訊息，逐項排除。
