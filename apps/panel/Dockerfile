# Production image (multi-stage): the SPA is built here, then served statically.
# REACT_APP_* are inlined in the bundle at build time: one image per environment.
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile
ARG REACT_APP_BACKEND_URL
ARG REACT_APP_IMAGEKIT_ENDPOINT
ENV REACT_APP_BACKEND_URL=$REACT_APP_BACKEND_URL \
    REACT_APP_IMAGEKIT_ENDPOINT=$REACT_APP_IMAGEKIT_ENDPOINT \
    SKIP_PREFLIGHT_CHECK=true \
    GENERATE_SOURCEMAP=false \
    NODE_OPTIONS=--openssl-legacy-provider
COPY . .
RUN yarn build

FROM node:20-alpine AS prod
RUN npm install -g serve@14.2.8 \
 && addgroup -S -g 10001 app \
 && adduser -S -u 10001 -G app app
ENV HOME=/tmp \
    NO_UPDATE_NOTIFIER=1
WORKDIR /app
COPY --from=build /app/build /app/build
COPY serve.json /app/serve.json
USER 10001
EXPOSE 8080
CMD ["serve", "-c", "/app/serve.json", "-l", "8080", "--no-clipboard"]
