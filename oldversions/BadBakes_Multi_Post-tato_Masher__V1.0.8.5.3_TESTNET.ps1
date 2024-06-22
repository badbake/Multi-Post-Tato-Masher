<#
.SYNOPSIS
    Script for orchestrating multiple PoST Proving service instances, sequentially, based on cycle gap timing.
.DESCRIPTION
    This script runs different instances of the PoST Proving "service.exe" sequentially, waits for each to complete before starting the next, and handles Cycle Gap timing.
.NOTES
    File Name: BadBakes_Multi_Post-tato_Masher__V1.0.8_TESTNET.ps1
    Author: badbake
    Version: 1.0.8.5.2
    Last Updated: 2024-06-08
#>

# Set the window title
$WindowTitle = "Multi Post-tato Masher TESTNET"
$host.ui.RawUI.WindowTitle = $WindowTitle
$grpcurl = Join-Path -Path $PSScriptRoot -ChildPath "grpcurl.exe"

# Define log level (set to INFO by default, can be set to DEBUG, WARNING, ERROR)
$global:LogLevel = "INFO"

# Define user-customizable parameters
$logDirectory = ".\Logs"
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory
}

$logFileName = "PostMasher$((Get-Date).ToString('MMddyyyy_HHmm')).txt"
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
    "Post3" = @{									#Example - Post3 name for use with Post3.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post3",						#Set for Post DataDirectory 3
            "--operator-address=127.0.0.1:50053",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    "Post4" = @{									#Example - Post4 name for use with Post4.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post4",						#Set for Post DataDirectory 4
            "--operator-address=127.0.0.1:50054",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    "Post5" = @{									#Example - Post5 name for use with Post5.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post5",						#Set for Post DataDirectory 5
            "--operator-address=127.0.0.1:50055",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    # Add/Remove Posts with names and arguments for all Post Services needed.
}

# Function to log messages with timestamp and log level
function Log-Message {
    param (
        [string]$message,
        [string]$level = "INFO"  # Default level is INFO
    )

    # Define the log level hierarchy
    $logLevelHierarchy = @{
        "DEBUG" = 1
        "INFO" = 2
        "WARNING" = 3
        "ERROR" = 4
    }

    # Only log messages that are equal to or higher than the current log level
    if ($logLevelHierarchy[$level] -ge $logLevelHierarchy[$global:LogLevel]) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logMessage = "$timestamp - [$level] - $message"

        # Write the log message to the console with colors
        Colorize-Logs -message $message -level $level -timestamp $timestamp

        # Also write to the log file without colors
        $logMessage | Out-File -Append -FilePath $logFilePath
    }
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
            $levelColor = "DarkYellow"
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

    # Expected responses and Flags
    $idleResponse = '"state": "IDLE"'
    $provingResponse = '"state": "PROVING"'
    $previousState = ""
    $provingFound = $false
    $idleFound = $false
    $provingStateReached = $false
	
    # Log for service.exe
	$serviceLogFileName = "${instanceName}_service$((Get-Date).ToString('yyyyMMdd')).txt"
	$serviceLogFilePath = Join-Path -Path $logDirectory -ChildPath $serviceLogFileName

    # Extract port number from the address argument
    $addressArgument = ($arguments -like "--address=*")[0]
    $port = $addressArgument.Split(":")[2].Trim("http://")

	# Start Service with Arguments for Instance
    Log-Message "$instanceName is starting service.exe" "INFO"
    $serviceProcess = Start-Process -FilePath ".\service.exe" -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardError $serviceLogFilePath

    # Check if service process started successfully
    if ($serviceProcess -ne $null -and (Get-Process -Id $serviceProcess.Id -ErrorAction Inquire)) {
        Log-Message "$instanceName has successfully started Post Service." "INFO"
    } else {
        Log-Message "$instanceName failed to start Post Service." "ERROR"
        return $null
    }

    do {
        Start-Sleep -Seconds 30

        $response = & "$grpcurl" --plaintext -d '{}' "localhost:$port" spacemesh.v1.PostInfoService.PostStates 2>&1

        # Check if the response is empty or if there's an error
        if (-not $response) {
            Log-Message "No response received from gRPC call." "ERROR"
            return $serviceProcess
        }

        # Convert response to JSON
        try {
            $jsonResponse = $response | ConvertFrom-Json
        } catch {
            Log-Message "Failed to convert response to JSON: $_" "ERROR"
            return $serviceProcess
        }

        # Check if JSON conversion was successful
        if (-not $jsonResponse) {
            Log-Message "Failed to convert response to JSON." "ERROR"
            return $serviceProcess
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
        } elseif ($idleFound -and $provingStateReached) {
            Log-Message "PostService '$instanceName' has completed PROVING and is now in the IDLE state. Initiating shutdown." "INFO"
            Stop-Gracefully -process $serviceProcess
            return $serviceProcess
		} elseif ($provingFound -and $previousState -eq "PROVING") {
            # Call the function to check operator address response
			$operatorResponseMessage = Check-OperatorAddressResponse -instanceName $instanceName -instanceArguments $arguments
			# Log the message returned by the function
			Log-Message $operatorResponseMessage "INFO"
        } elseif ($idleFound -and $previousState -ne "IDLE" -and -not $provingStateReached) {
            Log-Message "PostService '$instanceName' is in the IDLE state." "INFO"
            $previousState = "IDLE"
        } elseif ($idleFound -and $previousState -eq "IDLE") {
            Log-Message "PostService '$instanceName' continues to be in the IDLE state." "INFO"
        }
    } while ($true)
}

function Check-OperatorAddressResponse {
    param (
        [string]$instanceName,
        [string[]]$instanceArguments
    )

    # Extract operator address from instance arguments
    $operatorAddressArgument = ($instanceArguments -like "--operator-address=*")[0]
    $operatorAddress = $operatorAddressArgument.Split("=")[1]

    # Perform curl request to operator address
    $curlResponse = Invoke-RestMethod -Uri "http://$operatorAddress/status" -Method Get

    # Define expected responses
    $expectedResponse1 = '{"Proving":{"nonces":{"start":0,"end":128},"position":0}}'
    $expectedResponse2 = '{"Proving":{"nonces":{"start":0,"end":128},"position":0}}'

    # Compare the response to expected responses
    if ($curlResponse -eq $expectedResponse1) {
        return "Operator address response matches expected response 1 for instance '$instanceName'"
    } elseif ($curlResponse -eq $expectedResponse2) {
        return "Operator address response matches expected response 2 for instance '$instanceName'"
    } else {
        return "Operator address response does not match expected responses for instance '$instanceName'"
    }
}


# Function to initiate a graceful shutdown of the process
function Stop-Gracefully {
    param (
        [System.Diagnostics.Process]$process
    )

    try {
        # Send a termination signal and wait for the process to exit gracefully
        $retryCount = 5
        $retryInterval = 10000  # 10 seconds

        for ($i = 0; $i -lt $retryCount; $i++) {
            if ($process.HasExited) {
                Log-Message "Instance ended successfully." "INFO"
                return
            }
            Log-Message "Sending termination signal to process ID $($process.Id)..." "INFO"
            Stop-Process -Id $process.Id -Force:$false

            Log-Message "Waiting for process to exit gracefully..." "INFO"
            Start-Sleep -Milliseconds $retryInterval
        }

        # If the process is still not exited, forcefully terminate it
        if (-not $process.HasExited) {
            Log-Message "Process did not exit gracefully within the timeout period. Forcing termination." "WARNING"
            $process.Kill()
            $process.WaitForExit()
        }

        Log-Message "Instance ended successfully." "INFO"
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
        $serviceProcess = Get-Process -Name $instanceName -ErrorAction Inquire
        if ($serviceProcess) {
            Log-Message "Found running instance of service.exe for '$instanceName'. Attempting to stop it." "INFO"
            Stop-Gracefully -process $serviceProcess
            Start-Sleep -Seconds 1
        } else {
            Start-Sleep -Seconds 1
        }
    } while (Get-Process -Name $instanceName -ErrorAction Inquire)

    Log-Message "PostService '$instanceName' has stopped and released resources." "INFO"
}

# Function to run all instances sequentially
function Run-AllInstances {
    foreach ($instanceName in $instances.Keys) {
        $instance = $instances[$instanceName]
        Run-Instance -instanceName $instanceName -arguments $instance.Arguments
        Wait-ForServiceStopped -instanceName $instanceName
    }

    # Check if any instances are still in PROVING state and run them again
    $instancesInProvingState = $false
    do {
        # Check each instance for PROVING state
        foreach ($instanceName in $instances.Keys) {
            $instance = $instances[$instanceName]
		
				# Display Message
				Log-Message "Checking State of '$instanceName'." "INFO"
		
            try {
                # Extract port number from the address argument
                $addressArgument = ($instance.Arguments -like "--address=*")[0]
                $port = $addressArgument.Split(":")[2].Trim("http://")

                # Perform gRPC call to check the state
                $response = & "$grpcurl" --plaintext -d '{}' "localhost:$port" spacemesh.v1.PostInfoService.PostStates 2>&1

                # Check if the response contains PROVING state
                if ($response -match '"state": "PROVING"') {
                    $instancesInProvingState = $true
                    Log-Message "PROVING state found for instance '$instanceName'. Running instance again." "INFO"
                    Run-Instance -instanceName $instanceName -arguments $instance.Arguments
                    Wait-ForServiceStopped -instanceName $instanceName
                }
                elseif ($response -match '"state": "IDLE"') {
                    # Do nothing, instance is in IDLE state
                }
                else {
                    Log-Message "Unknown state for instance '$instanceName'." "WARNING"
                }
            }
            catch {
                Log-Message "Error occurred while checking state for instance '$instanceName': $_" "ERROR"
            }
        }
    } while ($instancesInProvingState)

    Log-Message "All POST Services have completed proofs." "INFO"
}


# Function to calculate the next trigger time based on the user's local time zone
function Calculate-NextTriggerTime {
    # Define the initial trigger date and time in UTC
    $initialTriggerDateTimeUtc = [DateTime]::new(2024, 6, 6, 23, 00, 0)

    # Convert the initial trigger time to the local time zone
    $initialTriggerDateTimeLocal = $initialTriggerDateTimeUtc.ToLocalTime()
    # Get the current date and time in the local time zone
    $currentDateTimeLocal = Get-Date

    # Define the trigger window (2 hours)
    $triggerWindowHours = 2

    # Check if the current date and time is past the initial trigger time
    if ($currentDateTimeLocal -gt $initialTriggerDateTimeLocal.AddHours($triggerWindowHours)) {
        # Calculate the time difference between the current time and the initial trigger time
        $timeDifference = $currentDateTimeLocal - $initialTriggerDateTimeLocal
        # Calculate the number of full 1-day intervals that have passed
        $fullIntervals = [Math]::Floor($timeDifference.TotalDays)
        # Calculate the next trigger time by adding the necessary number of 1-day intervals to the initial trigger time
        $nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal.AddDays($fullIntervals + 1)
    } else {
        # If the current time is before the initial trigger time + window, the next trigger time is the initial trigger time
        $nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal
    }

    # Log the next trigger date and time
    Log-Message "Next Cycle Gap: $nextTriggerDateTimeLocal"
    # Return the next trigger date and time
    return $nextTriggerDateTimeLocal
}

# Function to update the console with the remaining time
function Update-ConsoleWithRemainingTime {
    param (
        [datetime]$nextTriggerTime,
        [int]$triggerWindowHours
    )

    while ($true) {
        $currentDateTime = Get-Date
        $timeDifference = $nextTriggerTime - $currentDateTime

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

        # Exit the loop when the current time is within the trigger window
        if ($currentDateTime -ge $nextTriggerTime -and $currentDateTime -lt $nextTriggerTime.AddHours($triggerWindowHours)) {
            Log-Message "Running POST Services" "INFO"
            break
        }
    }
}

# Function to wait for the trigger command
function Wait-ForTrigger {
    while ($true) {
        $nextTriggerTime = Calculate-NextTriggerTime
        $triggerWindowHours = 2

        Log-Message "Waiting until PoEt Cycle Gap..." "INFO"

        # Update the console with the remaining time until the next trigger
        Update-ConsoleWithRemainingTime -nextTriggerTime $nextTriggerTime -triggerWindowHours $triggerWindowHours

        # Trigger all instances once the timer reaches the trigger window
        Run-AllInstances
    }
}


# Function to check for PROVING states and run corresponding instances
function Check-And-Run-ProvingInstances {
    $provingInstancesFound = $false
    
    foreach ($instanceName in $instances.Keys) {
        $instance = $instances[$instanceName]
		
		# Display Message
		Log-Message "Checking State of '$instanceName'." "INFO"

        try {
            # Extract port number from the address argument
            $addressArgument = ($instance.Arguments -like "--address=*")[0]
            $port = $addressArgument.Split(":")[2].Trim("http://")

            # Perform gRPC call to check the state
            $response = & "$grpcurl" --plaintext -d '{}' "localhost:$port" spacemesh.v1.PostInfoService.PostStates 2>&1

            # Check if the response contains PROVING state
            if ($response -match '"state": "PROVING"') {
                $provingInstancesFound = $true
                Log-Message "PROVING state found for instance '$instanceName'. Running instance before proceeding." "INFO"
                Run-Instance -instanceName $instanceName -arguments $instance.Arguments
                Wait-ForServiceStopped -instanceName $instanceName
            }
            elseif ($response -match '"state": "IDLE"') {
                Log-Message "'$instanceName' shows IDLE." "INFO"
            }
            else {
                Log-Message "Unknown state for instance '$instanceName'." "WARNING"
            }
        }
        catch {
            Log-Message "Error occurred while checking state for instance '$instanceName': $_" "ERROR"
        }
    }
    
    # If no instances requiring proof were found, log a message before proceeding with the timer
    if (-not $provingInstancesFound) {
        Log-Message "No PoST Services found requiring proof, proceeding with timer..." "INFO"
    }
}



# Main entry point
Check-And-Run-ProvingInstances
Wait-ForTrigger
