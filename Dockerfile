ARG IMAGE_ALPINE_VERSION=3.24.1
ARG IMAGE_ALPINE_DIGEST=28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

ARG UID=65532
ARG GID=65532

FROM docker.io/library/alpine:${IMAGE_ALPINE_VERSION}@sha256:${IMAGE_ALPINE_DIGEST} AS downloader

RUN set -e && \
    apk add --no-cache \
    ca-certificates=20260611-r0 \
    wget=1.25.0-r3 \
    gnupg=2.4.9-r1

RUN set -e && \
    rm -rf /var/lib/apk/tmp/* /var/cache/apk/* /var/log/apk.log

WORKDIR /opt/forgejo

ARG TARGETARCH

ARG IMAGE_FORGEJO_VERSION

RUN set -e \
    && \
    case ${TARGETARCH} in \
    "amd64")  FORGEJO_ARCH="amd64" \
    ;; \
    "arm64")  FORGEJO_ARCH="arm64" \
    ;; \
    *)        echo "Unsupported architecture: ${TARGETARCH}"; exit 1; \
    esac \
    && \
    wget -q -O ./forgejo "https://codeberg.org/forgejo/forgejo/releases/download/v${IMAGE_FORGEJO_VERSION}/forgejo-${IMAGE_FORGEJO_VERSION}-linux-${FORGEJO_ARCH}" \
    && \
    wget -q -O ./forgejo.asc "https://codeberg.org/forgejo/forgejo/releases/download/v${IMAGE_FORGEJO_VERSION}/forgejo-${IMAGE_FORGEJO_VERSION}-linux-${FORGEJO_ARCH}.asc"

RUN set -e \
    && \
    gpg --keyserver keys.openpgp.org --recv EB114F5E6C0DC2BCDD183550A4B61A2DC5923710 \
    && \
    gpg --verify ./forgejo.asc ./forgejo

FROM docker.io/library/alpine:${IMAGE_ALPINE_VERSION}@sha256:${IMAGE_ALPINE_DIGEST}

ARG SOURCE_DATE_EPOCH
ENV SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}

ARG IMAGE_VCS_DATE
ARG IMAGE_VCS_REV
ARG IMAGE_BUILD_REVISION

ARG IMAGE_FORGEJO_VERSION

LABEL org.opencontainers.image.title="Forgejo. Beyond coding. We forge." \
    org.opencontainers.image.vendor="Hantong Chen" \
    org.opencontainers.image.authors="Hantong Chen" \
    org.opencontainers.image.description="Third-party rootless reproducible OCI image of [Forgejo](https://forgejo.org/)." \
    org.opencontainers.image.documentation="https://github.com/hanyu-dev/oci-image-forgejo/blob/main/README.md" \
    org.opencontainers.image.source="https://github.com/hanyu-dev/oci-image-forgejo" \
    org.opencontainers.image.url="https://github.com/hanyu-dev/oci-image-forgejo" \
    org.opencontainers.image.licenses="GPL-3.0-or-later" \
    org.opencontainers.image.created=${IMAGE_VCS_DATE} \
    org.opencontainers.image.version=${IMAGE_FORGEJO_VERSION}-r${IMAGE_BUILD_REVISION} \
    org.opencontainers.image.revision=${IMAGE_VCS_REV}

RUN set -e && \
    apk add --no-cache \
    bash=5.3.9-r1 \
    ca-certificates=20260611-r0 \
    git=2.54.0-r0 \
    git-lfs=3.7.1-r0 \
    gnupg=2.4.9-r1 \
    openssh-client=10.3_p1-r0

RUN set -e && \
    rm -rf /var/lib/apk/tmp/* /var/cache/apk/* /var/log/apk.log

ARG UID
ARG GID

RUN set -e \
    && \
    addgroup -g "$GID" git \
    && \
    adduser -S -H -D -h /opt/forgejo/git -s /bin/bash -u "$UID" -G git git

COPY --from=downloader --chown="${UID}:${GID}" --chmod=775 /opt/forgejo /opt/forgejo

COPY --chown="root:root" --chmod=644 ./assets/build/gitconfig /etc/gitconfig

WORKDIR /opt/forgejo

USER ${UID}:${GID}

RUN set -e \
    && \
    mkdir -p /opt/forgejo/custom \
    && \
    chmod 775 /opt/forgejo/custom \
    && \
    mkdir -p /opt/forgejo/data \
    && \
    chmod 775 /opt/forgejo/data

ENTRYPOINT ["/opt/forgejo/forgejo"]
