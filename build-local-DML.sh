#!/usr/bin/env bash
set -euo pipefail

VERSION=20260923
IMAGE="ipsec-vpn--without-server"
PLATFORM="${PLATFORM:-linux/amd64}"
DOCKER_USERNAME_WSL=$(printf 'https://index.docker.io/v1/' | "/mnt/c/Program Files/Docker/Docker/resources/bin/docker-credential-desktop.exe" get 2>/dev/null | grep -o '"Username":"[^"]*"' | sed 's/"Username":"//;s/"//' || true)
DOCKER_USERNAME="${DOCKER_USERNAME:-${DOCKER_USERNAME_WSL:-waltermelow}}"

BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
VCS_REF="$(git rev-parse --short=8 HEAD)"

echo "Building ${IMAGE}:${VERSION}"
echo "Platform: ${PLATFORM}"
echo "Git ref: ${VCS_REF}"

docker buildx build \
  --progress plain \
  --platform "${PLATFORM}" \
  --build-arg BUILD_DATE="${BUILD_DATE}" \
  --build-arg VCS_REF="${VCS_REF}" \
  --build-arg VERSION=alpine-latest \
  --tag "${IMAGE}:${VERSION}" \
  --pull \
  --load \
  .

echo "Creando tag ${IMAGE}:${VERSION}  ->  ${DOCKER_USERNAME}/${IMAGE}:${VERSION}"
docker tag "${IMAGE}:${VERSION}" "${DOCKER_USERNAME}/${IMAGE}:${VERSION}"

echo "Creando tag ${IMAGE}:${VERSION}  ->  ${DOCKER_USERNAME}/${IMAGE}:latest"
docker tag "${IMAGE}:${VERSION}" "${DOCKER_USERNAME}/${IMAGE}:latest"

# Push Docker Hub (https://hub.docker.com)
if [[ "${1:-}" == "--push" || "${1:-}" == "push" ]]; then
  if [[ -z "${DOCKER_USERNAME_WSL}" ]]; then
    echo "No se encontraron credenciales activas en Docker Desktop. Ejecutando 'docker login'..."
    docker login -u "${DOCKER_USERNAME}"
  fi
  echo "Subiendo imágenes a Docker Hub ..."
  docker push "${DOCKER_USERNAME}/${IMAGE}:${VERSION}"
  docker push "${DOCKER_USERNAME}/${IMAGE}:latest"
fi
