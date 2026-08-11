# 專案目錄與整理原則

## 分類方式

此 repository 先依產品分類，再依安裝工具或用途分類：

```text
amascore/       AMASCORE（SCADA、C++）
amaspms/        AMASPMS 歷史與元件腳本
rails_setup/    AMASPMS 目前整理中的標準新機流程
doc/            專案文件
```

AMASPMS 歷史腳本依 Ruby 版本管理工具分類：

```text
amaspms/
|-- rbenv/
|-- mise/
|-- asdf/
`-- common/
```

`common/` 只放不隸屬單一 Ruby manager 的 Web server、Passenger 或元件維護腳本。

## 腳本狀態

文件中使用以下狀態：

- `current`：目前建議的新機入口，已具備明確文件與驗證流程。
- `maintenance`：仍可能用於既有客戶主機，但不建議新機使用。
- `legacy`：保留供查閱或舊機維護，執行前必須重新檢查。
- `unsupported`：已知 OS 或套件生命週期結束，不應再執行。
- `unverified`：用途可辨識，但尚未完成環境驗證。

## 整理規則

1. 搬移與功能修改分開進行，方便 Git review。
2. 第一輪搬移維持原檔名與內容，重新命名另開變更。
3. 每套 current 流程只能有一個清楚的入口 README。
4. 新機安裝與既有主機升級必須分開，不共用破壞性操作。
5. 共通邏輯成熟後才抽成 library，避免過早增加間接層。
6. 所有會修改 `/etc` 或 systemd 的腳本都應先檢查、備份並提供失敗還原方式。
7. 客戶 hostname、IP、password、certificate、private key、Rails credentials 與 database backup 不得提交 Git。

## 建議的後續結構

`rails_setup/` 穩定並正式成為 AMASPMS current 流程後，可再評估移入：

```text
amaspms/current/
```

在完成實機驗證及調整所有文件連結前，維持 `rails_setup/` 原位。

歷史腳本未來可再依狀態增加第二層目錄，但應先完成盤點：

```text
amaspms/rbenv/current-or-maintenance/
amaspms/rbenv/legacy/
```

目前不急著建立這些子目錄，以免在用途尚未確認前做出錯誤分類。

## 變更檢查清單

- 是否只修改本次目標範圍？
- 是否保留使用者既有變更？
- Shell script 是否通過 `bash -n`？
- 是否可重複執行？
- 是否會覆蓋既有設定？若會，是否備份與驗證？
- 是否明確列出支援的 Ubuntu／Ruby／Rails／Nginx 版本？
- README 與實際行為是否一致？
- 是否意外加入 customer secrets？
