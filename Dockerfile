FROM --platform=${BUILDPLATFORM:-linux/amd64} tonistiigi/xx AS xx
FROM --platform=${BUILDPLATFORM:-linux/amd64} lukemathwalker/cargo-chef:latest-rust-1.67.1 AS chef


FROM chef AS planner
WORKDIR /qdrant

COPY . .

RUN cargo chef prepare --recipe-path recipe.json

RUN --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index \
    cargo fetch


FROM chef as builder
WORKDIR /qdrant

COPY --from=xx / /

RUN apt update \
    && apt install -y clang lld cmake protobuf-compiler \
    && rustup component add rustfmt

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

RUN xx-apt install -y gcc g++ libc6-dev

COPY --from=planner /qdrant/recipe.json recipe.json
RUN --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index \
    xx-cargo chef cook --release --recipe-path recipe.json

COPY . .
RUN --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index \
    xx-cargo build --release --bin qdrant

RUN mv target/$(xx-cargo --print-target-triple)/release/qdrant /qdrant/qdrant


FROM debian:11-slim

RUN apt update \
    && apt install -y ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*

ARG APP=/qdrant

RUN mkdir -p ${APP}

COPY --from=builder /qdrant/qdrant ${APP}/qdrant
COPY --from=builder /qdrant/config ${APP}/config

WORKDIR ${APP}

ENV TZ=Etc/UTC \
    RUN_MODE=production

EXPOSE 6333
EXPOSE 6334

CMD ["./qdrant"]
