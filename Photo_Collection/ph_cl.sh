#!/bin/bash
set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 <link_file> <directory>"
  exit 1
fi

link_file="$1"
output_dir="$2"

echo "Link file: $link_file"
echo "Output directory: $output_dir"

if [ ! -f "$link_file" ]; then
  echo "Link file not found: $link_file" >&2
  exit 1
fi

echo "Creating directory $output_dir"
mkdir -p "$output_dir"

download_file() {
  local url="$1"
  local dir="$2"
  local file="$(basename "$url")"
  wget -q --progress=dot "$url" -O "$dir/$file" 2>&1 \
    | grep --line-buffered "%" \
    | sed -u "s/.* \([0-9]\+%\).*/$file: \1/"
  echo "$file: 100%"
}

echo "Starting downloads (up to 4 in parallel)"
max_jobs=4
jobs=0
while IFS= read -r url; do
  [ -z "$url" ] && continue
  download_file "$url" "$output_dir" &
  ((jobs++))
  if (( jobs >= max_jobs )); then
    wait -n
    ((jobs--))
  fi
done < "$link_file"
wait
echo "Download step complete"

echo "Checking archive tools"
packages=()
command -v unzip >/dev/null 2>&1 || packages+=(unzip)
command -v unrar >/dev/null 2>&1 || packages+=(unrar)
if [ ${#packages[@]} -gt 0 ]; then
  echo "Installing missing packages: ${packages[*]}"
  apt-get update
  apt-get install -y "${packages[@]}"
else
  echo "All archive tools already installed"
fi

echo "Beginning extraction"
shopt -s nullglob
for file in "$output_dir"/*; do
  base="$(basename "$file")"
  if [[ "$base" == *zip* ]]; then
    name="${base%.*}"
    echo "Extracting $base with unzip"
    tmp_dir="$(mktemp -d)"
    unzip -q "$file" -d "$tmp_dir"
  elif [[ "$base" == *rar* ]]; then
    name="${base%.*}"
    echo "Extracting $base with unrar"
    tmp_dir="$(mktemp -d)"
    unrar x -y "$file" "$tmp_dir/"
  else
    echo "Skipping $base (no zip or rar in name)"
    continue
  fi

  shopt -s dotglob
  contents=("$tmp_dir"/*)
  if [ ${#contents[@]} -eq 1 ] && [ -d "${contents[0]}" ]; then
    echo "Moving extracted folder for $base"
    mv "${contents[0]}" "$output_dir/"
  else
    echo "Creating directory $output_dir/$name"
    mkdir -p "$output_dir/$name"
    mv "$tmp_dir"/* "$output_dir/$name/"
  fi
  rm -r "$tmp_dir"
  echo "Finished extracting $base"
done
echo "Extraction step complete"
