#Requires -Version 5.1
<#
.SYNOPSIS
  Doomsday Client Scanner (USN Journal / Prefetch) — bloody UI restyle.
  by DEABLOV111
#>

$esc = [char]27

function Enable-AnsiConsole {
    try {
        Add-Type -ErrorAction Stop -Namespace Native -Name ConsoleVT -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError=true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
        $h = [Native.ConsoleVT]::GetStdHandle(-11)
        $mode = [uint32]0
        if ([Native.ConsoleVT]::GetConsoleMode($h, [ref]$mode)) {
            [void][Native.ConsoleVT]::SetConsoleMode($h, ($mode -bor 0x0004))
        }
    }
    catch {}
}

function Write-Ansi([string]$Text) { [Console]::Write($Text) }

function Show-Banner {
    Enable-AnsiConsole

    $sh  = "$esc[38;2;60;0;0m"
    $mid = "$esc[38;2;120;0;0m"
    $bld = "$esc[38;2;190;8;8m"
    $hot = "$esc[38;2;255;40;40m"
    $drip= "$esc[38;2;140;0;0m"
    $rst = "$esc[0m"
    $dim = "$esc[38;2;70;70;70m"

    $art = @(
        '██████╗ ███████╗ █████╗ ██████╗ ██╗      ██████╗ ██╗   ██╗ ██╗ ██╗ ██╗',
        '██╔══██╗██╔════╝██╔══██╗██╔══██╗██║     ██╔═══██╗██║   ██║███║███║███║',
        '██║  ██║█████╗  ███████║██████╔╝██║     ██║   ██║██║   ██║╚██║╚██║╚██║',
        '██║  ██║██╔══╝  ██╔══██║██╔══██╗██║     ██║   ██║╚██╗ ██╔╝ ██║ ██║ ██║',
        '██████╔╝███████╗██║  ██║██████╔╝███████╗╚██████╔╝ ╚████╔╝  ██║ ██║ ██║',
        '╚═════╝ ╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝ ╚═════╝   ╚═══╝   ╚═╝ ╚═╝ ╚═╝'
    )

    Write-Host ''
    foreach ($line in $art) { Write-Ansi ("  $sh$line$rst`n") }
    Write-Ansi ("$esc[$($art.Count)A")
    $i = 0
    foreach ($line in $art) {
        $color = if ($i -lt 2) { $hot } elseif ($i -lt 4) { $bld } else { $mid }
        Write-Ansi ("$color$line$rst`n")
        $i++
    }

    Write-Ansi ("$drip  ║     ║          ║    ║║          ║       ║║         ║  ║  ║$rst`n")
    Write-Ansi ("$drip  ┘     ┘          ░    ░░     ▄    ▕       ░░         ▕  ▕  ▕$rst`n")

    $tag = 'by DEABLOV111'
    Write-Ansi ("$sh  $tag$rst`n")
    Write-Ansi ("$esc[1A$hot$tag$rst  $dim Doomsday Client Scanner$rst`n")
    Write-Host ''
    Write-Ansi ("$dim  USN Journal / Prefetch forensics$rst`n")
    Write-Host ("  {0}" -f ('═' * 64)) -ForegroundColor DarkRed
    Write-Host ''
}

function Write-Section([string]$Text) {
    $c = "$esc[38;2;220;40;40m"
    $g = "$esc[38;2;90;90;90m"
    $w = "$esc[38;2;220;220;220m"
    $rst = "$esc[0m"
    $line = '─' * [Math]::Max(8, (58 - $Text.Length))
    Write-Host ''
    Write-Ansi ("$g┌─$c▓$rst $w$Text$rst $g$line$rst`n")
}

function Write-BloodOk([string]$Text)   { Write-Host "[+] $Text" -ForegroundColor Green }
function Write-BloodWarn([string]$Text) { Write-Host "[!] $Text" -ForegroundColor Yellow }
function Write-BloodFail([string]$Text) { Write-Host "[-] $Text" -ForegroundColor Red }
function Write-BloodInfo([string]$Text) { Write-Host "[*] $Text" -ForegroundColor DarkGray }

function Write-BloodFoot {
    Write-Host ''
    Write-Host ("  {0}" -f ('═' * 64)) -ForegroundColor DarkRed
    Write-Ansi ("  $esc[38;2;60;0;0m  by DEABLOV111$esc[0m`n")
    Write-Ansi ("$esc[1A  $esc[38;2;255;40;40mby DEABLOV111$esc[0m$esc[38;2;90;90;90m  Doomsday detector$esc[0m`n")
    Write-Host ''
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Global debug flag
$script:DebugMode = $false
$script:CheckUSN = $true

# Cache for USN journal data
$script:RecentDeletions = @{}
$script:USNSearched = $false

function Get-NTFSDrives {
    $ntfsDrives = @()
    
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' }
    
    foreach ($drive in $drives) {
        try {
            $driveLetter = $drive.Root.Substring(0, 2)
            
            # Check if drive is NTFS
            $volume = Get-Volume -DriveLetter $driveLetter[0] -ErrorAction SilentlyContinue
            
            if ($volume -and $volume.FileSystem -eq 'NTFS') {
                $ntfsDrives += $driveLetter[0]
            }
        }
        catch {
            # Skip drives that can't be accessed
            continue
        }
    }
    
    return $ntfsDrives
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class NtdllDecompressor {
    [DllImport("ntdll.dll")]
    public static extern uint RtlDecompressBufferEx(
        ushort CompressionFormat,
        byte[] UncompressedBuffer,
        int UncompressedBufferSize,
        byte[] CompressedBuffer,
        int CompressedBufferSize,
        out int FinalUncompressedSize,
        IntPtr WorkSpace
    );
    
    [DllImport("ntdll.dll")]
    public static extern uint RtlGetCompressionWorkSpaceSize(
        ushort CompressionFormat,
        out uint CompressBufferWorkSpaceSize,
        out uint CompressFragmentWorkSpaceSize
    );
    
    public static byte[] Decompress(byte[] compressed) {
        if (compressed.Length < 8) return null;
        if (compressed[0] != 0x4D || compressed[1] != 0x41 || compressed[2] != 0x4D) {
            return null;
        }
        
        int uncompSize = BitConverter.ToInt32(compressed, 4);
        
        uint wsComp, wsFrag;
        if (RtlGetCompressionWorkSpaceSize(4, out wsComp, out wsFrag) != 0) return null;
        
        IntPtr workspace = Marshal.AllocHGlobal((int)wsFrag);
        byte[] result = new byte[uncompSize];
        
        try {
            int finalSize;
            byte[] compData = new byte[compressed.Length - 8];
            Array.Copy(compressed, 8, compData, 0, compData.Length);
            
            uint status = RtlDecompressBufferEx(4, result, uncompSize, 
                compData, compData.Length, out finalSize, workspace);
            
            if (status != 0) return null;
            return result;
        }
        finally {
            Marshal.FreeHGlobal(workspace);
        }
    }
}
"@

function Get-RecentDeletionsFromUSN {
    param(
        [string[]]$DriveLetters,
        [int]$MinutesBack = 30
    )
    
    if ($script:USNSearched) {
        return $script:RecentDeletions
    }
    
    $allRecentActivity = @{}
    
    foreach ($driveLetter in $DriveLetters) {
        try {
            Write-BloodInfo ("Scanning drive {0}: for recent file activity (last {1} minutes)..." -f $driveLetter, $MinutesBack)
            
            $cutoffTime = (Get-Date).AddMinutes(-$MinutesBack)
            
            # Run fsutil to get USN journal
            $usnOutput = & fsutil usn readjournal "$driveLetter`:" 2>$null
            
            if ($LASTEXITCODE -ne 0) {
                Write-BloodWarn ("Unable to read USN Journal on drive {0}: (may be disabled)" -f $driveLetter)
                continue
            }
            
            $totalLines = $usnOutput.Count
            
            if ($totalLines -eq 0) {
                Write-BloodWarn ("No USN Journal data on drive {0}:" -f $driveLetter)
                continue
            }
            
            $recentActivity = @{}
            $activityCount = 0
            $currentFile = ""
            $currentTime = $null
            $currentReason = ""
            $entriesProcessed = 0
            
            foreach ($line in $usnOutput) {
                # Skip empty lines
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                
                # Look for "File name" line (with variable spacing)
                if ($line -match 'File name\s+:\s*(.+)$') {
                    $currentFile = $Matches[1].Trim()
                }
                # Look for "Time stamp" line (with variable spacing)
                elseif ($line -match 'Time stamp\s+:\s*(.+)$') {
                    $timeStr = $Matches[1].Trim()
                    try {
                        $currentTime = [DateTime]::Parse($timeStr)
                    } catch {
                        $currentTime = $null
                    }
                }
                # Look for "Reason" line - accept ANY reason
                elseif ($line -match 'Reason\s+:\s*(.+)$') {
                    $entriesProcessed++
                    $currentReason = $Matches[1].Trim()
                    
                    # Check if this entry is within our time window (ANY reason)
                    if ($currentFile -and $currentTime -and $currentTime -gt $cutoffTime) {
                        # Store with drive letter prefix to avoid collisions
                        $fullKey = "$driveLetter`:\$currentFile"
                        
                        # If file appears multiple times, keep the most recent
                        if (-not $recentActivity.ContainsKey($fullKey) -or 
                            $recentActivity[$fullKey].Timestamp -lt $currentTime) {
                            
                            $recentActivity[$fullKey] = @{
                                Timestamp = $currentTime
                                Reason = $currentReason
                                Drive = $driveLetter
                            }
                            
                            $activityCount++
                        }
                    }
                    
                    # Reset for next entry
                    $currentFile = ""
                    $currentTime = $null
                    $currentReason = ""
                }
            }
            
            Write-BloodOk ("Drive {0}: - Found {1} files with recent activity" -f $driveLetter, $activityCount)
            
            # Merge into overall activity
            foreach ($key in $recentActivity.Keys) {
                $allRecentActivity[$key] = $recentActivity[$key]
            }
            
        }
        catch {
            Write-BloodWarn ("Error reading USN Journal on drive {0}: - {1}" -f $driveLetter, $_)
            continue
        }
    }
    
    $script:RecentDeletions = $allRecentActivity
    $script:USNSearched = $true
    
    Write-BloodOk ("Total unique files with recent activity across all drives: {0}" -f $allRecentActivity.Count)
    
    return $allRecentActivity
}

function Test-RecentlyDeleted {
    param(
        [string]$FilePath
    )
    
    # Try full path match first
    if ($script:RecentDeletions.ContainsKey($FilePath)) {
        return $script:RecentDeletions[$FilePath]
    }
    
    # Try just filename
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    
    # Check if any key ends with this filename
    foreach ($key in $script:RecentDeletions.Keys) {
        if ($key -like "*\$fileName") {
            return $script:RecentDeletions[$key]
        }
    }
    
    return $null
}

function Get-PrefetchVersion {
    param([byte[]]$data)
    
    if ($data.Length -lt 8) { return 0 }
    
    # Check for SCCA signature at offset 4
    $sig = [System.Text.Encoding]::ASCII.GetString($data, 4, 4)
    if ($sig -ne "SCCA") { return 0 }
    
    # Version is at offset 0
    $version = [BitConverter]::ToUInt32($data, 0)
    return $version
}

function Get-SystemIndexes {
    param([string]$FilePath)
    
    try {
        $data = [System.IO.File]::ReadAllBytes($FilePath)
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] File: $([System.IO.Path]::GetFileName($FilePath))" -ForegroundColor Magenta
            Write-Host "  [DEBUG] Raw size: $($data.Length) bytes" -ForegroundColor Magenta
        }
        
        $isCompressed = ($data[0] -eq 0x4D -and $data[1] -eq 0x41 -and $data[2] -eq 0x4D)
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Compressed: $isCompressed" -ForegroundColor Magenta
        }
        
        if ($isCompressed) {
            $data = [NtdllDecompressor]::Decompress($data)
            if ($data -eq $null) {
                Write-Warning "Failed to decompress: $FilePath"
                return @()
            }
            
            if ($script:DebugMode) {
                Write-Host "  [DEBUG] Decompressed size: $($data.Length) bytes" -ForegroundColor Magenta
            }
        }
        
        # Validate minimum size
        if ($data.Length -lt 108) {
            Write-Warning "File too small after decompression: $FilePath"
            return @()
        }
        
        # Get prefetch version
        $version = Get-PrefetchVersion -data $data
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Prefetch version: $version" -ForegroundColor Magenta
        }
        
        $sig = [System.Text.Encoding]::ASCII.GetString($data, 4, 4)
        if ($sig -ne "SCCA") {
            Write-Warning "Invalid file signature: $FilePath (got: $sig)"
            return @()
        }
        
        # Handle different prefetch versions
        # Version 17 = XP/2003, 23 = Vista/7, 26 = Win8.1, 30 = Win10, 31 = Win11
        $stringsOffset = 0
        $stringsSize = 0
        
        switch ($version) {
            17 {
                # Windows XP/2003
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
            23 {
                # Windows Vista/7
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
            26 {
                # Windows 8.1
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
            30 {
                # Windows 10
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
            31 {
                # Windows 11
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
            default {
                Write-Warning "Unknown prefetch version $version for: $FilePath"
                # Try default offsets anyway
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
        }
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Strings offset: $stringsOffset" -ForegroundColor Magenta
            Write-Host "  [DEBUG] Strings size: $stringsSize" -ForegroundColor Magenta
        }
        
        # Validate offsets
        if ($stringsOffset -eq 0 -or $stringsSize -eq 0) {
            Write-Warning "Invalid string section offsets: $FilePath"
            return @()
        }
        
        if ($stringsOffset -ge $data.Length -or ($stringsOffset + $stringsSize) -gt $data.Length) {
            Write-Warning "String section out of bounds: $FilePath (offset: $stringsOffset, size: $stringsSize, data: $($data.Length))"
            return @()
        }
        
        $filenames = @()
        $pos = $stringsOffset
        $endPos = $stringsOffset + $stringsSize
        
        while ($pos -lt $endPos -and $pos -lt $data.Length - 2) {
            $nullPos = $pos
            while ($nullPos -lt $data.Length - 1) {
                if ($data[$nullPos] -eq 0 -and $data[$nullPos + 1] -eq 0) {
                    break
                }
                $nullPos += 2
            }
            
            if ($nullPos -gt $pos) {
                $strLen = $nullPos - $pos
                if ($strLen -gt 0 -and $strLen -lt 2048) {
                    try {
                        $filename = [System.Text.Encoding]::Unicode.GetString($data, $pos, $strLen)
                        if ($filename.Length -gt 0) {
                            $filenames += $filename
                        }
                    }
                    catch { }
                }
            }
            
            $pos = $nullPos + 2
            
            if ($filenames.Count -gt 1000) { break }
        }
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Extracted $($filenames.Count) filenames" -ForegroundColor Magenta
        }
        
        return $filenames
    }
    catch {
        Write-Warning "Error parsing $FilePath : $_"
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Exception: $($_.Exception.GetType().Name)" -ForegroundColor Red
            Write-Host "  [DEBUG] Message: $($_.Exception.Message)" -ForegroundColor Red
        }
        return @()
    }
}

function Test-FileInSizeRange {
    param(
        [string]$Path,
        [long]$MinBytes = 200KB,
        [long]$MaxBytes = 15MB
    )
    
    if (-not (Test-Path $Path -PathType Leaf)) {
        return $false
    }
    
    try {
        $size = (Get-Item $Path -ErrorAction Stop).Length
        return ($size -ge $MinBytes -and $size -le $MaxBytes)
    }
    catch {
        return $false
    }
}

$script:BytePatterns = @(
    @{
        Name = "Pattern #1"
        Bytes = "6161370E160609949E0029033EA7000A2C1D03548403011D1008A1FFF6033EA7000A2B1D03548403011D07A1FFF710FEAC150599001A2A160C14005C6588B800"
    },
    @{
        Name = "Pattern #2"
        Bytes = "0C1504851D85160A6161370E160609949E0029033EA7000A2C1D03548403011D1008A1FFF6033EA7000A2B1D03548403011D07A1FFF710FEAC150599001A2A16"
    },
    @{
        Name = "Pattern #3"
        Bytes = "5910071088544C2A2BB8004D3B033DA7000A2B1C03548402011C1008A1FFF61A9E000C1A110800A2000503AC04AC00000000000A0005004E000101FA000001D3"
    }
)

$script:ClassPatterns = @(
    "net/java/f",
    "net/java/g",
    "net/java/h",
    "net/java/i",
    "net/java/k",
    "net/java/l",
    "net/java/m",
    "net/java/r",
    "net/java/s",
    "net/java/t",
    "net/java/y"
)

function ConvertHex-ToBytes {
    param([string]$hexString)
    
    $bytes = New-Object byte[] ($hexString.Length / 2)
    for ($i = 0; $i -lt $hexString.Length; $i += 2) {
        $bytes[$i / 2] = [Convert]::ToByte($hexString.Substring($i, 2), 16)
    }
    return $bytes
}

function Search-BytePattern {
    param(
        [byte[]]$data,
        [byte[]]$pattern
    )
    
    $patternLength = $pattern.Length
    $dataLength = $data.Length
    
    for ($i = 0; $i -le ($dataLength - $patternLength); $i++) {
        $match = $true
        for ($j = 0; $j -lt $patternLength; $j++) {
            if ($data[$i + $j] -ne $pattern[$j]) {
                $match = $false
                break
            }
        }
        if ($match) {
            return $true
        }
    }
    return $false
}

function Search-ClassPattern {
    param(
        [byte[]]$data,
        [string]$className
    )
    
    $classBytes = [System.Text.Encoding]::ASCII.GetBytes($className)
    return Search-BytePattern -data $data -pattern $classBytes
}

function Test-ZipMagicBytes {
    param([string]$Path)
    
    try {
        $fileStream = [System.IO.File]::OpenRead($Path)
        $reader = New-Object System.IO.BinaryReader($fileStream)
        
        if ($fileStream.Length -lt 2) {
            $reader.Close()
            $fileStream.Close()
            return $false
        }
        
        $byte1 = $reader.ReadByte()
        $byte2 = $reader.ReadByte()
        
        $reader.Close()
        $fileStream.Close()
        
        return ($byte1 -eq 0x50 -and $byte2 -eq 0x4B)
        
    } catch {
        return $false
    }
}

function Find-SingleLetterClasses {
    param([string]$Path)
    
    $singleLetterClasses = @()
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        $jar = [System.IO.Compression.ZipFile]::OpenRead($Path)
        
        foreach ($entry in $jar.Entries) {
            if ($entry.FullName -like "*.class") {
                $className = $entry.FullName
                
                $parts = $className -split '/'
                $filename = $parts[-1]
                
                $classNameOnly = $filename -replace '\.class$', ''
                
                if ($classNameOnly -match '^[a-zA-Z]$') {
                    $fullPath = ($parts[0..($parts.Length-2)] -join '/') + '/' + $classNameOnly
                    $singleLetterClasses += $fullPath
                }
            }
        }
        
        $jar.Dispose()
        
    } catch {
    }
    
    return $singleLetterClasses
}

function Test-DoomsdayClient {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $result = [PSCustomObject]@{
        IsDetected = $false
        Confidence = "NONE"
        BytePatternMatches = @()
        ClassNameMatches = @()
        SingleLetterClasses = @()
        IsRenamedJar = $false
        Error = $null
    }
    
    if (-not (Test-Path $Path -PathType Leaf)) {
        $result.Error = "File not found"
        return $result
    }
    
    try {
        $fileExtension = [System.IO.Path]::GetExtension($Path).ToLower()
        
        $hasPKHeader = Test-ZipMagicBytes -Path $Path
        
        if ($hasPKHeader -and $fileExtension -ne ".jar") {
            $result.IsRenamedJar = $true
            $result.IsDetected = $true
            $result.Confidence = "HIGH"
        }
        
        if (-not $hasPKHeader) {
            $result.Error = "File is not a JAR/ZIP file (missing PK header)"
            return $result
        }
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        $jar = [System.IO.Compression.ZipFile]::OpenRead($Path)
        
        $classFiles = $jar.Entries | Where-Object { $_.FullName -like "*.class" }
        $classCount = $classFiles.Count
        
        if ($classCount -gt 30) {
            $jar.Dispose()
            $result.Error = "Skipped: Too many classes ($classCount) - likely legitimate library"
            return $result
        }
        
        if ($classCount -eq 0) {
            $jar.Dispose()
            $result.Error = "No .class files found in JAR"
            return $result
        }
        
        $allBytes = @()
        
        foreach ($entry in $classFiles) {
            $stream = $entry.Open()
            $reader = New-Object System.IO.BinaryReader($stream)
            $bytes = $reader.ReadBytes([int]$entry.Length)
            $allBytes += $bytes
            $reader.Close()
            $stream.Close()
        }
        
        $jar.Dispose()
        
        foreach ($pattern in $script:BytePatterns) {
            $patternBytes = ConvertHex-ToBytes -hexString $pattern.Bytes
            
            if (Search-BytePattern -data $allBytes -pattern $patternBytes) {
                $result.BytePatternMatches += $pattern.Name
            }
        }
        
        foreach ($className in $script:ClassPatterns) {
            if (Search-ClassPattern -data $allBytes -className $className) {
                $result.ClassNameMatches += $className
            }
        }
        
        $result.SingleLetterClasses = Find-SingleLetterClasses -Path $Path
        
        $byteMatchCount = $result.BytePatternMatches.Count
        $classMatchCount = $result.ClassNameMatches.Count
        $singleLetterCount = $result.SingleLetterClasses.Count
        
        if ($byteMatchCount -ge 2) {
            $result.IsDetected = $true
            $result.Confidence = "HIGH"
        }
        elseif ($byteMatchCount -eq 1 -and ($classMatchCount -ge 5 -or $singleLetterCount -ge 5)) {
            $result.IsDetected = $true
            $result.Confidence = "MEDIUM"
        }
        elseif ($byteMatchCount -eq 1) {
            $result.IsDetected = $true
            $result.Confidence = "LOW"
        }
        elseif ($singleLetterCount -ge 8 -and $classMatchCount -ge 3) {
            $result.IsDetected = $true
            $result.Confidence = "MEDIUM"
        }
        elseif ($singleLetterCount -ge 5 -or $classMatchCount -ge 5) {
            $result.IsDetected = $true
            $result.Confidence = "LOW"
        }
        
        if ($result.IsRenamedJar -and $result.Confidence -eq "NONE") {
            $result.Confidence = "MEDIUM"
        }
        
    } catch {
        $result.Error = $_.Exception.Message
    }
    
    return $result
}

function Start-DoomsdayScan {
    param(
        [switch]$Debug
    )
    
    $script:DebugMode = $Debug
    
    Show-Banner
    
    if (-not (Test-Administrator)) {
        Write-Section 'ERROR'
        Write-BloodFail 'Administrator privileges required!'
        Write-BloodWarn 'Please launch PowerShell as admin!'
        Write-BloodFoot
        return
    }

    Write-Section 'SYSTEM'
    $osVersion = [System.Environment]::OSVersion.Version
    Write-BloodInfo ("Windows Version: {0}.{1} Build {2}" -f $osVersion.Major, $osVersion.Minor, $osVersion.Build)

    if ($osVersion.Major -eq 10) {
        if ($osVersion.Build -ge 22000) {
            Write-BloodOk 'Detected: Windows 11'
        } else {
            Write-BloodOk 'Detected: Windows 10'
        }
    }

    Write-Section 'PREFETCH INDEXES'
    
    $systemPath = "C:\Windows\" + "Pre" + "fetch"
    
    if (-not (Test-Path $systemPath)) {
        Write-BloodFail ("Prefetch directory not found: {0}" -f $systemPath)
        Write-BloodFoot
        return
    }
    
    $javaFiles = Get-ChildItem -Path $systemPath -Filter "JAVA*.EXE-*.pf" -ErrorAction SilentlyContinue
    
    if ($javaFiles.Count -eq 0) {
        Write-BloodWarn ("No JAVA prefetch files found in {0}" -f $systemPath)
        Write-BloodInfo 'This could mean:'
        Write-Host '    - Java has never been run on this system' -ForegroundColor DarkGray
        Write-Host '    - Prefetch files have been cleared' -ForegroundColor DarkGray
        Write-Host '    - Prefetch is disabled' -ForegroundColor DarkGray
        Write-BloodFoot
        return
    }
    
    Write-BloodOk ("Found {0} JAVA prefetch file(s)" -f $javaFiles.Count)
    
    $allJarPaths = @()
    $fileMetadata = @{}
    $processedFiles = 0
    $successfulParsing = 0
    
    foreach ($sysFile in $javaFiles) {
        $processedFiles++
        Write-Progress -Activity "Extracting Indexes" `
                      -Status "Processing file $processedFiles of $($javaFiles.Count)" `
                      -PercentComplete (($processedFiles / $javaFiles.Count) * 100)
        
        if ($script:DebugMode) {
            Write-Host ""
            Write-Host "[DEBUG] ======================================" -ForegroundColor Magenta
        }
        
        $indexes = Get-SystemIndexes -FilePath $sysFile.FullName
        
        if ($indexes.Count -eq 0) {
            if ($script:DebugMode) {
                Write-Host "  [DEBUG] No indexes extracted from $($sysFile.Name)" -ForegroundColor Yellow
            }
            continue
        }
        
        $successfulParsing++
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Successfully extracted $($indexes.Count) paths" -ForegroundColor Green
        }
        
        $indexNum = 0
        foreach ($index in $indexes) {
            $indexNum++
            
            # Strip volume GUID if present, assume C: drive initially
            if ($index -match '\\VOLUME\{[^\}]+\}\\(.*)$') {
                $relativePath = $Matches[1]
                $assumedPath = "C:\$relativePath"
                $allJarPaths += $assumedPath
                
                if (-not $fileMetadata.ContainsKey($assumedPath)) {
                    $fileMetadata[$assumedPath] = @{
                        SourceFile = $sysFile.Name
                        IndexNumber = $indexNum
                        OriginalPath = $index
                    }
                }
            }
            else {
                # No volume GUID, use path as-is
                $allJarPaths += $index
                
                if (-not $fileMetadata.ContainsKey($index)) {
                    $fileMetadata[$index] = @{
                        SourceFile = $sysFile.Name
                        IndexNumber = $indexNum
                        OriginalPath = $index
                    }
                }
            }
        }
    }
    
    Write-Progress -Activity "Extracting Indexes" -Completed
    
    Write-BloodOk ("Prefetch files successfully parsed: {0} / {1}" -f $successfulParsing, $processedFiles)
    Write-BloodOk ("Total file paths extracted: {0}" -f $allJarPaths.Count)

    if ($allJarPaths.Count -eq 0) {
        Write-BloodWarn 'No file paths could be extracted from prefetch files'
        Write-BloodInfo 'Possible issues:'
        Write-Host '    - Prefetch parsing failed (incompatible format)' -ForegroundColor DarkGray
        Write-Host '    - No Java applications with file references' -ForegroundColor DarkGray
        Write-BloodInfo 'Try Start-DoomsdayScan -Debug'
        Write-BloodFoot
        return
    }

    $uniquePaths = $allJarPaths | Select-Object -Unique
    Write-BloodOk ("Unique files to scan: {0}" -f $uniquePaths.Count)

    Write-Section 'FILE CHECK'
    
    $existingPaths = @{}  # Store path -> actual location
    $trulyMissingPaths = @()
    $checkCount = 0
    $outsideRangeCount = 0
    $resolvedToDifferentDrive = 0
    
    # Get all available drives
    $allDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' } | ForEach-Object { $_.Root.Substring(0, 1) }
    
    foreach ($path in $uniquePaths) {
        $checkCount++
        
        $foundPath = $null
        
        # First, check if file exists at the given path (usually C:)
        if (Test-Path $path -PathType Leaf) {
            $foundPath = $path
        }
        else {
            # File doesn't exist at assumed location
            # Try to find it on other drives
            if ($path -match '^[A-Z]:\\(.*)$') {
                $relativePath = $Matches[1]
                
                # Try each drive
                foreach ($drive in $allDrives) {
                    $testPath = "$drive`:\$relativePath"
                    
                    if (Test-Path $testPath -PathType Leaf) {
                        $foundPath = $testPath
                        $resolvedToDifferentDrive++
                        
                        if ($script:DebugMode) {
                            Write-Host "  [DEBUG] Found on different drive: $testPath (assumed $path)" -ForegroundColor Cyan
                        }
                        break
                    }
                }
            }
        }
        
        if ($foundPath) {
            # File exists somewhere
            $fileSize = (Get-Item $foundPath -ErrorAction SilentlyContinue).Length
            
            if ($fileSize -ge 200KB -and $fileSize -le 15MB) {
                $existingPaths[$path] = $foundPath
            } else {
                $outsideRangeCount++
                if ($script:DebugMode) {
                    $sizeMB = [math]::Round($fileSize / 1MB, 2)
                    Write-Host "  [DEBUG] Skipped (size: $sizeMB MB): $foundPath" -ForegroundColor Gray
                }
            }
        }
        else {
            # File doesn't exist on ANY drive - truly missing
            $trulyMissingPaths += $path
        }
    }
    
    $missingCount = $trulyMissingPaths.Count
    
    Write-BloodInfo ("Total paths checked: {0}" -f $checkCount)
    Write-BloodOk ("Files found and in size range (200KB-15MB): {0}" -f $existingPaths.Count)
    if ($resolvedToDifferentDrive -gt 0) {
        Write-BloodInfo ("Files resolved to different drives: {0}" -f $resolvedToDifferentDrive)
    }
    Write-Host ("[!] Files outside size range: {0}" -f $outsideRangeCount) -ForegroundColor DarkGray
    Write-BloodWarn ("Files truly missing (not on any drive): {0}" -f $missingCount)

    # Show truly missing files (filter out temp files, focus on JARs/EXEs)
    if ($missingCount -gt 0) {
        Write-Section 'DELETED / MISSING'
        
        $displayedCount = 0
        foreach ($missingPath in $trulyMissingPaths) {
            # Skip temp files and Java cleanup
            # Only skip JNA####.DLL patterns, not ALL .DLLs
            if ($missingPath -match '\\TEMP\\|\\TMP\\|HSPERFDATA|\.TMP$|JNA\d+\.DLL') {
                continue
            }
            
            # Show JAR, EXE, and DLL files
            if ($missingPath -notmatch '\.(JAR|EXE|DLL)$') {
                continue
            }
            
            $displayedCount++
            Write-Ansi (" $esc[38;2;255;45;45m✖ DELETED$esc[0m ")
            Write-Host $missingPath -ForegroundColor White
            Write-Host '      Source: ' -NoNewline -ForegroundColor DarkGray
            Write-Host "$($fileMetadata[$missingPath].SourceFile)" -ForegroundColor DarkRed
        }
        
        if ($displayedCount -eq 0) {
            Write-BloodOk 'No suspicious deletions found (only temp files deleted)'
        }
        
        Write-Host ""
    }
    
    if ($existingPaths.Count -eq 0) {
        Write-BloodWarn 'No files exist to scan'
        Write-BloodInfo 'All extracted paths point to files that either:'
        Write-Host '    - No longer exist (deleted)' -ForegroundColor DarkGray
        Write-Host '    - Are outside the 200KB-15MB size range' -ForegroundColor DarkGray
        Write-BloodFoot
        return
    }

    Write-Section 'SCAN'
    
    $detections = @()
    $scanned = 0
    $skipped = 0
    
    foreach ($assumedPath in $existingPaths.Keys) {
        $actualPath = $existingPaths[$assumedPath]
        $scanned++
        
        $filename = [System.IO.Path]::GetFileName($actualPath)
        
        Write-Progress -Activity "Scanning for Doomsday Client" `
                      -Status "[$scanned/$($existingPaths.Count)]" `
                      -PercentComplete (($scanned / $existingPaths.Count) * 100)
        
        Write-Host "`r[$scanned/$($existingPaths.Count)]" -NoNewline -ForegroundColor Cyan
        
        try {
            $result = Test-DoomsdayClient -Path $actualPath
            
            if ($result.Error -and $result.Error -like "Skipped:*") {
                $skipped++
            }
            
            if ($result.IsDetected) {
                Write-Host "`r                              `r" -NoNewline
                
                $detections += [PSCustomObject]@{
                    Path = $actualPath
                    SourceFile = $fileMetadata[$assumedPath].SourceFile
                    IndexNumber = $fileMetadata[$assumedPath].IndexNumber
                    Confidence = $result.Confidence
                    IsRenamedJar = $result.IsRenamedJar
                    BytePatterns = $result.BytePatternMatches.Count
                    ClassMatches = $result.ClassNameMatches.Count
                    SingleLetterClasses = $result.SingleLetterClasses.Count
                }
                
                Write-Ansi (" $esc[38;2;255;20;20m✖ DETECTION$esc[0m ")
                Write-Host $actualPath -ForegroundColor Red
                Write-Host '    Confidence: ' -NoNewline -ForegroundColor DarkGray

                switch ($result.Confidence) {
                    'HIGH'   { Write-Host 'HIGH' -ForegroundColor Red }
                    'MEDIUM' { Write-Host 'MEDIUM' -ForegroundColor Yellow }
                    'LOW'    { Write-Host 'LOW' -ForegroundColor DarkGray }
                }

                if ($result.IsRenamedJar) {
                    Write-BloodFail '    Renamed JAR detected!'
                }
                if ($result.BytePatternMatches.Count -gt 0) {
                    Write-BloodFail ("    Byte patterns: {0}" -f $result.BytePatternMatches.Count)
                }
                Write-Host ''
            }
        }
        catch {
            Write-Host "`r                              `r" -NoNewline
            Write-Host "Error scanning $filename : $_" -ForegroundColor Red
        }
    }
    
    Write-Host "`r                              `r" -NoNewline
    
    Write-Progress -Activity "Scanning for Doomsday Client" -Completed
    Write-Host ""
    
    Write-Section 'SCAN COMPLETE'
    Write-BloodInfo ("Total indexes extracted: {0}" -f $allJarPaths.Count)
    Write-BloodInfo ("Files in size range: {0}" -f $uniquePaths.Count)
    Write-BloodInfo ("Files exist: {0}" -f $existingPaths.Count)
    Write-BloodInfo ("Files scanned: {0}" -f $scanned)
    Write-Host ("[!] Files skipped (>30 classes): {0}" -f $skipped) -ForegroundColor DarkGray

    Write-Host ''
    Write-Host 'Doomsday Client detections: ' -NoNewline -ForegroundColor DarkGray

    if ($detections.Count -gt 0) {
        Write-Ansi ("$esc[1;38;2;255;40;40m{0}$esc[0m`n" -f $detections.Count)

        Write-Host 'Detections by confidence:' -ForegroundColor DarkRed
        $high = ($detections | Where-Object { $_.Confidence -eq 'HIGH' }).Count
        $medium = ($detections | Where-Object { $_.Confidence -eq 'MEDIUM' }).Count
        $low = ($detections | Where-Object { $_.Confidence -eq 'LOW' }).Count

        if ($high -gt 0) { Write-Host ("  HIGH: {0}" -f $high) -ForegroundColor Red }
        if ($medium -gt 0) { Write-Host ("  MEDIUM: {0}" -f $medium) -ForegroundColor Yellow }
        if ($low -gt 0) { Write-Host ("  LOW: {0}" -f $low) -ForegroundColor DarkGray }

        Write-Host ''
        Write-Ansi ("$esc[1;38;2;255;20;20m  DOOMSDAY CLIENT DETECTED ON THIS SYSTEM!$esc[0m`n")

        Write-Section 'DETECTION DETAILS'

        $detectionNum = 1
        foreach ($detection in $detections) {
            Write-Ansi (" $esc[38;2;255;45;45m✖ [$detectionNum]$esc[0m ")
            Write-Host $detection.Path -ForegroundColor White
            Write-Host '    Source File: ' -NoNewline -ForegroundColor DarkGray
            Write-Host $detection.SourceFile -ForegroundColor DarkRed
            Write-Host '    Index Number: ' -NoNewline -ForegroundColor DarkGray
            Write-Host ("#{0}" -f $detection.IndexNumber) -ForegroundColor Red
            Write-Host '    Confidence: ' -NoNewline -ForegroundColor DarkGray

            switch ($detection.Confidence) {
                'HIGH'   { Write-Host 'HIGH' -ForegroundColor Red }
                'MEDIUM' { Write-Host 'MEDIUM' -ForegroundColor Yellow }
                'LOW'    { Write-Host 'LOW' -ForegroundColor DarkGray }
            }

            if ($detection.IsRenamedJar) {
                Write-Host '    Renamed JAR: ' -NoNewline -ForegroundColor DarkGray
                Write-Host 'YES' -ForegroundColor Red
            }

            if ($detection.BytePatterns -gt 0) {
                Write-Host '    Byte Patterns: ' -NoNewline -ForegroundColor DarkGray
                Write-Host $detection.BytePatterns -ForegroundColor Red
            }

            if ($detection.ClassMatches -gt 0) {
                Write-Host '    Class Matches: ' -NoNewline -ForegroundColor DarkGray
                Write-Host $detection.ClassMatches -ForegroundColor Yellow
            }

            if ($detection.SingleLetterClasses -gt 0) {
                Write-Host '    Single-Letter Classes: ' -NoNewline -ForegroundColor DarkGray
                Write-Host $detection.SingleLetterClasses -ForegroundColor Yellow
            }

            Write-Host ''
            $detectionNum++
        }

    } else {
        Write-Host '0' -ForegroundColor Green
        Write-Host ''
        Write-Ansi ("$esc[38;2;80;220;120m  No Doomsday Client detected!$esc[0m`n")
    }

    if ($script:DebugMode) {
        Write-Host '[DEBUG MODE] Scan completed with debugging enabled' -ForegroundColor Magenta
    }

    Write-BloodFoot
}

# Run the scan
# To enable debug mode, use: Start-DoomsdayScan -Debug
Start-DoomsdayScan