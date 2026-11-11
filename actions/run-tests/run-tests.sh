#!/usr/bin/env bash
# Harnais de test du Tunnel : exécute la commande de test d'un repo dans un conteneur verrouillé.
# Entrées (variables d'environnement, jamais interpolées dans le script) :
#   TUNNEL_TEST_COMMAND   commande exécutée par `sh -c` dans le conteneur
#   TUNNEL_TIMEOUT        durée maximale en secondes (défaut 600, borne 1..3600)
#   TUNNEL_WORKDIR        répertoire du repo monté en lecture seule (défaut .)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=image.lock
source "$here/image.lock"

command_line="${TUNNEL_TEST_COMMAND:-}"
timeout_s="${TUNNEL_TIMEOUT:-600}"
workdir="${TUNNEL_WORKDIR:-.}"

if [[ -z "$command_line" ]]; then
  echo "tunnel-ci: aucune commande de test" >&2
  exit 2
fi
if ! [[ "$timeout_s" =~ ^[0-9]+$ ]] || (( timeout_s < 1 || timeout_s > 3600 )); then
  echo "tunnel-ci: durée invalide" >&2
  exit 2
fi
if ! [[ "$IMAGE" =~ ^[a-z0-9./_-]+@sha256:[0-9a-f]{64}$ ]]; then
  echo "tunnel-ci: l'image doit être épinglée par digest" >&2
  exit 2
fi
workdir="$(cd "$workdir" && pwd)"
name="tunnel-test-$$-$RANDOM"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT

echo "tunnel-ci: image $IMAGE"
echo "tunnel-ci: délai ${timeout_s}s, sans réseau, système de fichiers en lecture seule"

# Aucun réseau, aucun secret (environnement vide), aucune capacité, aucun socket Docker, racine en lecture seule.
set +e
timeout --kill-after=10 "$timeout_s" docker run --rm --name "$name" \
  --network none --read-only --cap-drop all --security-opt no-new-privileges \
  --user 10001:10001 --pids-limit 512 --memory 4g --cpus 2 --ulimit nofile=1024 \
  --tmpfs /tmp:rw,noexec,nosuid,size=256m \
  -e PYTHONDONTWRITEBYTECODE=1 -e PYTHONPYCACHEPREFIX=/tmp/pyc -e PYTHONHASHSEED=0 -e HOME=/tmp \
  -v "$workdir":/src:ro -w /src \
  "$IMAGE" sh -c "$command_line"
status=$?
set -e

if (( status == 124 || status == 137 )); then
  echo "tunnel-ci: délai dépassé" >&2
  exit 124
fi
exit "$status"
