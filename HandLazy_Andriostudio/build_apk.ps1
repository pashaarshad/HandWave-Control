<#
.SYNOPSIS
    Automated Build Script for HandLazy
    Downloads Gradle and Android SDK Command Line Tools automatically.
    Builds the APK without Android Studio.

.DESCRIPTION
    1. Checks for Java (Required).
    2. Downloads 'tools/gradle' if missing.
    3. Downloads 'tools/android-sdk' if missing.
    4. Accepts SDK Licenses.
    5. Installs Build Tools & Platform.
    6. Compiles the APK.
#>

$ErrorActionPreference = "Stop"

$ProjectRoot = Get-Location
$ToolsDir = "$ProjectRoot\build_tools"
$GradleVersion = "8.6"
$CmdLineToolsVersion = "11076708" # specific version id for commandlinetools-win-11076708_latest.zip
$SdkUrl = "https://dl.google.com/android/repository/commandlinetools-win-${CmdLineToolsVersion}_latest.zip"
$GradleUrl = "https://services.gradle.org/distributions/gradle-${GradleVersion}-bin.zip"

Write-Host "🚀 Starting Auto-Build Setup..." -ForegroundColor Green

# 1. Check Java
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    Write-Error "❌ Java is not installed or not in PATH. Please install Java (JDK 17+) and try again."
    exit 1
}
Write-Host "✅ Java found."

# 2. Create Directory
if (-not (Test-Path $ToolsDir)) {
    New-Item -ItemType Directory -Path $ToolsDir | Out-Null
}

# 3. Setup Gradle
$GradleHome = "$ToolsDir\gradle-$GradleVersion"
$GradleBin = "$GradleHome\bin\gradle.bat"

if (-not (Test-Path $GradleHome)) {
    Write-Host "⬇️ Downloading Gradle $GradleVersion..."
    $GradleZip = "$ToolsDir\gradle.zip"
    Invoke-WebRequest -Uri $GradleUrl -OutFile $GradleZip
    
    Write-Host "📦 Extracting Gradle..."
    Expand-Archive -Path $GradleZip -DestinationPath $ToolsDir
    Remove-Item $GradleZip
}
Write-Host "✅ Gradle Ready."

# 4. Setup Android SDK
$AndroidHome = "$ToolsDir\android-sdk"
$CmdLineToolsHome = "$AndroidHome\cmdline-tools\latest"
$SdkManager = "$CmdLineToolsHome\bin\sdkmanager.bat"

if (-not (Test-Path $SdkManager)) {
    Write-Host "⬇️ Downloading Android Command Line Tools..."
    $SdkZip = "$ToolsDir\sdk.zip"
    Invoke-WebRequest -Uri $SdkUrl -OutFile $SdkZip
    
    Write-Host "📦 Extracting SDK..."
    # Extract to temp first because of folder structure nuances
    $TempSdk = "$ToolsDir\temp_sdk"
    Expand-Archive -Path $SdkZip -DestinationPath $TempSdk
    
    # Move to correct path: android-sdk/cmdline-tools/latest
    New-Item -ItemType Directory -Path "$AndroidHome\cmdline-tools" -Force | Out-Null
    Move-Item -Path "$TempSdk\cmdline-tools" -Destination "$AndroidHome\cmdline-tools\latest"
    
    Remove-Item $SdkZip
    Remove-Item -Path $TempSdk -Recurse -Force
}
Write-Host "✅ Android SDK Tools Ready."

# Set Env Vars for this session
$env:ANDROID_HOME = $AndroidHome
$env:ANDROID_SDK_ROOT = $AndroidHome

# 5. Accept Licenses & Install Dependencies
Write-Host "📜 Accepting Licenses..."
# This pipe trick 'yes' simulates accepting licenses
& cmd /c "echo y | `"$SdkManager`" --licenses" | Out-Null

Write-Host "🛠️ Installing Platform & Build Tools (This may take a while)..."
& $SdkManager "platform-tools" "platforms;android-34" "build-tools;34.0.0" | Out-Null

# 6. Build
Write-Host "🏗️ compiling APK..."
& $GradleBin assembleDebug

if ($?) {
    Write-Host "
🎉 BUILD SUCCESSFUL!
apks are located at:" -ForegroundColor Green
    Get-ChildItem -Path "app\build\outputs\apk\debug\*.apk" | Select-Object FullName
} else {
    Write-Error "❌ Build Failed."
}
