export HUB_DIR="$HOME/.crush_hub"
export USERS_DIR="$HUB_DIR/users"
export WORKSPACES="$HOME/workspaces"
export HUB_CONF="$HUB_DIR/config"
export TMUX_SESSION="cloud"
export SESSION_LABEL="${SESSION_LABEL:-Cloud Hub OS}"
export PROXY_URL="http://localhost:8080"
mkdir -p "$USERS_DIR" "$WORKSPACES" "$HUB_CONF"

hub_active_user() {
  cat "$HUB_CONF/active_user" 2>/dev/null \
    || ls -1t "$USERS_DIR" 2>/dev/null | head -n1 \
    || echo "default"
}
hub_set_user() { echo "$1" > "$HUB_CONF/active_user"; }
hub_user_pat() {
  local u="${1:-$(hub_active_user)}"
  cat "$USERS_DIR/$u/pat" 2>/dev/null
}
hub_user_email() {
  local u="${1:-$(hub_active_user)}"
  cat "$USERS_DIR/$u/email" 2>/dev/null || echo "${u}@cloud.local"
}
hub_current_repo() { cat "$HUB_CONF/current_repo" 2>/dev/null; }
hub_set_repo() { echo "$1" > "$HUB_CONF/current_repo"; }
hub_github_repo() {
  echo "${GITHUB_REPOSITORY:-$(cat "$HUB_CONF/github_repo" 2>/dev/null)}"
}
hub_proxy_models() {
  curl -sf "$PROXY_URL/v1/models" 2>/dev/null \
    | jq -r '.data[].id' 2>/dev/null || echo ""
}
hub_proxy_alive() {
  curl -sf "$PROXY_URL/v1/models" >/dev/null 2>&1
}
hub_proxy_account_status() {
  grep -E 'acc[0-9]+:' ~/proxy.log 2>/dev/null | tail -5
}
hub_proxy_any_invalid() {
  grep -qiE 'acc[0-9]+: *(invalid|expired)' ~/proxy.log 2>/dev/null
}
hub_write_hermes_config() {
  local profile_dir="$1"
  mkdir -p "$profile_dir"
  cat > "$profile_dir/config.yaml" << 'CFGEOF'
model:
  provider: custom
  base_url: http://localhost:8080/v1
  default: qwen3.6-plus
  context_length: 1048576
compression:
  enabled: true
  threshold: 0.95
  target_ratio: 0.20
  protect_last_n: 50
agent:
  max_turns: 10000
tools:
  timeout: 21600
api:
  timeout: 21600
display:
  verbose: true
  skin: default
CFGEOF
  printf 'OPENAI_API_KEY=sk-qwen-proxy-local\n' > "$profile_dir/.env"
}
hub_push_secret() {
  local sname="$1" sval="$2" pat="${3:-$(hub_user_pat)}" repo
  repo="$(hub_github_repo)"
  if [ -z "$pat" ]; then dialog --msgbox "ERROR: No PAT found for current user." 7 52; return 1; fi
  if [ -z "$repo" ]; then dialog --msgbox "ERROR: GitHub repo not set." 7 52; return 1; fi
  if [ -z "$sname" ] || [ -z "$sval" ]; then dialog --msgbox "ERROR: Name or value empty." 5 45; return 1; fi
  local pk_json
  pk_json=$(curl -sf \
    -H "Authorization: Bearer $pat" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$repo/actions/secrets/public-key" 2>/dev/null)
  if [ -z "$pk_json" ] || [ "$(echo "$pk_json" | jq -r '.key // empty')" = "" ]; then
    dialog --msgbox "ERROR: Could not fetch public key.\nCheck PAT has repo scope." 7 58; return 1
  fi
  local key_id key_val encrypted http_code
  key_id=$(echo "$pk_json" | jq -r '.key_id')
  key_val=$(echo "$pk_json" | jq -r '.key')
  encrypted=$(python3 /usr/local/bin/hub_encrypt.py "$key_val" "$sval" 2>/dev/null)
  if [ -z "$encrypted" ]; then dialog --msgbox "ERROR: Encryption failed." 7 52; return 1; fi
  http_code=$(curl -sf -o /dev/null -w "%{http_code}" -X PUT \
    -H "Authorization: Bearer $pat" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$repo/actions/secrets/$sname" \
    -d "{\"encrypted_value\":\"$encrypted\",\"key_id\":\"$key_id\"}" 2>/dev/null) || true
  case "$http_code" in
    201|204) dialog --msgbox "Secret '$sname' saved!\nAvailable on the NEXT run." 8 52 ;;
    401|403) dialog --msgbox "ERROR $http_code: Permission denied.\nNeeds classic PAT with repo scope." 7 58 ;;
    404)     dialog --msgbox "ERROR 404: Repo '$repo' not found." 7 52 ;;
    *)       dialog --msgbox "ERROR: API returned HTTP $http_code." 6 52 ;;
  esac
}
hub_save_repo() {
  local repo_path="$1"
  local msg="${2:-Cloud session sync $(date -u '+%Y-%m-%d %H:%M UTC')}"
  local user="${3:-$(hub_active_user)}"
  [ -d "$repo_path/.git" ] || return 1
  (
    cd "$repo_path" || return 1
    git config user.name  "$user"
    git config user.email "$(hub_user_email "$user")"
    git add -A
    if git diff-index --quiet HEAD 2>/dev/null; then
      echo "  nothing to commit in $(basename "$repo_path")"
    else
      git commit -m "$msg" && git push && echo "  saved: $(basename "$repo_path")"
    fi
  ) 2>&1
}
hub_ensure_window() {
  local user="${1:-$(hub_active_user)}"
  local win_name="u-${user}"
  if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    if ! tmux list-windows -t "$TMUX_SESSION" -F '#W' 2>/dev/null | grep -qx "$win_name"; then
      tmux new-window -t "$TMUX_SESSION" -n "$win_name" 2>/dev/null
    fi
    if [ -n "$TMUX" ]; then
      tmux select-window -t "$TMUX_SESSION:$win_name" 2>/dev/null
    fi
  fi
}
hub_print_links() {
  local upterm_ssh cf_web
  upterm_ssh=$(cat "$HUB_CONF/upterm_ssh" 2>/dev/null || echo "not ready")
  cf_web=$(cat "$HUB_CONF/cf_web" 2>/dev/null || echo "not ready")
  printf '\n'
  printf '  +----------------------------------------------------------------+\n'
  printf '  |  SSH  (Termux / iOS / Mac / Windows / Linux, no extra tools): |\n'
  printf '  |  %s\n' "$upterm_ssh"
  printf '  |  Termux one-liner: pkg install openssh && %s\n' "$upterm_ssh"
  printf '  |                                                                |\n'
  printf '  |  WEB  (ttyd via Cloudflare, any browser):                    |\n'
  printf '  |  %s\n' "$cf_web"
  printf '  +----------------------------------------------------------------+\n'
  printf '\n'
}
