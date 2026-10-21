FROM debian:bookworm-slim

LABEL maintainer="MeyRay" \
      description="Hardened VLESS proxy via GitHub Codespaces with Nginx reverse proxy and live subscription"

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash git curl wget unzip tzdata openssl ca-certificates uuid-runtime procps nginx-light \
    && rm -rf /var/lib/apt/lists/*

COPY install.sh /app/install.sh
RUN chmod +x /app/install.sh && /app/install.sh

RUN mkdir -p /etc/mey2ray /var/www/dashboard /var/www/sub /var/log/nginx /var/run/mey2ray

COPY config.json /etc/mey2ray/config.template.json
COPY nginx.conf /etc/nginx/nginx.conf
COPY ips.txt /etc/mey2ray/ips.txt

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY show-info.sh /usr/local/bin/show-info.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY keepalive.sh /usr/local/bin/keepalive.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/show-info.sh /usr/local/bin/healthcheck.sh /usr/local/bin/keepalive.sh

COPY dashboard/ /var/www/dashboard/

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

EXPOSE 443

CMD ["/usr/local/bin/entrypoint.sh"]
