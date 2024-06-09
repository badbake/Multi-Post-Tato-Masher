<#
.SYNOPSIS
    Script for orchestrating multiple PoST Proving service instances, sequentially, based on cycle gap timing.
.DESCRIPTION
    This script runs different instances of the PoST Proving "service.exe" sequentially, waits for each to complete before starting the next, and handles Cycle Gap timing.
.NOTES
    File Name: BadBakes_Multi_Post-tato_Masher__V1.0.8_TESTNET.ps1
    Author: badbake
    Version: 1.0.8
    Last Updated: 2024-06-08
#>

# Set the window title
$WindowTitle = "Multi Post-tato Masher TESTNET"
$host.ui.RawUI.WindowTitle = $WindowTitle
$grpcurl = Join-Path -Path $PSScriptRoot -ChildPath "grpcurl.exe"

# Define user-customizable parameters
$logDirectory = ".\Logs"
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory
}

$logFileName = "MultiMasherLog$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
$logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName

# Define configurations for each set of POST Data. 
$instances = @{
    "Post1" = @{									#Name of each instance must match the identity.key associaited with that POST data set. (Example - Post1 for use with Post1.key.) 
        Arguments = @(
            "--address=http://localhost:9094",		#Node's gRPC address. Ensure it matches the node's grpc-post-listener config option.
            "--dir=./Post1",						#Post Data Directory, Set for each different set of Post Data.
            "--operator-address=127.0.0.1:50051",	#Operator API
            "--threads=1",							#Proving Options based on your hardware
            "--nonces=128",							#Proving Options based on your hardware
            "--randomx-mode=fast"					#Proving Options based on your hardware
        )
    }
    "Post2" = @{									#Example - Post2 name for use with Post2.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post2",						#Set for Post DataDirectory 2
            "--operator-address=127.0.0.1:50052",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    "Post3" = @{									#Example - Post2 name for use with Post2.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post3",						#Set for Post DataDirectory 2
            "--operator-address=127.0.0.1:50053",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    "Post4" = @{									#Example - Post2 name for use with Post2.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post4",						#Set for Post DataDirectory 2
            "--operator-address=127.0.0.1:50054",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    "Post5" = @{									#Example - Post2 name for use with Post2.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post5",						#Set for Post DataDirectory 2
            "--operator-address=127.0.0.1:50055",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    # Add more Posts with names and arguments for all Post Services needed.
}

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
        "DEBUG" {
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

function Run-Instance {
    param (
        [string]$instanceName,
        [string[]]$arguments
    )

    # Expected responses
    $idleResponse = '"state": "IDLE"'
    $provingResponse = '"state": "PROVING"'

    # Log for service.exe
    $serviceLogFileName = "${instanceName}_service$((Get-Date).ToString('yyyyMMdd')).txt"
    $serviceLogFilePath = Join-Path -Path $logDirectory -ChildPath $serviceLogFileName

    # Extract port number from the address argument
    $addressArgument = ($arguments -like "--address=*")[0]
    $port = $addressArgument.Split(":")[2].Trim("http://")

    # Flag for PROVING state
    $provingStateReached = $false

    Log-Message "$instanceName is starting service.exe" "INFO"
    $serviceProcess = Start-Process -FilePath ".\service.exe" -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardError $serviceLogFilePath

    # Check if service process started successfully
    if ($serviceProcess -ne $null -and (Get-Process -Id $serviceProcess.Id -ErrorAction SilentlyContinue)) {
        Log-Message "$instanceName has successfully started Post Service." "INFO"
    } else {
        Log-Message "$instanceName failed to start Post Service." "ERROR"
        return
    }

    $previousState = ""
    $provingFound = $false
    $idleFound = $false

    do {
        Start-Sleep -Seconds 30

        $response = & "$grpcurl" --plaintext -d '{}' "localhost:$port" spacemesh.v1.PostInfoService.PostStates 2>&1

        # Check if the response is empty or if there's an error
        if (-not $response) {
            Log-Message "No response received from gRPC call." "ERROR"
            return
        }

        # Convert response to JSON
        try {
            $jsonResponse = $response | ConvertFrom-Json
        } catch {
            Log-Message "Failed to convert response to JSON: $_" "ERROR"
            return
        }

        # Check if JSON conversion was successful
        if (-not $jsonResponse) {
            Log-Message "Failed to convert response to JSON." "ERROR"
            return
        }

        # Now continue with processing the JSON response
        foreach ($state in $jsonResponse.states) {
            Log-Message "Found instance '$($state.name)' with state '$($state.state)'." "DEBUG"
            if ($state.name -like "$instanceName*") {  # Check if the name contains the expected instance name
                Log-Message "Instance name '$instanceName' matched in the response." "DEBUG"
                if ($state.state -eq "PROVING") {
                    $provingFound = $true
                    Log-Message "Proving found for '$instanceName'." "DEBUG"
                } elseif ($state.state -eq "IDLE") {
                    $idleFound = $true
                    Log-Message "Idle found for '$instanceName'." "DEBUG"
                }
            }
        }

        if ($provingFound -and $previousState -ne "PROVING") {
            Log-Message "PostService '$instanceName' is PROVING." "INFO"
            $provingStateReached = $true
            $previousState = "PROVING"
        } elseif ($provingFound -and $previousState -eq "PROVING") {
            Log-Message "PostService '$instanceName' is still PROVING." "DEBUG"
        } elseif ($idleFound -and $previousState -ne "IDLE" -and -not $provingStateReached) {
            Log-Message "PostService '$instanceName' is in the IDLE state." "INFO"
            $previousState = "IDLE"
        } elseif ($idleFound -and $previousState -eq "IDLE") {
            Log-Message "PostService '$instanceName' continues to be in the IDLE state." "DEBUG"
        } elseif ($idleFound -and $provingStateReached) {
            Log-Message "PostService '$instanceName' has completed PROVING and is now in the IDLE state. Initiating shutdown." "INFO"
            Stop-Gracefully -process $serviceProcess
            $previousState = " "
            $provingStateReached = $false
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
        if (-not $process.WaitForExit(30)) {  # Wait up to 30 seconds for graceful exit
            Log-Message "Process did not exit gracefully within the timeout period. Forcing termination." "WARNING"
            $process.Kill()
        } else {
            Log-Message "Instance ended successfully." "INFO"
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
            Log-Message "Found running instance of service.exe for '$instanceName'. Attempting to stop it." "INFO"
            Stop-Gracefully -process $serviceProcess
            Start-Sleep -Seconds 1
        } else {
            Start-Sleep -Seconds 1
        }
    } while (Get-Process -Name $instanceName -ErrorAction SilentlyContinue)

    Log-Message "PostService '$instanceName' has stopped and released resources." "INFO"
}

# Function to run all instances sequentially
function Run-AllInstances {
    foreach ($instanceName in $instances.Keys) {
        $instance = $instances[$instanceName]
        Run-Instance -instanceName $instanceName -arguments $instance.Arguments
        Wait-ForServiceStopped -instanceName $instanceName
    }

    Log-Message "All PostServices have completed." "INFO"
}

# Function to calculate the next trigger time based on the user's local time zone
function Calculate-NextTriggerTime {
    # Define the initial trigger date and time in UTC
    $initialTriggerDateTimeUtc = [DateTime]::new(2024, 6, 6, 22, 59, 0)

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

# Function to update the console with the remaining time
function Update-ConsoleWithRemainingTime {
    param (
        [datetime]$nextTriggerTime
    )

    while ($true) {
        $timeDifference = $nextTriggerTime - (Get-Date)

        # Calculate remaining time in days, hours, minutes, and seconds
        $remainingDays = [Math]::Floor($timeDifference.TotalDays)
        $remainingHours = $timeDifference.Hours
        $remainingMinutes = $timeDifference.Minutes
        $remainingSeconds = $timeDifference.Seconds

        # Format the remaining time
        $formattedRemainingTime = '{0}:{1:00}:{2:00}' -f ($remainingDays * 24 + $remainingHours), $remainingMinutes, $remainingSeconds

        # Update console with the remaining time
        Write-Host -NoNewline "`r                             - Time Remaining: $formattedRemainingTime"
        Start-Sleep -Seconds 1  # Update every second

        # Exit the loop when the time difference is less than or equal to zero
        if ($timeDifference.TotalSeconds -le 0) {
            break
        }
    }
}

# Function to wait for the trigger command
function Wait-ForTrigger {
    while ($true) {
        $nextTriggerTime = Calculate-NextTriggerTime
        $timeDifference = $nextTriggerTime - (Get-Date)

        Log-Message "Waiting until PoEt Cycle Gap..." "INFO"

        # Update the console with the remaining time until the next trigger
        Update-ConsoleWithRemainingTime -nextTriggerTime $nextTriggerTime

        # Trigger all instances once the timer reaches zero
        Run-AllInstances
    }
}

# Function to check for PROVING states and run corresponding instances
function Check-And-Run-ProvingInstances {
    foreach ($instanceName in $instances.Keys) {
        $instance = $instances[$instanceName]

        # Extract port number from the address argument
        $addressArgument = ($instance.Arguments -like "--address=*")[0]
        $port = $addressArgument.Split(":")[2].Trim("http://")

        # Perform gRPC call to check the state
        $response = & "$grpcurl" --plaintext -d '{}' "localhost:$port" spacemesh.v1.PostInfoService.PostStates 2>&1

        # Check if the response contains PROVING state
        if ($response -match '"state": "PROVING"') {
            Log-Message "PROVING state found for instance '$instanceName'. Running instance before proceeding." "INFO"
            Run-Instance -instanceName $instanceName -arguments $instance.Arguments
            Wait-ForServiceStopped -instanceName $instanceName
        }
    }
}


# Main entry point
Check-And-Run-ProvingInstances
Wait-ForTrigger
