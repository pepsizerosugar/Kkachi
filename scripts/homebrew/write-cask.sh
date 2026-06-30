#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <version> <sha256> <output-path>" >&2
  exit 64
fi

version="$1"
sha256="$2"
output_path="$3"

if [[ -z "$version" || -z "$sha256" || -z "$output_path" ]]; then
  echo "version, sha256, and output path are required" >&2
  exit 64
fi

mkdir -p "$(dirname "$output_path")"

cat > "$output_path" <<CASK
cask "kkachi" do
  version "$version"
  sha256 "$sha256"

  url "https://github.com/pepsizerosugar/Kkachi/releases/download/v#{version}/Kkachi-#{version}.dmg"
  name "Kkachi"
  desc "Tucks away idle browser tabs you keep meaning to close"
  homepage "https://github.com/pepsizerosugar/Kkachi"

  livecheck do
    url "https://github.com/pepsizerosugar/Kkachi"
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "Kkachi.app"

  zap trash: [
    "~/Library/Application Support/Kkachi",
    "~/Library/Preferences/io.github.pepsizerosugar.Kkachi.plist",
  ]
end
CASK
