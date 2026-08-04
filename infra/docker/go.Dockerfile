# Shared build for every Go service. Pass SERVICE to pick which one.
# Build context is the repository root so the shared module is available.
FROM golang:1.23-alpine AS build

ARG SERVICE
WORKDIR /src

COPY go.work ./
COPY shared/go ./shared/go
COPY services ./services

# No external modules, so the build needs no network.
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" \
    -o /out/service ./services/${SERVICE}/cmd

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/service /service
USER nonroot:nonroot
ENTRYPOINT ["/service"]
