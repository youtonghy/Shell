#!/bin/bash
set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 <link_file> <directory>"
  exit 1
fi

link_file="$1"
output_dir="$2"

if [ ! -f "$link_file" ]; then
  echo "Link file not found: $link_file" >&2
  exit 1
fi

mkdir -p "$output_dir"

# download each link
while IFS= read -r url; do
  [ -z "$url" ] && continue
  wget -P "$output_dir" "$url"
done < "$link_file"

# ensure unzip/unrar installed
packages=()
command -v unzip >/dev/null 2>&1 || packages+=(unzip)
command -v unrar >/dev/null 2>&1 || packages+=(unrar)
if [ ${#packages[@]} -gt 0 ]; then
  apt-get update
  apt-get install -y "${packages[@]}"
fi

shopt -s nullglob
for file in "$output_dir"/*; do
  case "$file" in
    *.zip|*.rar)
      base="$(basename "$file")"
      name="${base%.*}"
      tmp_dir="$(mktemp -d)"
      if [[ "$file" == *.zip ]]; then
        unzip -q "$file" -d "$tmp_dir"
      else
        unrar x -y "$file" "$tmp_dir/"
      fi
      shopt -s dotglob
      contents=("$tmp_dir"/*)
      if [ ${#contents[@]} -eq 1 ] && [ -d "${contents[0]}" ]; then
        mv "${contents[0]}" "$output_dir/"
      else
        mkdir -p "$output_dir/$name"
        mv "$tmp_dir"/* "$output_dir/$name/"
      fi
      rm -r "$tmp_dir"
      ;;
  esac
done

