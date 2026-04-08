$projectScript = Join-Path $PSScriptRoot "ev_data_logger\build_apk.ps1"

if (-not (Test-Path $projectScript)) {
    throw "Khong tim thay script tai: $projectScript"
}

& $projectScript @args
exit $LASTEXITCODE
