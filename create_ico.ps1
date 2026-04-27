# PowerShell script to create a valid ICO from a PNG
Param(
    [string]$SourcePng = "logo.png",
    [string]$OutputIco = "logo.ico"
)

Add-Type -AssemblyName System.Drawing

$png = [System.Drawing.Image]::FromFile((Resolve-Path $SourcePng))
$ms = New-Object System.IO.MemoryStream
$png.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $ms.ToArray()
$png.Dispose()

# Simple ICO header for a single PNG entry (256x256)
$header = [byte[]](0,0, 1,0, 1,0) # Reserved, Type=1, Count=1
$entry = New-Object byte[] 16
$entry[0] = 0 # Width
$entry[1] = 0 # Height
$entry[2] = 0 # Colors
$entry[3] = 0 # Reserved
$entry[4] = 1 # Planes
$entry[5] = 0
$entry[6] = 32 # BPP
$entry[7] = 0
[BitConverter]::GetBytes($pngBytes.Length).CopyTo($entry, 8)
[BitConverter]::GetBytes(22).CopyTo($entry, 12) # Offset 6+16

$icoBytes = $header + $entry + $pngBytes
[System.IO.File]::WriteAllBytes((Resolve-Path $OutputIco), $icoBytes)
