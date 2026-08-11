# Rails Server Setup

Ubuntu Rails server bootstrap for:

- nginx.org Nginx
- Nginx reverse proxy
- Puma
- `systemd --user`
- rbenv / ruby-build
- Node.js / Yarn
- Optional MySQL / PHP

Passenger and `nginx-extras` are intentionally not used.

## Repository layout

```text
rails_server_setup/
├── install.sh
├── install_puma_service.sh
├── setup.conf
└── setup_config/
    ├── nginx.conf
    ├── nginx-app.conf.template
    ├── puma.rb.template
    └── puma.service.template
```

## 1. Configure

Edit `setup.conf`.

Important values:

```bash
APP_NAME="myapp"
APP_ROOT="${HOME}/${APP_NAME}"
APP_CURRENT="${APP_ROOT}/current"
SERVER_NAME="_"
PUMA_PORT="3000"

RUBY_VERSION="3.3.6"
RAILS_VERSION="7.2.2"
```

## 2. Base installation

Run as the application user:

```bash
chmod +x install.sh install_puma_service.sh
./install.sh
```

The base installer:

1. Installs system dependencies.
2. Configures the nginx.org repository.
3. Installs Nginx.
4. Installs optional MySQL/PHP.
5. Installs Node.js/Yarn.
6. Installs rbenv, Ruby and Rails.
7. Installs the Nginx reverse-proxy configuration.
8. Creates Puma staging files under `~/server-setup`.

Nginx is configured immediately, but Puma is not installed or started yet.

Before Puma starts, requests requiring Rails may return `502 Bad Gateway`.

## 3. RD deploys the Rails project

The expected path is:

```text
APP_CURRENT
```

For example:

```text
/home/amastek/myapp/current
```

RD should finish project preparation first, including project-specific steps such as:

```bash
bundle install
yarn install
RAILS_ENV=production bundle exec rails assets:precompile
```

Database preparation is project-specific and is not performed by these scripts.

## 4. Install Puma service

After the Rails application is ready:

```bash
~/server-setup/install_puma_service.sh
```

The Puma installer checks:

- application directory
- `Gemfile`
- `bundle check`
- Puma availability
- Rails production boot

It then:

- installs `config/puma.rb` only if the project does not already have one
- installs the user systemd service
- enables the service
- enables `loginctl` linger
- starts Puma
- verifies `127.0.0.1:PUMA_PORT`

Nginx does not need to be restarted or reloaded.

## Notes

### HTTPS

HTTPS configuration is intentionally deployment-specific. Add certificates and the HTTPS `server` block according to the target environment.

### Existing `config/puma.rb`

The installer does not overwrite an existing application `config/puma.rb`.

### Git management

Keep environment-independent defaults and templates in Git. For customer-specific secrets, certificates, passwords, and private keys, do not commit them to the repository.
