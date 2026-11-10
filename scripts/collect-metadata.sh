#!/usr/bin/env bash
set -euo pipefail

# Read-only metadata collection. Pass the path to an extracted firmware rootfs.
rootfs="${1:-}"
if [[ -z "$rootfs" || ! -d "$rootfs" ]]; then
  printf 'Usage: %s /path/to/extracted/rootfs\n' "$0" >&2
  exit 2
fi

for path in \
  usr/sbin/dnsmasq \
  usr/lib/libscapi.so \
  opt/lantiq/servd/lib/liblanservices.so \
  opt/lantiq/servd/lib/libnetwork.so; do
  file="$rootfs/$path"
  if [[ ! -f "$file" ]]; then
    printf 'Missing: %s\n' "$file" >&2
    continue
  fi
  printf '\n=== %s ===\n' "$path"
  sha256sum "$file"
  command -v file >/dev/null 2>&1 && command file "$file" || true
  readelf -D -sW "$file" 2>/dev/null | grep -E 'scapi_spawn|dnsmasq_start|dnsmasq_stop|libucihelper_UCICommit|libucihelper_UCISet' || true
done
