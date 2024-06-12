<#
.SYNOPSIS
    Script for orchestrating multiple PoST Proving service instances, sequentially, based on cycle gap timing.
.DESCRIPTION
    This script runs different instances of the PoST Proving "service.exe" sequentially, waits for each to complete before starting the next, and handles Cycle Gap timing.
.NOTES
    File Name: BadBakes_Multi_Post-tato_Masher__V1.0.8_TESTNET.ps1
    Author: badbake
    Version: 1.1.1
    Last Updated: 2024-06-11
#>

# Set the window title
$WindowTitle = "Multi Post-tato Masher TESTNET"
$host.ui.RawUI.WindowTitle = $WindowTitle
$grpcurl = Join-Path -Path $PSScriptRoot -ChildPath "grpcurl.exe"

# Define log levels for console and logfile (set to INFO by default, can be set to DEBUG, WARN, ERROR)
$global:ConsoleLogLevel = "INFO"
$global:FileLogLevel = "DEBUG"

# Define Log Directory
$logDirectory = ".\Logs"
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory
}

# Set Interval in seconds for Checking Post Service Status while running.
$provingCheckInterval = 30

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
            "--nonces=64",							#Proving Options based on your hardware
            "--randomx-mode=fast"					#Proving Options based on your hardware
        )
    }
    "Post2" = @{									#Example - Post2 name for use with Post2.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post2",						#Set for Post DataDirectory 2
            "--operator-address=127.0.0.1:50052",
            "--threads=1",
            "--nonces=64",
            "--randomx-mode=fast"
        )
    }
    "Post3" = @{									
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post3",						
            "--operator-address=127.0.0.1:50053",
            "--threads=1",
            "--nonces=64",
            "--randomx-mode=fast"
        )
    }
    "Post4" = @{									
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post4",						
            "--operator-address=127.0.0.1:50054",
            "--threads=1",
            "--nonces=64",
            "--randomx-mode=fast"
        )
    }
    "Post5" = @{									
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post5",						
            "--operator-address=127.0.0.1:50055",
            "--threads=1",
            "--nonces=64",
            "--randomx-mode=fast"
        )
    }
    "Post6" = @{									
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post6",						
            "--operator-address=127.0.0.1:50056",
            "--threads=1",
            "--nonces=64",
            "--randomx-mode=fast"
        )
    }
    "Post7" = @{									
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post7",						
            "--operator-address=127.0.0.1:50057",
            "--threads=1",
            "--nonces=64",
            "--randomx-mode=fast"
        )
    }
    "Post8" = @{									
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post8",						
            "--operator-address=127.0.0.1:50058",
            "--threads=1",
            "--nonces=64",
            "--randomx-mode=fast"
        )
    }
    "Post9" = @{									
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post9",						
            "--operator-address=127.0.0.1:50059",
            "--threads=1",
            "--nonces=64",
            "--randomx-mode=fast"
        )
    }
    "Post10" = @{									
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post10",						
            "--operator-address=127.0.0.1:50060",
            "--threads=1",
            "--nonces=64",
            "--randomx-mode=fast"
        )
    }

    # Add/Remove Posts with names and arguments for all Post Services needed.
}

# Function to log messages with timestamp and log level
function Log-Message {
    param (
        [string]$message,
        [string]$level = "INFO"  # Default level is INFO for log file
    )

    # Define the log level hierarchy
    $logLevelHierarchy = @{
        "DEBUG" = 1
        "INFO" = 2
        "WARN" = 3
        "ERROR" = 4
    }

    # Only log messages that are equal to or higher than the current log level for file output
    if ($logLevelHierarchy[$level] -ge $logLevelHierarchy[$global:FileLogLevel]) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logMessage = "$timestamp - [$level] - $message"

        # Write to the log file without colors
        $logMessage | Out-File -Append -FilePath $logFilePath
    }

    # Only log messages that are equal to or higher than the current log level for console output
    if ($logLevelHierarchy[$level] -ge $logLevelHierarchy[$global:ConsoleLogLevel]) {
        # Colorize and write the log message to the console
        Colorize-Logs -message $message -level $level -timestamp $timestamp
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
            $timestampColor = "DarkBlue"
            $levelColor = "DarkCyan"
            $messageColor = "White"
        }
        "WARN" {
            $timestampColor = "DarkBlue"
            $levelColor = "Yellow"
            $messageColor = "Gray"
        }
        "DEBUG" {
            $timestampColor = "DarkBlue"
            $levelColor = "DarkYellow"
            $messageColor = "Gray"
        }
        "ERROR" {
            $timestampColor = "Red"
            $levelColor = "DarkRed"
            $messageColor = "Red"
        }
        default {
            $timestampColor = "DarkBlue"
            $levelColor = "White"
            $messageColor = "Gray"
        }
    }

    # Print the log message with color
    Write-Host -NoNewline -ForegroundColor $timestampColor $timestamp
    Write-Host -NoNewline " : "
    Write-Host -NoNewline -ForegroundColor $levelColor "[$level]"
    Write-Host -NoNewline " - "
    Write-Host -ForegroundColor $messageColor $message
}

# Function to get # of SU's from postdata_metadata.json
function GetNumUnitsForInstance {
    param (
        [string]$instanceDir
    )
    
    $metadataFilePath = Join-Path -Path $instanceDir -ChildPath "postdata_metadata.json"

    if (Test-Path -Path $metadataFilePath) {
        try {
            $metadataContent = Get-Content -Path $metadataFilePath | ConvertFrom-Json
            $numUnits = $metadataContent.NumUnits
            Log-Message "NumUnits for ${instanceName}: $numUnits" "INFO"
            return $numUnits
        } catch {
            Log-Message "Failed to read or parse ${metadataFilePath}: $_" "ERROR"
            return $null
        }
    } else {
	Log-Message "Metadata file not found at ${metadataFilePath}" "ERROR"
        return $null
    }
}

# Function to calculate Proving %
function Curl-ProvingProgress {
    param (
        [string]$operatorAddress,
        [int]$numUnits
    )

    while ($true) {
        $response = Invoke-Expression ("curl http://$operatorAddress/status") 2>$null -ErrorAction Inquire
		Log-Message " $($response) " "DEBUG"

        if ($response -match "DoneProving") {
            Log-Message "Proving process completed" "INFO"
            return
        } elseif ($response -match "IDLE") {
            Log-Message "Proving process completed, returned to Idle state" "INFO"
            return
        } elseif ($postStatus -match '^{.*}$') {
            $response | ConvertFrom-Json
		}
        try {
            $jsonResponse = $response | ConvertFrom-Json
            if ($jsonResponse.Proving -and $jsonResponse.Proving.nonces) {
                $position = $jsonResponse.Proving.position

                if ($position -eq 0) {
                    Log-Message "Proving is in Stage 1." "INFO"
                } elseif ($position -gt 0) {
                    #$progressPercentage = [math]::Round(($position / ($numUnits * 68719476736)) * 100, 0) MainNet 
					$progressPercentage = [math]::Round(($position / ($numUnits * 16384)) * 100, 0) #testNet
					Log-Message "Math Result: ( $($position) / $($numUnits) ) x 100 = $($progressPercentage)" "DEBUG"
                    Log-Message "Proving Post_Data Read: Progress $($progressPercentage)%" "INFO"
                }

                Start-Sleep -Seconds $provingCheckInterval
            } else {
                Log-Message "Unexpected JSON structure: Response = $($response) JsonResponse = $($jsonResponse) " "WARN"
                return $null
            }
        } catch {
            Log-Message "Failed to parse JSON response: $_" "ERROR"
            return $null
        }
    }
}



function Run-Instance {
    param (
        [string]$instanceName,
        [string[]]$arguments
    )

    # Extract directory from the arguments
    $dirArgument = ($arguments -like "--dir=*")[0]
    $instanceDir = $dirArgument.Split("=")[1]

    # Call GetNumUnitsForInstance to get the NumUnits value
    $numUnits = GetNumUnitsForInstance -instanceDir $instanceDir

    # Extract operator address from the arguments
    $operatorAddressArgument = ($arguments -like "--operator-address=*")[0]
    $operatorAddress = $operatorAddressArgument.Split("=")[1]

    # Expected responses and Flags
    $idleResponse = '"state": "IDLE"'
    $provingResponse = '"state": "PROVING"'
    $previousState = ""
    $provingFound = $false
    $idleFound = $false
    $provingStateReached = $false
    $shutdownInitiated = $false

    # Log for service.exe
    $serviceLogFileName = "${instanceName}_service$((Get-Date).ToString('MMddyyyy_HHmm')).txt"
    $serviceLogFilePath = Join-Path -Path $logDirectory -ChildPath $serviceLogFileName

    # Extract port number from the address argument
    $addressArgument = ($arguments -like "--address=*")[0]
    $port = $addressArgument.Split(":")[2].Trim("http://")

    # Start Service with Arguments for Instance
    Log-Message "$instanceName is starting service.exe" "INFO"
    $serviceProcess = Start-Process -FilePath ".\service.exe" -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardError $serviceLogFilePath

    # Check if service process started successfully
    if ($serviceProcess -ne $null -and (Get-Process -Id $serviceProcess.Id -ErrorAction Inquire)) {
        Log-Message "$instanceName has successfully started PoST-Service." "INFO"
    } else {
        Log-Message "$instanceName failed to start PoST-Service." "ERROR"
        return $null
    }

    do {
        Start-Sleep -Seconds $provingCheckInterval

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
            Log-Message "Found '$($state.name)' with state '$($state.state)'." "DEBUG"
            if ($state.name -eq "$instanceName.key") {  # Check if the name exactly matches the instance name with ".key" suffix
                Log-Message "'$instanceName' matched in the response." "DEBUG"
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
            Log-Message "PoST-Service '$instanceName' is PROVING." "INFO"
            $provingStateReached = $true
            $previousState = "PROVING"
        } elseif ($shutdownInitiated -eq $true) {
            Log-Message "Node returning idle for '$instanceName'. Proof is assumed accepted" "INFO"
            Stop-PoST-Service -process $serviceProcess
            return
        } elseif ($provingFound -and $previousState -eq "PROVING") {
            Curl-ProvingProgress -operatorAddress $operatorAddress -numUnits $numUnits
			$shutdownInitiated = $true
            Log-Message "PoST-Service '$instanceName' has completed PROVING. Checking Node..." "INFO"
        } elseif ($idleFound -and $previousState -ne "IDLE" -and -not $provingStateReached) {
            Log-Message "PoST-Service '$instanceName' is in the IDLE state." "INFO"
            $previousState = "IDLE"
        } elseif ($idleFound -and $previousState -eq "IDLE") {
            Log-Message "PoST-Service '$instanceName' continues to be in the IDLE state." "INFO"
        }
    } while ($true)
}



# Function to initiate a graceful shutdown of the process
function Stop-PoST-Service {
    param (
        [System.Diagnostics.Process]$process
    )

    try {
        # Send a termination signal and wait for the process to exit
        $retryCount = 3
        $retryInterval = 5000  # 5 seconds

        for ($i = 0; $i -lt $retryCount; $i++) {
            if ($process.HasExited) {
                Log-Message "PoST-Service ended successfully." "INFO"
                return
            }
            Log-Message "Sending termination signal to PoST-Service..." "INFO"
            Stop-Process -Id $process.Id -Force:$false

            Log-Message "Waiting for process to exit..." "INFO"
            Start-Sleep -Milliseconds $retryInterval
        }

        # If the process is still not exited, forcefully terminate it
        if (-not $process.HasExited) {
            Log-Message "PoST-Service did not exit within the timeout period. Forcing termination." "WARN"
            $process.Kill()
            $process.WaitForExit()
        }

        Log-Message "PoST-Service ended successfully." "INFO"
    } catch {
        Log-Message "An error occurred while attempting to stop the PoST-Service: $_" "ERROR"
    }
}


# Function to run all instances sequentially
function Run-AllInstances {
    foreach ($instanceName in $instances.Keys) {
        $instance = $instances[$instanceName]
        Run-Instance -instanceName $instanceName -arguments $instance.Arguments
    }

    # Check if any instances are still in PROVING state and run them again
    $instancesInProvingState = $false
	Log-Message "All Instances Ran. Re-Checking all Instances for PROVING state." "INFO"
	
    foreach ($instanceName in $instances.Keys) {
        $instance = $instances[$instanceName]
		
		# Display Message
		Log-Message "Checking State of '$instanceName'." "DEBUG"

        try {
            # Extract port number from the address argument
            $addressArgument = ($instance.Arguments -like "--address=*")[0]
            $port = $addressArgument.Split(":")[2].Trim("http://")

            # Perform gRPC call to check the state
            $response = & "$grpcurl" --plaintext -d '{}' "localhost:$port" spacemesh.v1.PostInfoService.PostStates 2>&1

            # Check if the response is empty or if there's an error
            if (-not $response) {
                Log-Message "No response received from gRPC call." "ERROR"
                continue
            }

            # Convert response to JSON
            try {
                $jsonResponse = $response | ConvertFrom-Json
            } catch {
                Log-Message "Failed to convert response to JSON: $_" "ERROR"
                continue
            }

            # Check if JSON conversion was successful
            if (-not $jsonResponse) {
                Log-Message "Failed to convert response to JSON." "ERROR"
                continue
            }

            # Now continue with processing the JSON response
            foreach ($state in $jsonResponse.states) {
                Log-Message "Found '$($state.name)' with state '$($state.state)'." "DEBUG"
                if ($state.name -eq "$instanceName.key") {  # Check if the name exactly matches the instance name with ".key" suffix
                    Log-Message "Instance name '$instanceName' matched in the response." "DEBUG"
                    if ($state.state -eq "PROVING") {
                        $instancesInProvingState = $true
                        Log-Message "PROVING state found. Running PoST-Service for '$instanceName'." "INFO"
                        Run-Instance -instanceName $instanceName -arguments $instance.Arguments
                    } elseif ($state.state -eq "IDLE") {
                        Log-Message "'$instanceName' shows IDLE." "DEBUG"
                    } else {
                        Log-Message "Unknown state for instance '$instanceName'." "WARN"
                    }
                    break
                }
            }
        }
        catch {
            Log-Message "Error occurred while checking state for instance '$instanceName': $_" "ERROR"
        }
    }
    # If no instances requiring proof were found after running and checking again. Proceed.
    if (-not $instancesInProvingState) {
        Log-Message "All PoST-Service's showing IDLE." "INFO"
		Log-Message "All PoST-Service's have completed proving." "INFO"
    }
}



# Function to calculate the next trigger time based on the user's local time zone
function Calculate-NextTriggerTime {
    # Define the initial trigger date and time in UTC
    $initialTriggerDateTimeUtc = [DateTime]::new(2024, 6, 6, 23, 00, 0) #testnet12
	#$initialTriggerDateTimeUtc = [DateTime]::new(2024, 5, 12, 20, 00, 0) #mainnet

    # Convert the initial trigger time to the local time zone
    $initialTriggerDateTimeLocal = $initialTriggerDateTimeUtc.ToLocalTime()
    # Get the current date and time in the local time zone
    $currentDateTimeLocal = Get-Date

    # Check if the current date and time is past the initial trigger time
    if ($currentDateTimeLocal -gt $initialTriggerDateTimeLocal) {
        # Calculate the time difference between the current time and the initial trigger time
        $timeDifference = $currentDateTimeLocal - $initialTriggerDateTimeLocal
        # Calculate the number of full 1-day intervals that have passed
        $fullIntervals = [Math]::Floor($timeDifference.TotalDays) #testnet12
		#$fullIntervals = [Math]::Floor($timeDifference.TotalDays / 14) #mainnet
        # Calculate the next trigger time by adding the necessary number of 1-day intervals to the initial trigger time
        $nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal.AddDays($fullIntervals + 1) #testnet12
		#$nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal.AddDays(($fullIntervals + 1) * 14) #mainnet
    } else {
        # If the current time is before the initial trigger time, the next trigger time is the initial trigger time
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
        if ($timeDifference.TotalSeconds -le 1) {
            Write-Host
			Log-Message "Running POST Services" "INFO"
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

            # Check if the response is empty or if there's an error
            if (-not $response) {
                Log-Message "No response received from gRPC call." "ERROR"
                continue
            }

            # Convert response to JSON
            try {
                $jsonResponse = $response | ConvertFrom-Json
            } catch {
                Log-Message "Failed to convert response to JSON: $_" "ERROR"
                continue
            }

            # Check if JSON conversion was successful
            if (-not $jsonResponse) {
                Log-Message "Failed to convert response to JSON." "ERROR"
                continue
            }

            # Now continue with processing the JSON response
            foreach ($state in $jsonResponse.states) {
                Log-Message "Found '$($state.name)' with state '$($state.state)'." "DEBUG"
                if ($state.name -eq "$instanceName.key") {  # Check if the name exactly matches the instance name with ".key" suffix
                    Log-Message "Instance name '$instanceName' matched in the response." "DEBUG"
                    if ($state.state -eq "PROVING") {
                        $provingInstancesFound = $true
                        Log-Message "PROVING state found. Running PoST-Service for '$instanceName'." "INFO"
                        Run-Instance -instanceName $instanceName -arguments $instance.Arguments
                    } elseif ($state.state -eq "IDLE") {
                        Log-Message "'$instanceName' shows IDLE." "DEBUG"
                    } else {
                        Log-Message "Unknown state for instance '$instanceName'." "WARN"
                    }
                    # Break out of the loop once the correct instance is found
                    break
                }
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
