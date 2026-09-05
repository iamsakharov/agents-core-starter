# Seed-шаблон Dockerfile (agents-core). Скопируй в проект и адаптируй под стек.
# Здесь пример для Node-приложения — замени на свой рантайм при необходимости.
#
# Принцип: multi-stage — собираем в одном слое, в финальный образ кладём только результат.
# Секретов здесь быть не должно: они приходят из окружения на сервере / из GitHub Secrets.

# ── build stage ──────────────────────────────────────────────────────────────
FROM node:22-alpine AS build

WORKDIR /app

# зависимости отдельно от кода — слой кэшируется, пересборка быстрее
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# ── runtime stage ────────────────────────────────────────────────────────────
FROM node:22-alpine AS runtime

WORKDIR /app
ENV NODE_ENV=production

# только прод-зависимости
COPY package*.json ./
RUN npm ci --omit=dev

# артефакт сборки из предыдущего слоя
COPY --from=build /app/dist ./dist

# не запускать от root
USER node

EXPOSE 3000

CMD ["node", "dist/index.js"]
