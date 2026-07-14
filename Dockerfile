# ---- Build stage: pre-compile the optimized Keycloak distribution ----
FROM quay.io/keycloak/keycloak:26.7.0 AS builder

ENV KC_DB=postgres
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

WORKDIR /opt/keycloak
RUN /opt/keycloak/bin/kc.sh build

# ---- Runtime stage ----
FROM quay.io/keycloak/keycloak:26.7.0

COPY --from=builder /opt/keycloak/ /opt/keycloak/
COPY realm-export.json /opt/keycloak/data/import/realm-export.json
COPY docker-entrypoint.sh /opt/keycloak/bin/docker-entrypoint.sh

USER root
RUN chmod +x /opt/keycloak/bin/docker-entrypoint.sh
USER keycloak

# 8080: application traffic (put a TLS-terminating reverse proxy/load balancer in front)
# 9000: management interface (/health, /health/ready, /health/live, /metrics)
EXPOSE 8080 9000

# The base image ships without curl/wget, so probe the management port with bash's /dev/tcp.
# Note: `exec 3<>...` must run in the current shell, not a `(...)` subshell, or fd 3 closes
# again as soon as the subshell exits and the following `>&3` fails with "Bad file descriptor".
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/9000 && \
    printf "GET /health/ready HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" >&3 && \
    grep -q "\"status\": \"UP\"" <&3' || exit 1

ENTRYPOINT ["/opt/keycloak/bin/docker-entrypoint.sh"]
