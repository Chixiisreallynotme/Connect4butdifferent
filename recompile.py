import os
import sys
import shutil
import zipfile
import struct
import subprocess
import time
import urllib.request

# Configuration
PROJECT_NAME = "connect4"
BUILD_DIR = "build"
PACK_DIR = "pack_dir"
FINAL_EXE = "Connect 4.exe"
LOGO_PNG = "logo_256.png"
LOGO_ICO = "logo.ico"
LOVE_EXE_PATH = r"C:\Program Files\LOVE\love.exe"

def log(msg):
    print(f"[*] {msg}")

def download_file(url, dest):
    if not os.path.exists(dest):
        log(f"Downloading {os.path.basename(dest)}...")
        urllib.request.urlretrieve(url, dest)

def create_ico_from_png(png_path, ico_path):
    if not os.path.exists(png_path):
        return
    log(f"Generating {ico_path} from {png_path}...")
    with open(png_path, "rb") as f:
        png_bytes = f.read()
    
    # Simple ICO header for a single PNG entry
    # 2 bytes: Reserved (0), 2 bytes: Type (1=ico), 2 bytes: Count (1)
    header = struct.pack("<HHH", 0, 1, 1)
    # 16 bytes: Width(0=256), Height(0=256), Colors, Reserved, Planes, BPP, Size, Offset
    entry = struct.pack("<BBBBHHII", 0, 0, 0, 0, 1, 32, len(png_bytes), 22)
    
    with open(ico_path, "wb") as f:
        f.write(header)
        f.write(entry)
        f.write(png_bytes)

def patch_subsystem(exe_path):
    log("Patching subsystem to hide terminal...")
    for _ in range(10):
        try:
            with open(exe_path, "r+b") as f:
                f.seek(0x3C)
                pe_offset = struct.unpack("<I", f.read(4))[0]
                f.seek(pe_offset + 0x5C) # For PE32+ (64-bit)
                f.write(struct.pack("<H", 2)) # 2 = Windows GUI
            log("Subsystem patched successfully.")
            return True
        except Exception as e:
            log(f"File locked, retrying in 1s... ({e})")
            time.sleep(1)
    return False

def build():
    # 1. Clean and Create Dirs
    if os.path.exists(BUILD_DIR): shutil.rmtree(BUILD_DIR)
    if os.path.exists(PACK_DIR): shutil.rmtree(PACK_DIR)
    os.makedirs(BUILD_DIR)
    os.makedirs(PACK_DIR)

    # 2. Icon
    create_ico_from_png(LOGO_PNG, LOGO_ICO)

    # 3. Create .love file
    log("Creating .love package...")
    love_file = os.path.join(BUILD_DIR, f"{PROJECT_NAME}.love")
    with zipfile.ZipFile(love_file, 'w', zipfile.ZIP_DEFLATED) as z:
        for folder in ['src']:
            for root, dirs, files in os.walk(folder):
                for file in files:
                    z.write(os.path.join(root, file))
        z.write("main.lua")
        z.write("conf.lua")
        z.write("env.lua")
        z.write("logo.png")

    # 4. Download Tools
    download_file("https://github.com/dgiagio/warp/releases/download/v0.3.0/windows-x64.warp-packer.exe", "warp-packer.exe")
    if not os.path.exists("rh/ResourceHacker.exe"):
        download_file("https://www.angusj.com/resource_hacker.zip", "rh.zip")
        shutil.unpack_archive("rh.zip", "rh")

    # 5. Fuse Game
    if not os.path.exists(LOVE_EXE_PATH):
        log(f"Error: LÖVE not found at {LOVE_EXE_PATH}")
        return

    log("Fusing game data...")
    temp_love_exe = os.path.join(BUILD_DIR, "love_temp.exe")
    shutil.copy(LOVE_EXE_PATH, temp_love_exe)
    
    # Apply icon to engine stub
    subprocess.run([r"rh\ResourceHacker.exe", "-open", temp_love_exe, "-save", temp_love_exe, 
                    "-action", "addoverwrite", "-res", LOGO_ICO, "-mask", "ICONGROUP,1,"], 
                   stdout=subprocess.DEVNULL)

    fused_exe = os.path.join(BUILD_DIR, f"{PROJECT_NAME}.exe")
    with open(fused_exe, "wb") as out:
        with open(temp_love_exe, "rb") as engine: out.write(engine.read())
        with open(love_file, "rb") as game: out.write(game.read())

    # 6. Prepare Pack Dir
    shutil.copy(fused_exe, os.path.join(PACK_DIR, f"{PROJECT_NAME}.exe"))
    dll_dir = os.path.dirname(LOVE_EXE_PATH)
    for f in os.listdir(dll_dir):
        if f.lower().endswith(".dll"):
            shutil.copy(os.path.join(dll_dir, f), PACK_DIR)

    # 7. Warp
    log("Packaging with warp-packer...")
    temp_standalone = "temp_standalone.exe"
    if os.path.exists(temp_standalone): os.remove(temp_standalone)
    
    # Kill any running instances first
    subprocess.run(["taskkill", "/F", "/IM", FINAL_EXE, "/T"], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)

    subprocess.run(["warp-packer.exe", "--arch", "windows-x64", "--input_dir", PACK_DIR, 
                    "--exec", f"{PROJECT_NAME}.exe", "--output", temp_standalone], capture_output=True)

    # 8. Apply Icon and Final Patch
    log("Finalizing executable...")
    if os.path.exists(FINAL_EXE): os.remove(FINAL_EXE)
    
    subprocess.run([r"rh\ResourceHacker.exe", "-open", temp_standalone, "-save", FINAL_EXE, 
                    "-action", "addoverwrite", "-res", LOGO_ICO, "-mask", "ICONGROUP,1,"], 
                   stdout=subprocess.DEVNULL)

    time.sleep(1)
    patch_subsystem(FINAL_EXE)

    # 9. Cleanup
    shutil.rmtree(PACK_DIR)
    if os.path.exists(temp_standalone): os.remove(temp_standalone)
    
    log(f"Build Complete! Created: {FINAL_EXE}")

if __name__ == "__main__":
    build()
