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
