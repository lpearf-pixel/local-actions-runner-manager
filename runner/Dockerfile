FROM ubuntu:24.04

ARG TARGETARCH
ARG RUNNER_VERSION=2.328.0

ENV DEBIAN_FRONTEND=noninteractive \
    RUNNER_HOME=/runner

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl git gosu jq docker.io libicu74 libssl3 tini \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --home-dir /runner --shell /bin/bash runner \
    && case "$TARGETARCH" in \
         amd64) RUNNER_ARCH=x64 ;; \
         arm64) RUNNER_ARCH=arm64 ;; \
         *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
       esac \
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
