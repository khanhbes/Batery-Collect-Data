param(
    [string]$ProjectDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$TargetPlatform = "android-arm64",
    [switch]$NoVersionBump
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$pubspecPath = Join-Path $ProjectDir "pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
    throw "Khong tim thay pubspec.yaml tai: $pubspecPath"
}

$pubspecContent = Get-Content -Path $pubspecPath -Raw
$versionPattern = "(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$"
$match = [regex]::Match($pubspecContent, $versionPattern)

if (-not $match.Success) {
    throw "Khong doc duoc version theo dinh dang x.y.z+build trong pubspec.yaml"
}

$semver = $match.Groups[1].Value
$buildNumber = [int]$match.Groups[2].Value

if (-not $NoVersionBump) {
    $buildNumber++
    $newVersionLine = "version: $semver+$buildNumber"
    $updatedContent = [regex]::Replace(
        $pubspecContent,
        $versionPattern,
        $newVersionLine,
        1
    )
    Set-Content -Path $pubspecPath -Value $updatedContent -Encoding utf8
    Write-Host "Da cap nhat version -> $semver+$buildNumber"
} else {
    Write-Host "Giu nguyen version -> $semver+$buildNumber"
}

Push-Location $ProjectDir
try {
    $buildArgs = @(
        "build",
        "apk",
        "--release",
        "--target-platform", $TargetPlatform,
        "--build-number", "$buildNumber"
    )

    Write-Host "Dang build APK..."
    flutter @buildArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Build that bai voi exit code: $LASTEXITCODE"
    }

    $apkPath = Join-Path $ProjectDir "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        Write-Host "Build thanh cong: $apkPath"
    } else {
        Write-Host "Build thanh cong, nhung khong tim thay APK tai duong dan mac dinh."
    }
}
finally {
    Pop-Location
}
