#!/usr/bin/env bash

# Simple profile manager for Codex/Claude Code/Gemini CLI.
# Currently implements Codex, Claude Code, and Gemini CLI profile save/switch.

set -euo pipefail

CODEX_DIR="${HOME}/.codex"
CODEX_CONFIG="${CODEX_DIR}/config.toml"
CODEX_AUTH="${CODEX_DIR}/auth.json"
AIM_DIR="${CODEX_DIR}/aiM"
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
      echo "名称不能为空。"
      continue
    fi
    if [[ "$name" =~ [^a-zA-Z0-9_-] ]]; then
      echo "名称只能包含字母、数字、下划线或短横线。"
      continue
    fi
    printf '%s\n' "$name"
    return 0
  done
}

ensure_codex_dirs() {
  mkdir -p "$AIM_DIR"
}

ensure_claude_dirs() {
  mkdir -p "$CLAUDE_AIM_DIR"
}

ensure_gemini_dirs() {
  mkdir -p "$GEMINI_AIM_DIR"
}

save_codex_profile() {
  ensure_codex_dirs

  if [ ! -f "$CODEX_CONFIG" ] || [ ! -f "$CODEX_AUTH" ]; then
    echo "未找到 ${CODEX_CONFIG} 或 ${CODEX_AUTH}，无法保存。"
    pause
    return
  fi

  local name
  if ! name=$(prompt_profile_name "Codex"); then
    echo "已取消保存。"
    pause
    return
  fi

  local target_dir="${AIM_DIR}/${name}"
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
  cp "$CODEX_CONFIG" "${target_dir}/config.toml"
  cp "$CODEX_AUTH" "${target_dir}/auth.json"
  echo "已保存当前配置为：$name"
  pause
}

switch_codex_profile() {
  ensure_codex_dirs

  local choices=()
  for dir in "$AIM_DIR"/*; do
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

  if [ ! -f "${AIM_DIR}/${chosen}/config.toml" ] || [ ! -f "${AIM_DIR}/${chosen}/auth.json" ]; then
    echo "所选配置缺少必要文件，无法切换。"
    pause
    return
  fi

  cp "${AIM_DIR}/${chosen}/config.toml" "$CODEX_CONFIG"
  cp "${AIM_DIR}/${chosen}/auth.json" "$CODEX_AUTH"
  echo "已切换到配置：$chosen"
  pause
}

update_codex_model() {
  ensure_codex_dirs

  local choices=()
  for dir in "$AIM_DIR"/*; do
    [ -d "$dir" ] || continue
    choices+=("$(basename "$dir")")
  done

  if [ ${#choices[@]} -eq 0 ]; then
    echo "暂无已保存的配置。"
    pause
    return
  fi

  local new_model
  new_model=$(prompt "请输入新的模型名称（如 gpt-5.2-codex，输入0取消）：")
  new_model=${new_model// /}
  if [[ "$new_model" == "0" || -z "$new_model" ]]; then
    echo "已取消更新。"
    pause
    return
  fi

  echo "将更新以下配置中的模型为：$new_model"
  for name in "${choices[@]}"; do
    echo "  - $name"
  done

  local confirm
  confirm=$(prompt "确认更新所有配置？(y/N)：")
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消更新。"
    pause
    return
  fi

  local updated=0
  for name in "${choices[@]}"; do
    local config_file="${AIM_DIR}/${name}/config.toml"
    if [ -f "$config_file" ]; then
      if sed -i "s/^model = \".*\"/model = \"${new_model}\"/" "$config_file"; then
        echo "已更新：$name"
        updated=$((updated + 1))
      else
        echo "更新失败：$name"
      fi
    fi
  done

  echo "共更新 ${updated} 个配置。"
  pause
}

delete_codex_profile() {
  ensure_codex_dirs

  local choices=()
  for dir in "$AIM_DIR"/*; do
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
  local target_dir="${AIM_DIR}/${chosen}"
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

create_custom_provider() {
  ensure_codex_dirs

  # 检查前置条件
  if [ ! -f "$CODEX_CONFIG" ] || [ ! -f "$CODEX_AUTH" ]; then
    echo "未找到 ${CODEX_CONFIG} 或 ${CODEX_AUTH}，无法创建自定义供应源。"
    pause
    return
  fi

  # 获取供应源名称（仅英文）
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

    # 检查是否已存在
    if grep -q "^\[model_providers\.${provider_name}\]" "$CODEX_CONFIG"; then
      local overwrite
      overwrite=$(prompt "供应源 ${provider_name} 已存在于当前配置，是否覆盖？(y/N)：")
      if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "请使用其他名称。"
        continue
      fi
    fi

    break
  done

  # 获取 Base URL
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

    # HTTP 安全警告
    if [[ "$base_url" =~ ^http:// ]]; then
      local confirm_http
      confirm_http=$(prompt "警告：使用 HTTP 连接不安全。确认继续？(y/N)：")
      if [[ ! "$confirm_http" =~ ^[Yy]$ ]]; then
        continue
      fi
    fi

    break
  done

  # 获取 API Key
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

  # 读取当前配置参数
  local current_provider
  current_provider=$(grep '^model_provider = ' "$CODEX_CONFIG" | sed 's/model_provider = "\(.*\)"/\1/')

  if [[ -z "$current_provider" ]]; then
    echo "错误：无法读取当前 model_provider。"
    pause
    return
  fi

  # 读取 wire_api（默认 "responses"）
  local wire_api
  wire_api=$(grep -A 3 "^\[model_providers\.${current_provider}\]" "$CODEX_CONFIG" | grep '^wire_api = ' | sed 's/wire_api = "\(.*\)"/\1/')
  if [[ -z "$wire_api" ]]; then
    wire_api="responses"
  fi

  # 读取 requires_openai_auth（默认 true）
  local requires_auth
  requires_auth=$(grep -A 3 "^\[model_providers\.${current_provider}\]" "$CODEX_CONFIG" | grep '^requires_openai_auth = ' | sed 's/requires_openai_auth = \(.*\)/\1/')
  if [[ -z "$requires_auth" ]]; then
    requires_auth="true"
  fi

  # 创建临时配置文件
  local temp_config="${CODEX_DIR}/config.toml.tmp"
  local temp_auth="${CODEX_DIR}/auth.json.tmp"
  trap 'rm -f "$temp_config" "$temp_auth"' EXIT

  # 复制并修改 config.toml
  cp "$CODEX_CONFIG" "$temp_config"
  sed -i "s/^model_provider = \".*\"/model_provider = \"${provider_name}\"/" "$temp_config"

  # 删除旧的同名 provider 段（如果存在）
  sed -i "/^\[model_providers\.${provider_name}\]/,/^$/d" "$temp_config"

  # 找到最后一个 [model_providers.X] 段的位置
  local last_provider_line
  last_provider_line=$(grep -n '^\[model_providers\.' "$temp_config" | tail -1 | cut -d: -f1)

  if [[ -n "$last_provider_line" ]]; then
    # 找到该段的结束位置（空行或下一个段）
    local insert_line
    insert_line=$(tail -n +$((last_provider_line + 1)) "$temp_config" | grep -n '^$\|^\[' | head -1 | cut -d: -f1)
    if [[ -n "$insert_line" ]]; then
      insert_line=$((last_provider_line + insert_line))
    else
      insert_line=$(($(wc -l < "$temp_config") + 1))
    fi
  else
    # 没有现有 provider，插入到 model_provider 行之后
    insert_line=$(grep -n '^model_provider = ' "$temp_config" | cut -d: -f1)
    insert_line=$((insert_line + 1))
  fi

  # 插入新 provider 段
  sed -i "${insert_line}i\\
\\
[model_providers.${provider_name}]\\
name = \"${provider_name}\"\\
base_url = \"${base_url}\"\\
wire_api = \"${wire_api}\"\\
requires_openai_auth = ${requires_auth}" "$temp_config"

  # 更新 auth.json
  if command -v jq >/dev/null 2>&1; then
    jq --arg key "$api_key" '.OPENAI_API_KEY = $key' "$CODEX_AUTH" > "$temp_auth"
  else
    # 备用方案：手动构建 JSON
    echo "{" > "$temp_auth"
    echo "  \"OPENAI_API_KEY\": \"${api_key}\"" >> "$temp_auth"
    echo "}" >> "$temp_auth"
  fi

  # 保存为新配置文件
  local profile_name
  if ! profile_name=$(prompt_profile_name "自定义供应源"); then
    echo "已取消保存。"
    pause
    return
  fi

  local target_dir="${AIM_DIR}/${profile_name}"
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
  mv "$temp_config" "${target_dir}/config.toml"
  mv "$temp_auth" "${target_dir}/auth.json"

  echo "已成功创建自定义供应源配置：$profile_name"
  echo "  供应源名称：$provider_name"
  echo "  Base URL：$base_url"
  echo "配置已保存，可通过「切换到已保存的配置」选项切换使用。"
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
    echo "1) 保存当前配置为新配置"
    echo "2) 切换到已保存的配置"
    echo "3) 删除已保存的配置"
    echo "4) 批量更新模型名称"
    echo "5) 添加自定义API供应源"
    echo "0) 返回主菜单"
    choice=$(prompt "请选择：")
    case "$choice" in
      1) save_codex_profile ;;
      2) switch_codex_profile ;;
      3) delete_codex_profile ;;
      4) update_codex_model ;;
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
