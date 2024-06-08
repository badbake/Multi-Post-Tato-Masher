<#
.SYNOPSIS
    Script for orchestrating multiple instances of PoST Proving 'service.exe', sequentially, based on cycle gap timing.
.DESCRIPTION
    This script runs different instances of the PoST Proving "service.exe" sequentially, waits for each to complete before starting the next, and handles Cycle Gap timing.
.NOTES
    File Name: BadBakes_Multi_Post-tato_Masher__V1.0.8_TESTNET.ps1
    Author: badbake
    Version: 1.0.9
    Last Updated: 2024-06-08
#>

# Set the window title
$WindowTitle = "Multi Post-tato Masher TESTNET"
$host.ui.RawUI.WindowTitle = $WindowTitle

# Define user-customizable parameters
$logDirectory = ".\Logs"						#Can be changed to customize log directory
$serviceExecutable = ".\service.exe"			#Set location of 'service.exe'. (Defaults to directory script is run from)
$grpcurlExecutable = ".\grpcurl.exe"			#Set location of 'grpcurl.exe'. (Defaults to directory script is run from)

if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory
}

$logFileName = "MultiMasherLog$((Get-Date).ToString('yyyyMMdd_HHmm')).txt"
$logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName

# Function to log messages with timestamp and log level
function Log-Message {
    param (
        [string]$message,
        [string]$level = "INFO"  # Default level is INFO
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "$timestamp - [$level] - $message"

    # Write the log message to the console with colors
    Colorize-Logs -message $message -level $level -timestamp $timestamp

    # Also write to the log file without colors
    $logMessage | Out-File -Append -FilePath $logFilePath
}

# Function to display colorized logs in the console
function Colorize-Logs {
    param (
        [string]$message,
        [string]$level,
        [string]$timestamp
    )

    switch ($level) {
        "INFO" {
            $timestampColor = "Green"
            $levelColor = "Cyan"
            $messageColor = "Gray"
        }
        "WARNING" {
            $timestampColor = "Green"
            $levelColor = "Yellow"
            $messageColor = "Gray"
        }
        "ERROR" {
            $timestampColor = "Green"
            $levelColor = "Red"
            $messageColor = "Gray"
        }
        default {
            $timestampColor = "Green"
            $levelColor = "White"
            $messageColor = "Gray"
        }
    }

    # Print the log message with color
    Write-Host -NoNewline -ForegroundColor $timestampColor $timestamp
    Write-Host -NoNewline " - "
    Write-Host -NoNewline -ForegroundColor $levelColor "[$level]"
    Write-Host -NoNewline " - "
    Write-Host -ForegroundColor $messageColor $message
}

# Load instance configurations from an external PowerShell script
function Load-Configurations {
    param (
        [string]$configFilePath
    )
    try {
        if (-not (Test-Path -Path $configFilePath)) {
            throw "Configuration file not found at path: $configFilePath"
        }
        . $configFilePath
        return $instances
    } catch {
        Log-Message "Error loading configurations: $_" "ERROR"
        throw $_
    }
}

$configFilePath = ".\Masher_config.ps1"
$instances = Load-Configurations -configFilePath $configFilePath

# Function to run an instance
function Run-Instance {
    param (
        [string]$instanceName,
        [string[]]$arguments
    )

    # Expected responses
    $idleResponse = '"state": "IDLE"'
    $provingResponse = '"state": "PROVING"'

    # Log for service.exe
    $serviceLogFileName = "$instanceName_serviceLog$((Get-Date).ToString('yyyyMMdd')).txt"
    $serviceLogFilePath = Join-Path -Path $logDirectory -ChildPath $serviceLogFileName

    # Extract port number from the address argument
    $addressArgument = ($arguments -like "--address=*")[0]
    $port = $addressArgument.Split(":")[2].Trim("http://")

    # Flag for PROVING state
    $provingStateReached = $false

    Log-Message "$instanceName is starting service.exe"
    $serviceProcess = Start-Process -FilePath $serviceExecutable -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardError $serviceLogFilePath

    # Check if service process started successfully
    if ($serviceProcess -ne $null -and (Get-Process -Id $serviceProcess.Id -ErrorAction SilentlyContinue)) {
        Log-Message "$instanceName has successfully started Post Service."
    } else {
        Log-Message "$instanceName failed to start Post Service." "ERROR"
        return
    }

    $previousState = ""

    do {
        Start-Sleep -Seconds 30

        $response = & "$grpcurlExecutable" --plaintext -d '{}' "localhost:$port" spacemesh.v1.PostInfoService.PostStates 2>&1

        $provingFound = $false
        $idleFound = $false

        # Check each state in the response
        if ($response -match '"states": \[.*?\]') {
            $jsonResponse = $response | ConvertFrom-Json
            foreach ($state in $jsonResponse.states) {
                if ($state.name -eq $instanceName) {
                    if ($state.state -eq "PROVING") {
                        $provingFound = $true
                    } elseif ($state.state -eq "IDLE") {
                        $idleFound = $true
                    }
                }
            }
        }

        if ($provingFound -and $previousState -ne "PROVING") {
            Log-Message "PostService '$instanceName' is PROVING."
            $provingStateReached = $true
            $previousState = "PROVING"
        } elseif ($provingFound -and $previousState -eq "PROVING") {
            Log-Message "PostService '$instanceName' is still PROVING."
        } elseif ($idleFound -and $previousState -ne "IDLE" -and -not $provingStateReached) {
            Log-Message "PostService '$instanceName' is in the IDLE state."
            $previousState = "IDLE"
        } elseif ($idleFound -and $previousState -eq "IDLE") {
            Log-Message "PostService '$instanceName' continues to be in the IDLE state."
        } elseif ($idleFound -and $provingStateReached) {
            Log-Message "PostService '$instanceName' has completed PROVING and is now in the IDLE state. Initiating shutdown."
            Stop-Gracefully -process $serviceProcess
            return
        }
    } while ($true)
}

# Function to initiate a graceful shutdown of the process
function Stop-Gracefully {
    param (
        [System.Diagnostics.Process]$process
    )

    try {
        # Send a termination signal (assuming the process handles it for graceful shutdown)
        $process.CloseMainWindow()

        # Wait for the process to exit gracefully
        if (-not $process.WaitForExit(30000)) {  # Wait up to 30 seconds for graceful exit
            Log-Message "Process did not exit gracefully within the timeout period. Forcing termination." "WARNING"
            $process.Kill()
        } else {
            Log-Message "Instance ended successfully."
        }
    } catch {
        Log-Message "An error occurred while attempting to stop the process gracefully: $_" "ERROR"
    }
}

# Function to wait for service to stop
function Wait-ForServiceStopped {
    param (
        [string]$instanceName
    )

    do {
        $serviceProcess = Get-Process -Name $instanceName -ErrorAction SilentlyContinue
        if ($serviceProcess) {
            Log-Message "Found running instance of service.exe for '$instanceName'. Attempting to stop it."
            Stop-Gracefully -process $serviceProcess
            Start-Sleep -Seconds 1
        } else {
            Start-Sleep -Seconds 1
        }
    } while (Get-Process -Name $instanceName -ErrorAction SilentlyContinue)

    Log-Message "PostService '$instanceName' has stopped and released resources."
}

# Function to run all instances sequentially
function Run-AllInstances {
    foreach ($instanceName in $instances.Keys) {
        $instance = $instances[$instanceName]
        Run-Instance -instanceName $instanceName -arguments $instance.Arguments
        Wait-ForServiceStopped -instanceName $instanceName
    }

    Log-Message "All PostServices have completed."
}

# Function to calculate the next trigger time based on the user's local time zone
function Calculate-NextTriggerTime {
    # Define the initial trigger date and time in UTC
    $initialTriggerDateTimeUtc = [DateTime]::new(2024, 6, 6, 22, 59, 0)		#testnet12

    # Convert the initial trigger time to the local time zone
    $initialTriggerDateTimeLocal = $initialTriggerDateTimeUtc.ToLocalTime()
    # Get the current date and time in the local time zone
    $currentDateTimeLocal = Get-Date

    # Check if the current date and time is past the initial trigger time
    if ($currentDateTimeLocal -gt $initialTriggerDateTimeLocal) {
        # Calculate the time difference between the current time and the initial trigger time
        $timeDifference = $currentDateTimeLocal - $initialTriggerDateTimeLocal
        # Calculate the number of full 1-day intervals that have passed
        $fullIntervals = [Math]::Floor($timeDifference.TotalDays)
        # Calculate the next trigger time by adding the necessary number of 1-day intervals to the initial trigger time
        $nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal.AddDays($fullIntervals + 1)
    } else {
        # If the current time is before the initial trigger time, the next trigger time is the initial trigger time
        $nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal
    }

    # Log the next trigger date and time
    Log-Message "Next trigger date and time: $nextTriggerDateTimeLocal"
    # Return the next trigger date and time
    return $nextTriggerDateTimeLocal
}

# Function to wait for the trigger command
function Wait-ForTrigger {
    while ($true) {
        $nextTriggerTime = Calculate-NextTriggerTime
        $timeDifference = $nextTriggerTime - (Get-Date)

        Log-Message "Sleeping until PoEt Cycle Gap... $timeDifference"
        if ($timeDifference.TotalSeconds -gt 0) {
            Start-Sleep -Seconds $timeDifference.TotalSeconds
        }

        Run-AllInstances
    }
}

# Main entry point
Wait-ForTrigger
