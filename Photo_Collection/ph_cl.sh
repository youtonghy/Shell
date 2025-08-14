#!/usr/bin/env bash
set -euo pipefail

# 用法: ph_cl.sh <链接列表文件> <目标文件夹名>

usage() {
  echo "用法: $(basename "$0") <链接列表文件> <目标文件夹名>" >&2
  echo "说明: 从文件读取每行链接, 使用 wget 下载到当前目录下指定文件夹, 然后用 unzip/unrar 解压." >&2
}

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 2 ]]; then
  usage
  exit 1
fi

LINK_FILE=$1
TARGET_DIR=$2

if [[ ! -f "$LINK_FILE" ]]; then
  echo "错误: 链接列表文件不存在: $LINK_FILE" >&2
  exit 1
fi

log "创建/确认目标目录: $TARGET_DIR"
mkdir -p -- "$TARGET_DIR"

# 检查/安装依赖
SUDO_CMD=""
if [[ $(id -u) -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO_CMD="sudo"
fi

APT_UPDATED=0
pm_install() {
  # 按常见包管理器尝试安装
  local pkgs=("$@")
  if command -v apt-get >/dev/null 2>&1; then
    if [[ $APT_UPDATED -eq 0 ]]; then
      log "检测到 apt-get, 正在更新软件包索引..."
      $SUDO_CMD apt-get update -y || true
      APT_UPDATED=1
    fi
    $SUDO_CMD apt-get install -y "${pkgs[@]}"
    return $?
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO_CMD dnf install -y "${pkgs[@]}"
    return $?
  elif command -v yum >/dev/null 2>&1; then
    $SUDO_CMD yum install -y "${pkgs[@]}"
    return $?
  elif command -v pacman >/dev/null 2>&1; then
    $SUDO_CMD pacman -Sy --noconfirm "${pkgs[@]}"
    return $?
  elif command -v zypper >/dev/null 2>&1; then
    $SUDO_CMD zypper --non-interactive install "${pkgs[@]}"
    return $?
  elif command -v brew >/dev/null 2>&1; then
    brew install "${pkgs[@]}"
    return $?
  fi
  return 127
}

ensure_cmd() {
  # ensure_cmd <cmd> <pkg-name...>
  local cmd=$1; shift
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  if [[ $# -gt 0 ]]; then
    log "未检测到 $cmd, 正在尝试安装: $*"
    if ! pm_install "$@"; then
      echo "警告: 自动安装 $cmd 失败, 请手动安装后重试." >&2
      return 1
    fi
  else
    echo "警告: 未检测到 $cmd, 且未提供安装包名." >&2
    return 1
  fi
}

# 需要 wget 下载
ensure_cmd wget wget || { echo "错误: 需要 wget 来下载文件." >&2; exit 1; }

# =============== 下载（并发 4 + 自定义进度） ===============

# 解压命令的安全封装：
# - 静默标准输出与警告（stderr）
# - 将退出码 0/1（成功/警告）都视作成功，仅 >1 视作失败
unzip_safely() {
  unzip -o -- "$1" -d "$2" >/dev/null 2>&1
  local rc=$?
  if (( rc == 0 || rc == 1 )); then return 0; fi
  return $rc
}

unrar_safely() {
  unrar x -o+ -- "$1" "$2/" >/dev/null 2>&1
  local rc=$?
  if (( rc == 0 || rc == 1 )); then return 0; fi
  return $rc
}

# 尝试从响应头解析文件名
guess_name_from_headers() {
  local url="$1"
  local hdr
  if hdr=$(wget --spider --server-response --content-disposition -q "$url" 2>&1); then
    local cd_line fname
    cd_line=$(printf '%s\n' "$hdr" | awk -F': ' 'BEGIN{IGNORECASE=1}/^  Content-Disposition:/{print $0; exit}')
    if [[ -n "$cd_line" ]]; then
      fname=$(printf '%s' "$cd_line" | sed -nE "s/.*filename\*=[^']+'([^']+)'.*/\1/p")
      if [[ -z "$fname" ]]; then
        fname=$(printf '%s' "$cd_line" | sed -nE 's/.*filename="?([^";]+)"?.*/\1/p')
      fi
      if [[ -n "$fname" ]]; then
        basename -- "$fname"
        return 0
      fi
    fi
  fi
  return 1
}

head_content_length() {
  local url="$1"
  local len
  if len=$(wget --spider --server-response -q "$url" 2>&1 | awk 'BEGIN{IGNORECASE=1}/^  Content-Length:/{print $2; exit}'); then
    [[ -n "$len" ]] && printf '%s' "$len" && return 0
  fi
  return 1
}

sanitize_name() {
  local name="$1"
  name=${name//\//_}
  name=${name//\`/_}
  name=${name//\$/_}
  name=${name//\*/_}
  name=${name//\?/}
  printf '%s' "$name"
}

determine_filename() {
  local url="$1"
  local name
  if name=$(guess_name_from_headers "$url" 2>/dev/null); then
    printf '%s' "$(sanitize_name "$name")"
    return 0
  fi
  name=$(basename -- "${url%%\?*}")
  if [[ -z "$name" || "$name" == "/" || "$name" == "." ]]; then
    name="download_$(date +%s%N)"
  fi
  printf '%s' "$(sanitize_name "$name")"
}

download_one() {
  local url="$1"
  local outdir="$2"
  local name size dest tmp
  name=$(determine_filename "$url")
  dest="$outdir/$name"
  tmp="$dest.part"
  local pdir="$outdir/.progress"
  local pfile="$pdir/${name}.status"
  mkdir -p -- "$pdir"
  if [[ -e "$dest" ]]; then
    log "已存在, 跳过下载: $name"
    return 0
  fi
  size=""
  if size=$(head_content_length "$url" 2>/dev/null); then :; fi

  : > "$tmp" || true
  ( wget -q -O "$tmp" "$url" && mv -f -- "$tmp" "$dest" ) &
  local wpid=$!
  printf '%s: 0%%' "$name" >"$pfile" 2>/dev/null || true
  while kill -0 "$wpid" >/dev/null 2>&1; do
    if [[ -f "$tmp" ]]; then
      local cur=0
      cur=$(stat -c '%s' -- "$tmp" 2>/dev/null || echo 0)
      if [[ -n "${size:-}" && "$size" =~ ^[0-9]+$ && "$size" -gt 0 ]]; then
        local pct=$(( cur * 100 / size ))
        printf '%s: %d%%' "$name" "$pct" >"$pfile" 2>/dev/null || true
      else
        printf '%s: ?%%' "$name" >"$pfile" 2>/dev/null || true
      fi
    else
      printf '%s: 0%%' "$name" >"$pfile" 2>/dev/null || true
    fi
    sleep 1
  done
  wait "$wpid" || { echo "${name}: 下载失败" >&2; rm -f -- "$tmp" 2>/dev/null || true; return 1; }
  printf '%s: 100%%' "$name" >"$pfile" 2>/dev/null || true
}

# 在终端中原位刷新输出各文件下载进度（每文件一行）
progress_monitor() {
  local pdir="$1" total="$2"
  local prev_lines=0
  # 仅在交互终端时显示动态进度
  if [[ ! -t 1 ]]; then
    return 0
  fi
  while :; do
    local files=()
    IFS=$'\n' read -r -d '' -a files < <(ls -1 "$pdir"/*.status 2>/dev/null | sort && printf '\0') || true
    local lines=()
    local done_cnt=0
    local f
    for f in "${files[@]}"; do
      if [[ -f "$f" ]]; then
        local line
        line=$(cat -- "$f" 2>/dev/null || true)
        lines+=("$line")
        [[ "$line" =~ 100%$ ]] && ((done_cnt++)) || true
      fi
    done

    local cur_lines=${#lines[@]}
    if (( prev_lines > 0 )); then
      printf '\033[%dA' "$prev_lines"
    fi
    local i
    for (( i=0; i<cur_lines; i++ )); do
      printf '\033[K%s\n' "${lines[$i]}"
    done
    if (( cur_lines < prev_lines )); then
      local diff=$(( prev_lines - cur_lines ))
      for (( i=0; i<diff; i++ )); do
        printf '\033[K\n'
      done
    fi
    prev_lines=$cur_lines

    if (( cur_lines >= total && done_cnt == cur_lines && cur_lines > 0 )); then
      break
    fi
    sleep 0.5
  done
}

# =============== 解压函数（提前定义以便复用） ===============

zip_has_root_files() {
  local f=$1
  local list
  if ! list=$(unzip -Z1 -- "$f" 2>/dev/null); then
    return 1
  fi
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" == __MACOSX/* ]] && continue
    [[ "$line" == */ ]] && continue
    if [[ "$line" != */* ]]; then
      return 0
    fi
  done <<< "$list"
  return 1
}

rar_has_root_files() {
  local f=$1
  local list
  if ! list=$(unrar lb -- "$f" 2>/dev/null); then
    return 1
  fi
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" == __MACOSX/* ]] && continue
    if [[ "$line" != */* ]]; then
      return 0
    fi
  done <<< "$list"
  return 1
}

# 将解压流程封装为函数，便于多次调用
extract_archives() {
  local dir="$1"
  log "开始解压下载的压缩包..."
  shopt -s nullglob
  local archives=("$dir"/*)
  shopt -u nullglob
  if [[ ${#archives[@]} -eq 0 ]]; then
    log "未在 $dir 中发现可用文件。"
    return 0
  fi
  local arch fname base base_no_ext out_dir
  for arch in "${archives[@]}"; do
    [[ -f "$arch" ]] || continue
    fname=$(basename -- "$arch")
    if [[ "$fname" =~ [Zz][Ii][Pp] ]]; then
        if ! command -v unzip >/dev/null 2>&1; then
          ensure_cmd unzip unzip || { echo "错误: 需要 unzip 以解压 ZIP 文件." >&2; continue; }
        fi
        base=$(basename -- "$arch")
        base_no_ext=${base%.*}
        if zip_has_root_files "$arch"; then
          out_dir="$dir/$base_no_ext"
          mkdir -p -- "$out_dir"
          log "解压 ZIP 到: $out_dir"
          if ! unzip_safely "$arch" "$out_dir"; then
            echo "错误: 解压 ZIP 失败: $arch" >&2; continue
          fi
          log "解压完成, 删除压缩包: $arch"
          rm -f -- "$arch"
        else
          log "解压 ZIP 到: $dir"
          if ! unzip_safely "$arch" "$dir"; then
            echo "错误: 解压 ZIP 失败: $arch" >&2; continue
          fi
          log "解压完成, 删除压缩包: $arch"
          rm -f -- "$arch"
        fi
    elif [[ "$fname" =~ [Rr][Aa][Rr] ]]; then
        if ! command -v unrar >/dev/null 2>&1; then
          if ! ensure_cmd unrar unrar; then
            ensure_cmd unrar unrar-free || { echo "错误: 需要 unrar 以解压 RAR 文件." >&2; continue; }
          fi
        fi
        base=$(basename -- "$arch")
        base_no_ext=${base%.*}
        if rar_has_root_files "$arch"; then
          out_dir="$dir/$base_no_ext"
          mkdir -p -- "$out_dir"
          log "解压 RAR 到: $out_dir"
          if ! unrar_safely "$arch" "$out_dir"; then
            echo "错误: 解压 RAR 失败: $arch" >&2; continue
          fi
          log "解压完成, 删除压缩包: $arch"
          rm -f -- "$arch"
        else
          log "解压 RAR 到: $dir"
          if ! unrar_safely "$arch" "$dir"; then
            echo "错误: 解压 RAR 失败: $arch" >&2; continue
          fi
          log "解压完成, 删除压缩包: $arch"
          rm -f -- "$arch"
        fi
    else
        :
    fi
  done
  log "完成。"
}

log "开始读取链接并并发下载 (最多 4 个) 到: $TARGET_DIR"

# 先解压目标目录中已存在的压缩包，避免重复等待
extract_archives "$TARGET_DIR"

declare -a URLS=()
while IFS= read -r url || [[ -n "${url:-}" ]]; do
  url_trimmed=${url//[$'\t\r\n']}
  url_trimmed=$(printf '%s' "$url_trimmed" | sed 's/^\s\+//;s/\s\+$//')
  [[ -z "$url_trimmed" || "$url_trimmed" =~ ^# ]] && continue
  URLS+=("$url_trimmed")
done < "$LINK_FILE"

if [[ ${#URLS[@]} -eq 0 ]]; then
  log "未发现可下载链接, 结束。"
  exit 0
fi

max_jobs=4
PROG_DIR="$TARGET_DIR/.progress"
mkdir -p -- "$PROG_DIR"
progress_monitor "$PROG_DIR" ${#URLS[@]} &
pm_pid=$!
for u in "${URLS[@]}"; do
  while (( $(jobs -rp | wc -l) >= max_jobs )); do sleep 0.2; done
  (
    download_one "$u" "$TARGET_DIR"
  ) &
done

wait
if kill -0 "$pm_pid" >/dev/null 2>&1; then
  wait "$pm_pid" || true
fi
if [[ -d "$PROG_DIR" ]]; then
  rm -f -- "$PROG_DIR"/*.status 2>/dev/null || true
  rmdir --ignore-fail-on-non-empty "$PROG_DIR" 2>/dev/null || true
fi
log "全部下载完成"

# 再次解压（包括新下载的压缩包）
extract_archives "$TARGET_DIR"
