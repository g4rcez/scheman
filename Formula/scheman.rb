class Scheman < Formula
  desc "List and set default apps for URL schemes and file types on macOS"
  homepage "https://github.com/g4rcez/scheman"
  # url and sha256 are updated by .github/workflows/release.yml
  url "https://github.com/g4rcez/scheman/releases/download/v0.1.0/scheman-0.1.0-macos-universal.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  depends_on :macos

  def install
    bin.install "scheman"
    generate_completions_from_executable(bin/"scheman", "completion", shells: [:zsh, :bash, :fish])
  end

  test do
    assert_match "scheman #{version}", shell_output("#{bin}/scheman --version")
    assert_match "mailto://", shell_output("#{bin}/scheman get mailto")
  end
end
