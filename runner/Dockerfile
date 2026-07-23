FROM ubuntu:24.04

ARG TARGETARCH
ARG RUNNER_VERSION=2.336.0
ARG DOCKER_CLI_VERSION=20.10.24
ARG DOCKER_COMPOSE_VERSION=2.3.3

ENV DEBIAN_FRONTEND=noninteractive \
    RUNNER_HOME=/runner

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl git gosu jq libicu74 libssl3 tini \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --home-dir /runner --shell /bin/bash runner \
    && case "$TARGETARCH" in \
         amd64) RUNNER_ARCH=x64; DOCKER_STATIC_ARCH=x86_64; COMPOSE_ARCH=x86_64 ;; \
         arm64) RUNNER_ARCH=arm64; DOCKER_STATIC_ARCH=aarch64; COMPOSE_ARCH=aarch64 ;; \
         *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
       esac \
    && echo "Installing Docker CLI ${DOCKER_CLI_VERSION} for ${DOCKER_STATIC_ARCH}" \
    && curl --fail --location --retry 3 \
       "https://download.docker.com/linux/static/stable/${DOCKER_STATIC_ARCH}/docker-${DOCKER_CLI_VERSION}.tgz" \
       --output /tmp/docker-cli.tgz \
    && tar --extract --gzip --file /tmp/docker-cli.tgz --directory /tmp docker/docker \
    && install -m 0755 /tmp/docker/docker /usr/local/bin/docker \
    && rm -rf /tmp/docker /tmp/docker-cli.tgz \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && echo "Installing Docker Compose plugin ${DOCKER_COMPOSE_VERSION} for ${COMPOSE_ARCH}" \
    && curl --fail --location --retry 3 \
       "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" \
       --output /usr/local/lib/docker/cli-plugins/docker-compose \
    && chmod 0755 /usr/local/lib/docker/cli-plugins/docker-compose \
    && docker --version \
    && docker compose version \
    && echo "Installing GitHub Actions runner ${RUNNER_VERSION} for ${RUNNER_ARCH}" \
    && curl --fail --location --retry 3 \
       "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" \
       --output /tmp/actions-runner.tar.gz \
    && tar --extract --gzip --file /tmp/actions-runner.tar.gz --directory /runner \
    && rm /tmp/actions-runner.tar.gz \
    && /runner/bin/installdependencies.sh \
    && chown -R runner:runner /runner

COPY --chown=runner:runner runner/entrypoint.sh /usr/local/bin/runner-entrypoint
RUN chmod 0755 /usr/local/bin/runner-entrypoint

WORKDIR /runner
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/runner-entrypoint"]
