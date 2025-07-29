# --- Self-Elevation Boilerplate ---
# Place this code at the very top of your PowerShell script.

# Function to check if the script is running with administrator privileges
function Test-IsAdmin {
    $currentPrincipal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    $currentPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# If the script is not running as administrator, restart it in an elevated session
if (-not (Test-IsAdmin)) {
    Write-Host "This script is not running with administrator privileges. Attempting to self-elevate..." -ForegroundColor Yellow
    
    # Get the path of the currently executing script
    $scriptPath = $MyInvocation.MyCommand.Definition

    # Get the arguments that were passed to the current script
    # The '@' symbol expands the array into separate arguments
    $arguments = @($args)

    try {
        # Restart the script in a new process with administrator privileges
        # The '-Verb RunAs' is the key that triggers the UAC prompt
        Start-Process -FilePath "powershell.exe" -Verb "RunAs" -ArgumentList "-File `"$scriptPath`" $arguments"
        
        Write-Host "The User Account Control (UAC) prompt should have appeared." -ForegroundColor Cyan
        Write-Host "Please accept it to continue." -ForegroundColor Cyan
    }
    catch {
        Write-Error "Failed to start the elevated process. Error: $($_.Exception.Message)"
        Write-Host "The script will now exit. Please run it manually as an administrator." -ForegroundColor Red
        # Exit with a non-zero code to indicate an error
        exit 1
    }

    # Exit the current, non-elevated script.
    # The new elevated process will continue the execution.
    exit
}

# --- END of Self-Elevation Boilerplate ---


# CRITICAL: This command must be run in a PowerShell session
# started as an Administrator.

# --- Function to find the base path of the latest Windows Kits 'bin' directory.
# This function is the same as in the previous script.
function Find-LatestWindowsKitsBinPath {
    $kitsPath = "C:\Program Files (x86)\Windows Kits\10\bin"
    if (-not (Test-Path $kitsPath)) {
        Write-Error "ERROR: Windows Kits 'bin' directory not found at '$kitsPath'."
        return $null
    }

    try {
        $latestVersionDir = Get-ChildItem -Path $kitsPath -Directory |
            Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
            Sort-Object -Property Name |
            Select-Object -Last 1

        if ($latestVersionDir) {
            return $latestVersionDir.FullName
        } else {
            Write-Error "ERROR: No versioned SDK directories found under '$kitsPath'."
            return $null
        }
    } catch {
        Write-Error "ERROR: An unexpected error occurred while searching for Windows Kits. $($_.Exception.Message)"
        return $null
    }
}

# --- Main Script Logic ---
Write-Host "Preparing to update the system PATH variable..." -ForegroundColor Cyan

# Define all the paths that need to be in the PATH variable
$pathsToAdd = @()

# Add the InnoSetup path
$pathsToAdd += "C:\Program Files (x86)\Inno Setup 6\"

# Add the Windows SDK paths (x64 and x86) by finding the latest version
$windowsKitsBinPath = Find-LatestWindowsKitsBinPath
if ($windowsKitsBinPath) {
    Write-Host "  Using Windows Kits version: $(Split-Path -Path $windowsKitsBinPath -Leaf)" -ForegroundColor DarkGreen
    $pathsToAdd += Join-Path $windowsKitsBinPath "x64"
    $pathsToAdd += Join-Path $windowsKitsBinPath "x86"
} else {
    Write-Host "  Warning: Windows SDK paths could not be determined. Tools like 'signtool.exe' may not be found." -ForegroundColor Yellow
}

# Get the current system PATH as a semicolon-separated string
$currentSystemPathString = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")

# Get the current system PATH as an array of strings for easier checking
$currentSystemPaths = $currentSystemPathString.Split(';')

# Create an array of new paths that need to be appended (to avoid duplicates)
$pathsToAppend = @()

foreach ($newPath in $pathsToAdd) {
    # Check if the new path is already in the system PATH
    $isAlreadyPresent = $currentSystemPaths | Where-Object { $_ -eq $newPath }
    
    if ([string]::IsNullOrEmpty($isAlreadyPresent)) {
        $pathsToAppend += $newPath
    }
}

# If there are new paths to add...
if ($pathsToAppend.Count -gt 0) {
    # Append the new paths to the current PATH string
    $pathsToAppendString = $pathsToAppend -join ";"
    $newSystemPath = $currentSystemPathString + ";" + $pathsToAppendString

    # Set the new system PATH environment variable
    [System.Environment]::SetEnvironmentVariable("PATH", $newSystemPath, "Machine")
    
    Write-Host "`nSuccess: The following paths have been added to the system PATH:" -ForegroundColor Green
    $pathsToAppend | ForEach-Object { Write-Host "  - $_" }
} else {
    Write-Host "`nInfo: All specified paths are already in the system PATH." -ForegroundColor Yellow
}

Write-Host "`nPlease open a new PowerShell or Command Prompt window for the changes to take effect." -ForegroundColor Cyan