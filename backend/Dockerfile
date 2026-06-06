# syntax=docker/dockerfile:1.4

# ── deps stage: install production dependencies only ──────────────────────────
FROM node:lts-alpine AS deps
WORKDIR /code
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ── development stage: includes devDeps + hot-reload ──────────────────────────
FROM node:lts-alpine AS development
ARG NODE_ENV=development
ENV NODE_ENV=$NODE_ENV
WORKDIR /code
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ARG PORT=80
ENV PORT=$PORT
EXPOSE $PORT 9229 9230
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node healthcheck.js
CMD ["npm", "run", "start-watch"]

# ── production stage: minimal alpine image, non-root user ─────────────────────
FROM node:lts-alpine AS production
ENV NODE_ENV=production
WORKDIR /code

# Run as non-root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=deps /code/node_modules ./node_modules
COPY . .

RUN chown -R appuser:appgroup /code
USER appuser

ARG PORT=80
ENV PORT=$PORT
EXPOSE $PORT

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node healthcheck.js

CMD ["node", "src/index.js"]
