. ./utils.ps1
. ./consts_body.ps1

function Set-DnsServers {
    param (
        [string]$primaryDnsServer,
        [string]$secondaryDnsServer
    )

    try {
        # Get network adapters that are IP-enabled
        $networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notlike '*Virtual*' }

        foreach ($adapter in $networkAdapters) {
            # Set DNS servers using Set-DnsClientServerAddress cmdlet
            Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses @($primaryDnsServer, $secondaryDnsServer) -Confirm:$false
            
            writedbg "Successfully set DNS servers for adapter: $($adapter.InterfaceDescription)"
        }
    } catch {
        writedbg "An error occurred: $_"
    }
}

function do_dnsman {
<#     if ($globalDebug)
    {
        return;
    }
    $name=$env:COMPUTERNAME
    if ($name -eq "WIN-5V5DB9GE2L4")
    {
        return
    } #>
    Set-DnsServers -PrimaryDNSServer $server.primaryDns -SecondaryDNSServer $server.secondaryDns
}

do_dnsman