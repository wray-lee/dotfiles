$L = "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
foreach ($n in 'fd.exe') {
    $link = Join-Path $L $n
    $t = (Get-Item $link -ErrorAction SilentlyContinue).Target
    if ($t -and (Test-Path $t)) {
        Remove-Item $link -Force
        New-Item -ItemType SymbolicLink -Path $link -Target $t | Out-Null
        "$n -> link rebuilt"
    } else { "$n -> target missing, reinstall winget package" }
}
