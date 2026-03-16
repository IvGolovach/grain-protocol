FROM rust:1.86-bookworm

ARG NODE_VERSION=22.22.0
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  jq \
  python3 \
  python3-pip \
  zip \
  && rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH}" in \
    amd64) NODE_ARCH="x64" ;; \
    arm64) NODE_ARCH="arm64" ;; \
    *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
  esac \
  && curl -fsSLo /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
  && mkdir -p /usr/local/lib/nodejs \
  && tar -xJf /tmp/node.tar.xz -C /usr/local/lib/nodejs \
  && ln -s "/usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${NODE_ARCH}" /usr/local/lib/nodejs/current \
  && rm /tmp/node.tar.xz

ENV PATH="/usr/local/lib/nodejs/current/bin:${PATH}"
ENV NODE_NO_WARNINGS=1

WORKDIR /work

ENTRYPOINT ["bash"]
