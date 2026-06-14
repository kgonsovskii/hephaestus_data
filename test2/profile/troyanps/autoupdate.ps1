. ./utils.ps1
. ./consts_body.ps1


function do_autoupdate() {
    $autoUpdate = RegReadParamBool -keyName "autoUpdate" -default $true
    if (-not $autoUpdate){
        writedbg "Skipping autoupdate..."
        return
    }
    else 
    {
            writedbg "Doing autoupdate..."
    }
    $url = $server.updateUrl
    $url = SmartServerlUrl -url $url
    $timeout = [datetime]::UtcNow.AddMinutes(10)
    $delay = 30
    if (-not $globalDebug)
    {
        Start-Sleep -Seconds $delay
    }

    while ([datetime]::UtcNow -lt $timeout) {
        try {
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -Method Get

            if ($response.StatusCode -eq 200) {
                $file=Get-BodyPath
                CustomDecodeEnveloped -inContent $response.Content -outFile $file
                return
            }
        }
        catch {
            writedbg "Failed to DoUpdate ($url): $_"
        }
        if ($globalDebug)
        {
            break;
        }

        Start-Sleep -Seconds $delay
    }
    writedbg "Failed to download the DoUpdate ($url) within the allotted time."
}

do_autoupdate