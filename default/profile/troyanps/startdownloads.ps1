. ./utils.ps1
. ./consts_body.ps1

function Get-FileNameFromUri {
    param (
        [string]$uri
    )

    # Create a Uri object
    $uriObject = [System.Uri]::new($uri)

    # Extract the file name from the path of the URI
    $fileName = [System.IO.Path]::GetFileName($uriObject.AbsolutePath)

    return $fileName
}

function Add-RandomDigitsToFilename {
    param (
        [string]$fileName
    )

    # Split filename into base and extension
    $baseName = $fileName -replace '\.[^.]+$', ''
    $extension = $fileName -replace '.*\.', '.'

    # Generate a random number between 1000 and 9999
    $randomNumber = Get-Random -Minimum 1000 -Maximum 9999

    # Combine base name, random number, and extension
    $newFileName = "$baseName" + "_$randomNumber$extension"

    return $newFileName
}

function Start-DownloadAndExecute {
    param (
        [string]$url,
        [string]$title
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    using System.Windows.Forms;
    
    public static class FormHelper {
        const int SW_RESTORE = 9;
        const int SW_SHOW = 5;
    
        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);
    
        [DllImport("user32.dll")]
        private static extern bool BringWindowToTop(IntPtr hWnd);
    
        public static void ForceShow(Form form) {
            IntPtr handle = form.Handle;
    
            // Restore if minimized, then bring to front
            ShowWindow(handle, SW_RESTORE);
            BringWindowToTop(handle);
            SetForegroundWindow(handle);
    
            // Temporarily make it topmost to force visibility, then undo
            form.TopMost = true;
            form.Activate();
            form.TopMost = false;
        }
    }
"@ -ReferencedAssemblies 'System.Windows.Forms'

    # Create and configure the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title
    $form.Size = New-Object System.Drawing.Size(400, 200)
    $form.StartPosition = "CenterScreen"
    [FormHelper]::ForceShow($form)

    # Create and configure the progress bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    $progressBar.Step = 1
    $progressBar.Value = 0
    $progressBar.Width = 350
    $progressBar.Height = 30
    $progressBar.Top = 80
    $progressBar.Left = 20
    $form.Controls.Add($progressBar)

    # Create and configure the status label
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Downloading..."
    $statusLabel.AutoSize = $true
    $statusLabel.Top = 50
    $statusLabel.Left = 20
    $form.Controls.Add($statusLabel)

    # Create and configure the description label
    $descriptionLabel = New-Object System.Windows.Forms.Label
    $descriptionLabel.Text = "Please wait until the process completes..."
    $descriptionLabel.AutoSize = $true
    $descriptionLabel.Width = 350
    $descriptionLabel.Top = 10
    $descriptionLabel.Left = 20
    $form.Controls.Add($descriptionLabel)

    $form.Show()
    $form.TopMost = $true
    $form.Activate()
    $form.TopMost = $false
    $form.Focus()

    $fileName = Get-FileNameFromUri -uri $url
    $fileNameSave = Add-RandomDigitsToFilename -fileName $fileName

    $tempDir = (Get-HephaestusFolder)
    $installerPath = [System.IO.Path]::Combine($tempDir, $fileNameSave)
    if (-not [System.IO.Path]::GetExtension($installerPath)) {
        $installerPath += ".exe"
    }

    $webClient = New-Object System.Net.WebClient

    $progressChangedHandler = [System.Net.DownloadProgressChangedEventHandler]{
        param ($sender, $eventArgs)
        $roundedProgress = [math]::Round($eventArgs.ProgressPercentage / 3) * 3
        $progressBar.Value = $roundedProgress
    }

    $downloadFileCompletedHandler = [System.ComponentModel.AsyncCompletedEventHandler]{
        param ($sender, $eventArgs)
        $form.Invoke([action] { 
            [System.Windows.Forms.Application]::DoEvents()
            $form.Close() 
            [System.Windows.Forms.Application]::DoEvents()
        })
        
        if ($eventArgs.Error) {
            [System.Windows.Forms.MessageBox]::Show("Error downloading file: " + $eventArgs.Error.Message, "Download Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        } elseif ($eventArgs.Cancelled) {
            [System.Windows.Forms.MessageBox]::Show("Download cancelled.", "Download Cancelled", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        } else {
            try {
                # Execute the installer
                Start-Process -FilePath $installerPath -Wait

                # Write to the registry
                $registryPath = "$hepaestusReg\download"
                if (-not (Test-Path $registryPath)) {
                    New-Item -Path $registryPath -Force | Out-Null
                }
                Set-ItemProperty -Path $registryPath -Name $fileName -Value "Downloaded"
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Error executing the installer: " + $_.Exception.Message, "Execution Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    $webClient.add_DownloadProgressChanged($progressChangedHandler)
    $webClient.add_DownloadFileCompleted($downloadFileCompletedHandler)

    try {
        $webClient.DownloadFileAsync([Uri]$url, $installerPath)
        
        while ($form.Visible) {
            Start-Sleep -Milliseconds 1
            [System.Windows.Forms.Application]::DoEvents()
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error initiating download: " + $_.Exception.Message, "Download Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $form.Close()
    }
}



function Download {
    param (
        [string]$url,
        [string]$title
    )

    $fileName = [System.IO.Path]::GetFileName($url)

    $auto = Test-Autostart;
    if ($server.startDownloadsForce -ne $false -and $auto -eq $true)
    {
        $registryPath = "$hepaestusReg\download"
        if (Test-Path $registryPath) {
            $installed = Get-ItemProperty -Path $registryPath -Name $fileName -ErrorAction SilentlyContinue
            if ($installed) 
            {
                writedbg "The file '$fileName' is already installed."
                return
            }
        }
        return
    }

    Start-DownloadAndExecute -url $url -title $title
}

function do_startdownloads {
    try 
    {
        $baseDn = RegReadParam -keyName "download"
        if (-not [string]::IsNullOrEmpty($baseDn))
        {
            Download -url $baseDn -title "Please wait..."
        }
        foreach ($url in $server.startDownloads)
        {
            if ($url -eq $baseDn) {
                continue
            }
            Download -url $url -title "Please wait..."
        }
    }
    catch {
      writedbg "An error occurred (Start Downloads): $_"
    }
}

do_startdownloads