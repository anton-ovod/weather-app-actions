FROM nginx:1.28.0-alpine-slim

ARG PORT=80
ENV PORT=$PORT

LABEL org.opencontainers.image.authors="Anton Ovod <s99806@pollub.edu.pl>"
LABEL org.opencontainers.image.description="Simple weather web app"

WORKDIR /app
COPY ./app .
RUN sh -c "mv public/index.html /usr/share/nginx/html/index.html && \
    mv nginx.conf /etc/nginx/nginx.conf && \
    mv entrypoint.sh /entrypoint.sh && \
    chmod +x /entrypoint.sh"

EXPOSE $PORT

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --spider -q http://127.0.0.1:$PORT/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]