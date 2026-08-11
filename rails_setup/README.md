# Rails Server Setup

AMASPMS Ubuntu 新機安裝流程，使用 nginx.org Nginx、Puma、rbenv、Node.js/Yarn，以及選配的 MySQL/PHP。此流程不使用 Passenger 或 `nginx-extras`。

## 架構

```text
HTTP/HTTPS -> Nginx -> 127.0.0.1:PUMA_PORT -> Puma -> Rails
```

- Nginx：TLS、靜態檔案、安全 headers、CSP、WebSocket 與 reverse proxy。
- Puma：以 application user 的 `systemd --user` service 執行。
- Rails：由 RD 部署至 `APP_CURRENT`。
- phpMyAdmin：不自動下載，僅準備 PHP-FPM、Nginx 範例與 Blowfish secret。

## 檔案

```text
rails_setup/
|-- install.sh                       # 基礎環境安裝
|-- install_dev_user_tools.sh        # 相容入口，轉交 host_setup 執行
|-- install_mssql_support.sh         # 選配 TinyTDS/FreeTDS system support
|-- configure_nginx.sh               # 產生、驗證及套用 application conf
|-- install_puma_service.sh          # Rails 就緒後安裝 Puma service
|-- setup.conf                       # 安裝參數
`-- setup_config/
    |-- nginx.conf                   # 主設定參考，不會自動套用
    |-- nginx-app.conf.template      # HTTPS Rails vhost
    |-- nginx-app-http.conf.template # HTTP Rails vhost
    |-- nginx-phpmyadmin.conf.example
    |-- puma.rb.template
    `-- puma.service.template
```

## 前置條件

- Ubuntu 22.04 或 24.04。
- 以 application user 執行，該帳號需要 sudo 權限。
- 執行前確認 `setup.conf`。
- `ENABLE_SSL="yes"` 時，必須先準備正式 hostname、full-chain certificate 與 private key。

主要設定：

```bash
APP_NAME="myapp"
APP_CURRENT="${HOME}/${APP_NAME}/current"
SERVER_NAME="app.example.com"
PUMA_PORT="3000"

ENABLE_SSL="yes"
SSL_CERTIFICATE="/etc/nginx/ssl/myapp.fullchain.pem"
SSL_CERTIFICATE_KEY="/etc/nginx/ssl/myapp.key"

RUBY_VERSION="3.3.6"
RAILS_VERSION="7.2.2"

INSTALL_MYSQL="yes"
INSTALL_PHP="yes"
```

若新機需要先提供 HTTP 以申請憑證，使用：

```bash
ENABLE_SSL="no"
```

取得憑證後改回 `yes`，再執行 `configure_nginx.sh`。

## 操作步驟

### 1. 基礎安裝

```bash
chmod +x install.sh configure_nginx.sh install_puma_service.sh
./install.sh
```

安裝內容包括：

1. Ubuntu dependencies。
2. nginx.org repository 與 Nginx。
3. 選配 MySQL、PHP-FPM。
4. Node.js LTS 與 Yarn。
5. rbenv、ruby-build、Ruby、Bundler 與 Rails。
6. `/etc/nginx/conf.d/<APP_NAME>.conf`。
7. `~/server-setup` 後續維護檔案。

腳本不會取代 `/etc/nginx/nginx.conf`。如需調整主設定，僅參考 `setup_config/nginx.conf` 後人工處理。

此階段 Puma 尚未啟動，因此 Rails request 可能回傳 `502 Bad Gateway`。

### 2. RD 部署 Rails

將專案準備至 `APP_CURRENT`，例如：

```text
/home/amastek/myapp/current
```

依專案需求完成：

```bash
bundle install
yarn install
RAILS_ENV=production bundle exec rails assets:precompile
```

Credentials、environment variables、database 建立及 migration 不由本套腳本處理。

### 3. 安裝 Puma service

```bash
~/server-setup/install_puma_service.sh
```

執行前會檢查 `Gemfile`、bundle、Puma 及 Rails production boot。既有的 `config/puma.rb` 不會被覆蓋。

### 4. 後續調整 Nginx

修改：

```text
~/server-setup/setup.conf
```

然後執行：

```bash
~/server-setup/configure_nginx.sh
```

適用於修改 hostname、Puma port、proxy timeout、SSL 模式或憑證路徑。工具會：

- 備份既有 application conf。
- 產生 HTTP 或 HTTPS vhost。
- 執行 `nginx -t`。
- 驗證失敗時還原舊設定。
- 對運行中的 Nginx 執行 reload，否則 start。

## Nginx 安全設定

Rails vhost 包含 WebSocket headers、proxy timeouts、`X-Content-Type-Options`、`Referrer-Policy`、`Permissions-Policy` 與 CSP。

目前 CSP 以相容既有 Rails 專案為優先，仍允許 inline script/style 與 `unsafe-eval`。正式上線前應依專案實際使用的 CDN、API、WebSocket、iframe 與前端套件逐步收緊。

## 額外開發帳號

若同一台非正式環境 server 已執行過 `install.sh`，要讓另一個 Linux user 自行管理 Ruby 與 Node.js，請切換到該 user，從完整 repository 執行標準入口：

```bash
chmod +x host_setup/install_rbenv_nvm.sh
host_setup/install_rbenv_nvm.sh
```

這支腳本只在目前 user 的 home directory 安裝或更新：

- `~/.rbenv`
- `~/.rbenv/plugins/ruby-build`
- `~/.nvm`
- 對應的 `~/.bashrc` 初始化設定

它不使用 sudo、不安裝 apt packages，也不安裝任何 Ruby、Rails、Node.js 或 Yarn 版本。使用者重新登入後，依專案需求自行執行 `rbenv install` 與 `nvm install`。

`rails_setup/install_dev_user_tools.sh` 是舊指令的相容 wrapper；唯一實作位於 `host_setup/install_rbenv_nvm.sh`。

`rails_setup` 選用 rbenv + nvm 作為開發帳號標準，以便和正式環境的 Ruby 管理方式一致。mise 與 asdf 能提供類似功能，但不在此目錄同時維護；其舊腳本保留於 `amaspms/` 供評估與歷史環境使用。

## 選配 MSSQL 支援

標準環境使用 MySQL。只有 Rails project 使用 `tiny_tds` 與 `activerecord-sqlserver-adapter` 時，才需要額外執行：

```bash
chmod +x install_mssql_support.sh
./install_mssql_support.sh
```

若 Rails project 已部署，可傳入 project 路徑並一併檢查 TinyTDS native extension：

```bash
./install_mssql_support.sh /home/amastek/myapp/current
```

腳本安裝 Ubuntu 的 `freetds-bin`、`freetds-dev` 與 `libsybdb5`，並驗證 `tsql` 和 dynamic linker 中的 `libsybdb`。若 project bundle 已完整，還會執行 `require "tiny_tds"` 測試。

此腳本專門支援 TinyTDS 的 FreeTDS DB-Library 路線，不安裝 `unixodbc-dev`、`tdsodbc`、Microsoft ODBC Driver、`sqlcmd` 或 `bcp`，也不修改 `database.yml` 或保存 MSSQL credentials。

連線診斷範例：

```bash
TDSVER=auto tsql -H <mssql-host> -p 1433 -U <username>
```

密碼由 `tsql` 互動式詢問，不要把密碼放入 command line 或 shell history。

## phpMyAdmin

phpMyAdmin 必須從官方網站手動下載。`INSTALL_PHP="yes"` 時，安裝器會：

- 嘗試偵測 PHP-FPM socket。
- 產生 `~/server-setup/nginx-phpmyadmin.conf.example`。
- 產生 `~/server-setup/phpmyadmin-blowfish-secret.php`。

調整 phpMyAdmin hostname、安裝路徑、PHP-FPM socket、TLS certificate 與允許網段後，再複製到 `/etc/nginx/conf.d/`：

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Blowfish secret 檔案權限為 `600`。將其中設定貼入 phpMyAdmin `config.inc.php` 後刪除暫存檔。

phpMyAdmin 不應在缺少 HTTPS、來源限制或其他存取保護的情況下公開至 Internet。

## 維運指令

```bash
systemctl --user status <APP_NAME>-puma.service
systemctl --user restart <APP_NAME>-puma.service
journalctl --user -u <APP_NAME>-puma.service -f

sudo nginx -t
sudo systemctl reload nginx
```

## 不包含的工作

- Rails project deployment。
- Database schema、migration 或 customer data。
- HTTPS certificate 的申請與續期。
- phpMyAdmin 的下載、更新與移除。
- 客戶 secrets、private keys 或 Rails credentials 管理。
