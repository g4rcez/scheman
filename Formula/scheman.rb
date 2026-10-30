class Scheman < Formula
  desc "List and set default apps for URL schemes and file types on macOS"
  homepage "https://github.com/g4rcez/scheman"
  url "https://github.com/g4rcez/scheman/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
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
