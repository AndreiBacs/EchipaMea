# syntax=docker/dockerfile:1

# --- deps -------------------------------------------------------------------
FROM node:22-bookworm-slim AS deps
WORKDIR /app
# argon2 builds a native addon on install.
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json* ./
RUN npm ci

# --- build ------------------------------------------------------------------
FROM deps AS build
WORKDIR /app
COPY prisma ./prisma
RUN npx prisma generate
COPY tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src ./src
RUN npm run build

# --- runtime ----------------------------------------------------------------
FROM node:22-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json* ./
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma
COPY prisma ./prisma

RUN npm prune --omit=dev || true

USER node
EXPOSE 3000
# Migrations run on start, from the image's own pinned Prisma CLI (a runtime
# dependency for exactly this reason): `npx prisma` after a dev-dependency
# prune would download whatever version is latest at boot time.
CMD ["sh", "-c", "./node_modules/.bin/prisma migrate deploy && exec node dist/main"]
