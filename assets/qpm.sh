#!/usr/bin/env bash
set -euo pipefail

CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell-package-manager"
CONFIG_FILE="$CONFIG_ROOT/config.json"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-package-manager"
REBUILD_STATE_FILE="$STATE_ROOT/rebuild-state.json"
REBUILD_LOG_FILE="$STATE_ROOT/rebuild.log"
HELPER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PY_HELPER="$HELPER_DIR/packages_file.py"

mkdir -p "$CONFIG_ROOT"
mkdir -p "$STATE_ROOT"

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

write_rebuild_state() {
  local status="$1"
  local message="$2"
  local pid="${3:-null}"
  local code="${4:-null}"
  local now
  now="$(date -Iseconds)"

  jq -n \
    --arg status "$status" \
    --arg message "$message" \
    --arg updatedAt "$now" \
    --argjson pid "$pid" \
    --argjson code "$code" \
    '{status: $status, message: $message, pid: $pid, code: $code, updatedAt: $updatedAt}' > "$REBUILD_STATE_FILE"
}

ensure_rebuild_state() {
  if [[ ! -f "$REBUILD_STATE_FILE" ]]; then
    write_rebuild_state "idle" "Ready" null null
  fi
}

read_rebuild_state() {
  ensure_rebuild_state
  cat "$REBUILD_STATE_FILE"
}

query_rebuild_status() {
  local state status pid
  state="$(read_rebuild_state)"
  status="$(jq -r '.status // "idle"' <<< "$state")"
  pid="$(jq -r '.pid // empty' <<< "$state")"

  if [[ "$status" == "running" && -n "$pid" ]]; then
    if kill -0 "$pid" 2>/dev/null; then
      printf '%s\n' "$state"
      return
    fi

    local last_line
    last_line="$(tail -n 1 "$REBUILD_LOG_FILE" 2>/dev/null || true)"
    if [[ -n "$last_line" ]]; then
      write_rebuild_state "failed" "$last_line" null 1
    else
      write_rebuild_state "failed" "Rebuild process ended unexpectedly" null 1
    fi
  fi

  read_rebuild_state
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
    write_rebuild_state "failed" "No rebuild alias configured" null null
    jq -n '{error: "No rebuild alias configured"}'
    return 1
  fi

  local current_state current_status current_pid
  current_state="$(query_rebuild_status)"
  current_status="$(jq -r '.status // "idle"' <<< "$current_state")"
  current_pid="$(jq -r '.pid // empty' <<< "$current_state")"

  if [[ "$current_status" == "running" && -n "$current_pid" ]]; then
    jq -n --arg message "Rebuild already in progress" '{ok: true, alreadyRunning: true, message: $message}'
    return 0
  fi

  local runner
  runner="$(mktemp "$STATE_ROOT/rebuild-runner.XXXXXX.sh")"
  cat > "$runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

set +e
bash -lc "$QPM_REBUILD_ALIAS" > "$QPM_REBUILD_LOG_FILE" 2>&1
exit_code=$?
set -e

last_line="$(tail -n 1 "$QPM_REBUILD_LOG_FILE" 2>/dev/null || true)"
updated_at="$(date -Iseconds)"

if [[ "$exit_code" -eq 0 ]]; then
  message="${last_line:-Rebuild completed}"
  jq -n --arg message "$message" --arg updatedAt "$updated_at" '{status:"success", message:$message, pid:null, code:0, updatedAt:$updatedAt}' > "$QPM_REBUILD_STATE_FILE"
else
  message="${last_line:-Rebuild command failed}"
  jq -n --arg message "$message" --arg updatedAt "$updated_at" --argjson code "$exit_code" '{status:"failed", message:$message, pid:null, code:$code, updatedAt:$updatedAt}' > "$QPM_REBUILD_STATE_FILE"
fi
EOF
  chmod +x "$runner"

  : > "$REBUILD_LOG_FILE"
  nohup env \
    QPM_REBUILD_ALIAS="$rebuild_alias" \
    QPM_REBUILD_LOG_FILE="$REBUILD_LOG_FILE" \
    QPM_REBUILD_STATE_FILE="$REBUILD_STATE_FILE" \
    bash "$runner" >/dev/null 2>&1 &
  local rebuild_pid=$!

  write_rebuild_state "running" "Rebuild in progress" "$rebuild_pid" null
  jq -n '{ok: true, status: "running", message: "Rebuild in progress"}'
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
  rebuild-status)
    query_rebuild_status
    ;;
  *)
    jq -n --arg error "unknown command: $cmd" '{error: $error}'
    exit 1
    ;;
esac
