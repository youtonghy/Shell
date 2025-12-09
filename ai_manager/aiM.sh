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
  while :; do
    name=$(prompt "为当前配置输入一个名称（仅字母数字、下划线、短横线）：")
    name=${name// /}
    if [[ -z "$name" ]]; then
      echo "名称不能为空。"
      continue
    fi
    if [[ "$name" =~ [^a-zA-Z0-9_-] ]]; then
      echo "名称只能包含字母、数字、下划线或短横线。"
      continue
    fi
    break
  done

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
    selection=$(prompt "输入要切换的配置编号：")
    if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo "请输入有效编号。"
      continue
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

save_claude_profile() {
  ensure_claude_dirs

  if [ ! -f "$CLAUDE_CONFIG" ] || [ ! -f "$CLAUDE_SETTINGS" ]; then
    echo "未找到 ${CLAUDE_CONFIG} 或 ${CLAUDE_SETTINGS}，无法保存。"
    pause
    return
  fi

  local name
  while :; do
    name=$(prompt "为当前Claude配置输入一个名称（仅字母数字、下划线、短横线）：")
    name=${name// /}
    if [[ -z "$name" ]]; then
      echo "名称不能为空。"
      continue
    fi
    if [[ "$name" =~ [^a-zA-Z0-9_-] ]]; then
      echo "名称只能包含字母、数字、下划线或短横线。"
      continue
    fi
    break
  done

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
    selection=$(prompt "输入要切换的配置编号：")
    if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo "请输入有效编号。"
      continue
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
  while :; do
    name=$(prompt "为当前Gemini配置输入一个名称（仅字母数字、下划线、短横线）：")
    name=${name// /}
    if [[ -z "$name" ]]; then
      echo "名称不能为空。"
      continue
    fi
    if [[ "$name" =~ [^a-zA-Z0-9_-] ]]; then
      echo "名称只能包含字母、数字、下划线或短横线。"
      continue
    fi
    break
  done

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
    selection=$(prompt "输入要切换的配置编号：")
    if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo "请输入有效编号。"
      continue
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

gemini_menu() {
  ensure_gemini_dirs
  while true; do
    clear
    echo "== Gemini CLI 配置管理 =="
    echo "1) 保存当前配置为新配置"
    echo "2) 切换到已保存的配置"
    echo "3) 返回主菜单"
    choice=$(prompt "请选择：")
    case "$choice" in
      1) save_gemini_profile ;;
      2) switch_gemini_profile ;;
      3) return ;;
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
    echo "3) 返回主菜单"
    choice=$(prompt "请选择：")
    case "$choice" in
      1) save_claude_profile ;;
      2) switch_claude_profile ;;
      3) return ;;
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
    echo "3) 返回主菜单"
    choice=$(prompt "请选择：")
    case "$choice" in
      1) save_codex_profile ;;
      2) switch_codex_profile ;;
      3) return ;;
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
    echo "4) 退出"
    choice=$(prompt "请选择：")
    case "$choice" in
      1) codex_menu ;;
      2) claude_menu ;;
      3) gemini_menu ;;
      4) echo "已退出。" ; exit 0 ;;
      *) echo "无效选项。" ; pause ;;
    esac
  done
}

main_menu
