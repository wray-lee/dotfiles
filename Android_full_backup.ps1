<#
  安卓通用只读全量备份脚本（Windows 10/11，PowerShell 5.1 / 7 均可）

  只读保证：手机端只执行读取命令（dd if= / cat / tar -c / find / stat / sha256sum / getprop / pm list 等），
  内置命令守卫，含 of= / > / rm / setprop / reboot / install 等可能写手机的命令一律拒绝执行。

  备份内容（自动识别机型，联发科 / 高通 / 三星 / Pixel、A/B 与非 A/B 均适用）：
    已 root（Magisk / KernelSU / APatch）：
      1. 全部物理分区 dd 镜像（自动排除 userdata、swap 分区、整盘设备；super 等大分区分块读取逐块校验）
      2. 运行中挂载的可写分区再做一份文件级打包（persist / nvdata / efs / metadata 等校准数据）
      3. 内部存储（每个用户的 /data/media/<用户>，按目录分包）
      4. 应用数据（/data/user、/data/user_de 按应用分包，/data/app 和其余 /data 目录按目录分包，带 SELinux 标签）
    未 root：
      只能备份内部存储（/sdcard，不含 Android/data）和第三方应用安装包（apk，不含应用数据）

  校验：分区与手机端 sha256 比对（正被写入的分区用连续两次一致的读取）；tar 包比对文件数 + 总字节数。
  断线会等待重连；已校验的部分重新运行时自动跳过，可随时中断后续传。

  用法：
    powershell -ExecutionPolicy Bypass -File .\Android_full_backup.ps1                    # 全量备份到脚本目录下 <型号>_<序列号>_<日期>
    .\Android_full_backup.ps1 -OutDir E:\backup                                          # 指定输出目录（中断后用同一目录重跑即续传）
    .\Android_full_backup.ps1 -NoData                                                    # 只备份分区
    .\Android_full_backup.ps1 -NoPartitions                                              # 只备份内部存储和应用数据
    .\Android_full_backup.ps1 -Only boot_a,persist -OutDir .\test                        # 只备份指定分区（测试用，不备份数据）
    .\Android_full_backup.ps1 -AllLogical                                                # 额外单独导出 super 里的每个逻辑分区
    .\Android_full_backup.ps1 -Serial XXXX                                               # 连了多台手机时指定序列号
    .\Android_full_backup.ps1 -Skip cache,logdump                                        # 额外排除某些分区

  还原提示：分区镜像只能刷回同一台手机（校准分区 nvdata / persist / efs / modem 等千万不要刷到别的手机）；
  应用数据包是解密后的明文，请妥善保管，还原需 root 后用 tar --selinux -xpf 解包并修正属主。
#>
[CmdletBinding()]
param(
    [string]$OutDir = '',
    [ValidateScript({ $_ -ge 4 -and $_ % 4 -eq 0 })][int]$ChunkMB = 512,
    [string[]]$Skip = @(),
    [string[]]$Only = @(),
    [switch]$AllLogical,
    [switch]$NoPartitions,
    [switch]$NoData,
    [string]$Serial = '',
    [string]$Adb = 'adb'
)
$ErrorActionPreference = 'Stop'
# -File 方式调用时 "a,b,c" 会作为一个字符串传入，这里统一拆开
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Skip = @($Skip | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$SArgs = @(); if ($Serial) { $SArgs = @('-s', $Serial) }
$TarExe = Join-Path $env:WINDIR 'System32\tar.exe'
$LogFile = $null
$script:Su = 'sh'
$script:Sha = ''
$script:TarSel = ''
$script:Fails = New-Object Collections.Generic.List[string]
$script:Warns = 0
$script:Clash = @{}
$script:XferOk = $true
$Utf8 = New-Object Text.UTF8Encoding $false

function Log([string]$m) {
    $l = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m
    Write-Host $l
    if ($LogFile) { [IO.File]::AppendAllText($LogFile, "$l`r`n", $Utf8) }
}
function Add-Fail([string]$what) { $script:Fails.Add($what); Log "失败 $what" }

function Wait-Device {
    $ErrorActionPreference = 'Continue'   # PS 5.1 下 adb 的 stderr 在 Stop 模式会被当成异常
    while ($true) {
        $s = (& $Adb @SArgs get-state 2>&1 | ForEach-Object { "$_" }) -join ' '
        if ($s -match '^\s*device\s*$') { return }
        if ($s -match 'more than one') { throw '连接了多台设备，请用 -Serial 指定序列号（adb devices 查看）' }
        Log "等待手机连接（当前：$(($s -replace '\s+', ' ').Trim())）：检查数据线、USB 调试是否开启、手机上是否点了允许调试..."
        Start-Sleep -Seconds 10
    }
}

# 只读守卫：拒绝任何可能写手机的命令（引号内的路径不参与判断，写到 /dev/null 和 2>&1 不算写）
function Assert-ReadOnly([string]$cmd) {
    # 先去掉 Esc 产生的 '\'' 转义，否则含单引号的文件名会让引号配对错位
    $c = ($cmd.Replace("'\''", '') -replace "'[^']*'", "''") -replace '[12]?>\s*/dev/null', '' -replace '2>&1', ''
    if ($c -match '(\bof=|>|\brm\b|\bmv\b|\bcp\b|\bln\b|\btee\b|\btruncate\b|\bsed\b.*\s-i|\bdd\b.*\bconv=|setprop|resetprop|\breboot\b|fastboot|mkfs|\bformat\b|wipe|\bsettings\s+put\b|\bpm\b(?!\s+(list|path)\b)|\bcmd\b|\bam\b|\binstall\b|\bsetenforce\b|\btouch\b|\bmkdir\b|\bchmod\b|\bchown\b|\bchcon\b|\brestorecon\b|\bmount\b|\bumount\b|\bblockdev\b.*--set|\bkill\b)') {
        throw "拒绝执行非只读命令: $cmd"
    }
}

# 在手机上执行只读命令（root 时经 su），stdout 原样写入文件（二进制安全）。命令经 base64 传输，避免 Windows 引号转义问题。
function Invoke-ToFile([string]$cmd, [string]$path) {
    $cmd = $cmd.Replace("`r", '')   # 本文件是 CRLF，多行命令要去掉 \r 手机 shell 才能执行
    Assert-ReadOnly $cmd
    Wait-Device
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($cmd))
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $Adb
    $pre = ''; if ($Serial) { $pre = "-s $Serial " }
    $psi.Arguments = "$pre" + "exec-out `"echo $b64|base64 -d|$($script:Su)`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = [Diagnostics.Process]::Start($psi)
    $errTask = $p.StandardError.ReadToEndAsync()
    $fs = [IO.File]::Open($path, [IO.FileMode]::Create, [IO.FileAccess]::Write)
    try { $p.StandardOutput.BaseStream.CopyTo($fs, 4MB) } finally { $fs.Close() }
    $p.WaitForExit()
    [void]$errTask.Wait(5000)
    # adb 自身出错（断线、adb 服务被关）时输出不完整；exec-out 不传手机端退出码，所以这里只反映传输是否正常
    $script:XferOk = $p.ExitCode -eq 0 -and -not ($errTask.IsCompleted -and $errTask.Result -match 'error')
}

function Invoke-Text([string]$cmd) {
    $tmp = [IO.Path]::GetTempFileName()
    try {
        # 文本输出（目录列表、文件大小、校验值）不完整会导致漏备份或误判，传输出错就重试
        for ($t = 1; $t -le 5; $t++) {
            Invoke-ToFile $cmd $tmp
            if ($script:XferOk) { return [IO.File]::ReadAllText($tmp) }
            Log "adb 传输出错，重试（第 $t 次）"; Start-Sleep -Seconds 3
        }
        throw "adb 连续传输失败，请检查连接后用同一目录重新运行（已完成的部分会自动跳过）：$cmd"
    }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}
function Get-Lines([string]$cmd) { @((Invoke-Text $cmd) -split "`n" | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ }) }

function Esc([string]$s) { $s.Replace("'", "'\''") }

# 列出目录下的全部条目（含隐藏文件；不用 ls，避免空格等字符被转义）
function Get-Entries([string]$dir) {
    $t = 'cd ''DIR'' 2>/dev/null && for f in * .[!.]* ..?*; do if [ -e "$f" ] || [ -L "$f" ]; then echo "$f"; fi; done'
    $names = Get-Lines $t.Replace('DIR', (Esc $dir))
    # Windows 不区分大小写：同一目录里只差大小写（或转换后同名）的条目全部加哈希区分，每次运行结果一致
    $names | Group-Object { (Get-SafeBase $_).ToLower() } | Where-Object { $_.Count -gt 1 } |
        ForEach-Object { foreach ($x in $_.Group) { $script:Clash[$x] = 1 } }
    $names
}

function Get-Sha([string]$path) {
    $sha = [Security.Cryptography.SHA256]::Create(); $fs = [IO.File]::OpenRead($path)
    try { return (-join ($sha.ComputeHash($fs) | ForEach-Object { $_.ToString('x2') })) } finally { $fs.Close(); $sha.Dispose() }
}
# 手机端对某个只读输出流算 sha256；手机没有 sha256 工具时返回空（此时靠连续两次一致的读取校验）
function Get-DevSha([string]$src) {
    if (-not $script:Sha) { return '' }
    ((Invoke-Text "$src | $($script:Sha)").Trim() -split '\s+')[0].ToLower()
}
# 不带 BOM，Linux 下 sha256sum -c 可直接核对
function Add-Sum([string]$hash, [string]$rel) { [IO.File]::AppendAllText($SumFile, "$hash  $rel`r`n", $Utf8) }
function Get-Rel([string]$path) { $path.Substring($OutDir.Length).TrimStart('\') }

function Get-SafeBase([string]$n) {
    $s = ($n -replace '[\\/:*?"<>|\x00-\x1f]', '_').TrimEnd('. ')
    if (-not $s -or $s -match '^(CON|PRN|AUX|NUL|COM\d|LPT\d)(\..*)?$') { $s = '_' + $s }
    $s
}
# 把手机上的名字转成 Windows 可用的文件名；改动过、过长或与同级条目只差大小写时追加哈希，保证不重名
function Get-SafeName([string]$n) {
    $s = Get-SafeBase $n
    if ($s -cne $n -or $s.Length -gt 80 -or $script:Clash.ContainsKey($n)) {
        $h = [Security.Cryptography.SHA1]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($n))
        if ($s.Length -gt 60) { $s = $s.Substring(0, 60) }
        $s += '~' + (-join ($h[0..3] | ForEach-Object { $_.ToString('x2') }))
    }
    return $s
}

# 备份一个块设备或文件（$src 是 dd 能读的路径）。小的整块读；大的分块读、逐块校验；全部可续传。
function Backup-Block([string]$src, [string]$name, [string]$dir, [long]$size, [string]$ext = '.img') {
    [void](New-Item -ItemType Directory -Force -Path $dir)
    $out = Join-Path $dir ((Get-SafeName $name) + $ext)
    $ok = "$out.ok"
    $rel = Get-Rel $out
    if (Test-Path -LiteralPath $ok) { Log "跳过（已校验）$rel"; return }
    $chunk = [long]$ChunkMB * 1MB
    $per = [int]($chunk / 4MB)
    $q = "'$(Esc $src)'"

    if ($size -le $chunk) {
        $prev = ''
        for ($t = 1; $t -le 4; $t++) {
            $devh = Get-DevSha "dd if=$q bs=4M 2>/dev/null"
            Invoke-ToFile "dd if=$q bs=4M 2>/dev/null" $out
            $xok = $script:XferOk
            $len = (Get-Item -LiteralPath $out).Length
            $pc = Get-Sha $out
            if ($xok -and $len -eq $size -and ($pc -eq $devh -or $pc -eq $prev)) {
                Set-Content -LiteralPath $ok -Value $pc; Add-Sum $pc $rel
                if ($pc -eq $devh) { Log "OK  $rel $len" } else { Log "OK  $rel $len（内容正被系统写入，采用连续两次一致的读取）" }
                return
            }
            if ($xok -and $len -eq $size) { $prev = $pc }
            Log "重试 $rel（第 $t 次）size=$len/$size 传输正常=$xok"
        }
        Add-Fail $rel; return
    }

    $n = [int][Math]::Ceiling($size / [double]$chunk)
    $cdir = "$out.chunks"
    [void](New-Item -ItemType Directory -Force -Path $cdir)
    Log "== $rel $size 字节，分 $n 块"
    for ($i = 0; $i -lt $n; $i++) {
        $part = Join-Path $cdir ('{0:D4}' -f $i)
        if (Test-Path -LiteralPath "$part.ok") { continue }
        $want = [Math]::Min($chunk, $size - [long]$i * $chunk)
        $range = "dd if=$q bs=4M skip=$($i * $per) count=$per 2>/dev/null"
        $done = $false; $prev = ''
        for ($t = 1; $t -le 4 -and -not $done; $t++) {
            $devh = Get-DevSha $range
            Invoke-ToFile $range $part
            $xok = $script:XferOk
            $len = (Get-Item -LiteralPath $part).Length
            $pc = Get-Sha $part
            if ($xok -and $len -eq $want -and ($pc -eq $devh -or $pc -eq $prev)) { Set-Content -LiteralPath "$part.ok" -Value $pc; $done = $true }
            else { if ($xok -and $len -eq $want) { $prev = $pc }; Log "重试 $name 块 $i（第 $t 次）size=$len/$want 传输正常=$xok" }
        }
        if (-not $done) { Add-Fail "$rel 块 $i（重新运行脚本可续传）"; return }
        Log ('OK  {0} 块 {1}/{2}' -f $name, ($i + 1), $n)
    }
    $fs = [IO.File]::Open($out, [IO.FileMode]::Create, [IO.FileAccess]::Write)
    try {
        for ($i = 0; $i -lt $n; $i++) {
            $in = [IO.File]::OpenRead((Join-Path $cdir ('{0:D4}' -f $i)))
            try { $in.CopyTo($fs, 4MB) } finally { $in.Close() }
        }
    } finally { $fs.Close() }
    $len = (Get-Item -LiteralPath $out).Length
    if ($len -ne $size) { Add-Fail "$rel 合并后大小 $len != $size"; return }
    $pc = Get-Sha $out
    Set-Content -LiteralPath $ok -Value $pc; Add-Sum $pc $rel
    Remove-Item -LiteralPath $cdir -Recurse -Force
    Log "OK  $rel $len（分块全部校验通过并已合并）"
}

# tar 流完整结束的标志：长度是 512 的倍数且以两个全零块结尾（传输中断的包没有）
function Test-TarEnd([string]$path) {
    $len = (Get-Item -LiteralPath $path).Length
    if ($len -lt 1024 -or $len % 512) { return $false }
    $fs = [IO.File]::OpenRead($path)
    try { [void]$fs.Seek(-1024, 'End'); $b = New-Object byte[] 1024; [void]$fs.Read($b, 0, 1024) } finally { $fs.Close() }
    foreach ($x in $b) { if ($x) { return $false } }
    return $true
}

# 打包手机上的一个目录或文件，并用文件数 + 总字节数与手机端比对。-Live：内容在运行中变动，结构完整即接受。
function Backup-Tar([string]$parent, [string]$entry, [string]$dir, [switch]$Live) {
    [void](New-Item -ItemType Directory -Force -Path $dir)
    $out = Join-Path $dir ((Get-SafeName $entry) + '.tar')
    $rel = Get-Rel $out
    if (Test-Path -LiteralPath "$out.ok") { Log "跳过（已校验）$rel"; return }
    $p = Esc "$parent/$entry"; $par = Esc $parent; $e = Esc "./$entry"
    $gotN = 0; $gotB = [long]0; $wantN = 0; $wantB = [long]0; $intact = $false
    for ($t = 1; $t -le 3; $t++) {
        # 硬链接在 tar 里只存一份数据，按 inode 去重后再统计
        $sizes = (Invoke-Text "find '$p' -type f -print0 | xargs -0 stat -c '%i %s' 2>/dev/null | sort -u -k1,1 | cut -d' ' -f2") -split "`n" | Where-Object { $_ -match '^\d+$' }
        $wantN = @($sizes).Count; $wantB = [long]0; foreach ($z in $sizes) { $wantB += [long]$z }
        Invoke-ToFile "tar $($script:TarSel)-cf - -C '$par' '$e' 2>/dev/null" $out
        $xok = $script:XferOk
        $gotN = 0; $gotB = [long]0
        $ErrorActionPreference = 'Continue'
        $all = @(& $TarExe -tvf $out 2>&1)
        $code = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $list = $all | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] }
        # toybox 的 --selinux 标签记录末尾带 NUL，Windows tar 会报 "malformed pax attributes" 但内容完好，这类提示不算损坏
        $errs = @($all | Where-Object { $_ -is [Management.Automation.ErrorRecord] } | ForEach-Object { "$_" } |
            Where-Object { $_ -notmatch 'malformed pax attributes|Error exit delayed from previous errors' })
        $intact = $xok -and (($code -eq 0) -or ($errs.Count -eq 0)) -and (Test-TarEnd $out)
        if ($intact) {
            foreach ($l in $list) { if ($l -match '^-\S*\s+\S+\s+\S+\s+\S+\s+(\d+)\s') { $gotN++; $gotB += [long]$Matches[1] } }
            if ($gotN -eq $wantN -and $gotB -eq $wantB) {
                $h = Get-Sha $out; Set-Content -LiteralPath "$out.ok" -Value $h; Add-Sum $h $rel
                Log "OK  $rel 文件=$gotN 字节=$gotB"; return
            }
        }
        Log "重试 $rel（第 $t 次）手机=$wantN/$wantB 备份=$gotN/$gotB 包完整=$intact"
    }
    # 手机上有文件而包里一个都没有，说明没读到内容，不能当快照接受
    if ($Live -and $intact -and ($wantN -eq 0 -or $gotN -gt 0)) {
        $h = Get-Sha $out; Set-Content -LiteralPath "$out.ok" -Value $h; Add-Sum $h $rel; $script:Warns++
        Log "警告 $rel 与手机端不完全一致（运行中的数据在变动，属正常）：手机=$wantN/$wantB 备份=$gotN/$gotB"; return
    }
    Add-Fail "$rel（$parent/$entry，已保留，重新运行会重试）"
}

# ---------------- 连接与环境检测 ----------------
Wait-Device
if ((Invoke-Text 'echo ok').Trim() -ne 'ok') { throw '无法在手机上执行命令（需要 Android 7 以上，且 adb 已授权）' }
$model = (Invoke-Text 'getprop ro.product.model').Trim()
$sn = (Invoke-Text 'getprop ro.serialno').Trim()
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot ((Get-SafeName "${model}_$sn") + '_' + (Get-Date -Format yyyyMMdd)) }
$OutDir = [IO.Path]::GetFullPath($OutDir).TrimEnd('\')
[void](New-Item -ItemType Directory -Force -Path $OutDir)
$LogFile = Join-Path $OutDir 'backup.log'
$SumFile = Join-Path $OutDir 'SHA256SUMS.txt'
$PartDir = Join-Path $OutDir 'partitions'
$LogiDir = Join-Path $OutDir 'logical'
$MntDir = Join-Path $OutDir 'mounted'
$DataDir = Join-Path $OutDir 'data'
Log "== 开始备份 $model（$sn）-> $OutDir"

Log '检测 root（如果手机弹出超级用户授权，请点允许）...'
$script:Su = 'su'
$Root = $false
try { $Root = (Invoke-Text 'id') -match 'uid=0' } catch { }
if (-not $Root) {
    $script:Su = 'sh'
    Log '警告：未获得 root，只能备份内部存储（不含 Android/data）和第三方应用安装包；分区和应用数据需要 root'
}
$script:Sha = (Invoke-Text 'for c in "sha256sum" "toybox sha256sum" "busybox sha256sum" "/data/adb/magisk/busybox sha256sum" "/data/adb/ksu/bin/busybox sha256sum" "/data/adb/ap/bin/busybox sha256sum"; do if echo | $c >/dev/null 2>&1; then echo "$c"; break; fi; done').Trim()
if (-not $script:Sha) { Log '警告：手机上没有 sha256 工具，改用连续两次读取一致来校验' }
if ($Root -and (Invoke-Text 'tar --help 2>&1') -match '--selinux') { $script:TarSel = '--selinux ' }

[IO.File]::WriteAllText((Join-Path $OutDir 'getprop.txt'), (Invoke-Text 'getprop'))
[IO.File]::WriteAllText((Join-Path $OutDir 'mounts.txt'), (Invoke-Text 'cat /proc/mounts'))
[IO.File]::WriteAllText((Join-Path $OutDir 'proc_partitions.txt'), (Invoke-Text 'cat /proc/partitions'))
if ($Root) { [IO.File]::WriteAllText((Join-Path $OutDir 'lpdump.txt'), (Invoke-Text 'lpdump --slot=0 2>/dev/null; lpdump --slot=1 2>/dev/null')) }

# ---------------- 分区清单 ----------------
$parts = @(); $excl = @{}
if ($Root -and -not $NoPartitions) {
    # 找 by-name 目录；算出 /data 和 swap 背后的块设备（含 dm 下层），这些不 dd（userdata 加密且巨大，swap 一直在变）
    $scan = @'
BN=; for d in /dev/block/by-name /dev/block/bootdevice/by-name /dev/block/platform/*/by-name /dev/block/platform/*/*/by-name; do if [ -d "$d" ]; then BN=$d; break; fi; done
echo "DIR $BN"
sl(){ for s in /sys/class/block/$1/slaves/*; do if [ -e "$s" ]; then echo "EXCL ${s##*/}"; sl ${s##*/}; fi; done; }
d=$(readlink -f "$(grep ' /data ' /proc/mounts | head -1 | cut -d' ' -f1)"); echo "EXCL ${d##*/}"; sl ${d##*/}
tail -n +2 /proc/swaps | while read f r; do b=$(readlink -f $f); echo "EXCL ${b##*/}"; sl ${b##*/}; done
[ -n "$BN" ] && cd $BN && for n in *; do t=$(readlink -f $n); b=${t##*/}; s=$(blockdev --getsize64 $t 2>/dev/null) || { echo "BROKEN $n"; continue; }; w=0; ls -d /sys/block/$b/$b* >/dev/null 2>&1 && w=1; echo "P $n $s $b $w"; done
'@
    $lines = Get-Lines $scan
    [IO.File]::WriteAllLines((Join-Path $OutDir 'partition_scan.txt'), [string[]]$lines)
    $bn = (($lines | Where-Object { $_ -like 'DIR *' }) -replace '^DIR\s*', '') | Select-Object -First 1
    if (-not $bn) { Add-Fail '找不到 by-name 分区目录，无法备份分区' }
    foreach ($l in $lines) { if ($l -match '^EXCL (\S+)') { $excl[$Matches[1]] = 1 } }
    $seen = @{}
    foreach ($l in $lines) {
        if ($l -match '^BROKEN (\S+)') { Log "跳过 $($Matches[1])（链接指向不存在的设备）"; continue }
        if ($l -notmatch '^P (\S+) (\d+) (\S+) (\d)') { continue }
        $pt = [pscustomobject]@{ Name = $Matches[1]; Size = [long]$Matches[2]; Dev = $Matches[3]; Whole = $Matches[4] -eq '1' }
        if ($Only.Count -and -not ($Only -contains $pt.Name)) { continue }
        if ($Skip -contains $pt.Name) { Log "跳过 $($pt.Name)（-Skip 指定）"; continue }
        if ($pt.Name -eq 'userdata' -or $excl.ContainsKey($pt.Dev)) { Log "跳过 $($pt.Name)（用户数据 / swap 分区，数据改用文件级备份）"; continue }
        if ($pt.Whole) { Log "跳过 $($pt.Name)（整盘设备，其中的分区已单独备份）"; continue }
        if ($seen.ContainsKey($pt.Dev)) { Log "跳过 $($pt.Name)（与 $($seen[$pt.Dev]) 是同一个设备）"; continue }
        $seen[$pt.Dev] = $pt.Name
        $parts += $pt
    }
    $parts = @($parts | Sort-Object Size)
} elseif (-not $Root -and -not $NoPartitions) { Log '跳过分区备份（需要 root）' }

$DoData = -not $NoData -and -not $Only.Count
if (-not $NoData -and $Only.Count) { Log '已指定 -Only，本次不备份内部存储和应用数据' }

# ---------------- 空间检查 ----------------
$need = [long]0; foreach ($pt in $parts) { $need += $pt.Size }
if ($DoData) {
    $df = (Invoke-Text 'df -k /data 2>/dev/null | tail -1') -split '\s+'
    if ($df.Count -ge 3 -and $df[2] -match '^\d+$') { $need += [long]$df[2] * 1KB }
}
$free = [long]-1
try { $free = (New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($OutDir))).AvailableFreeSpace } catch { }   # 网络路径取不到
if ($free -ge 0) { Log ('预计需要约 {0:N1} GB，目标盘剩余 {1:N1} GB' -f ($need / 1GB), ($free / 1GB)) }
else { Log ('预计需要约 {0:N1} GB（网络路径，无法检查剩余空间）' -f ($need / 1GB)) }
if ($free -ge 0 -and $need -gt $free) { Log '警告：目标盘空间可能不够，空间用完后脚本会出错停止；腾出空间后用同一目录重新运行即可续传' }

# ---------------- 1. 物理分区 ----------------
foreach ($pt in $parts) { Backup-Block "$bn/$($pt.Name)" $pt.Name $PartDir $pt.Size }

if ($Root -and -not $NoPartitions) {
    # ---------------- 2. 逻辑分区（内容已包含在 super 镜像中，默认不单独导出） ----------------
    if ($AllLogical -or $Only.Count) {
        $scan = 'cd /dev/block/mapper 2>/dev/null && for n in *; do [ -b "$n" ] || continue; case "$n" in userdata|*-verity|*-cow|*-cow-img|*-base|scratch|com.*) continue;; esac; b=$(readlink -f $n); echo "L $n $(blockdev --getsize64 $n) ${b##*/}"; done'
        foreach ($l in (Get-Lines $scan)) {
            if ($l -notmatch '^L (\S+) (\d+) (\S+)') { continue }
            $name = $Matches[1]; $size = [long]$Matches[2]
            if ($Only.Count -and -not ($Only -contains $name)) { continue }
            if ($excl.ContainsKey($Matches[3]) -or $Skip -contains $name) { continue }
            Backup-Block "/dev/block/mapper/$name" $name $LogiDir $size
        }
    } else { Log '逻辑分区已包含在 super 镜像里；需要单独导出每个逻辑分区请加 -AllLogical' }

    # ---------------- 3. 运行中挂载的可写分区：文件级打包 ----------------
    $scan = 'while read dev mp fs opt rest; do case "$opt" in rw*) ;; *) continue;; esac; case "$fs" in ext2|ext3|ext4|f2fs|vfat|exfat) ;; *) continue;; esac; case "$mp" in /data|/data/*|/data_mirror*|/mnt/pass_through*|/mnt/user*|/mnt/installer*|/mnt/androidwritable*|/mnt/media_rw*|/storage*) continue;; esac; [ -d "$mp" ] || continue; b=$(readlink -f $dev); echo "M ${b##*/} $mp"; done < /proc/mounts'
    $mseen = @{}
    foreach ($l in (Get-Lines $scan)) {
        if ($l -notmatch '^M (\S+) (/.*)$') { continue }
        $dev = $Matches[1]; $mp = $Matches[2]
        if ($excl.ContainsKey($dev) -or $mseen.ContainsKey($dev)) { continue }
        $leaf = $mp.Substring($mp.LastIndexOf('/') + 1)
        if ($Only.Count -and -not ($Only -contains $leaf)) { continue }
        $mseen[$dev] = 1
        $parent = $mp.Substring(0, $mp.LastIndexOf('/')); if (-not $parent) { $parent = '/' }
        Backup-Tar $parent $leaf (Join-Path $MntDir ($parent.Trim('/') -replace '/', '_')) -Live
    }
}

# ---------------- 4. 内部存储和应用数据 ----------------
if ($DoData -and $Root) {
    $ce = (Invoke-Text 'getprop sys.user.0.ce_available').Trim()
    if ($ce -eq 'false') { Add-Fail '手机尚未解锁，/data 用户数据仍是加密状态：请解锁手机后重新运行' }
    else {
        $swapTop = @{}
        foreach ($l in (Get-Lines 'tail -n +2 /proc/swaps')) { if ($l -match '^/data/([^/\s]+)') { $swapTop[$Matches[1]] = 1 } }
        Log '== 内部存储 /data/media（每个用户按目录分包）'
        foreach ($u in (Get-Entries '/data/media')) {
            if ($u -match '^\d+$') {
                foreach ($e in (Get-Entries "/data/media/$u")) { Backup-Tar "/data/media/$u" $e (Join-Path $DataDir "internal_storage\$u") -Live }
            } else { Backup-Tar '/data/media' $u (Join-Path $DataDir 'internal_storage') -Live }
        }
        Log '== 应用数据 /data（按应用 / 按目录分包，排除 media、dalvik-cache）'
        $ad = Join-Path $DataDir 'appdata'
        foreach ($e in (Get-Entries '/data')) {
            # /data/data 与 /data/user/0 是同一份数据，只备份 /data/user 下的
            if ('media', 'dalvik-cache', 'lost+found', 'data' -contains $e) { continue }
            if ($swapTop.ContainsKey($e)) { Log "跳过 /data/$e（里面是正在使用的 swap 文件）"; continue }
            if ('user', 'user_de' -contains $e) {
                foreach ($u in (Get-Entries "/data/$e")) {
                    foreach ($pkg in (Get-Entries "/data/$e/$u")) { Backup-Tar "/data/$e/$u" $pkg (Join-Path $ad "$e\$u") -Live }
                }
            } elseif ($e -eq 'app') {
                foreach ($pkg in (Get-Entries '/data/app')) { Backup-Tar '/data/app' $pkg (Join-Path $ad 'app') -Live }
            } else { Backup-Tar '/data' $e $ad -Live }
        }
    }
} elseif ($DoData) {
    Log '== 内部存储 /sdcard（未 root：不含 Android/data）'
    foreach ($e in (Get-Entries '/storage/emulated/0')) { Backup-Tar '/storage/emulated/0' $e (Join-Path $DataDir 'internal_storage\0') -Live }
    Log '== 第三方应用安装包（未 root：只有 apk，没有应用数据）'
    foreach ($l in (Get-Lines 'pm list packages -3')) {
        $pkg = $l -replace '^package:', ''
        foreach ($ap in (Get-Lines "pm path '$(Esc $pkg)'")) {
            $path = $ap -replace '^package:', ''
            $size = (Invoke-Text "stat -c %s '$(Esc $path)'").Trim()
            if ($size -notmatch '^\d+$') { Add-Fail "apk $path（读不到大小）"; continue }
            $leaf = $path.Substring($path.LastIndexOf('/') + 1) -replace '\.apk$', ''
            Backup-Block $path $leaf (Join-Path $DataDir ('apks\' + (Get-SafeName $pkg))) ([long]$size) '.apk'
        }
    }
}

if ($script:Fails.Count) {
    Log "== 结束：$($script:Fails.Count) 项未通过校验（重新运行脚本即可，已通过的部分会自动跳过）："
    foreach ($f in $script:Fails) { Log "   $f" }
    exit 1
}
Log "== 全部完成，所有项目校验通过（其中 $($script:Warns) 项为运行中变动的数据，已按完整快照接受）。建议再复制一份到另一块硬盘。"
