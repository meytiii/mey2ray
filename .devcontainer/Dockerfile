FROM debian:bookworm-slim

LABEL maintainer="MeyRay" \
      description="Hardened VLESS proxy via GitHub Codespaces with Nginx reverse proxy and live subscription"

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash git curl wget unzip tzdata openssl ca-certificates uuid-runtime procps nginx-light \
    && rm -rf /var/lib/apt/lists/*

COPY install.sh /app/install.sh
RUN chmod +x /app/install.sh && /app/install.sh

# Directory structure
RUN mkdir -p /etc/mey2ray /var/www/dashboard /var/www/sub /var/log/nginx /var/run/mey2ray

# Configuration files and templates
COPY config.json /etc/mey2ray/config.template.json
COPY nginx.conf /etc/nginx/nginx.conf
COPY ips.txt /etc/mey2ray/ips.txt

# Scripts
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY show-info.sh /usr/local/bin/show-info.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/show-info.sh /usr/local/bin/healthcheck.sh

# Dashboard static assets
COPY dashboard/ /var/www/dashboard/

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

EXPOSE 443

CMD ["/usr/local/bin/entrypoint.sh"]
