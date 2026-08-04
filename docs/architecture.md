# Architecture

## Goals

Cross-platform mobile client, a backend that runs on hardware you own, and a
path to the cloud that does not require a rewrite.

## Why this split

**Flutter** gives one UI codebase for Android and iOS. Platform channels are
reserved for things Dart cannot reach — biometrics, background sync, widgets.

**Go** handles anything that is mostly I/O and coordination: HTTP, auth,
CRUD, billing, fan-out. Fast to write, cheap goroutines, small static binaries
that cross-compile to the Pi's arm64 without fuss.

**Rust** handles the work where a request occupies a core: image and video
processing, encryption, compression, model inference. These are exactly the
cases where Go's garbage collector and Dart's single isolate hurt, and where
Rust's lack of a runtime tax shows up.

The dividing line is not "Rust is faster". It is: does this request spend its
time waiting, or computing? Waiting goes to Go, computing goes to Rust.

## Layers

```
                 Flutter app
                      │  HTTPS
                      ▼
                 Nginx (TLS, upload limits, real client IP)
                      │
                 Go gateway (CORS, rate limit, routing, auth check)
              ┌───────┴────────┐
              ▼                ▼
   Go services            Rust services
   auth, users,           media, ai, crypto
   notifications
              └───────┬────────┘
                      ▼
              PostgreSQL  ·  Redis  ·  Kafka (later)
```

### Nginx

The only container with a published port. Terminates TLS, caps request bodies
at 32 MB, and sets `X-Real-IP` so the gateway's rate limiter sees clients
rather than the proxy.

### Gateway

One public surface for the client, which keeps service topology private and
lets services move without an app release. It owns cross-cutting concerns —
CORS, rate limiting, and (next) token validation, so downstream services can
trust the identity header instead of each re-parsing JWTs.

Routing is prefix-based: `/api/v1/<service>/...` goes to `<service>`, with the
prefix stripped so each service sees clean paths.

### Data

PostgreSQL is the system of record. Money is stored in **minor units as
`BIGINT`** — never floating point — with the currency alongside it.

Redis covers sessions, rate-limit counters and cache. Kafka arrives when work
needs to outlive the request that started it (video transcoding, batch
re-categorisation); until then an in-process channel in the notifications
service is enough, and the swap is a change to one function.

## Service inventory

| Service | Language | Port | Responsibility |
| --- | --- | --- | --- |
| gateway | Go | 8080 | Routing, CORS, rate limiting |
| auth | Go | 8081 | Registration, login, JWT issue/verify |
| users | Go | 8082 | Profiles |
| notifications | Go | 8083 | Push, email, SMS fan-out |
| media | Rust | 9091 | Image and video processing |
| ai | Rust | 9092 | Inference |
| crypto | Rust | 9093 | Hashing, encryption |

## Communication

REST/JSON between the client and the gateway — easy to debug, and every HTTP
client speaks it. Between services, gRPC once the contracts in `api/proto/`
are generated: typed stubs, and a schema that fails the build rather than
production when it drifts. Kafka for work that must be durable and async.

## Security

- Passwords: PBKDF2-HMAC-SHA256, 210k iterations, per-user random salt. The
  stored hash records its own cost, so raising it does not invalidate old rows.
- Tokens: HS256 JWTs, 24-hour expiry, constant-time signature comparison.
  Move to RS256 when services stop sharing a trust boundary — then the gateway
  holds the private key and services verify with the public one.
- Login returns the same error for an unknown address and a wrong password, so
  the endpoint cannot be used to enumerate accounts.
- Only Nginx is reachable from outside the Docker network.

## Deployment

One `docker compose up` on the Pi. Images are multi-arch and the binaries are
static, so the same compose file works on arm64 and x86.

Scaling out, in order of what usually binds first:

1. `docker compose up --scale gateway=3` — but move rate-limit counters to
   Redis first, or each replica enforces its own limit.
2. Split Rust services onto their own host; they are the CPU consumers.
3. PostgreSQL read replicas once reads dominate.
4. Kafka when queues need to survive restarts.
5. Kubernetes when a single host stops being enough — the container contracts
   do not change, only the scheduler.

## Decisions worth revisiting

- **In-memory stores.** Deliberate, so the stack runs with no migrations.
  PostgreSQL is already up and the schema is written; wiring is the next task.
- **`httpmini`.** A hand-rolled HTTP server exists only so the Rust services
  build with no crates.io access. Replace it with `axum` + `tokio` as soon as
  dependencies are acceptable — thread-per-connection will not hold under load.
- **Hand-written SHA-256 and PBKDF2.** Correct and tested against published
  vectors, but standard crates are the right long-term answer. Do not extend
  this pattern to encryption.
