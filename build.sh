#!/bin/bash

set -euo pipefail

# ================================
# Variables

PUSH=false

IMAGE_FORGEJO_VERSION="${IMAGE_FORGEJO_VERSION:-}"
IMAGE_BUILD_REVISION="${IMAGE_BUILD_REVISION:-}"

IMAGE_REGISTRY="${IMAGE_REGISTRY:-}"
IMAGE_NAME="${IMAGE_NAME:-}"
IMAGE_BUILD_PLATFORMS="${IMAGE_BUILD_PLATFORMS:-linux/amd64}"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--push)
		PUSH=true
		shift
		;;
	--image-forgejo-version)
		IMAGE_FORGEJO_VERSION="$2"
		shift 2
		;;
	--image-build-revision)
		IMAGE_BUILD_REVISION="$2"
		shift 2
		;;
	--image-registry)
		IMAGE_REGISTRY="$2"
		shift 2
		;;
	--image-name)
		IMAGE_NAME="$2"
		shift 2
		;;
	--platforms)
		IMAGE_BUILD_PLATFORMS="$2"
		shift 2
		;;
	*)
		echo "Unknown option: '$1'"
		exit 1
		;;
	esac
done

if [ -z "$IMAGE_FORGEJO_VERSION" ] || [ -z "$IMAGE_BUILD_REVISION" ] || [ -z "$IMAGE_REGISTRY" ] || [ -z "$IMAGE_NAME" ] || [ -z "$IMAGE_BUILD_PLATFORMS" ]; then
	echo "Missing required variables!"
	exit 1
fi

IMAGE_REPO="${IMAGE_REGISTRY}/${IMAGE_NAME}"

IMAGE_TAG_FULL_QUALIFIED="${IMAGE_REPO}:${IMAGE_FORGEJO_VERSION}-r${IMAGE_BUILD_REVISION}"
IMAGE_TAG_IGNORE_BUILD_REVISION="${IMAGE_REPO}:${IMAGE_FORGEJO_VERSION}"
IMAGE_TAG_MAJOR_MINOR="${IMAGE_REPO}:${IMAGE_FORGEJO_VERSION%.*}"
IMAGE_TAG_MAJOR="${IMAGE_REPO}:${IMAGE_FORGEJO_VERSION%%.*}"
IMAGE_TAG_LATEST="${IMAGE_REPO}:latest"

# ================================
# VCS Information

git config --global --add safe.directory "*" 2>/dev/null || true

IMAGE_VCS_DATE_EPOCH=$(git log -1 --pretty=%ct)
IMAGE_VCS_DATE=$(date -u -d @$IMAGE_VCS_DATE_EPOCH +'%Y-%m-%dT%H:%M:%S+00:00')
IMAGE_VCS_REV=$(git rev-parse HEAD)

# ================================
# Build

LOCAL_MANIFEST="localhost/${IMAGE_NAME}:build"

buildah manifest rm "${LOCAL_MANIFEST}" 2>/dev/null || true

buildah build \
	--no-cache \
	--platform="${IMAGE_BUILD_PLATFORMS}" \
	--manifest="${LOCAL_MANIFEST}" \
	--jobs=4 \
	--timestamp=${IMAGE_VCS_DATE_EPOCH} \
	--build-arg IMAGE_VCS_DATE=$IMAGE_VCS_DATE \
	--build-arg IMAGE_VCS_REV=$IMAGE_VCS_REV \
	--build-arg IMAGE_FORGEJO_VERSION=$IMAGE_FORGEJO_VERSION \
	--build-arg IMAGE_BUILD_REVISION=$IMAGE_BUILD_REVISION \
	-f Dockerfile .

# ================================
# Push

if [ "$PUSH" = true ]; then
	echo "$IMAGE_REGISTRY_PASSWORD" | buildah login "$IMAGE_REGISTRY" -u "$IMAGE_REGISTRY_USERNAME" --password-stdin

	for TAG in \
		"${IMAGE_TAG_FULL_QUALIFIED}" \
		"${IMAGE_TAG_IGNORE_BUILD_REVISION}" \
		"${IMAGE_TAG_MAJOR_MINOR}" \
		"${IMAGE_TAG_MAJOR}" \
		"${IMAGE_TAG_LATEST}"; do
		echo "Pushing images, tagging: ${TAG}..."
		buildah manifest push --all "${LOCAL_MANIFEST}" "docker://${TAG}"
	done
else
	echo "Skipping images push..."
fi
