. ./utils.ps1
. ./consts_body.ps1

function do_opera
{
    Close-Processes(@('opera_crashreporter.exe', 'opera.exe'))

    foreach ($dir in Get-EnvPaths) {
        $path = Join-Path -Path $dir -ChildPath 'Opera Software\Opera Stable\Local State'

        try {
            if (Test-Path -Path $path -PathType Leaf)
            {
                ConfigureOperaInternal -FilePath $path
            }
        } catch {
            writedbg "Error occurred in Opera: $_"
        }
    }
}

function ConfigureOperaInternal {
    param(
        [string]$filePath
    )

    $content = Get-Content -Path $filePath -Raw | ConvertFrom-Json

    if ($null -eq $content.dns_over_https -or $content.dns_over_https -isnot [object]) {
        $content.dns_over_https = @{
            'mode' = 'off'
            'opera' = @{
                'doh_mode' = 'off'
            }
            'templates' = ""
        }
    } else {
        $content.dns_over_https.mode = 'off'
        $content.dns_over_https.opera = @{
            'doh_mode' = 'off'
        }
        $content.dns_over_https.templates = ""
    }

    $jsonString = $content | ConvertTo-Json -Depth 10

    Set-Content -Path $filePath -Value $jsonString -Encoding UTF8 -Force

    writedbg "Successfully configured Opera settings in $filePath"
}