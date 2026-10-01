#!/bin/sh
# Writes Casks/icop.rb for an icop release.
#
# Usage: render_cask.sh [VERSION]
#   VERSION  release version without the leading "v" (e.g. 0.1.7). When
#            omitted, the newest published (non-draft, non-prerelease)
#            release that ships both macOS archives is used.
#
# Needs: gh (authenticated, or GH_TOKEN), curl.
# Env:   ICOP_REPO (default asayed18/icop), CASK_PATH (default Casks/icop.rb),
#        ICOP_DOWNLOAD_BASE to read archives from another base URL (tests).

set -eu

repo=${ICOP_REPO:-asayed18/icop}
cask_path=${CASK_PATH:-Casks/icop.rb}
download_base=${ICOP_DOWNLOAD_BASE:-https://github.com/$repo/releases/download}

die() {
    printf 'render_cask: %s\n' "$*" >&2
    exit 1
}

has_mac_assets() {
    assets=$(gh release view "v$1" --repo "$repo" --json assets \
        --jq '.assets[].name' 2>/dev/null) || return 1
    for arch in arm64 x86_64; do
        for suffix in tar.gz tar.gz.sha256; do
            printf '%s\n' "$assets" |
                grep -qx "icop-v$1-mac-$arch.$suffix" || return 1
        done
    done
}

version=${1:-}
version=${version#v}
if [ -z "$version" ]; then
    for tag in $(gh release list --repo "$repo" --exclude-drafts \
        --exclude-pre-releases --limit 30 --json tagName --jq '.[].tagName'); do
        case $tag in v[0-9]*) ;; *) continue ;; esac
        if has_mac_assets "${tag#v}"; then
            version=${tag#v}
            break
        fi
    done
    [ -n "$version" ] ||
        die "no published $repo release ships both macOS archives yet"
elif [ -z "${ICOP_DOWNLOAD_BASE:-}" ]; then
    has_mac_assets "$version" ||
        die "v$version is not published with both macOS archives"
fi

sha_for() {
    url="$download_base/v$version/icop-v$version-mac-$1.tar.gz.sha256"
    sum=$(curl -fsSL "$url" | awk 'NR == 1 { print $1 }') ||
        die "could not download $url"
    printf '%s\n' "$sum" | grep -Eq '^[0-9a-f]{64}$' ||
        die "bad checksum in $url"
    printf '%s\n' "$sum"
}

sha_arm=$(sha_for arm64)
sha_intel=$(sha_for x86_64)

mkdir -p "$(dirname "$cask_path")"
cat > "$cask_path" <<EOF
cask "icop" do
  arch arm: "arm64", intel: "x86_64"

  version "$version"
  sha256 arm:   "$sha_arm",
         intel: "$sha_intel"

  url "$download_base/v#{version}/icop-v#{version}-mac-#{arch}.tar.gz"
  name "icop"
  desc "Local AI content filter plugin for VLC"
  homepage "https://github.com/$repo"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  installer script: {
    executable: "mac/install_icop_plugin.sh",
    args:       ["--release-dir", "#{staged_path}/mac"],
  }

  uninstall script: {
    executable: "#{staged_path}/mac/install_icop_plugin.sh",
    args:       ["--uninstall", "--release-dir", "#{staged_path}/mac"],
  }

  caveats <<~EOS
    icop is installed into VLC.app, which needs VLC 3.x and VLC closed.

    If installation fails with "Operation not permitted", allow your
    terminal under System Settings > Privacy & Security > App Management
    and run:
      brew reinstall --cask icop

    VLC updates replace VLC.app and remove the plugin; run the same
    command after each VLC update.
  EOS
end
EOF
printf 'Rendered %s for icop %s\n' "$cask_path" "$version"
