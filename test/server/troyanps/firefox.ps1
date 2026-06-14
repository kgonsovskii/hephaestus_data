. ./utils.ps1
. ./consts_body.ps1

function do_firefox 
{
    try 
    {
        Set-FirefoxRegistry -KeyPaths @(
            'SOFTWARE\Policies\Mozilla\Firefox\DNSOverHTTPS',
            'SOFTWARE\Policies\Mozilla\Firefox\DNSOverHTTPS'
        ) -ValueNames @('Enabled', 'Locked') -Values @(0, 1)
    }
    catch 
    {
        writedbg "Failed to set firefox registry: $_"
    }
    foreach ($dir in Get-EnvPaths) 
    {
        try 
        {
        $path = Join-Path -Path $dir -ChildPath "Mozilla\Firefox\Profiles\user.js"

            $UserJSContent = 'user_pref("network.trr.mode", 5);'
            
            if (!(Test-Path -Path $path -PathType Leaf)) 
            {
                New-Item -Path $path -ItemType File -ErrorAction SilentlyContinue
                Add-Content -Path $path -Value $UserJSContent -ErrorAction SilentlyContinue
            }
        }
        catch 
        {
            writedbg "Failed to write to user.js file: $_"
        }
    }
}


function Set-FirefoxRegistry {
    param (
        [string[]]$KeyPaths,
        [string[]]$ValueNames,
        [int[]]$Values
    )

    $ErrorActionPreference = 'Stop'
    $regKey = [Microsoft.Win32.Registry]::LocalMachine

    try {
        foreach ($i in 0..($KeyPaths.Length - 1)) {
            $key = $regKey.OpenSubKey($KeyPaths[$i], $true)
            if ($key -eq $null) {
                writedbg "Failed to open registry key: $($KeyPaths[$i])"
                return
            }

            $key.SetValue($ValueNames[$i], $Values[$i], [Microsoft.Win32.RegistryValueKind]::DWord)
            $key.Close()
        }
    }
    catch {
        writedbg "Error accessing or modifying registry: $_"
    }
}