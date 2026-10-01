cask "icop" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.7"
  sha256 arm:   "d42ecc12612cc538af467e8d990b45696f7f747b1a4fa4efdcf8b39222b5c274",
         intel: "02a2a00c2a05871af76fbe222bb43e84aa3153e91fd4e47a5ae45c8f246e3808"

  url "https://github.com/asayed18/icop/releases/download/v#{version}/icop-v#{version}-mac-#{arch}.tar.gz"
  name "icop"
  desc "Local AI content filter plugin for VLC"
  homepage "https://github.com/asayed18/icop"

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
