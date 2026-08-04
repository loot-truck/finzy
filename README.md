# Finance Tracker

Polyglot, self-hostable backend with a Flutter client. Runs on a Raspberry Pi
today; the same images run on Kubernetes or a cloud VM later.

- **Flutter** — Android and iOS client
- **Go** — gateway, auth, users, notifications
- **Rust** — media, AI, crypto (the CPU-bound work)
- **Nginx / PostgreSQL / Redis / Prometheus / Grafana** — infrastructure

## Quick start

```bash
./scripts/dev.sh     # build and start the stack, wait for health
./scripts/smoke.sh   # exercise every service through the gateway
docker compose down  # stop
```

The API is at `http://localhost:8080`. Add the monitoring stack with
`docker compose --profile monitoring up -d` (Grafana on `:3000`).

Run the app against it:

```bash
cd mobile/flutter_app
flutter run                                             # Android emulator
flutter run --dart-define=API_BASE_URL=http://<pi-ip>:8080   # real device
```

## Request path

```
Flutter → Nginx → Go gateway → { Go services | Rust services } → PostgreSQL / Redis
```

Nginx terminates TLS and caps upload size. The gateway applies CORS and per-IP
rate limiting, strips the `/api/v1/<service>` prefix, and forwards to the owner.

## Endpoints

All paths are relative to `http://localhost:8080`.

| Method | Path | Service | Purpose |
| --- | --- | --- | --- |
| GET | `/healthz` | gateway | Liveness |
| POST | `/api/v1/auth/register` | auth (Go) | Create an account |
| POST | `/api/v1/auth/login` | auth (Go) | Get a JWT |
| GET | `/api/v1/auth/me` | auth (Go) | Claims for a bearer token |
| GET/PUT | `/api/v1/users/profiles/{id}` | users (Go) | Read/write a profile |
| POST | `/api/v1/notifications/send` | notifications (Go) | Queue a notification |
| POST | `/api/v1/media/inspect` | media (Rust) | Format + dimensions of an image |
| POST | `/api/v1/ai/classify` | ai (Rust) | Categorise a transaction |
| POST | `/api/v1/crypto/digest` | crypto (Rust) | SHA-256 of a payload |

Each service also serves its own `/healthz`.

## Layout

```
mobile/flutter_app/     Flutter client (lib/api/api_client.dart wraps the gateway)
api/proto/              gRPC contracts shared by services and client
services/*-go/          Go services
services/*-rust/        Rust services
shared/go/              Go helpers: JSON, health, logging, graceful shutdown
shared/rust/httpmini/   Dependency-free HTTP server for the Rust services
infra/docker/           Dockerfiles and the PostgreSQL schema
infra/nginx/            Edge proxy config
infra/monitoring/       Prometheus config
scripts/                dev.sh, smoke.sh
docs/                   Architecture notes
```

## Working on it locally

Docker builds everything, so Go and Rust toolchains are optional. With them
installed:

```bash
# Go: a workspace ties the modules together, but ./... must be run per module.
for m in shared/go services/*-go; do (cd "$m" && go vet ./... && go test ./...); done

cargo test                                  # Rust workspace at the repo root
cd mobile/flutter_app && flutter test       # Flutter
```

Without the toolchains installed, run them in a container instead:

```bash
docker run --rm -v "$PWD":/src -w /src golang:1.23-alpine \
  sh -c 'cd services/auth-go && go test ./...'
docker run --rm -v "$PWD":/src -w /src rust:1-alpine \
  sh -c 'apk add -q --no-cache musl-dev && cargo test'
```

## What is a stub

The scaffold runs end to end, but these are deliberately placeholders:

- **Persistence** — auth and users keep state in memory. The target schema is
  `infra/docker/initdb/001_schema.sql`; PostgreSQL and Redis are running and
  wired into the environment, but no service connects yet.
- **AI** — `classify` is a keyword rule, not a model.
- **Media** — `inspect` reads header bytes; there is no transcoding.
- **Crypto** — SHA-256 only. Use a reviewed crate for encryption.
- **Metrics** — Prometheus scrapes `/healthz`; no `/metrics` endpoint yet.
- **gRPC and Kafka** — the proto contracts exist, services talk REST for now.
- **Rate limiting** — in-memory per gateway instance; move to Redis before
  running more than one replica.

## Before exposing this beyond your LAN

Set `JWT_SECRET` in `.env`, change the PostgreSQL password, and put TLS
certificates in front of Nginx.

## Deploying and device testing

- [`docs/raspberry-pi.md`](docs/raspberry-pi.md) — OS image, Docker setup,
  and running the full stack on a Raspberry Pi.
- [`docs/ios-testflight.md`](docs/ios-testflight.md) — CI pipeline that
  builds, signs, and uploads the Flutter app to TestFlight so it can be
  tested on a physical iPhone without a local Xcode install.
- [`docs/ios-self-hosted-runner.md`](docs/ios-self-hosted-runner.md) — free
  alternative: a self-hosted GitHub Actions runner on your own Mac installs
  straight to a connected iPhone, no Apple Developer Program required.
- [`docs/android-firebase-distribution.md`](docs/android-firebase-distribution.md)
  — CI pipeline that builds a signed release APK and uploads it to Firebase
  App Distribution, so testers install/update on their own Android devices
  with no cable, no paid account, and no dependency on your machine.
