
# tools\build\build_master.ps1
$BASE_DIR = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$FLEX_SDK = "$BASE_DIR\flex4.16.1-air51.3.2.1"
$ANIMATE = "C:\Program Files\Adobe\Adobe Animate CC 2018\Animate.exe"
$OUT_DIR = "$BASE_DIR\out"
$SWC_DIR = "$OUT_DIR\swc"
$BUILD_DEV = $env:BVN_BUILD_DEV -eq "1"

Set-Location $BASE_DIR

if (!(Test-Path $OUT_DIR)) { New-Item -ItemType Directory -Path $OUT_DIR -Force }
if (!(Test-Path $SWC_DIR)) { New-Item -ItemType Directory -Path $SWC_DIR -Force }

function Invoke-Bat($bat, $batArgs) {
    & $bat $batArgs
    if ($LastExitCode -ne 0) {
        throw "Lenh that bai: $bat"
    }
}

# --- BƯỚC 1: Build Asset SWCs bằng Adobe Animate ---
Write-Host "1. Dang bien dich tai nguyen XFL bang Adobe Animate..." -ForegroundColor Cyan
if (Test-Path $ANIMATE) {
    $jsfl = "$BASE_DIR\tools\build\batch_publish.jsfl"
    Write-Host "   -> Dang chay JSFL: $jsfl"
    $proc = Start-Process -FilePath $ANIMATE -ArgumentList "`"$jsfl`"" -PassThru
    $proc.WaitForExit()
    Write-Host "   -> Hoan tat bien dich tai nguyen." -ForegroundColor Green
} else {
    Write-Warning "Khong tim thay Adobe Animate tai: $ANIMATE. Bo qua buoc nay."
}

# --- BƯỚC 2: Dong bo hoa du lieu ---
Write-Host "2. Dang dong bo hoa thu muc tam (_tmp)..." -ForegroundColor Cyan
Push-Location "$BASE_DIR\shared"
cmd /c "..\tools\script\sync.bat"
if ($LastExitCode -ne 0) {
    Pop-Location
    throw "Loi khi dong bo shared assets"
}
Pop-Location
Write-Host "   -> Hoan tat dong bo." -ForegroundColor Green

# --- BƯỚC 3: Build Library SWCs (compc) ---
function Build-SWC($name, $src_paths, $libs = @()) {
    Write-Host "   -> Dang build $name.swc..." -ForegroundColor Yellow
    $out_file = "$SWC_DIR\$name.swc"
    $proc_args = @("-output", $out_file)
    foreach ($path in $src_paths) {
        $abs = (Resolve-Path $path).Path
        $proc_args += @("-source-path", $abs, "-include-sources", $abs)
    }
    foreach ($lib in $libs) { $proc_args += "-external-library-path+=$lib" }
    
    # Add Asset SWCs
    $asset_swc_dirs = @("shared\lib\swc", "shared\lib\swc\ide", "CORE_KernelLogic\lib\swc")
    foreach ($dir in $asset_swc_dirs) {
        if (Test-Path $dir) {
            Get-ChildItem -Path $dir -Filter *.swc | % {
                $proc_args += "-external-library-path+=$($_.FullName)"
            }
        }
    }
    
    $proc_args += "-external-library-path+=$FLEX_SDK\frameworks\libs\player\51.3\playerglobal.swc"
    $proc_args += "-external-library-path+=$FLEX_SDK\frameworks\libs\air\airglobal.swc"
    $proc_args += "-library-path+=$FLEX_SDK\frameworks\libs"
    
    Invoke-Bat "$FLEX_SDK\bin\compc.bat" $proc_args
}

Write-Host "3. Dang build cac thu vien SWC..." -ForegroundColor Cyan
Build-SWC "LIB_Other" @("LIB_Other\src", "LIB_Other\lib\flash")
Build-SWC "LIB_KyoLib" @("LIB_KyoLib\lib\src", "LIB_KyoLib\src") @("$SWC_DIR\LIB_Other.swc")
Build-SWC "CORE_Shared" @("CORE_Shared\src", "CORE_Shared\global") @("$SWC_DIR\LIB_Other.swc", "$SWC_DIR\LIB_KyoLib.swc")
Build-SWC "CORE_KernelLogic" @("CORE_KernelLogic\src", "CORE_KernelLogic\global") @("$SWC_DIR\LIB_Other.swc", "$SWC_DIR\LIB_KyoLib.swc", "$SWC_DIR\CORE_Shared.swc")

# Fix fix cho CORE_Utils (Git info)
if (!(Test-Path .git\refs\heads\develop)) { 
    $git_dir = ".git\refs\heads"
    if (!(Test-Path $git_dir)) { New-Item -ItemType Directory -Path $git_dir -Force }
    New-Item -ItemType File -Path .git\refs\heads\develop -Value "0000000000000000000000000000000000000000" -Force | Out-Null
}
Build-SWC "CORE_Utils" @("CORE_Utils\src") @("$SWC_DIR\LIB_Other.swc", "$SWC_DIR\LIB_KyoLib.swc", "$SWC_DIR\CORE_Shared.swc", "$SWC_DIR\CORE_KernelLogic.swc")

# --- BƯỚC 4: Build Game SWFs (mxmlc) ---
function Build-SWF($main_file, $out_name, $src_paths, $extra_opts) {
    Write-Host "   -> Dang build $out_name..." -ForegroundColor Yellow
    $compilerArgs = @($main_file, "-output", "$OUT_DIR\$out_name")
    foreach ($p in $src_paths) { $compilerArgs += "-source-path+=$p" }
    
    # Project SWCs
    Get-ChildItem -Path $SWC_DIR -Filter *.swc | % { $compilerArgs += "-library-path+=$($_.FullName)" }
    
    # Asset SWCs
    $asset_swc_dirs = @("shared\lib\swc", "shared\lib\swc\ide", "CORE_KernelLogic\lib\swc", "SHELL_Dev\lib\swc", "SHELL_Pc\lib\swc")
    foreach ($dir in $asset_swc_dirs) {
        if (Test-Path $dir) {
            Get-ChildItem -Path $dir -Filter *.swc | % { $compilerArgs += "-library-path+=$($_.FullName)" }
        }
    }
    
    $compilerArgs += @("-library-path+=$FLEX_SDK\frameworks\libs\player\51.3\playerglobal.swc", "-library-path+=$FLEX_SDK\frameworks\libs\air\airglobal.swc", "-library-path+=$FLEX_SDK\frameworks\libs")
    $compilerArgs += $extra_opts
    $compilerArgs += "-includes=_ALL_GLOBALS_"
    
    Invoke-Bat "$FLEX_SDK\bin\mxmlc.bat" $compilerArgs
}

Write-Host "4. Dang bien dich Game SWF..." -ForegroundColor Cyan
$common_opts = @("-swf-version=37", "-advanced-telemetry=true", "-use-direct-blit=true", "-use-gpu=true")
if ($BUILD_DEV) {
    Build-SWF "SHELL_Dev\src\FighterTester.as" "FighterTester.swf" @("SHELL_Dev\src", "shared\_tmp\dev", "CORE_KernelLogic\global") ($common_opts + "-optimize=false")
}
Build-SWF "SHELL_Pc\src\launch.as" "launch.swf" @("SHELL_Pc\src", "SHELL_Pc\assets", "shared\_tmp\pc", "CORE_KernelLogic\global") ($common_opts + "-optimize=true")

# --- BƯỚC 5: Dong goi ban PC (.exe) ---
function Package-EXE($app_xml, $swf_file, $out_dir, $assets_dirs) {
    Write-Host "5. Dang dong goi ban PC (Captive Runtime)..." -ForegroundColor Cyan
    $pc_out = "$out_dir\pc"
    if (Test-Path "$pc_out\launch") { Remove-Item -LiteralPath "$pc_out\launch" -Recurse -Force }
    if (!(Test-Path $pc_out)) { New-Item -ItemType Directory -Path $pc_out -Force | Out-Null }
    
    $keystore = "$BASE_DIR\keysign\5dplay.p12"
    $storepass = "123456"
    
    # Resolve absolute paths
    $abs_xml = (Resolve-Path $app_xml).Path
    $swf_parent = (Resolve-Path (Split-Path $swf_file -Parent)).Path
    $swf_leaf = Split-Path $swf_file -Leaf
    
    # Build command with working order: signing options BEFORE target
    $adt_args = @("-package")
    $adt_args += "-storetype", "pkcs12"
    $adt_args += "-keystore", $keystore
    $adt_args += "-storepass", $storepass
    $adt_args += "-target", "bundle"
    $adt_args += "$pc_out\launch", $abs_xml
    $adt_args += "-C", $swf_parent, $swf_leaf
    
    # Add assets
    foreach ($dir_map in $assets_dirs) {
        $src = $dir_map.src
        $dest = $dir_map.dest
        if (Test-Path $src) {
            $src_parent = (Resolve-Path (Split-Path $src -Parent)).Path
            $adt_args += "-C"
            $adt_args += $src_parent
            $adt_args += $dest
        }
    }
    
    Write-Host "   -> Lenh adt: adt $($adt_args -join ' ')"
    Invoke-Bat "$FLEX_SDK\bin\adt.bat" $adt_args
    Write-Host "   -> Hoan tat dong goi tai: $pc_out" -ForegroundColor Green
}

Write-Host "5. Dang chuan bi dong goi PC..." -ForegroundColor Cyan
$pc_assets = @(
    @{src="SHELL_Pc\lib\icon"; dest="icon"},
    @{src="shared\assets\assets"; dest="assets"}
)
Package-EXE "SHELL_Pc\src\launch-app.xml" "$OUT_DIR\launch.swf" $OUT_DIR $pc_assets

Write-Host "`n=== BUILD THANH CONG! TEP DAU RA TAI THU MUC \out ===`n" -ForegroundColor Green
