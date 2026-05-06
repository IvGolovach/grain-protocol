FROM rust:1.86-bookworm AS build

WORKDIR /work
COPY core/rust/Cargo.toml core/rust/Cargo.lock ./core/rust/
COPY core/rust ./core/rust
COPY conformance ./conformance
RUN cargo build --manifest-path core/rust/Cargo.toml -p grain-runner --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /work/core/rust/target/release/grain-runner /usr/local/bin/grain-runner

ENTRYPOINT ["/usr/local/bin/grain-runner"]
