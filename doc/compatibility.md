# 支援與驗證矩陣

本文件區分「腳本程式碼宣告的支援範圍」與「實際完成驗證的環境」。只有完成實機或等效 VM 驗證後，才能在驗證欄標示通過。

## 目前矩陣

| 流程 | Ubuntu | Runtime／Web stack | 狀態 | 實機驗證 |
|---|---|---|---|---|
| `rails_setup` | 22.04 | rbenv、Nginx、Puma | current candidate | 待補 |
| `rails_setup` | 24.04 | rbenv、Nginx、Puma | current candidate | 待補 |
| `amascore_env20.sh` | 20.04 系列 | C++、Apache、MySQL、PHP | maintenance/unverified | 待補 |
| 其他 `amascore/` 腳本 | 多個舊 Ubuntu 版本 | C++／Rails 混合 | legacy/unverified | 待補 |
| `amaspms/rbenv/` | 多個舊 Ubuntu／Rails 版本 | rbenv、Passenger 或 Apache/Nginx | legacy | 待補 |
| `amaspms/mise/` | Ubuntu 20.04 之後的假設 | mise、Nginx、Puma | experimental/unverified | 待補 |
| `amaspms/asdf/` | 未明確 | asdf | legacy/unverified | 待補 |
| `host_setup/install_python.sh` | 22.04／24.04 | Ubuntu Python 3、pip、venv | current candidate | 待補 |
| `host_setup/install_docker.sh` | 22.04／24.04 | Docker CE、Buildx、Compose | current candidate | 待補 |
| `host_setup/install_rbenv_nvm.sh` | 已安裝 dependencies 的 Ubuntu host | rbenv、ruby-build、nvm | current candidate | 待補 |

`current candidate` 代表設計上預計成為 current，但尚需在公司標準 VM 與至少一套實際專案部署完成驗證。

## Rails setup 驗證項目

每個支援的 Ubuntu 版本至少驗證：

1. 全新 OS 執行 `install.sh`。
2. `ENABLE_SSL=no` 的 HTTP vhost。
3. `ENABLE_SSL=yes` 的 certificate/full-chain/private-key。
4. Nginx config rollback 與 reload。
5. Rails production boot 與 Puma user service。
6. 主機 reboot 後 Puma linger 自動啟動。
7. WebSocket／Action Cable。
8. assets、upload size 與長時間 request timeout。
9. CSP 對實際 AMASPMS 頁面、API、CDN 與前端套件的影響。
10. MySQL/PHP 選配開關。
11. PHP-FPM socket 偵測。
12. phpMyAdmin 人工安裝、存取限制與 Blowfish secret。
13. TinyTDS/FreeTDS 選配安裝、`tsql` 與 `libsybdb` 驗證。

## 驗證紀錄格式

完成驗證時記錄：

```text
Date:
Engineer:
Ubuntu:
Script commit:
Ruby / Rails:
Nginx / Puma:
Application:
Result:
Known issues:
```

不要只記錄「成功」，必須保存 commit、版本與已知限制，否則未來無法判斷套件更新是否造成差異。
