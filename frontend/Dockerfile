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

# Allow nginx to run as non-root: redirect pid file and tmp dirs to writable paths
RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
  && mkdir -p /var/cache/nginx/client_temp \
              /var/cache/nginx/proxy_temp \
              /var/cache/nginx/fastcgi_temp \
              /var/cache/nginx/uwsgi_temp \
              /var/cache/nginx/scgi_temp \
              /tmp/nginx \
  && chown -R appuser:appgroup \
              /var/cache/nginx \
              /var/log/nginx \
              /etc/nginx/conf.d \
              /usr/share/nginx/html \
              /tmp/nginx

COPY --from=builder /code/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

RUN chown -R appuser:appgroup /usr/share/nginx/html

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
