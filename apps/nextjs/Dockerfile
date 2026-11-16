# Production image (multi-stage). Requires output: 'standalone' in next.config.ts.
# NEXT_PUBLIC_* are inlined in the JavaScript at build time: one image per environment.
FROM node:22-alpine AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

FROM node:22-alpine AS build
WORKDIR /app
ARG NEXT_PUBLIC_BACKEND_URL
ARG NEXT_PUBLIC_BACKEND_URL_FRONT
ARG NEXT_PUBLIC_GOOGLE_CLIENT_ID
ARG BACKEND_URL
ENV NEXT_PUBLIC_BACKEND_URL=$NEXT_PUBLIC_BACKEND_URL \
    NEXT_PUBLIC_BACKEND_URL_FRONT=$NEXT_PUBLIC_BACKEND_URL_FRONT \
    NEXT_PUBLIC_GOOGLE_CLIENT_ID=$NEXT_PUBLIC_GOOGLE_CLIENT_ID \
    BACKEND_URL=$BACKEND_URL \
    NEXT_TELEMETRY_DISABLED=1
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN yarn build

FROM node:22-alpine AS prod
WORKDIR /app

ENV NODE_ENV=production \
    PORT=3000 \
    NEXT_TELEMETRY_DISABLED=1 \
    HOME=/tmp

RUN addgroup --system --gid 10001 nodejs \
 && adduser  --system --uid 10001 --ingroup nodejs nextjs

COPY --from=build --chown=10001:10001 /app/public            ./public
COPY --from=build --chown=10001:10001 /app/.next/standalone  ./
COPY --from=build --chown=10001:10001 /app/.next/static      ./.next/static
RUN mkdir -p /app/.next/cache && chown 10001:10001 /app/.next/cache

USER 10001

EXPOSE 3000

# Kubernetes overrides HOSTNAME with the pod name: force the listen address.
CMD ["sh", "-c", "HOSTNAME=0.0.0.0 exec node server.js"]
