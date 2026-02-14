#!/usr/bin/env bash
set -euo pipefail

CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell-package-manager"
CONFIG_FILE="$CONFIG_ROOT/config.json"
HELPER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PY_HELPER="$HELPER_DIR/packages_file.py"

mkdir -p "$CONFIG_ROOT"

write_default_config() {
  local initial_path="${QPM_INITIAL_PACKAGES_FILE:-}"
  local channel="${QPM_CHANNEL:-nixos-unstable}"

  jq -n \
    --arg packagesFile "$initial_path" \
    --arg channel "$channel" \
    '{packagesFile: $packagesFile, channel: $channel}' > "$CONFIG_FILE"
}

ensure_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    write_default_config
  fi
}

read_config() {
  ensure_config
  cat "$CONFIG_FILE"
}

save_config() {
  local packages_file="$1"
  local channel="$2"

  jq -n \
    --arg packagesFile "$packages_file" \
    --arg channel "$channel" \
    '{packagesFile: $packagesFile, channel: $channel}' > "$CONFIG_FILE"
}

get_packages_file() {
  read_config | jq -r '.packagesFile // ""'
}

get_channel() {
  read_config | jq -r '.channel // "nixos-unstable"'
}

require_packages_file() {
  local path
  path="$(get_packages_file)"
  if [[ -z "$path" ]]; then
    jq -n '{error: "No packages file configured"}'
    exit 1
  fi
  printf '%s' "$path"
}

emit_state() {
  local cfg file packages
  cfg="$(read_config)"
  file="$(jq -r '.packagesFile // ""' <<< "$cfg")"

  if [[ -n "$file" ]]; then
    packages="$(python3 "$PY_HELPER" read "$file")"
  else
    packages='[]'
  fi

  jq -n --argjson config "$cfg" --argjson packages "$packages" '{config: $config, packages: $packages}'
}

extract_api_flags() {
  local cache_file="$CONFIG_ROOT/search-api-flags.json"
  local now epoch age
  epoch="$(date +%s)"

  if [[ -f "$cache_file" ]]; then
    now="$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)"
    age=$((epoch - now))
    if [[ "$age" -lt 21600 ]]; then
      cat "$cache_file"
      return
    fi
  fi

  local extracted
  if ! extracted="$(python3 - <<'PY'
import json
import re
import urllib.request

js = urllib.request.urlopen("https://search.nixos.org/bundle.js", timeout=20).read().decode("utf-8", "replace")

def require(pattern, label):
    match = re.search(pattern, js)
    if not match:
        raise RuntimeError(f"Missing {label} in bundle flags")
    return match.group(1)

output = {
    "schema": require(r'elasticsearchMappingSchemaVersion:parseInt\("([^"]+)"\)', "schema"),
    "url": require(r'elasticsearchUrl:"([^"]+)"', "url"),
    "username": require(r'elasticsearchUsername:"([^"]+)"', "username"),
    "password": require(r'elasticsearchPassword:"([^"]+)"', "password"),
}

print(json.dumps(output))
PY
  )"; then
    jq -n --arg error "Unable to parse search.nixos.org bundle flags" '{error: $error}'
    return 1
  fi

  if [[ -z "$extracted" ]]; then
    jq -n --arg error "Empty backend flag payload" '{error: $error}'
    return 1
  fi

  printf '%s' "$extracted" > "$cache_file"
  printf '%s\n' "$extracted"
}

search_packages() {
  local query="$1"
  local limit="${2:-30}"
  local channel="$(get_channel)"

  if [[ -z "$query" ]]; then
    echo '[]'
    return
  fi

  local flags schema url username password endpoint body result
  flags="$(extract_api_flags)" || {
    jq -n --arg error "Unable to resolve search API credentials" '{error: $error}'
    return 1
  }

  schema="$(jq -r '.schema' <<< "$flags")"
  url="$(jq -r '.url' <<< "$flags")"
  username="$(jq -r '.username' <<< "$flags")"
  password="$(jq -r '.password' <<< "$flags")"

  endpoint="https://search.nixos.org${url}/latest-${schema}-${channel}/_search"

  body="$(jq -n --arg q "$query" --argjson size "$limit" '{
    size: $size,
    query: {
      bool: {
        should: [
          { term: { package_attr_name: { value: $q, boost: 14 } } },
          { match: { package_attr_name: { query: $q, operator: "and", boost: 8 } } },
          { match: { package_pname: { query: $q, operator: "and", boost: 6 } } },
          { match: { package_description: { query: $q, operator: "and", boost: 2 } } }
        ],
        minimum_should_match: 1
      }
    },
    sort: ["_score"]
  }')"

  result="$(curl -fsSL -u "$username:$password" \
    -H 'content-type: application/json' \
    -X POST "$endpoint" \
    --data "$body")" || {
      jq -n --arg error "Failed to query search.nixos.org" '{error: $error}'
      return 1
    }

  jq '[
    .hits.hits[]?
    | ._source
    | {
        attr: .package_attr_name,
        attrSet: .package_attr_set,
        identifier: (if .package_attr_set == "No package set" then .package_attr_name else (.package_attr_set + "." + .package_attr_name) end),
        version: (.package_pversion // ""),
        description: (.package_description // "")
      }
  ] | unique_by(.identifier)' <<< "$result"
}

run_rebuild() {
  local rebuild_alias="${QPM_REBUILD_ALIAS:-}"

  if [[ -z "$rebuild_alias" ]]; then
    jq -n '{error: "No rebuild alias configured"}'
    return 1
  fi

  local output
  if output="$(bash -lc "$rebuild_alias" 2>&1)"; then
    jq -n --arg output "$output" '{ok: true, output: $output}'
    return 0
  fi

  jq -n --arg error "Rebuild command failed" --arg output "$output" '{error: $error, output: $output}'
  return 1
}

cmd="${1:-}"
case "$cmd" in
  state)
    emit_state
    ;;
  set-path)
    shift
    path="${1:-}"
    channel="$(get_channel)"
    save_config "$path" "$channel"
    emit_state
    ;;
  set-channel)
    shift
    channel="${1:-nixos-unstable}"
    path="$(get_packages_file)"
    save_config "$path" "$channel"
    emit_state
    ;;
  search)
    shift
    query="${1:-}"
    limit="${2:-30}"
    search_packages "$query" "$limit"
    ;;
  add)
    shift
    pkg="${1:-}"
    target="$(require_packages_file)"
    python3 "$PY_HELPER" add "$target" "$pkg"
    ;;
  remove)
    shift
    pkg="${1:-}"
    target="$(require_packages_file)"
    python3 "$PY_HELPER" remove "$target" "$pkg"
    ;;
  read)
    target="$(require_packages_file)"
    python3 "$PY_HELPER" read "$target"
    ;;
  rebuild)
    run_rebuild
    ;;
  *)
    jq -n --arg error "unknown command: $cmd" '{error: $error}'
    exit 1
    ;;
esac
