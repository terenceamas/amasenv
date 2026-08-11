# 腳本盤點

本文件記錄目錄中的腳本用途與目前建議。狀態仍需配合實機驗證更新。

## AMASCORE

| 腳本 | 初步用途 | 建議狀態 |
|---|---|---|
| `amascore_env.sh` | AMASCORE 通用／早期 Ubuntu 環境 | legacy/unverified |
| `amascore_env18.sh` | Ubuntu 18.04 環境 | unsupported candidate |
| `amascore_env20.sh` | Ubuntu 20.04 環境 | maintenance/unverified |
| `amascore_env_python.sh` | 含 Python 需求的環境 | unverified |
| `amascore_wsl.sh` | WSL 環境 | legacy/unverified |
| `amascore_env_ror*.sh` | AMASCORE 名稱下的 Rails 環境 | 需釐清產品歸屬 |
| `amascore_rbenv*.sh` | AMASCORE 名稱下的 rbenv/Rails 安裝 | 需釐清產品歸屬 |

`amascore_env_ror*` 與 `amascore_rbenv*` 雖以 AMASCORE 命名，內容屬 Rails 安裝流程。後續應由維護人員確認它們是 AMASCORE 附屬 Web UI，或其實應歸 AMASPMS。

## AMASPMS rbenv

| 腳本 | 初步用途 | 建議狀態 |
|---|---|---|
| `rbenv_nginx.sh` | rbenv、Nginx、Passenger | legacy |
| `rbenv_apache.sh` | rbenv、Apache、Passenger | legacy |
| `rbenv_only.sh` | 單獨安裝 rbenv/Ruby | maintenance/unverified |
| `rbenv18.sh` | 舊 Ubuntu/rbenv 流程 | legacy |
| `rbenv_install.sh` | 舊 rbenv 安裝 | legacy |
| `rbenv_lite.sh` | 精簡 rbenv 安裝 | legacy |
| `rbenv_ror5.sh` | Rails 5 相關安裝 | legacy |

## AMASPMS mise

| 腳本 | 初步用途 | 建議狀態 |
|---|---|---|
| `mise_nginx.sh` | mise、Nginx、Puma 安裝原型 | experimental/unverified |
| `only_mise.sh` | 單獨安裝 mise/runtime | experimental/unverified |

## AMASPMS asdf

| 腳本 | 初步用途 | 建議狀態 |
|---|---|---|
| `asdf_install.sh` | asdf runtime 安裝流程 | legacy/unverified |

## AMASPMS common

| 檔案 | 初步用途 | 建議狀態 |
|---|---|---|
| `nginx-upgrade.sh` | nginx.org repository／升級片段 | maintenance，執行前需更新 |
| `apache_upgrade.sh` | Apache 升級片段 | unverified |
| `only_passenger.sh` | 單獨安裝 Passenger | legacy |
| `nginx_php` | PHP Nginx 設定片段 | reference/legacy |
| `nginx_ror` | Rails Nginx 設定片段 | reference/legacy |

## Rails setup

| 檔案 | 用途 | 建議狀態 |
|---|---|---|
| `install.sh` | AMASPMS 新機基礎安裝入口 | current candidate |
| `install_dev_user_tools.sh` | 非正式環境額外 user 的 rbenv、ruby-build、nvm bootstrap | current candidate |
| `install_mssql_support.sh` | TinyTDS 專案的 FreeTDS system dependencies 與驗證 | current candidate |
| `configure_nginx.sh` | Rails vhost 產生、驗證與套用 | current candidate |
| `install_puma_service.sh` | 專案就緒後安裝 Puma service | current candidate |
| `setup_config/*` | Nginx/Puma templates 與參考設定 | current candidate |

## 待確認事項

1. `amascore_env_ror*` 與 `amascore_rbenv*` 的實際產品歸屬。
2. AMASCORE 目前正式支援的 Ubuntu 最低版本。
3. AMASPMS 是否正式統一採用 rbenv，或未來改以 mise 為標準。
4. Passenger 是否仍有客戶主機必須維護。
5. Rails 5／Ruby 2.x 客戶環境的維護期限。
6. `nginx-upgrade.sh` 是否要發展成獨立且具備 rollback 的維護工具。
