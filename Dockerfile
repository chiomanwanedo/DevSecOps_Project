# --- Builder ---
FROM node:20-alpine AS builder
WORKDIR /app

# Speed up installs + avoid flaky timeouts
RUN yarn config set network-timeout 600000 \
 && yarn config set registry https://registry.npmjs.org

# Copy only manifests first to maximize layer cache
COPY package.json yarn.lock ./

# Use BuildKit cache for Yarn
# (Make sure to build with DOCKER_BUILDKIT=1)
RUN --mount=type=cache,target=/root/.cache/yarn \
    yarn install --frozen-lockfile --non-interactive

# Bring in the rest and build
COPY . .

# Build-time API key (avoid putting real secrets in images)
ARG TMDB_V3_API_KEY=""
ENV VITE_APP_TMDB_V3_API_KEY=$TMDB_V3_API_KEY
ENV VITE_APP_API_ENDPOINT_URL="https://api.themoviedb.org/3"

RUN yarn build

# --- Runtime (Nginx) ---
FROM nginx:stable-alpine
WORKDIR /usr/share/nginx/html
RUN rm -rf ./*
COPY --from=builder /app/dist ./
EXPOSE 80
ENTRYPOINT ["nginx", "-g", "daemon off;"]
