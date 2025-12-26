#!/usr/bin/env bash

# Simple profile manager for Codex/Claude Code/Gemini CLI.
# Currently implements Codex, Claude Code, and Gemini CLI profile save/switch.

set -euo pipefail

CODEX_DIR="${HOME}/.codex"
CODEX_CONFIG="${CODEX_DIR}/config.toml"
CODEX_AUTH="${CODEX_DIR}/auth.json"
AIM_DIR="${CODEX_DIR}/aiM"
CODEX_PROVIDER_FILE="provider.env"
CODEX_PROVIDERS_DIR="${AIM_DIR}/providers"
CODEX_MCP_DIR="${AIM_DIR}/mcp"
CODEX_GLOBAL_FILE="${AIM_DIR}/global.env"
CODEX_MCP_PREFIX="mcp-"
CODEX_MCP_SUFFIX=".toml"
CLAUDE_DIR="${HOME}/.claude"
CLAUDE_CONFIG="${CLAUDE_DIR}/config.json"
CLAUDE_SETTINGS="${CLAUDE_DIR}/settings.json"
CLAUDE_AIM_DIR="${CLAUDE_DIR}/aiM"
GEMINI_DIR="${HOME}/.gemini"
GEMINI_AIM_DIR="${GEMINI_DIR}/aiM"
GEMINI_FILES=("google_accounts.json" "oauth_creds.json" "settings.json" "state.json")

prompt() {
  local msg=$1
  read -r -p "$msg" reply
  echo "$reply"
}

pause() {
  read -r -p "按回车继续..." _
}

prompt_profile_name() {
  local label=$1
  local name
  while :; do
    name=$(prompt "为当前${label}配置输入一个名称（仅字母数字、下划线、短横线；输入0取消）：")
    name=${name// /}
    if [[ "$name" == "0" ]]; then
      return 1
    fi
    if [[ -z "$name" ]]; then
      echo "名称不能为空。" >&2
      continue
    fi
    if [[ "$name" =~ [^a-zA-Z0-9_-] ]]; then
      echo "名称只能包含字母、数字、下划线或短横线。" >&2
      continue
    fi
    printf '%s\n' "$name"
    return 0
  done
}

ensure_codex_dirs() {
  mkdir -p "$CODEX_PROVIDERS_DIR" "$CODEX_MCP_DIR"
}

ensure_claude_dirs() {
  mkdir -p "$CLAUDE_AIM_DIR"
}

ensure_gemini_dirs() {
  mkdir -p "$GEMINI_AIM_DIR"
}

base64_encode_file() {
  local file=$1
  if command -v base64 >/dev/null 2>&1; then
    if base64 --help 2>/dev/null | grep -q -- '-w'; then
      base64 -w 0 "$file"
    else
      base64 "$file" | tr -d '\n'
    fi
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" <<'PY'
import base64
import sys

with open(sys.argv[1], "rb") as f:
    sys.stdout.write(base64.b64encode(f.read()).decode("ascii"))
PY
    return 0
  fi
  echo "错误：需要 base64 或 python3 来编码 auth.json。"
  return 1
}

base64_decode_to_file() {
  local encoded=$1
  local dest=$2
  if command -v base64 >/dev/null 2>&1; then
    if printf '%s' "$encoded" | base64 -d > "$dest" 2>/dev/null; then
      return 0
    fi
    if printf '%s' "$encoded" | base64 -D > "$dest" 2>/dev/null; then
      return 0
    fi
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$encoded" | python3 - "$dest" <<'PY'
import base64
import sys

data = sys.stdin.read().encode("ascii")
decoded = base64.b64decode(data)
with open(sys.argv[1], "wb") as f:
    f.write(decoded)
PY
    return 0
  fi
  echo "错误：需要 base64 或 python3 来解码 auth.json。"
  return 1
}

codex_get_toml_value() {
  local config=$1
  local key=$2
  awk -v key="$key" '
    $0 ~ "^" key "[[:space:]]*=" {
      sub("^[^=]+=[[:space:]]*", "", $0)
      gsub("\"", "", $0)
      print $0
      exit
    }
  ' "$config"
}

codex_get_provider_field() {
  local config=$1
  local provider=$2
  local key=$3
  awk -v provider="$provider" -v key="$key" '
    $0 ~ "^\\[model_providers\\." provider "\\]" { in=1; next }
    /^\[/ { if (in) exit; next }
    in && $0 ~ "^" key "[[:space:]]*=" {
      sub("^[^=]+=[[:space:]]*", "", $0)
      gsub("\"", "", $0)
      print $0
      exit
    }
  ' "$config"
}

codex_read_env_value() {
  local file=$1
  local key=$2
  sed -n "s/^${key}=//p" "$file" | head -1
}

codex_write_global_settings() {
  local model=$1
  local reasoning=$2
  ensure_codex_dirs
  {
    echo "MODEL=$model"
    echo "MODEL_REASONING_EFFORT=$reasoning"
  } > "$CODEX_GLOBAL_FILE"
}

codex_load_global_settings() {
  local model=""
  local reasoning=""
  local needs_write=0

  if [ -f "$CODEX_GLOBAL_FILE" ]; then
    while IFS='=' read -r key value; do
      key=${key//$'\r'/}
      value=${value%$'\r'}
      if [[ -z "$key" || "$key" == \#* ]]; then
        continue
      fi
      case "$key" in
        MODEL) model="$value" ;;
        MODEL_REASONING_EFFORT) reasoning="$value" ;;
      esac
    done < "$CODEX_GLOBAL_FILE"
  else
    needs_write=1
  fi

  if [[ -z "$model" ]]; then
    if [ -f "$CODEX_CONFIG" ]; then
      model=$(codex_get_toml_value "$CODEX_CONFIG" "model")
    fi
  fi
  if [[ -z "$model" ]]; then
    model=$(codex_find_provider_value "MODEL")
  fi
  if [[ -z "$model" ]]; then
    model="gpt-5.2-codex"
  fi

  if [[ -z "$reasoning" ]]; then
    if [ -f "$CODEX_CONFIG" ]; then
      reasoning=$(codex_get_toml_value "$CODEX_CONFIG" "model_reasoning_effort")
    fi
  fi
  if [[ -z "$reasoning" ]]; then
    reasoning=$(codex_find_provider_value "MODEL_REASONING_EFFORT")
  fi
  if [[ -z "$reasoning" ]]; then
    reasoning="high"
  fi

  if [[ ! -f "$CODEX_GLOBAL_FILE" || $needs_write -eq 1 ]]; then
    codex_write_global_settings "$model" "$reasoning"
  else
    if ! grep -q '^MODEL=' "$CODEX_GLOBAL_FILE" || ! grep -q '^MODEL_REASONING_EFFORT=' "$CODEX_GLOBAL_FILE"; then
      codex_write_global_settings "$model" "$reasoning"
    fi
  fi

  MODEL="$model"
  MODEL_REASONING_EFFORT="$reasoning"
}

codex_find_provider_value() {
  local key=$1
  local file
  for file in "$CODEX_PROVIDERS_DIR"/*/"$CODEX_PROVIDER_FILE" "$AIM_DIR"/*/"$CODEX_PROVIDER_FILE"; do
    [ -f "$file" ] || continue
    local value
    value=$(sed -n "s/^${key}=//p" "$file" | head -1)
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done
  return 0
}

codex_extract_provider_from_config() {
  local config=$1
  local auth=$2
  local provider_file=$3

  local provider_name
  provider_name=$(codex_get_toml_value "$config" "model_provider")
  if [[ -z "$provider_name" ]]; then
    echo "错误：无法读取 model_provider。"
    return 1
  fi

  local disable_response_storage="true"

  local base_url wire_api requires_auth
  base_url=$(codex_get_provider_field "$config" "$provider_name" "base_url")
  wire_api="responses"
  requires_auth="true"

  if [[ -z "$base_url" ]]; then
    echo "错误：无法读取 ${provider_name} 的 base_url。"
    return 1
  fi

  if [ ! -f "$auth" ]; then
    echo "错误：未找到 ${auth}。"
    return 1
  fi

  local auth_type="api_key"
  local openai_api_key=""
  openai_api_key=$(sed -n 's/.*"OPENAI_API_KEY":[[:space:]]*"\([^"]*\)".*/\1/p' "$auth" | head -1)

  if grep -q '"tokens"' "$auth" || grep -q '"access_token"' "$auth" || grep -q '"id_token"' "$auth" || grep -q '"OPENAI_API_KEY":[[:space:]]*null' "$auth"; then
    auth_type="official"
  fi

  local auth_json_b64=""
  if [[ "$auth_type" == "official" ]]; then
    if ! auth_json_b64=$(base64_encode_file "$auth"); then
      return 1
    fi
  fi

  {
    echo "PROVIDER_NAME=$provider_name"
    echo "BASE_URL=$base_url"
    echo "WIRE_API=$wire_api"
    echo "REQUIRES_OPENAI_AUTH=$requires_auth"
    if [[ -n "$disable_response_storage" ]]; then
      echo "DISABLE_RESPONSE_STORAGE=$disable_response_storage"
    fi
    echo "AUTH_TYPE=$auth_type"
    if [[ "$auth_type" == "api_key" && -n "$openai_api_key" && "$openai_api_key" != "null" ]]; then
      echo "OPENAI_API_KEY=$openai_api_key"
    fi
    if [[ "$auth_type" == "official" && -n "$auth_json_b64" ]]; then
      echo "AUTH_JSON_B64=$auth_json_b64"
    fi
  } > "$provider_file"
}

codex_extract_mcp_from_config() {
  local config=$1
  local target=$2
  awk '
    BEGIN { keep=0 }
    /^\[/ {
      if ($0 ~ /^\[mcp_servers\./ || $0 ~ /^\[projects\./ || $0 ~ /^\[notice\]/) {
        keep=1
      } else {
        keep=0
      }
    }
    keep { print }
  ' "$config" > "$target"
}

codex_load_provider() {
  local provider_file=$1
  PROVIDER_NAME=""
  BASE_URL=""
  WIRE_API=""
  REQUIRES_OPENAI_AUTH=""
  MODEL=""
  MODEL_REASONING_EFFORT=""
  DISABLE_RESPONSE_STORAGE=""
  AUTH_TYPE=""
  OPENAI_API_KEY=""
  AUTH_JSON_B64=""

  while IFS='=' read -r key value; do
    key=${key//$'\r'/}
    value=${value%$'\r'}
    if [[ -z "$key" || "$key" == \#* ]]; then
      continue
    fi
    case "$key" in
      PROVIDER_NAME) PROVIDER_NAME="$value" ;;
      BASE_URL) BASE_URL="$value" ;;
      WIRE_API) WIRE_API="$value" ;;
      REQUIRES_OPENAI_AUTH) REQUIRES_OPENAI_AUTH="$value" ;;
      DISABLE_RESPONSE_STORAGE) DISABLE_RESPONSE_STORAGE="$value" ;;
      AUTH_TYPE) AUTH_TYPE="$value" ;;
      OPENAI_API_KEY) OPENAI_API_KEY="$value" ;;
      AUTH_JSON_B64) AUTH_JSON_B64="$value" ;;
    esac
  done < "$provider_file"

  if [[ -z "$AUTH_TYPE" ]]; then
    if [[ -n "$AUTH_JSON_B64" ]]; then
      AUTH_TYPE="official"
    else
      AUTH_TYPE="api_key"
    fi
  fi

  codex_load_global_settings

  if [[ -z "$WIRE_API" ]]; then
    WIRE_API="responses"
  fi
  if [[ -z "$REQUIRES_OPENAI_AUTH" ]]; then
    REQUIRES_OPENAI_AUTH="true"
  fi
}

codex_write_auth_from_provider() {
  if [[ -n "$AUTH_JSON_B64" ]]; then
    if ! base64_decode_to_file "$AUTH_JSON_B64" "$CODEX_AUTH"; then
      return 1
    fi
    return 0
  fi

  if [[ "$AUTH_TYPE" == "official" ]]; then
    echo "错误：官方登录缺少 auth.json。"
    return 1
  fi

  if [[ -z "$OPENAI_API_KEY" ]]; then
    echo "错误：缺少 OPENAI_API_KEY。"
    return 1
  fi

  {
    echo "{"
    echo "  \"OPENAI_API_KEY\": \"${OPENAI_API_KEY}\""
    echo "}"
  } > "$CODEX_AUTH"
}

codex_write_config_from_provider() {
  local mcp_file=$1

  if [[ -z "$PROVIDER_NAME" || -z "$BASE_URL" ]]; then
    echo "错误：供应商信息不完整，无法生成 config.toml。"
    return 1
  fi

  {
    echo "model_provider = \"${PROVIDER_NAME}\""
    if [[ -n "$MODEL" ]]; then
      echo "model = \"${MODEL}\""
    fi
    if [[ -n "$MODEL_REASONING_EFFORT" ]]; then
      echo "model_reasoning_effort = \"${MODEL_REASONING_EFFORT}\""
    fi
    if [[ -n "$DISABLE_RESPONSE_STORAGE" ]]; then
      echo "disable_response_storage = ${DISABLE_RESPONSE_STORAGE}"
    fi
    echo
    echo "[model_providers.${PROVIDER_NAME}]"
    echo "name = \"${PROVIDER_NAME}\""
    echo "base_url = \"${BASE_URL}\""
    echo "wire_api = \"${WIRE_API}\""
    echo "requires_openai_auth = ${REQUIRES_OPENAI_AUTH}"
    if [[ -s "$mcp_file" ]]; then
      echo
      cat "$mcp_file"
    fi
  } > "$CODEX_CONFIG"
}

codex_import_legacy_profile() {
  local dir=$1
  local name
  name=$(basename "$dir")

  local config="${dir}/config.toml"
  local auth="${dir}/auth.json"
  local legacy_provider="${dir}/${CODEX_PROVIDER_FILE}"
  local provider_dir="${CODEX_PROVIDERS_DIR}/${name}"
  local provider_file="${provider_dir}/${CODEX_PROVIDER_FILE}"

  CODEX_IMPORTED_PROVIDER_DIR=""

  mkdir -p "$provider_dir"
  if [ ! -f "$provider_file" ]; then
    if [ -f "$legacy_provider" ]; then
      cp "$legacy_provider" "$provider_file"
    elif [ -f "$config" ] && [ -f "$auth" ]; then
      if ! codex_extract_provider_from_config "$config" "$auth" "$provider_file"; then
        return 1
      fi
    else
      return 1
    fi
  fi

  local migrated=0
  local legacy_mcp
  for legacy_mcp in "${dir}/${CODEX_MCP_PREFIX}"*"${CODEX_MCP_SUFFIX}"; do
    [ -f "$legacy_mcp" ] || continue
    local base name_part target_name target
    base=$(basename "$legacy_mcp")
    name_part=${base#${CODEX_MCP_PREFIX}}
    name_part=${name_part%${CODEX_MCP_SUFFIX}}
    target_name="${name}-${name_part}"
    target="${CODEX_MCP_DIR}/${CODEX_MCP_PREFIX}${target_name}${CODEX_MCP_SUFFIX}"
    if [ ! -f "$target" ]; then
      cp "$legacy_mcp" "$target"
    fi
    migrated=1
  done

  if [[ $migrated -eq 0 && -f "$config" ]]; then
    local target="${CODEX_MCP_DIR}/${CODEX_MCP_PREFIX}${name}-default${CODEX_MCP_SUFFIX}"
    if [ ! -f "$target" ]; then
      codex_extract_mcp_from_config "$config" "$target"
    fi
  fi

  CODEX_IMPORTED_PROVIDER_DIR="$provider_dir"
}

codex_select_provider() {
  local choices=()
  local display=()
  CODEX_SELECTED_PROVIDER_DIR=""
  CODEX_SELECTED_PROVIDER_NAME=""

  for dir in "$CODEX_PROVIDERS_DIR"/*; do
    [ -d "$dir" ] || continue
    if [ -f "${dir}/${CODEX_PROVIDER_FILE}" ]; then
      local name
      name=$(basename "$dir")
      choices+=("$dir")
      display+=("$name")
    fi
  done

  local legacy
  for legacy in "$AIM_DIR"/*; do
    [ -d "$legacy" ] || continue
    local legacy_name
    legacy_name=$(basename "$legacy")
    if [[ "$legacy_name" == "$(basename "$CODEX_PROVIDERS_DIR")" || "$legacy_name" == "$(basename "$CODEX_MCP_DIR")" ]]; then
      continue
    fi
    if [ -f "${legacy}/${CODEX_PROVIDER_FILE}" ] || { [ -f "${legacy}/config.toml" ] && [ -f "${legacy}/auth.json" ]; }; then
      choices+=("$legacy")
      display+=("${legacy_name} (legacy)")
    fi
  done

  if [ ${#choices[@]} -eq 0 ]; then
    echo "暂无已保存的供应商配置。"
    pause
    return 1
  fi

  echo "已保存的供应商："
  local idx=1
  for name in "${display[@]}"; do
    echo "  ${idx}) ${name}"
    idx=$((idx + 1))
  done

  local selection
  while :; do
    selection=$(prompt "输入要选择的供应商编号（输入0返回）：")
    if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo "请输入有效编号。"
      continue
    fi
    if (( selection == 0 )); then
      CODEX_SELECTED_PROVIDER_DIR=""
      CODEX_SELECTED_PROVIDER_NAME=""
      return 1
    fi
    if (( selection < 1 || selection > ${#choices[@]} )); then
      echo "编号超出范围，请重试。"
      continue
    fi
    break
  done

  local chosen_path="${choices[$((selection - 1))]}"
  if [[ "$chosen_path" == "$CODEX_PROVIDERS_DIR/"* ]]; then
    CODEX_SELECTED_PROVIDER_DIR="$chosen_path"
  else
    if ! codex_import_legacy_profile "$chosen_path"; then
      echo "所选供应商缺少必要文件，无法切换。"
      pause
      return 1
    fi
    CODEX_SELECTED_PROVIDER_DIR="$CODEX_IMPORTED_PROVIDER_DIR"
  fi

  CODEX_SELECTED_PROVIDER_NAME=$(basename "$CODEX_SELECTED_PROVIDER_DIR")
}

codex_select_mcp_set() {
  local choices=()
  local display=()
  CODEX_SELECTED_MCP_FILE=""

  local file
  for file in "${CODEX_MCP_DIR}/${CODEX_MCP_PREFIX}"*"${CODEX_MCP_SUFFIX}"; do
    [ -f "$file" ] || continue
    local name
    name=$(basename "$file")
    name=${name#${CODEX_MCP_PREFIX}}
    name=${name%${CODEX_MCP_SUFFIX}}
    choices+=("$file")
    display+=("$name")
  done

  if [ ${#choices[@]} -eq 0 ]; then
    echo "暂无 MCP/信任配置，请先保存。"
    pause
    return 1
  fi

  echo "可用的 MCP/信任配置："
  local idx=1
  for name in "${display[@]}"; do
    echo "  ${idx}) ${name}"
    idx=$((idx + 1))
  done

  local selection
  while :; do
    selection=$(prompt "输入要选择的配置编号（输入0返回）：")
    if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo "请输入有效编号。"
      continue
    fi
    if (( selection == 0 )); then
      CODEX_SELECTED_MCP_FILE=""
      return 1
    fi
    if (( selection < 1 || selection > ${#choices[@]} )); then
      echo "编号超出范围，请重试。"
      continue
    fi
    break
  done

  CODEX_SELECTED_MCP_FILE="${choices[$((selection - 1))]}"
}

save_codex_profile() {
  ensure_codex_dirs

  if [ ! -f "$CODEX_CONFIG" ] || [ ! -f "$CODEX_AUTH" ]; then
    echo "未找到 ${CODEX_CONFIG} 或 ${CODEX_AUTH}，无法保存。"
    pause
    return
  fi

  local name
  if ! name=$(prompt_profile_name "Codex 供应商"); then
    echo "已取消保存。"
    pause
    return
  fi

  local target_dir="${CODEX_PROVIDERS_DIR}/${name}"
  mkdir -p "$target_dir"

  local provider_file="${target_dir}/${CODEX_PROVIDER_FILE}"
  if [ -f "$provider_file" ]; then
    local overwrite
    overwrite=$(prompt "供应商已存在，是否覆盖供应商信息？(y/N)：")
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
      echo "已取消保存。"
      pause
      return
    fi
  fi

  if ! codex_extract_provider_from_config "$CODEX_CONFIG" "$CODEX_AUTH" "$provider_file"; then
    pause
    return
  fi

  echo "已保存当前供应商为：$name"
  echo "请在「保存 MCP/信任配置」中创建 MCP/信任配置。"
  pause
}

save_codex_mcp_set() {
  ensure_codex_dirs

  if [ ! -f "$CODEX_CONFIG" ]; then
    echo "未找到 ${CODEX_CONFIG}，无法保存 MCP/信任配置。"
    pause
    return
  fi

  local mcp_name
  if ! mcp_name=$(prompt_profile_name "MCP/信任配置"); then
    echo "已取消保存。"
    pause
    return
  fi

  local mcp_file="${CODEX_MCP_DIR}/${CODEX_MCP_PREFIX}${mcp_name}${CODEX_MCP_SUFFIX}"
  if [ -f "$mcp_file" ]; then
    local overwrite
    overwrite=$(prompt "MCP/信任配置已存在，是否覆盖？(y/N)：")
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
      echo "已取消保存。"
      pause
      return
    fi
  fi

  codex_extract_mcp_from_config "$CODEX_CONFIG" "$mcp_file"
  echo "已保存 MCP/信任配置：$mcp_name"
  pause
}

switch_codex_profile() {
  ensure_codex_dirs

  if ! codex_select_provider; then
    return
  fi

  local provider_dir="${CODEX_SELECTED_PROVIDER_DIR}"
  local chosen="${CODEX_SELECTED_PROVIDER_NAME}"
  local provider_file="${provider_dir}/${CODEX_PROVIDER_FILE}"
  if [ ! -f "$provider_file" ]; then
    echo "所选供应商缺少必要文件，无法切换。"
    pause
    return
  fi

  if ! codex_select_mcp_set; then
    return
  fi
  local mcp_file="${CODEX_SELECTED_MCP_FILE}"

  codex_load_provider "$provider_file"
  if ! codex_write_auth_from_provider; then
    pause
    return
  fi

  if ! codex_write_config_from_provider "$mcp_file"; then
    pause
    return
  fi

  local mcp_name
  mcp_name=$(basename "$mcp_file")
  mcp_name=${mcp_name#${CODEX_MCP_PREFIX}}
  mcp_name=${mcp_name%${CODEX_MCP_SUFFIX}}

  echo "已切换到供应商：$chosen"
  echo "  MCP/信任配置：$mcp_name"
  pause
}

update_codex_model() {
  ensure_codex_dirs

  local new_model new_reasoning
  new_model=$(prompt "请输入新的模型名称（如 gpt-5.2-codex，输入0取消）：")
  new_model=${new_model// /}
  if [[ "$new_model" == "0" || -z "$new_model" ]]; then
    echo "已取消更新。"
    pause
    return
  fi

  new_reasoning=$(prompt "请输入新的思考强度（如 low/medium/high，输入0取消）：")
  new_reasoning=${new_reasoning// /}
  if [[ "$new_reasoning" == "0" || -z "$new_reasoning" ]]; then
    echo "已取消更新。"
    pause
    return
  fi

  echo "将更新全局模型/思考强度："
  echo "  模型：$new_model"
  echo "  思考强度：$new_reasoning"

  local confirm
  confirm=$(prompt "确认更新？(y/N)：")
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消更新。"
    pause
    return
  fi

  codex_write_global_settings "$new_model" "$new_reasoning"
  local provider_file
  for provider_file in "$CODEX_PROVIDERS_DIR"/*/"$CODEX_PROVIDER_FILE"; do
    [ -f "$provider_file" ] || continue
    sed -i '/^MODEL=/d;/^MODEL_REASONING_EFFORT=/d' "$provider_file"
  done

  echo "已更新全局模型/思考强度。"
  pause
}

delete_codex_profile() {
  ensure_codex_dirs

  local choices=()
  local display=()
  for dir in "$CODEX_PROVIDERS_DIR"/*; do
    [ -d "$dir" ] || continue
    local name
    name=$(basename "$dir")
    if [ -f "${dir}/${CODEX_PROVIDER_FILE}" ]; then
      choices+=("$name")
      display+=("$name")
    fi
  done

  if [ ${#choices[@]} -eq 0 ]; then
    echo "暂无可删除的供应商。"
    pause
    return
  fi

  echo "可删除的供应商："
  local idx=1
  for name in "${display[@]}"; do
    echo "  ${idx}) ${name}"
    idx=$((idx + 1))
  done

  local selection
  while :; do
    selection=$(prompt "输入要删除的供应商编号（输入0返回）：")
    if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo "请输入有效编号。"
      continue
    fi
    if (( selection == 0 )); then
      return
    fi
    if (( selection < 1 || selection > ${#choices[@]} )); then
      echo "编号超出范围，请重试。"
      continue
    fi
    break
  done

  local chosen="${choices[$((selection - 1))]}"
  local target_dir="${CODEX_PROVIDERS_DIR}/${chosen}"
  local confirm
  confirm=$(prompt "确认删除供应商「${chosen}」？此操作不可恢复。(y/N)：")
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消删除。"
    pause
    return
  fi

  rm -rf -- "$target_dir"
  echo "已删除供应商：$chosen"
  pause
}

create_custom_provider() {
  ensure_codex_dirs

  if [ ! -f "$CODEX_CONFIG" ] || [ ! -f "$CODEX_AUTH" ]; then
    echo "未找到 ${CODEX_CONFIG} 或 ${CODEX_AUTH}，无法创建自定义供应源。"
    pause
    return
  fi

  local provider_name
  while :; do
    provider_name=$(prompt "请输入供应源名称（仅英文字母、数字、下划线、短横线；输入0取消）：")
    provider_name=${provider_name// /}

    if [[ "$provider_name" == "0" ]]; then
      echo "已取消创建。"
      pause
      return
    fi

    if [[ -z "$provider_name" ]]; then
      echo "供应源名称不能为空。"
      continue
    fi

    if [[ "$provider_name" =~ [^a-zA-Z0-9_-] ]]; then
      echo "供应源名称只能包含英文字母、数字、下划线或短横线。"
      continue
    fi

    break
  done

  local base_url
  while :; do
    base_url=$(prompt "请输入 API Base URL（如 https://api.example.com/v1；输入0取消）：")
    base_url=${base_url// /}

    if [[ "$base_url" == "0" ]]; then
      echo "已取消创建。"
      pause
      return
    fi

    if [[ -z "$base_url" ]]; then
      echo "Base URL 不能为空。"
      continue
    fi

    if [[ ! "$base_url" =~ ^https?:// ]]; then
      echo "Base URL 必须以 http:// 或 https:// 开头。"
      continue
    fi

    if [[ "$base_url" =~ ^http:// ]]; then
      local confirm_http
      confirm_http=$(prompt "警告：使用 HTTP 连接不安全。确认继续？(y/N)：")
      if [[ ! "$confirm_http" =~ ^[Yy]$ ]]; then
        continue
      fi
    fi

    local normalized_url
    normalized_url="${base_url%/}"
    if [[ "$normalized_url" != */v1 ]]; then
      normalized_url="${normalized_url}/v1"
    fi
    if [[ "$normalized_url" != "$base_url" ]]; then
      echo "Base URL 已补全为：$normalized_url"
    fi
    base_url="$normalized_url"

    break
  done

  local api_key
  while :; do
    api_key=$(prompt "请输入 API Key（输入0取消）：")
    api_key=${api_key// /}

    if [[ "$api_key" == "0" ]]; then
      echo "已取消创建。"
      pause
      return
    fi

    if [[ -z "$api_key" ]]; then
      echo "API Key 不能为空。"
      continue
    fi

    break
  done

  local wire_api="responses"
  local requires_auth="true"
  local disable_response_storage="true"

  local profile_name
  if ! profile_name=$(prompt_profile_name "自定义供应源"); then
    echo "已取消保存。"
    pause
    return
  fi

  local target_dir="${CODEX_PROVIDERS_DIR}/${profile_name}"
  mkdir -p "$target_dir"

  local provider_file="${target_dir}/${CODEX_PROVIDER_FILE}"
  if [ -f "$provider_file" ]; then
    local overwrite
    overwrite=$(prompt "供应商已存在，是否覆盖供应商信息？(y/N)：")
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
      echo "已取消保存。"
      pause
      return
    fi
  fi

  {
    echo "PROVIDER_NAME=$provider_name"
    echo "BASE_URL=$base_url"
    echo "WIRE_API=$wire_api"
    echo "REQUIRES_OPENAI_AUTH=$requires_auth"
    if [[ -n "$disable_response_storage" ]]; then
      echo "DISABLE_RESPONSE_STORAGE=$disable_response_storage"
    fi
    echo "AUTH_TYPE=api_key"
    echo "OPENAI_API_KEY=$api_key"
  } > "$provider_file"

  echo "已成功创建自定义供应源配置：$profile_name"
  echo "  供应源名称：$provider_name"
  echo "  Base URL：$base_url"
  echo "请在「保存 MCP/信任配置」中为该供应商创建配置。"
  pause
}

save_claude_profile() {
  ensure_claude_dirs

  if [ ! -f "$CLAUDE_CONFIG" ] || [ ! -f "$CLAUDE_SETTINGS" ]; then
    echo "未找到 ${CLAUDE_CONFIG} 或 ${CLAUDE_SETTINGS}，无法保存。"
    pause
    return
  fi

  local name
  if ! name=$(prompt_profile_name "Claude"); then
    echo "已取消保存。"
    pause
    return
  fi

  local target_dir="${CLAUDE_AIM_DIR}/${name}"
  if [ -e "$target_dir" ]; then
    local overwrite
    overwrite=$(prompt "配置已存在，是否覆盖？(y/N)：")
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
      echo "已取消保存。"
      pause
      return
    fi
  fi

  mkdir -p "$target_dir"
  cp "$CLAUDE_CONFIG" "${target_dir}/config.json"
  cp "$CLAUDE_SETTINGS" "${target_dir}/settings.json"
  echo "已保存当前配置为：$name"
  pause
}

switch_claude_profile() {
  ensure_claude_dirs

  local choices=()
  for dir in "$CLAUDE_AIM_DIR"/*; do
    [ -d "$dir" ] || continue
    choices+=("$(basename "$dir")")
  done

  if [ ${#choices[@]} -eq 0 ]; then
    echo "暂无已保存的配置。"
    pause
    return
  fi

  echo "已保存的配置："
  local idx=1
  for name in "${choices[@]}"; do
    echo "  ${idx}) ${name}"
    idx=$((idx + 1))
  done

  local selection
  while :; do
    selection=$(prompt "输入要切换的配置编号（输入0返回）：")
    if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo "请输入有效编号。"
      continue
    fi
    if (( selection == 0 )); then
      return
    fi
    if (( selection < 1 || selection > ${#choices[@]} )); then
      echo "编号超出范围，请重试。"
      continue
    fi
    break
  done

  local chosen="${choices[$((selection - 1))]}"

  if [ ! -f "${CLAUDE_AIM_DIR}/${chosen}/config.json" ] || [ ! -f "${CLAUDE_AIM_DIR}/${chosen}/settings.json" ]; then
    echo "所选配置缺少必要文件，无法切换。"
    pause
    return
  fi

  cp "${CLAUDE_AIM_DIR}/${chosen}/config.json" "$CLAUDE_CONFIG"
  cp "${CLAUDE_AIM_DIR}/${chosen}/settings.json" "$CLAUDE_SETTINGS"
  echo "已切换到配置：$chosen"
  pause
}

delete_claude_profile() {
  ensure_claude_dirs

  local choices=()
  for dir in "$CLAUDE_AIM_DIR"/*; do
    [ -d "$dir" ] || continue
    choices+=("$(basename "$dir")")
  done

  if [ ${#choices[@]} -eq 0 ]; then
    echo "暂无可删除的配置。"
    pause
    return
  fi

  echo "可删除的配置："
  local idx=1
  for name in "${choices[@]}"; do
    echo "  ${idx}) ${name}"
    idx=$((idx + 1))
  done

  local selection
  while :; do
    selection=$(prompt "输入要删除的配置编号（输入0返回）：")
    if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo "请输入有效编号。"
      continue
    fi
    if (( selection == 0 )); then
      return
    fi
    if (( selection < 1 || selection > ${#choices[@]} )); then
      echo "编号超出范围，请重试。"
      continue
    fi
    break
  done

  local chosen="${choices[$((selection - 1))]}"
  local target_dir="${CLAUDE_AIM_DIR}/${chosen}"
  local confirm
  confirm=$(prompt "确认删除配置「${chosen}」？此操作不可恢复。(y/N)：")
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消删除。"
    pause
    return
  fi

  rm -rf -- "$target_dir"
  echo "已删除配置：$chosen"
  pause
}

save_gemini_profile() {
  ensure_gemini_dirs

  local existing=()
  for f in "${GEMINI_FILES[@]}"; do
    if [ -f "${GEMINI_DIR}/${f}" ]; then
      existing+=("$f")
    fi
  done

  if [ ${#existing[@]} -eq 0 ]; then
    echo "未找到可保存的 Gemini 配置文件，已跳过。"
    pause
    return
  fi

  local name
  if ! name=$(prompt_profile_name "Gemini"); then
    echo "已取消保存。"
    pause
    return
  fi

  local target_dir="${GEMINI_AIM_DIR}/${name}"
  if [ -e "$target_dir" ]; then
    local overwrite
    overwrite=$(prompt "配置已存在，是否覆盖？(y/N)：")
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
      echo "已取消保存。"
      pause
      return
    fi
  fi

  mkdir -p "$target_dir"
  for f in "${existing[@]}"; do
    cp "${GEMINI_DIR}/${f}" "${target_dir}/${f}"
  done
  echo "已保存当前 Gemini 配置为：$name"
  pause
}

switch_gemini_profile() {
  ensure_gemini_dirs

  local choices=()
  for dir in "$GEMINI_AIM_DIR"/*; do
    [ -d "$dir" ] || continue
    choices+=("$(basename "$dir")")
  done

  if [ ${#choices[@]} -eq 0 ]; then
    echo "暂无已保存的配置。"
    pause
    return
  fi

  echo "已保存的配置："
  local idx=1
  for name in "${choices[@]}"; do
    echo "  ${idx}) ${name}"
    idx=$((idx + 1))
  done

  local selection
  while :; do
    selection=$(prompt "输入要切换的配置编号（输入0返回）：")
    if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo "请输入有效编号。"
      continue
    fi
    if (( selection == 0 )); then
      return
    fi
    if (( selection < 1 || selection > ${#choices[@]} )); then
      echo "编号超出范围，请重试。"
      continue
    fi
    break
  done

  local chosen="${choices[$((selection - 1))]}"

  local found_any=false
  mkdir -p "$GEMINI_DIR"
  for f in "${GEMINI_FILES[@]}"; do
    if [ -f "${GEMINI_AIM_DIR}/${chosen}/${f}" ]; then
      cp "${GEMINI_AIM_DIR}/${chosen}/${f}" "${GEMINI_DIR}/${f}"
      found_any=true
    fi
  done

  if [ "$found_any" = false ]; then
    echo "所选配置缺少必要文件，无法切换。"
    pause
    return
  fi

  echo "已切换到 Gemini 配置：$chosen"
  pause
}

delete_gemini_profile() {
  ensure_gemini_dirs

  local choices=()
  for dir in "$GEMINI_AIM_DIR"/*; do
    [ -d "$dir" ] || continue
    choices+=("$(basename "$dir")")
  done

  if [ ${#choices[@]} -eq 0 ]; then
    echo "暂无可删除的配置。"
    pause
    return
  fi

  echo "可删除的配置："
  local idx=1
  for name in "${choices[@]}"; do
    echo "  ${idx}) ${name}"
    idx=$((idx + 1))
  done

  local selection
  while :; do
    selection=$(prompt "输入要删除的配置编号（输入0返回）：")
    if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo "请输入有效编号。"
      continue
    fi
    if (( selection == 0 )); then
      return
    fi
    if (( selection < 1 || selection > ${#choices[@]} )); then
      echo "编号超出范围，请重试。"
      continue
    fi
    break
  done

  local chosen="${choices[$((selection - 1))]}"
  local target_dir="${GEMINI_AIM_DIR}/${chosen}"
  local confirm
  confirm=$(prompt "确认删除配置「${chosen}」？此操作不可恢复。(y/N)：")
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消删除。"
    pause
    return
  fi

  rm -rf -- "$target_dir"
  echo "已删除配置：$chosen"
  pause
}

gemini_menu() {
  ensure_gemini_dirs
  while true; do
    clear
    echo "== Gemini CLI 配置管理 =="
    echo "1) 保存当前配置为新配置"
    echo "2) 切换到已保存的配置"
    echo "3) 删除已保存的配置"
    echo "0) 返回主菜单"
    choice=$(prompt "请选择：")
    case "$choice" in
      1) save_gemini_profile ;;
      2) switch_gemini_profile ;;
      3) delete_gemini_profile ;;
      0) return ;;
      *) echo "无效选项。" ; pause ;;
    esac
  done
}

claude_menu() {
  ensure_claude_dirs
  while true; do
    clear
    echo "== Claude Code 配置管理 =="
    echo "1) 保存当前配置为新配置"
    echo "2) 切换到已保存的配置"
    echo "3) 删除已保存的配置"
    echo "0) 返回主菜单"
    choice=$(prompt "请选择：")
    case "$choice" in
      1) save_claude_profile ;;
      2) switch_claude_profile ;;
      3) delete_claude_profile ;;
      0) return ;;
      *) echo "无效选项。" ; pause ;;
    esac
  done
}

codex_menu() {
  ensure_codex_dirs
  while true; do
    clear
    echo "== Codex 配置管理 =="
    echo "1) 切换供应商/MCP配置"
    echo "2) 删除供应商"
    echo "3) 批量更新模型/思考强度"
    echo "4) 保存 MCP/信任配置"
    echo "5) 添加自定义API供应源"
    echo "0) 返回主菜单"
    choice=$(prompt "请选择：")
    case "$choice" in
      1) switch_codex_profile ;;
      2) delete_codex_profile ;;
      3) update_codex_model ;;
      4) save_codex_mcp_set ;;
      5) create_custom_provider ;;
      0) return ;;
      *) echo "无效选项。" ; pause ;;
    esac
  done
}

main_menu() {
  while true; do
    clear
    echo "== aiM 配置管理器 =="
    echo "1) Codex"
    echo "2) Claude Code"
    echo "3) Gemini CLI"
    echo "0) 退出"
    choice=$(prompt "请选择：")
    case "$choice" in
      1) codex_menu ;;
      2) claude_menu ;;
      3) gemini_menu ;;
      0) echo "已退出。" ; exit 0 ;;
      *) echo "无效选项。" ; pause ;;
    esac
  done
}

main_menu
