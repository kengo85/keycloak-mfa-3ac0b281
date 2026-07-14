FROM quay.io/keycloak/keycloak:24.0

USER root

RUN rpm -q gettext || (dnf install -y gettext && dnf clean all) || (microdnf install -y gettext && microdnf clean all) || true

COPY realm-export.json /opt/keycloak/data/import/realm-export.json
COPY docker-entrypoint.sh /opt/keycloak/bin/docker-entrypoint.sh

RUN chmod +x /opt/keycloak/bin/docker-entrypoint.sh

USER keycloak

ENV KC_HTTP_PORT=80
ENV KC_HOSTNAME_STRICT=false
ENV KC_HOSTNAME_STRICT_HTTPS=false
ENV KC_HTTP_ENABLED=true
ENV KC_PROXY=edge
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_LOG_LEVEL=INFO
ENV KEYCLOAK_ADMIN=admin
ENV KEYCLOAK_ADMIN_PASSWORD=admin

RUN /opt/keycloak/bin/kc.sh build

EXPOSE 80

ENTRYPOINT ["/opt/keycloak/bin/docker-entrypoint.sh"]
