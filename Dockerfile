# syntax=docker/dockerfile:1

# SNI-only mode. The container exposes two listeners:
#   * PORT (injected by the platform, usually 8080) -- HTTP control plane:
#     setup page, /health, /config and the Telegram webhook.
#   * TLS_PORT (default 8443) -- the public SNI-only TLS listener that
#     accepts ANY SNI hostname and bridges the decrypted stream straight to
#     the SSH backend. There is no WebSocket and no HTTP payload.

FROM node:22-slim AS base
WORKDIR /app

# ---- install ALL deps (incl. devDependencies, needed to run esbuild) ----
FROM base AS deps
# build-essential/python3 are a safety net in case any native addon
# (e.g. ssh2's optional cpu-features) has no prebuilt binary for this
# platform and falls back to compiling from source.
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
COPY package.json ./
RUN npm install

# ---- bundle server.ts -> dist/server.cjs ----
FROM deps AS build
COPY server.ts tsconfig.json ./
RUN npm run build

# ---- production-only node_modules (no devDependencies) ----
FROM base AS prod-deps
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
COPY package.json ./
RUN npm install --omit=dev

# ---- final runtime image ----
FROM base AS runtime
ENV NODE_ENV=production
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh && mkdir -p /app/data

# Documentation only -- the platform injects its own PORT.
EXPOSE 8080 8443

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["node", "dist/server.cjs"]
