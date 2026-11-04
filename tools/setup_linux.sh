#!/usr/bin/env bash
#
# Sets up a Linux PC to build and run NplusPrep, without Android Studio.
#
# Installs (only what is missing):
#   - git, curl, unzip, Java 17, zenity          via apt (Debian/Ubuntu) or dnf (Fedora)
#   - Visual Studio Code                         via snap (or the Microsoft .deb / .rpm)
#   - Flutter SDK (stable)                       into ~/development/flutter
#   - Android SDK command-line tools, platform-tools, Android 36,
#     build-tools 36, NDK 27                     into ~/Android/Sdk
#   - the Flutter extension for VS Code
# Then adds ANDROID_HOME / PATH to ~/.bashrc (and ~/.zshrc if present),
# accepts the Android licences, optionally clones the project and runs
# `flutter doctor`. Safe to run again: finished steps are skipped.
#
# Usage:
#   bash tools/setup_linux.sh                        # tools only
#   bash setup_linux.sh --project-dir ~/projects/mental_ability_app
#   bash setup_linux.sh --dry-run                    # show what would happen

set -euo pipefail

FLUTTER_DIR="$HOME/development/flutter"
SDK_DIR="$HOME/Android/Sdk"
REPO_URL="https://github.com/harikn2003/mental-ability-app.git"
# Keep in step with android/app/build.gradle.kts (ndkVersion) and Flutter's compileSdk.
SDK_PACKAGES=("platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;27.0.12077973")
PROJECT_DIR=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
run() {
  # run "description" command...
  local what="$1"; shift
  if $DRY_RUN; then printf '    [dry run] %s\n' "$what"; else printf '    %s\n' "$what"; "$@"; fi
}
has() { command -v "$1" >/dev/null 2>&1; }

if has apt-get; then
  PKG=apt
elif has dnf; then
  PKG=dnf
else
  echo "This script supports Debian/Ubuntu (apt) and Fedora (dnf). Use the manual steps in docs/HANDOVER.md." >&2
  exit 1
fi

step "1/6  System packages: git, curl, unzip, Java 17, zenity"
if [[ $PKG == apt ]]; then
  run "apt install" sudo bash -c 'apt-get update -qq && apt-get install -y -qq git curl unzip xz-utils zip libglu1-mesa openjdk-17-jdk zenity'
else
  run "dnf install" sudo dnf install -y -q git curl unzip xz zip mesa-libGLU java-17-openjdk-devel zenity
fi

step "2/6  Visual Studio Code"
if has code; then
  echo "    VS Code already installed"
elif has snap; then
  run "install VS Code (snap)" sudo snap install code --classic
elif [[ $PKG == apt ]]; then
  run "install VS Code (.deb)" bash -c 'curl -fsSL -o /tmp/code.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" && sudo apt-get install -y -qq /tmp/code.deb && rm /tmp/code.deb'
else
  run "install VS Code (.rpm)" bash -c 'curl -fsSL -o /tmp/code.rpm "https://code.visualstudio.com/sha/download?build=stable&os=linux-rpm-x64" && sudo dnf install -y -q /tmp/code.rpm && rm /tmp/code.rpm'
fi

step "3/6  Flutter SDK"
if has flutter; then
  echo "    Flutter already installed: $(command -v flutter)"
else
  run "clone Flutter stable into $FLUTTER_DIR" bash -c "mkdir -p '$(dirname "$FLUTTER_DIR")' && git clone -q https://github.com/flutter/flutter.git -b stable '$FLUTTER_DIR'"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

step "4/6  Android SDK command-line tools and packages"
SDKMANAGER="$SDK_DIR/cmdline-tools/latest/bin/sdkmanager"
if [[ -x "$SDKMANAGER" ]]; then
  echo "    already in $SDK_DIR"
else
  run "download the latest command-line tools into $SDK_DIR" bash -c '
    set -e
    build=$(curl -fsSL https://dl.google.com/android/repository/repository2-3.xml \
      | grep -o "commandlinetools-linux-[0-9]*_latest.zip" | sed "s/.*linux-//;s/_latest.zip//" | sort -n | tail -1)
    tmp=$(mktemp -d)
    curl -fsSL -o "$tmp/tools.zip" "https://dl.google.com/android/repository/commandlinetools-linux-${build}_latest.zip"
    unzip -q "$tmp/tools.zip" -d "$tmp"
    mkdir -p "'"$SDK_DIR"'/cmdline-tools"
    mv "$tmp/cmdline-tools" "'"$SDK_DIR"'/cmdline-tools/latest"
    rm -rf "$tmp"'
fi
export ANDROID_HOME="$SDK_DIR"
export PATH="$SDK_DIR/platform-tools:$SDK_DIR/cmdline-tools/latest/bin:$PATH"
run "accept licences and install ${SDK_PACKAGES[*]}" bash -c "yes | '$SDKMANAGER' --licenses >/dev/null && '$SDKMANAGER' --install $(printf "'%s' " "${SDK_PACKAGES[@]}")"
run "point Flutter at the SDK and accept its licences" bash -c "flutter config --android-sdk '$SDK_DIR' >/dev/null && (yes | flutter doctor --android-licenses >/dev/null)"

PROFILE_LINES="
# NplusPrep development (added by setup_linux.sh)
export ANDROID_HOME=\"$SDK_DIR\"
export PATH=\"$FLUTTER_DIR/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH\""
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ -f "$rc" || "$rc" == "$HOME/.bashrc" ]] || continue
  if grep -q "added by setup_linux.sh" "$rc" 2>/dev/null; then
    echo "    $rc already set up"
  else
    run "add ANDROID_HOME and PATH to $rc" bash -c "printf '%s\n' '$PROFILE_LINES' >> '$rc'"
  fi
done

step "5/6  Flutter extension for VS Code"
if has code; then
  run "install Dart-Code.flutter (adds Dart too)" code --install-extension Dart-Code.flutter --force
else
  echo "    VS Code not found on PATH yet - open it once, then: code --install-extension Dart-Code.flutter"
fi

step "6/6  Project"
if [[ -n "$PROJECT_DIR" ]]; then
  if [[ -d "$PROJECT_DIR" ]]; then
    echo "    $PROJECT_DIR already exists - not cloning"
  else
    run "clone the project into $PROJECT_DIR" git clone -q "$REPO_URL" "$PROJECT_DIR"
  fi
  run "download packages and switch on the release hook" bash -c "cd '$PROJECT_DIR' && flutter pub get && git config core.hooksPath tools/git-hooks && chmod +x tools/git-hooks/pre-push"
else
  echo "    no --project-dir given - skipping the clone"
fi

step "Check"
$DRY_RUN || flutter doctor
printf '\n\033[1;32mDone.\033[0m Open a new terminal (or run: source ~/.bashrc), then: code <project folder>\n'
printf 'To use a phone over USB, also add yourself to the plugdev group: sudo usermod -aG plugdev "$USER" (then log out and in).\n'
