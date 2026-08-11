# Host Setup

與 AMASCORE、AMASPMS 或特定 project 無關的 Ubuntu 主機工具。腳本目前支援 Ubuntu 22.04／24.04，必須由具備 sudo 權限的一般 user 執行，不要直接使用 root。

## Python

```bash
chmod +x install_python.sh
./install_python.sh
```

安裝 Ubuntu 提供的：

- Python 3
- pip
- venv
- Python development headers
- native extension build tools

腳本會建立暫時 virtual environment 驗證後刪除，不會安裝任何 project package，也不會修改或取代 Ubuntu system Python。

每個 project 應自行建立環境：

```bash
cd <project-directory>
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

## Docker

```bash
chmod +x install_docker.sh
./install_docker.sh
```

使用 Docker 官方 apt repository 安裝：

- Docker Engine／CLI
- containerd
- Buildx plugin
- Docker Compose plugin

預設會執行 `hello-world` 驗證，但不會建立 project container。若環境無法連線 Docker Hub，可略過下載測試：

```bash
RUN_HELLO_WORLD=no ./install_docker.sh
```

預設不將 user 加入 `docker` group。可信任的測試環境如需免 sudo 操作：

```bash
ADD_USER_TO_DOCKER_GROUP=yes ./install_docker.sh
```

加入後必須重新登入。`docker` group 可控制 Docker daemon，等同授予接近 root 的主機權限。

若偵測到 Ubuntu Docker、舊 Compose、Podman compatibility package、獨立 containerd 或 runc，腳本會停止並列出衝突套件，不會自動移除既有軟體或資料。

Docker 發布 container port 時可能繞過 UFW／firewalld 的一般規則。對外開放任何 port 前，必須另外檢查主機 firewall、雲端 security group 與 Docker `DOCKER-USER` chain。

## 不包含的工作

- Python project dependencies 或 virtual environment 管理。
- pyenv 或多 Python 版本管理。
- Docker image build、Compose deployment 或 registry login。
- Container volume、database、backup 或 production deployment。
- Firewall、proxy、daemon JSON 或 log rotation 的客戶專屬設定。
