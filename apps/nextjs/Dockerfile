# Production image — expects .next to be pre-built by CI before docker build
# Requires output: 'standalone' in next.config.ts
FROM node:22-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

RUN addgroup --system --gid 1001 nodejs \
 && adduser  --system --uid 1001 nextjs

# Standalone output includes its own node_modules — no separate install needed
COPY --chown=nextjs:nodejs public            ./public
COPY --chown=nextjs:nodejs .next/standalone  ./
COPY --chown=nextjs:nodejs .next/static      ./.next/static

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
