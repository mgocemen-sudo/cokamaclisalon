FROM node:22-bookworm-slim AS client-build
WORKDIR /client
COPY client/package.json client/package-lock.json* ./
RUN npm install --no-audit --no-fund
COPY client/ ./
RUN npm run build

FROM node:22-bookworm-slim AS server-build
WORKDIR /server
COPY server/package.json server/package-lock.json* ./
RUN npm install --no-audit --no-fund
COPY server/ ./
RUN npm run build

FROM node:22-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
RUN useradd --system --uid 10001 --create-home appuser \
  && mkdir -p /app/data/uploads \
  && chown -R appuser:appuser /app
COPY --from=server-build /server/package.json /server/package-lock.json* ./server/
WORKDIR /app/server
RUN npm install --omit=dev --no-audit --no-fund
COPY --from=server-build /server/dist ./dist
COPY --from=server-build /server/src/db/migrations ./src/db/migrations
COPY --from=server-build /server/assets ./assets
COPY --from=client-build /client/dist /app/client/dist
WORKDIR /app
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=5s --retries=10 CMD node -e "fetch('http://127.0.0.1:8080/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "server/dist/index.js"]
