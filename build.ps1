$ErrorActionPreference = "Stop"

$ProjectName = "connect4"
$BuildDir = "build"
$PackDir = "pack_dir"
$LoveFile = "$BuildDir\$ProjectName.love"
$ExeFile = "$BuildDir\$ProjectName.exe"
$FinalExe = "Connect 4.exe"
$LogoPng = "logo_256.png"
$LogoIco = "logo.ico"

Write-Host "--- Starting Build Process ---"

If (-Not (Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir | Out-Null }
If (-Not (Test-Path $PackDir)) { Remove-Item $PackDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $PackDir | Out-Null

# 1. Prepare Icon
If (Test-Path $LogoPng) {
    Write-Host "Generating icon from $LogoPng..."
    .\create_ico.ps1 -SourcePng $LogoPng -OutputIco $LogoIco
}

# 2. Create .love package
Write-Host "Creating .love package..."
If (Test-Path $LoveFile) { Remove-Item $LoveFile }
Compress-Archive -Path "main.lua", "conf.lua", "env.lua", "src", "logo.png" -DestinationPath "$BuildDir\$ProjectName.zip" -Force
Rename-Item "$BuildDir\$ProjectName.zip" "$ProjectName.love" -Force

# 3. Prepare Tools
$Rcedit = "rcedit.exe"
If (-Not (Test-Path $Rcedit)) {
    Write-Host "Downloading rcedit..."
    Invoke-WebRequest -Uri "https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe" -OutFile $Rcedit
}
$WarpPacker = "warp-packer.exe"
If (-Not (Test-Path $WarpPacker)) {
    Write-Host "Downloading warp-packer..."
    Invoke-WebRequest -Uri "https://github.com/dgiagio/warp/releases/download/v0.3.0/windows-x64.warp-packer.exe" -OutFile $WarpPacker
}
$RH_Dir = "rh"
If (-Not (Test-Path "$RH_Dir\ResourceHacker.exe")) {
    Write-Host "Downloading Resource Hacker..."
    Invoke-WebRequest -Uri "https://www.angusj.com/resource_hacker.zip" -OutFile "rh.zip"
    Expand-Archive -Path "rh.zip" -DestinationPath $RH_Dir -Force
}

# 4. Find LÖVE
$LoveExeSource = "C:\Program Files\LOVE\love.exe"
If (-Not (Test-Path $LoveExeSource)) {
    Write-Host "Error: LÖVE not found at $LoveExeSource"
    Exit
}

# 5. Fuse Game
Write-Host "Fusing game data..."
$LoveExeTemp = "$BuildDir\love_temp.exe"
Copy-Item $LoveExeSource -Destination $LoveExeTemp -Force

# Apply icon to the engine stub using RH (safer than rcedit)
& ".\$RH_Dir\ResourceHacker.exe" -open $LoveExeTemp -save $LoveExeTemp -action addoverwrite -res $LogoIco -mask ICONGROUP,1,

cmd /c "copy /b `"$LoveExeTemp`"+`"$LoveFile`" `"$ExeFile`" >nul"

# 6. Prepare Pack Directory
Write-Host "Preparing pack directory..."
Copy-Item $ExeFile -Destination "$PackDir\$ProjectName.exe" -Force
$DllSource = Split-Path $LoveExeSource
Get-ChildItem -Path $DllSource -Filter "*.dll" | Copy-Item -Destination $PackDir -Force

# 7. Package with Warp
Write-Host "Packaging with warp-packer..."
$TempStandalone = "temp_standalone.exe"
If (Test-Path $TempStandalone) { Remove-Item $TempStandalone }
# Use Start-Process with -Wait to ensure it finishes
Start-Process -FilePath ".\$WarpPacker" -ArgumentList "--arch windows-x64 --input_dir $PackDir --exec `"$ProjectName.exe`" --output $TempStandalone" -Wait -NoNewWindow
Start-Sleep -Seconds 2

# 8. Patch Subsystem (Console -> GUI)
Write-Host "Patching subsystem to hide terminal..."
If (Test-Path $TempStandalone) {
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $TempStandalone))
    $peOffset = [BitConverter]::ToUInt32($bytes, 0x3C)
    $subsystemOffset = $peOffset + 0x5C # For PE32+ (64-bit)
    $bytes[$subsystemOffset] = 2 # 2 = Windows GUI
    $bytes[$subsystemOffset + 1] = 0
    [System.IO.File]::WriteAllBytes((Resolve-Path $TempStandalone), $bytes)
    Write-Host "Subsystem patched successfully."
}

# 9. Apply Icon to Final EXE
Write-Host "Applying icon to final executable..."
If (Test-Path $TempStandalone) {
    & ".\$RH_Dir\ResourceHacker.exe" -open $TempStandalone -save $FinalExe -action addoverwrite -res $LogoIco -mask "ICONGROUP,1,"
}

# 10. Patch Final Subsystem (Retry until unlocked)
Write-Host "Applying final terminal-hide patch..."
$patched = $false
for ($i = 0; $i -lt 10; $i++) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $FinalExe))
        $peOffset = [BitConverter]::ToUInt32($bytes, 0x3C)
        $subsystemOffset = $peOffset + 0x5C
        $bytes[$subsystemOffset] = 2
        $bytes[$subsystemOffset + 1] = 0
        [System.IO.File]::WriteAllBytes((Resolve-Path $FinalExe), $bytes)
        $patched = $true
        Write-Host "Subsystem patched successfully on attempt $($i+1)."
        break
    } catch {
        Write-Host "File locked, retrying in 1s..."
        Start-Sleep -Seconds 1
    }
}

# 11. Cleanup
If (Test-Path $PackDir) { Remove-Item $PackDir -Recurse -Force }
If (Test-Path $LoveExeTemp) { Remove-Item $LoveExeTemp -Force }
If (Test-Path $TempStandalone) { Remove-Item $TempStandalone -Force -ErrorAction SilentlyContinue }
If (Test-Path "rh.log") { Remove-Item "rh.log" }

Write-Host "--- Build Complete: $FinalExe ---"
