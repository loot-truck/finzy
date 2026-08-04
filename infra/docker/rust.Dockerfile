# Shared build for every Rust service. Pass SERVICE (crate name) to pick one.
# Build context is the repository root so the workspace resolves.
FROM rust:1-alpine AS build

ARG SERVICE
WORKDIR /src

RUN apk add --no-cache musl-dev

COPY Cargo.toml ./
COPY shared/rust ./shared/rust
COPY services/media-rust ./services/media-rust
COPY services/ai-rust ./services/ai-rust
COPY services/crypto-rust ./services/crypto-rust

RUN cargo build --release --package ${SERVICE} \
    && cp target/release/${SERVICE} /out-service

FROM alpine:3.20
RUN adduser -D -u 10001 app
COPY --from=build /out-service /service
USER app
ENTRYPOINT ["/service"]
