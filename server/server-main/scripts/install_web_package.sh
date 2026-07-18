#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/dlr-web.tar.gz" >&2
  exit 1
fi

archive="$1"
if [ ! -f "$archive" ]; then
  echo "Web package not found: $archive" >&2
  exit 1
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
server_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
web_dist="$server_dir/web_dist"

case "$web_dist" in
  "$server_dir"/*) ;;
  *)
    echo "Refusing to replace files outside $server_dir" >&2
    exit 1
    ;;
esac

mkdir -p "$web_dist"
find "$web_dist" -mindepth 1 -maxdepth 1 ! -name .gitignore -exec rm -rf -- {} +
tar -xzf "$archive" -C "$web_dist"

if [ ! -f "$web_dist/index.html" ]; then
  echo "Package does not contain index.html" >&2
  exit 1
fi

echo "Installed Flutter web files into $web_dist"
