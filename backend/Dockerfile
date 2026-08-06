FROM node:18-alpine AS base
WORKDIR /usr/src/app

FROM base AS deps
COPY package.json package-lock.json* ./
RUN npm install --omit=dev

FROM base AS runner
ENV NODE_ENV=production
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY . .
RUN mkdir -p logs tmp/uploads
EXPOSE 4000
USER node
CMD ["node", "src/server.js"]
