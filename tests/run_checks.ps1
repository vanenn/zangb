param([string]$Engine = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Engine)) {
    $Engine = Join-Path (Split-Path -Parent $projectRoot) 'system-supplier\tools\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $Engine)) { throw '未找到 Godot，请通过 -Engine 指定引擎路径。' }
foreach ($test in @('rules','v2','feedback','tactics_compare','campaign')) {
    & $Engine --headless --path $projectRoot --script "res://tests/$test.gd" --log-file (Join-Path $PSScriptRoot "$test.log")
    if ($LASTEXITCODE -ne 0) { throw "$test 检查失败。" }
}
Write-Output '规则与三路线检查通过。visual.gd、performance.gd 需在有图形界面的环境下单独运行。'
