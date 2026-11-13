<#
.SYNOPSIS
  Sets up a Windows PC to build and run NplusPrep, without Android Studio.

.DESCRIPTION
  Installs (only what is missing):
    - Git, Visual Studio Code, Java 17 (Temurin)         via winget
    - Flutter SDK (stable)                               into C:\src\flutter
    - Android SDK command-line tools, platform-tools,
      Android 36 platform, build-tools 36, NDK 27        into %LOCALAPPDATA%\Android\Sdk
    - The Flutter extension for VS Code
  Then sets ANDROID_HOME / PATH for your user, accepts the Android licences,
  optionally clones the project, and runs `flutter doctor`.

  About 1.5 GB of downloads (the NDK is most of it) instead of 3-4 GB for
  Android Studio. Safe to run again: finished steps are skipped.

.PARAMETER ProjectDir
  Where to clone the project (skipped if the folder already exists).

.PARAMETER DryRun
  Print what would be done without changing anything.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\setup_windows.ps1
  powershell -ExecutionPolicy Bypass -File setup_windows.ps1 -ProjectDir "$HOME\StudioProjects\mental_ability_app"
#>
param(
  [string]$ProjectDir = '',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$FlutterDir = 'C:\src\flutter'
$SdkDir = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$RepoUrl = 'https://github.com/harikn2003/mental-ability-app.git'
# Keep in step with android/app/build.gradle.kts (ndkVersion) and Flutter's compileSdk.
$SdkPackages = @('platform-tools', 'platforms;android-36', 'build-tools;36.0.0', 'ndk;27.0.12077973')

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Run($text, [scriptblock]$action) {
  if ($DryRun) { Write-Host "    [dry run] $text" -ForegroundColor DarkGray } else { Write-Host "    $text"; & $action }
}
function Has($command) { [bool](Get-Command $command -ErrorAction SilentlyContinue) }
function Add-UserPath($dir) {
  $path = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (($path -split ';') -notcontains $dir) {
    Run "add $dir to your PATH" { [Environment]::SetEnvironmentVariable('Path', "$path;$dir", 'User') }
  }
  if (($env:Path -split ';') -notcontains $dir) { $env:Path = "$env:Path;$dir" }
}
function Install-WithWinget($id, $name, $command) {
  if ($command -and (Has $command)) { Write-Host "    $name already installed"; return }
  Run "install $name" { winget.exe install --id $id --exact --silent --accept-package-agreements --accept-source-agreements }
}

if (-not (Has 'winget')) {
  throw 'winget is missing. Install "App Installer" from the Microsoft Store, then run this script again.'
}

Step '1/6  Git, Visual Studio Code, Java 17'
Install-WithWinget 'Git.Git' 'Git' 'git'
Install-WithWinget 'Microsoft.VisualStudioCode' 'Visual Studio Code' 'code'
# Java 17 or newer (Gradle 8.14 runs on 17-24). `java -version` prints to stderr, so ask cmd for it.
$javaMajor = 0
if (Has 'java') {
  $v = cmd /c 'java -version 2>&1' | Out-String
  if ($v -match 'version "(\d+)') { $javaMajor = [int]$Matches[1] }
}
if ($javaMajor -ge 17) { Write-Host "    Java $javaMajor already installed" } else { Install-WithWinget 'EclipseAdoptium.Temurin.17.JDK' 'Java 17 (Temurin)' $null }
# winget installs update PATH for new terminals; pick them up in this one too.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

Step '2/6  Flutter SDK'
if (Has 'flutter') {
  Write-Host "    Flutter already installed: $((Get-Command flutter).Source)"
} else {
  Run "clone Flutter stable into $FlutterDir" {
    New-Item -ItemType Directory -Force (Split-Path $FlutterDir) | Out-Null
    git clone https://github.com/flutter/flutter.git -b stable $FlutterDir
  }
  Add-UserPath "$FlutterDir\bin"
}

Step '3/6  Android SDK command-line tools'
$sdkManager = Join-Path $SdkDir 'cmdline-tools\latest\bin\sdkmanager.bat'
if (Test-Path $sdkManager) {
  Write-Host "    already in $SdkDir"
} else {
  Run "download the latest command-line tools into $SdkDir" {
    $xml = (Invoke-WebRequest 'https://dl.google.com/android/repository/repository2-3.xml' -UseBasicParsing).Content
    $build = ([regex]::Matches($xml, 'commandlinetools-win-(\d+)_latest\.zip') | ForEach-Object { [int64]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
    $zip = Join-Path $env:TEMP 'cmdline-tools.zip'
    Invoke-WebRequest "https://dl.google.com/android/repository/commandlinetools-win-${build}_latest.zip" -OutFile $zip -UseBasicParsing
    $tmp = Join-Path $env:TEMP 'cmdline-tools-unzip'
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $zip $tmp
    New-Item -ItemType Directory -Force (Join-Path $SdkDir 'cmdline-tools') | Out-Null
    Move-Item (Join-Path $tmp 'cmdline-tools') (Join-Path $SdkDir 'cmdline-tools\latest')
    Remove-Item $zip, $tmp -Recurse -Force
  }
}
Run 'set ANDROID_HOME for your user' {
  [Environment]::SetEnvironmentVariable('ANDROID_HOME', $SdkDir, 'User')
  $env:ANDROID_HOME = $SdkDir
}
Add-UserPath (Join-Path $SdkDir 'platform-tools')
Add-UserPath (Join-Path $SdkDir 'cmdline-tools\latest\bin')

Step '4/6  Android SDK packages and licences'
Run "install $($SdkPackages -join ', ')" {
  # Answer "y" to every licence prompt.
  $yes = ('y' + [Environment]::NewLine) * 30
  $yes | & $sdkManager --licenses | Out-Null
  & $sdkManager --install @SdkPackages
}
Run 'point Flutter at the SDK and accept its licences' {
  flutter config --android-sdk $SdkDir | Out-Null
  ('y' + [Environment]::NewLine) * 30 | flutter doctor --android-licenses | Out-Null
}

Step '5/6  Flutter extension for VS Code'
Run 'install Dart-Code.flutter (adds Dart too)' { code --install-extension Dart-Code.flutter --force | Out-Null }

Step '6/6  Project'
if ($ProjectDir) {
  if (Test-Path $ProjectDir) {
    Write-Host "    $ProjectDir already exists - not cloning"
  } else {
    Run "clone the project into $ProjectDir" { git clone $RepoUrl $ProjectDir }
  }
  Run 'download packages' {
    Push-Location $ProjectDir
    flutter pub get
    Pop-Location
  }
} else {
  Write-Host '    no -ProjectDir given - skipping the clone'
}

Step 'Check'
if (-not $DryRun) { flutter doctor }
Write-Host "`nDone. Open a NEW terminal (so PATH changes apply), then: code <project folder>" -ForegroundColor Green
