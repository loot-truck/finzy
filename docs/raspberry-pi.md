# Deploying to a Raspberry Pi

Target: Raspberry Pi 5, Raspberry Pi OS Lite (64-bit, Debian Bookworm). Lite
because this is a headless server — no desktop environment needed, and it
frees RAM/disk for the 10-container stack.

## 1. Flash the OS

Use Raspberry Pi Imager. Pick "Raspberry Pi OS Lite (64-bit)". In the
imager's advanced options (gear icon), enable SSH and set a hostname/user
before writing — this lets you boot headless with no monitor/keyboard.

## 2. First boot

```bash
ssh <user>@<pi-hostname>.local
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

## 3. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Log out and back in for the group change to take effect. This installs
Docker Engine with the Compose plugin (`docker compose`) and pulls native
arm64 images — every base image this repo uses (`golang:1.23-alpine`,
`rust:1-alpine`, `gcr.io/distroless/static-debian12:nonroot`,
`alpine:3.20`, `postgres:16-alpine`, `redis:7-alpine`, `nginx:1.27-alpine`)
publishes arm64 builds, so nothing in `docker-compose.yml` or the
Dockerfiles needs to change.

## 4. Get the code and configure secrets

```bash
git clone git@github.com:loot-truck/finzy.git
cd finzy
cp .env.example .env
```

Edit `.env` and set real values for `JWT_SECRET`, `POSTGRES_PASSWORD`, and
`GRAFANA_PASSWORD` — the defaults in `docker-compose.yml` are dev-only
placeholders (`dev-secret-change-me`, `admin`), per the README's "before
exposing this beyond your LAN" section.

## 5. Start the stack

```bash
./scripts/dev.sh
```

This builds every service's image locally on the Pi (first build compiles
Go and Rust from source — expect it to take a while on a Pi) and starts the
stack. Add monitoring separately:

```bash
docker compose --profile monitoring up -d
```

Every service already has `restart: unless-stopped`, and Docker's systemd
service is enabled by default after the install script — so the stack comes
back up automatically after a Pi reboot or power loss.

## 6. Reach it from your LAN

Only `nginx` (`8080`) and, if enabled, `grafana` (`3000`) publish ports —
everything else stays on the internal `backend` network. Don't forward these
ports on your router. For access from outside your LAN, use
[Tailscale](https://tailscale.com) (install on the Pi and on your dev
machine/phone) instead of exposing the Pi directly to the internet.

Verify it's up:

```bash
curl http://<pi-ip>:8080/healthz
```

## 7. Point the Flutter app at it

```bash
flutter run --dart-define=API_BASE_URL=http://<pi-ip>:8080
```

`lib/api/api_client.dart` reads `API_BASE_URL` at compile time, defaulting
to `http://10.0.2.2:8080` for the Android emulator — override it to your
Pi's LAN (or Tailscale) IP for real-device testing against the Pi.

## Updating

```bash
cd finzy
git pull
docker compose up -d --build
```

Compose only rebuilds images whose sources changed.
