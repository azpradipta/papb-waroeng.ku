param([switch]$Login)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & python tool/setup_automatic_deletion.py
    if ($LASTEXITCODE -ne 0) { throw 'Persiapan konfigurasi otomatis gagal.' }
    $target = Get-Content -LiteralPath '.tools/automatic-deletion/target.json' -Raw | ConvertFrom-Json
    if ($target.project_ref -notmatch '^[a-z0-9]{20}$') { throw 'Project target tidak valid.' }
    $cliArgs = @('--yes', '--cache', '.tools/npm', 'supabase@3.4.0')
    if ($Login) {
        & npx.cmd @cliArgs login
        if ($LASTEXITCODE -ne 0) { throw 'Login CLI Supabase belum berhasil.' }
    }
    & npx.cmd @cliArgs secrets set --env-file '.tools/automatic-deletion/worker.env' "--remote=$($target.project_ref)" --yes
    if ($LASTEXITCODE -ne 0) { throw 'Secret worker belum terkirim. Login CLI dahulu atau ulangi dengan -Login.' }
    foreach ($functionName in @('delete-account', 'process-account-deletions')) {
        & npx.cmd @cliArgs functions deploy $functionName "--remote=$($target.project_ref)" --no-verify-jwt --use-api --yes
        if ($LASTEXITCODE -ne 0) { throw "Deployment $functionName belum berhasil." }
    }
    Write-Output 'Dua Edge Function sudah terdeploy. Selanjutnya jalankan seluruh .tools/automatic-deletion/activate.sql di SQL Editor project yang sama.'
    Write-Output 'Setelah SQL sukses, jalankan python tool/check_backend.py dan uji memakai akun percobaan.'
}
finally {
    Pop-Location
}
