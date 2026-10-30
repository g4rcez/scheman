class Scheman < Formula
  desc "List and set default apps for URL schemes and file types on macOS"
  homepage "https://github.com/g4rcez/scheman"
  url "https://github.com/g4rcez/scheman/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "5e3c45f46f859e7fbbd3a11b76ca6d63992a7d39103f09e3b5e2c190929beb28"
  license "MIT"
  head "https://github.com/g4rcez/scheman.git", branch: "main"

  depends_on :macos
  depends_on xcode: ["16.0", :build]

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/scheman"
    generate_completions_from_executable(bin/"scheman", "completion", shells: [:zsh, :bash, :fish])
  end

  test do
    assert_match "scheman #{version}", shell_output("#{bin}/scheman --version")
    assert_match "mailto://", shell_output("#{bin}/scheman get mailto")
  end
end
