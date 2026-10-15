FROM cloudron/base:6.0.0@sha256:9bed4c8fa880645f8e669041ee28febe941481d00e9445e3e5a5483cb541d09b

LABEL org.opencontainers.image.source="https://github.com/marcusquinn/cloudron-librecrawl-app"
ARG LIBRECRAWL_COMMIT=05a1372de8334ca18dec0bc1f7470c62901a9418
ENV PLAYWRIGHT_BROWSERS_PATH=/app/code/ms-playwright \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/app/data \
    PATH=/app/code/bin:/app/code/venv/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app/code
RUN git clone https://github.com/PhialsBasement/LibreCrawl . \
    && git checkout "${LIBRECRAWL_COMMIT}" \
    && test "$(git rev-parse HEAD)" = "${LIBRECRAWL_COMMIT}" \
    && printf '%s\n' "${LIBRECRAWL_COMMIT}" > /app/code/upstream-commit \
    && rm -rf .git data .env \
    && ln -s /app/data /app/code/data
RUN python3 -m venv /app/code/venv \
    && /app/code/venv/bin/pip install --no-cache-dir -r requirements.txt \
    && /app/code/venv/bin/playwright install --with-deps chromium \
    && chmod -R a+rX /app/code/ms-playwright \
    && rm -rf /var/lib/apt/lists/*
COPY start.sh /app/code/start.sh
COPY bin/ /app/code/bin/
RUN chmod +x /app/code/start.sh /app/code/bin/*
EXPOSE 5000
CMD ["/app/code/start.sh"]
