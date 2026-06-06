# syntax=docker/dockerfile:1.4

# ── deps stage: install all dependencies ──────────────────────────────────────
FROM node:lts-alpine AS deps
WORKDIR /code
COPY package.json package-lock.json ./
RUN npm ci

# ── development stage: hot-reload dev server ──────────────────────────────────
FROM node:lts-alpine AS development
ENV CI=true
ENV PORT=3000
WORKDIR /code
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
EXPOSE 3000
CMD ["npm", "start"]

# ── builder stage: compile production build ───────────────────────────────────
FROM deps AS builder
COPY . .
RUN npm run build

# ── production stage: nginx serving static files, non-root ───────────────────
FROM nginx:1.25-alpine AS production

# Run nginx as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
  && chown -R appuser:appgroup /var/cache/nginx /var/log/nginx /etc/nginx/conf.d

COPY --from=builder /code/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

RUN chown -R appuser:appgroup /usr/share/nginx/html

USER appuser

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
