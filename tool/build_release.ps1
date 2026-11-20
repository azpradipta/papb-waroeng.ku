param(
    [ValidateSet('apk', 'appbundle')]
    [string]$Target = 'apk'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.env'))) {
    throw 'Isi .env terlebih dahulu; lihat docs/SETUP_SUPABASE.md.'
}
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'android/key.properties'))) {
    throw 'Pulihkan keystore dan android/key.properties; lihat docs/BUILD_RELEASE.md.'
}

$previousGradleCache = $env:GRADLE_USER_HOME
$previousDebugFlag = $env:DEBUG
Push-Location -LiteralPath $projectRoot
try {
    # Cache build disimpan di drive project, bukan memenuhi SSD C:.
    $env:GRADLE_USER_HOME = Join-Path $projectRoot '.tools/gradle'
    # Wrapper Gradle tidak perlu mencetak seluruh argumen dart-define.
    $env:DEBUG = $null
    & flutter build $Target --release --dart-define-from-file=.env
    if ($LASTEXITCODE -ne 0) {
        throw "Build $Target release gagal (exit $LASTEXITCODE)."
    }
}
finally {
    Pop-Location
    $env:GRADLE_USER_HOME = $previousGradleCache
    $env:DEBUG = $previousDebugFlag
}
