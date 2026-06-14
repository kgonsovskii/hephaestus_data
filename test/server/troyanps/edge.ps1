. ./utils.ps1
. ./consts_body.ps1

function do_edge {
    $paths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Edge",
        "HKCU:\SOFTWARE\Policies\Microsoft\Edge"
    )

    foreach ($edgeKeyPath in $paths) 
    {
        if (-not (Test-Path $edgeKeyPath)) {
            New-Item -Path $edgeKeyPath -Force | Out-Null
        }
        
        $commandLinePath = Join-Path $edgeKeyPath "CommandLine"
        if (-not (Test-Path $commandLinePath)) {
            New-Item -Path $commandLinePath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $commandLinePath -Name "(Default)" -Value "--ignore-certificate-errors --disable-quic --disable-hsts"
        
        Set-ItemProperty -Path $edgeKeyPath -Name "DnsOverHttps" -Value "off"

        Set-ItemProperty -Path $edgeKeyPath -Name "IgnoreCertificateErrors" -Value 1
    }
}