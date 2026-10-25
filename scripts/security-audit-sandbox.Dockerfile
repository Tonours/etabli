# Toolchain image for security-audit-sandbox: everything a target build or test may use
# must be here, because runs have no network.
FROM node:24-bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 python3-venv build-essential git ca-certificates procps \
  && rm -rf /var/lib/apt/lists/*
USER 65534:65534
WORKDIR /scratch
