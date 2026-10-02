# syntax=docker/dockerfile:1.7
# Multi-target build. Build context is the REPOSITORY ROOT:
#   docker build -f docker/Dockerfile --target backend  -t ecommerce-backend  .
#   docker build -f docker/Dockerfile --target frontend -t ecommerce-frontend .

# ---------- backend: dependencies ----------
FROM node:22-alpine AS deps
WORKDIR /app
COPY application/backend/package.json application/backend/package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

# ---------- backend: runtime ----------
FROM node:22-alpine AS backend
ENV NODE_ENV=production PORT=3000
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
WORKDIR /app
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node application/backend/package.json ./
COPY --chown=node:node application/backend/src ./src
USER node
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "src/server.js"]

# ---------- frontend: nginx (static files + reverse proxy), non-root ----------
FROM nginxinc/nginx-unprivileged:1.27-alpine AS frontend
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY application/frontend/ /usr/share/nginx/html/
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/nginx-health || exit 1
