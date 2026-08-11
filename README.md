# AMAS Environment Setup

You can download with following link
https://is.gd/amasenv
https://bit.ly/amasenv

公司內部 Ubuntu 環境建置與維護腳本，依產品分為：

- `amascore/`：AMASCORE（SCADA、C++）環境腳本。
- `amaspms/`：AMASPMS（Ruby on Rails）歷史腳本，依 Ruby 版本管理工具分類。
- `rails_setup/`：目前整理中的 AMASPMS 標準新機安裝流程。
- `doc/`：目錄規範、支援矩陣與現有腳本盤點。

## 專案架構

```text
amasenv/
|-- amascore/                 # AMASCORE 安裝腳本
|-- amaspms/
|   |-- rbenv/                # rbenv 版本的 AMASPMS 腳本
|   |-- mise/                 # mise 版本的 AMASPMS 腳本
|   |-- asdf/                 # asdf 版本的 AMASPMS 腳本
|   `-- common/               # Nginx、Apache、Passenger 共用維護工具
|-- rails_setup/              # 新版 Nginx + Puma + rbenv 安裝流程
`-- doc/
```

詳細整理原則請見 [doc/project-organization.md](doc/project-organization.md)，現有腳本用途請見 [doc/script-inventory.md](doc/script-inventory.md)。

## AMASPMS 新機架構

```text
Client
  |
  | HTTP/HTTPS
  v
nginx.org Nginx
  |
  | 127.0.0.1:PUMA_PORT
  v
Puma (systemd --user)
  |
  v
Rails application
```

標準流程使用 rbenv 管理 Ruby，Nginx 負責 TLS、靜態檔案與 reverse proxy，Puma 僅監聽 localhost。MySQL 與 PHP 為選配；phpMyAdmin 仍由人員從官方網站手動下載及安裝。

## AMASPMS 新機快速操作

支援範圍與詳細說明請先閱讀 [rails_setup/README.md](rails_setup/README.md)。基本流程如下。

### 1. 設定參數

編輯：

```text
rails_setup/setup.conf
```

至少確認 application 名稱、路徑、hostname、SSL 模式、憑證路徑、Ruby/Rails 版本，以及 MySQL/PHP 選項。

新機尚未取得憑證時可先使用：

```bash
ENABLE_SSL="no"
```

### 2. 安裝基礎環境

以 application user 執行，不要使用 root：

```bash
cd rails_setup
chmod +x install.sh configure_nginx.sh install_puma_service.sh
./install.sh
```

腳本會安裝系統套件、Nginx、Ruby、Rails、Node.js，以及選配的 MySQL/PHP，並在 `~/server-setup` 建立後續維護檔案。

### 3. 部署 Rails 專案

由 RD 將專案準備至 `APP_CURRENT`，並完成專案需要的 bundle、assets、credentials 與 database 作業。

### 4. 啟用 Puma

```bash
~/server-setup/install_puma_service.sh
```

### 5. 調整 Nginx 或啟用 SSL

修改 `~/server-setup/setup.conf` 後執行：

```bash
~/server-setup/configure_nginx.sh
```

該工具只管理 `/etc/nginx/conf.d/<APP_NAME>.conf`，不會取代 `/etc/nginx/nginx.conf`。

### 非正式環境增加開發帳號

server 已完成基礎安裝後，切換到新的開發 user，執行：

```bash
cd rails_setup
./install_dev_user_tools.sh
```

腳本只為目前 user 安裝 rbenv、ruby-build 與 nvm；Ruby、Rails 和 Node.js 版本由該 user 後續自行安裝。

## 維護原則

- 執行前先確認腳本支援的 Ubuntu 與套件版本。
- 客戶專屬 hostname、密碼、private key、憑證與 secrets 不得提交 Git。
- 既有客戶主機不可直接套用新機安裝腳本；元件升級需先盤點現況與備份。
- 搬移或重新命名舊腳本時先維持內容不變，功能修改另外提交。
- 尚未完成驗證的歷史腳本視為 legacy，不作為新機預設入口。

## 文件

- [目錄與整理原則](doc/project-organization.md)
- [支援與驗證矩陣](doc/compatibility.md)
- [腳本盤點](doc/script-inventory.md)
- [Rails server 詳細操作](rails_setup/README.md)
