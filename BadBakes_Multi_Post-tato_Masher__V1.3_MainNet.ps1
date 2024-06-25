<#
.SYNOPSIS
    Script for orchestrating multiple PoST Proving service instances, sequentially, based on cycle gap timing.
.DESCRIPTION
    This script runs different instances of the PoST Proving "service.exe" sequentially, waits for each to complete before starting the next, and handles Cycle Gap timing.
.NOTES
    File Name: BadBakes_Multi_Post-tato_Masher__V1.3_MainNet.ps1
    Author: badbake
    Version: 1.3
#>


# Set the window title and load configuration settings
$WindowTitle = "Multi Post-tato Masher MainNet"
$host.ui.RawUI.WindowTitle = $WindowTitle
. ".\Masher_Config.ps1"

# Ensure log directory exists and initialize log file path
$logDirectory = ".\Logs"
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory
}
$logFileName = "PostMasher$((Get-Date).ToString('MMddyyyy_HHmm')).txt"
$logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName


# Function to log messages with timestamp and log level
function Log-Message {
    param (
        [string]$message,
        [string]$level = "INFO"  # Default level is INFO for log file
    )

    $logLevelHierarchy = @{
        "DEBUG" = 1
        "INFO" = 2
        "WARN" = 3
        "ERROR" = 4
    }

    if ($logLevelHierarchy[$level] -ge $logLevelHierarchy[$FileLogLevel]) {
        $timestamp = Get-Date -Format 'MM-dd-yyyy hh:mm:ss tt'
        $logMessage = "$timestamp - [$level] - $message"
        $logMessage | Out-File -Append -FilePath $logFilePath
    }

    if ($logLevelHierarchy[$level] -ge $logLevelHierarchy[$ConsoleLogLevel]) {
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

    Write-Host -NoNewline -ForegroundColor $timestampColor $timestamp
    Write-Host -NoNewline -ForegroundColor $timestampColor ": "
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

# Function to run a PoST service instance with the specified arguments
function Run-Instance {
    param (
        [string]$instanceName,
        [string[]]$arguments
    )

    $dirArgument = ($arguments -like "--dir=*")[0]
    $instanceDir = $dirArgument.Split("=")[1]
	
	#Log Message to display which 'Post' Instance is starting.
	Log-Message "Starting Instance for $instanceName" "INFO"
	
    $numUnits = GetNumUnitsForInstance -instanceDir $instanceDir

    $operatorAddressArgument = ($arguments -like "--operator-address=*")[0]
    $operatorAddress = $operatorAddressArgument.Split("=")[1]

    $idleResponse = '"state": "IDLE"'
    $provingResponse = '"state": "PROVING"'
    $previousState = ""
    $provingFound = $false
    $idleFound = $false
    $provingStateReached = $false
    $shutdownInitiated = $false
    $idleCounter = 0

    # Log for service.exe
    $serviceLogFileName = "${instanceName}_service$((Get-Date).ToString('MMddyyyy_HHmm')).txt"
    $serviceLogFilePath = Join-Path -Path $logDirectory -ChildPath $serviceLogFileName

    $addressArgument = ($arguments -like "--address=*")[0]
    $port = $addressArgument.Split(":")[2].Trim("http://")

    Log-Message "$instanceName is starting service.exe" "INFO"
    $serviceProcess = Start-Process -FilePath ".\service.exe" -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardError $serviceLogFilePath

    if ($serviceProcess -ne $null -and (Get-Process -Id $serviceProcess.Id -ErrorAction Inquire)) {
        Log-Message "$instanceName has started service.exe" "INFO"
    } else {
        Log-Message "$instanceName failed to start service.exe" "ERROR"
        return $null
    }

    do {
        Start-Sleep -Seconds $provingCheckInterval

        $response = & "$grpcurl" --plaintext -d '{}' "localhost:$port" spacemesh.v1.PostInfoService.PostStates 2>&1

        if (-not $response) {
            Log-Message "No response received from gRPC call." "ERROR"
            return
        }

        try {
            $jsonResponse = $response | ConvertFrom-Json
        } catch {
            Log-Message "Failed to convert response to JSON: $_" "ERROR"
            return
        }

        if (-not $jsonResponse) {
            Log-Message "Failed to convert response to JSON." "ERROR"
            return
        }

        foreach ($state in $jsonResponse.states) {
            Log-Message "Found '$($state.name)' with state '$($state.state)'." "DEBUG"
            if ($state.name -eq "$instanceName.key") {
                Log-Message "'$instanceName' matched in the response." "DEBUG"
                if ($state.state -eq "PROVING") {
                    $provingFound = $true
					$idleFound = $false
                    Log-Message "Proving found for '$instanceName'." "DEBUG"
                } elseif ($state.state -eq "IDLE") {
                    $idleFound = $true
					$provingFound = $false
                    Log-Message "Idle found for '$instanceName'." "DEBUG"
                }
            }
        }

        if ($provingFound -and $previousState -ne "PROVING") {
            Log-Message "PoST-Service '$instanceName' is beginning proof." "INFO"
            $provingStateReached = $true
			$ProofStartTime = Get-Date
            $previousState = "PROVING"
            $idleCounter = 0
		} elseif ($provingFound -and $previousState -eq "PROVING" -and $shutdownInitiated -eq $true) {
			Log-Message "Node still returning PROVING for '$instanceName'. Check Masher_Config for ${instanceName}." "WARN"
			Stop-PoST-Service -process $serviceProcess
			return
        } elseif ($idleFound -and $previousState -eq "PROVING" -and $shutdownInitiated -eq $true) {
            Log-Message "Node returning idle for '$instanceName'. Proof is assumed accepted by Node." "INFO"
            Stop-PoST-Service -process $serviceProcess
			CalculateProvingTime -ProofStartTime $ProofStartTime -ProofEndTime $ProofEndTime -instanceName $instanceName
            return
        } elseif ($provingFound -and $previousState -eq "PROVING") {
            Curl-ProvingProgress -operatorAddress $operatorAddress -numUnits $numUnits -arguments $arguments
            $shutdownInitiated = $true
			$ProofEndTime = Get-Date
            Log-Message "PoST-Service: '$instanceName' Checking Node..." "INFO"
        } elseif ($idleFound -and $previousState -ne "IDLE" -and -not $provingStateReached) {
            Log-Message "PoST-Service '$instanceName' is in the IDLE state." "INFO"
            $previousState = "IDLE"
            $idleCounter = 0
        } elseif ($idleFound -and $previousState -eq "IDLE") {
            $idleCounter++
            Log-Message "PoST-Service '$instanceName' continues to be in the IDLE state. Idle count: $idleCounter" "INFO"
            if ($idleCounter -ge 10) {
                $shutdownInitiated = $true
                Log-Message "PoST-Service '$instanceName' idle state detected $idleCounter times. Initiating shutdown." "INFO"
                Stop-PoST-Service -process $serviceProcess
                return
            }
        }
    } while ($true)
	
}

# Function to calculate Proving progress
function Curl-ProvingProgress {
    param (
        [string]$operatorAddress,
        [int]$numUnits,
        [string[]]$arguments
    )

    # Extract the --nonces value from the arguments
    $noncesArgument = ($arguments -like "--nonces=*")[0]
    $nonces = [int]($noncesArgument.Split("=")[1])
	
	$k2powStarted = $false
	$k2powMorePasses = $false
	$passcountTicker = 0

    while ($true) {
        # Send request to operator address
        $response = Invoke-Expression ("curl http://$operatorAddress/status") 2>$null -ErrorAction Inquire
        Log-Message "Response: $($response)" "DEBUG"

        if ($response -match "DoneProving") {
			Log-Message "Proving process completed" "INFO"
            return
        } elseif ($response -match "IDLE") {
            Log-Message "Proving process completed, returned to Idle state" "INFO"
            return
        }

        try {
            $jsonResponse = $response | ConvertFrom-Json
            if ($jsonResponse.Proving) {
                $start = $jsonResponse.Proving.nonces.start
                $end = $jsonResponse.Proving.nonces.end
                $position = $jsonResponse.Proving.position
				$passNumber = $end / $nonces

                if ($end -eq 0) {
                    Log-Message "PoST-Service is warming up..." "INFO"
                } elseif ($end -eq $nonces -and $k2powStarted -eq $false) {
                    Log-Message "PoST-Service has started k2pow." "INFO"
					$k2powStarted = $true
					$passcountTicker++
                } elseif ($passNumber -gt $passcountTicker -and $k2powStarted -eq $true) {
                    Log-Message "PoST-Service has started k2pow pass number: $passNumber" "INFO"
					$passcountTicker++
					$k2powMorePasses = $true
                } elseif ($k2powMorePasses -eq $true) {
                    # Existing logic to handle position-based progress
                    if ($position -eq (($numUnits * 68719476736) * ($passNumber - 1))) {							
                        Log-Message "Proving is in Pass ${passNumber}, Stage 1." "INFO"
                    } elseif ($position -gt (($numUnits * 68719476736) * ($passNumber - 1))) {					
                        $progressPercentage = [math]::Round(($position / (($numUnits * 68719476736) * ($passNumber - 1))) * 100, 0) #mainNet 
                        Log-Message "Math Result: ( $($position) / $($numUnits) ) x 100 = $($progressPercentage) /Pass $passNumber" "DEBUG"
                        Log-Message "Proving Post_Data Read: Progress $($progressPercentage)% /Pass $passNumber" "INFO"
					}
                } elseif ($k2powStarted -eq $true -and $k2powMorePasses -eq $false) {
                    # Existing logic to handle position-based progress
                    if ($position -eq (($numUnits * 68719476736) * ($passNumber - 1))) {
                        Log-Message "Proving is in Stage 1." "INFO"
                    } elseif ($position -gt (($numUnits * 68719476736) * ($passNumber - 1))) {
                        $progressPercentage = [math]::Round(($position / ($numUnits * 68719476736)) * 100, 0) #mainNet 
                        Log-Message "Math Result: ( $($position) / $($numUnits) ) x 100 = $($progressPercentage)" "DEBUG"
                        Log-Message "Proving Post_Data Read: Progress $($progressPercentage)%" "INFO"
					}
                } else {
                    Log-Message "PoST-Service has returned an error." "WARN"
                }

                Start-Sleep -Seconds $provingCheckInterval
            } else {
                Log-Message "PoST-Service has returned an error." "WARN"
                return $null
            }
        } catch {
            Log-Message "Failed to parse JSON response: $_" "ERROR"
            return $null
        }
    }
}


# Function to Calculate Approximate Proving Time
function CalculateProvingTime {
    param (
        [datetime]$ProofStartTime,
		[datetime]$ProofEndTime,
        [string]$instanceName
    )

    try {
        $ProofTotalTime = $ProofEndTime - $ProofStartTime
		
        $ProofHours = $ProofTotalTime.Hours
        $ProofMinutes = $ProofTotalTime.Minutes
        $ProofSeconds = $ProofTotalTime.Seconds

        $formattedProofTime = 'Hours={0:00} Minutes={1:00} Seconds={2:00}' -f $ProofHours, $ProofMinutes, $ProofSeconds
        
        if ($ProofTotalTime -gt 0) {
            Log-Message "CalculateProvingTime for ${instanceName}: Start time= ${ProofStartTime} End Time= ${ProofEndTime} Total Time = ${ProofTotalTime} Formatted Time= ${formattedProofTime}" "DEBUG"
            Log-Message "Approximate Proving Time for ${instanceName}: ${formattedProofTime}" "INFO"
			break
        }
		else {
            Log-Message "CalculateProvingTime for ${instanceName}: Start time= ${ProofStartTime} End Time= ${ProofEndTime} Total Time = ${ProofTotalTime} Formatted Time= ${formattedProofTime}" "DEBUG"
            Log-Message "Approximate Proving Time Failed for ${instanceName}" "WARN"
			break
		}
		
    } catch {
        Log-Message "CalculateProvingTime for ${instanceName}: Start time= ${ProofStartTime} End Time= ${ProofEndTime} Total Time = ${ProofTotalTime} ProofHours = ${ProofHours} ProofMinutes = ${ProofMinutes} ProofSeconds = ${ProofSeconds} Formatted Time= ${formattedProofTime}" "DEBUG"
        Log-Message "Failed to determine approximate proving time." "ERROR"
    }
}



# Function to clear service log files
function Clear-ServiceLogFiles {
    param (
        [string]$logDirectory,
        [string[]]$instances
    )
    
    foreach ($instanceName in $instances) {
        $logFilesPattern = "${instanceName}_service*.txt"
        $logFiles = Get-ChildItem -Path $logDirectory -Filter $logFilesPattern
        
        foreach ($logFile in $logFiles) {
            try {
                Remove-Item -Path $logFile.FullName -Force
                Log-Message "Cleared log file: $($logFile.FullName)" "DEBUG"
            } catch {
                Log-Message "Failed to delete log file: $($logFile.FullName). Error: $_" "ERROR"
            }
        }
    }
}

# Function to initiate shutdown of the process
function Stop-PoST-Service {
    param (
        [System.Diagnostics.Process]$process
    )

    try {
        $retryCount = 3
        $retryInterval = 2000

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

# Function to check the state of an instance
function Check-InstanceState {
    param (
        [PSCustomObject]$instance,
        [string]$instanceName
    )

    try {
        $addressArgument = ($instance.Arguments -like "--address=*")[0]
        $port = $addressArgument.Split(":")[2].Trim("http://")
        $response = & "$grpcurl" --plaintext -d '{}' "localhost:$port" spacemesh.v1.PostInfoService.PostStates 2>&1

        if (-not $response) {
            Log-Message "No response received from gRPC call." "ERROR"
            return $false
        }

        $jsonResponse = $response | ConvertFrom-Json

        if (-not $jsonResponse) {
            Log-Message "Failed to convert response to JSON." "ERROR"
            return $false
        }

        foreach ($state in $jsonResponse.states) {
            Log-Message "Found '$($state.name)' with state '$($state.state)'." "DEBUG"
            if ($state.name -eq "$instanceName.key") {
                Log-Message "Instance name '$instanceName' matched in the response." "DEBUG"
                if ($state.state -eq "PROVING") {
                    return $true
                }
            }
        }
    } catch {
        Log-Message "Error occurred while checking state for instance '$instanceName': $_" "ERROR"
    }
    return $false
}

# Function to run all instances sequentially
function Run-AllInstances {
    foreach ($instanceName in $instances.Keys) {
        $instance = $instances[$instanceName]
        Run-Instance -instanceName $instanceName -arguments $instance.Arguments
    }

    $instancesInProvingState = $false
    Log-Message "All Instances Ran. Re-Checking all Instances for PROVING state." "INFO"
    
    try {
        foreach ($instanceName in $instances.Keys) {
            $instance = $instances[$instanceName]
            Log-Message "Checking State of '$instanceName'." "DEBUG"

            if (Check-InstanceState -instance $instance -instanceName $instanceName) {
                $instancesInProvingState = $true
                Log-Message "PROVING state found. Running PoST-Service for '$instanceName'." "INFO"
                Run-Instance -instanceName $instanceName -arguments $instance.Arguments
            }
        }

        if ($instancesInProvingState) {
            $instancesInProvingState = $false
            Log-Message "Re-checking instances after running PoST-Service." "INFO"

            foreach ($instanceName in $instances.Keys) {
                $instance = $instances[$instanceName]
                Log-Message "Checking State of '$instanceName'." "DEBUG"

                if (Check-InstanceState -instance $instance -instanceName $instanceName) {
                    $instancesInProvingState = $true
                    Log-Message "PROVING state still found for '$instanceName'." "WARN"
					Show-WarningMessage "PROVING state still found for ${instanceName} Start and run service manually/Check Masher_Config for ${instanceName} and restart script."
                    break
                }
            }
        }

        if (-not $instancesInProvingState) {
            Log-Message "All PoST-Service's showing IDLE." "INFO"
            Log-Message "All PoST-Service's have completed proving." "INFO"
        }
    } catch {
        Log-Message "An error occurred: $_" "ERROR"
    }

    if ($clearServiceLogFiles) {
        Clear-ServiceLogFiles -logDirectory $logDirectory -instances $instances.Keys
    }
}


# Function to show a warning message in a new window without blocking script execution
function Show-WarningMessage {
    param (
        [string]$Message
    )
    
    Add-Type -AssemblyName PresentationFramework

    # Use a background job to display the message box
    Start-Job -ScriptBlock {
        param ($msg)
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show($msg, "Warning", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    } -ArgumentList $Message | Out-Null
}


# Function to calculate the next trigger time based on the user's local time zone
function Calculate-NextTriggerTime {
	$initialTriggerDateTimeUtc = [DateTime]::new(2024, 5, 12, 20, 00, 0) #mainnet
    $initialTriggerDateTimeLocal = $initialTriggerDateTimeUtc.ToLocalTime()
    $currentDateTimeLocal = Get-Date

    if ($currentDateTimeLocal -gt $initialTriggerDateTimeLocal) {
        $timeDifference = $currentDateTimeLocal - $initialTriggerDateTimeLocal
        # Calculate the number of full 1-day intervals that have passed
	$fullIntervals = [Math]::Floor($timeDifference.TotalDays / 14) #mainnet
        # Calculate the next trigger time by adding the necessary number of 1-day intervals to the initial trigger time
	$nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal.AddDays(($fullIntervals + 1) * 14) #mainnet
    } else {
        $nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal
    }

    Log-Message "Next Cycle Gap: $($nextTriggerDateTimeLocal.ToString('MM/dd/yyyy hh:mm:ss tt'))" "INFO"
    return $nextTriggerDateTimeLocal
}

# Function to update the console with the remaining time
function Update-ConsoleWithRemainingTime {
    param (
        [datetime]$nextTriggerTime
    )

    while ($true) {
        $timeDifference = $nextTriggerTime - (Get-Date)

        $remainingDays = [Math]::Floor($timeDifference.TotalDays)
        $remainingHours = $timeDifference.Hours
        $remainingMinutes = $timeDifference.Minutes
        $remainingSeconds = $timeDifference.Seconds

        $formattedRemainingTime = 'Days={0} Hours={1:00} Minutes={2:00} Seconds={3:00}' -f $remainingDays, $remainingHours, $remainingMinutes, $remainingSeconds

        Write-Host -NoNewline "`r                               - Time Remaining: $formattedRemainingTime"
        Start-Sleep -Seconds 1

        if ($timeDifference.TotalSeconds -le 1) {
            Write-Host
            Log-Message "Cycle Gap Reached. Beginning Instances of PoST-Service" "INFO"
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

        Update-ConsoleWithRemainingTime -nextTriggerTime $nextTriggerTime

        Run-AllInstances
    }
}

# Function to check for PROVING states and run corresponding instances
function Check-And-Run-ProvingInstances {
    $provingInstancesFound = $false
    
    foreach ($instanceName in $instances.Keys) {
        $instance = $instances[$instanceName]
        Log-Message "Checking State of '$instanceName'." "INFO"

        if (Check-InstanceState -instance $instance -instanceName $instanceName) {
            $provingInstancesFound = $true
            Log-Message "PROVING state found. Running PoST-Service for '$instanceName'." "INFO"
            Run-Instance -instanceName $instanceName -arguments $instance.Arguments
        }
    }
    
    # If no instances requiring proof were found, log a message before proceeding with the timer
    if (-not $provingInstancesFound) {
        Log-Message "No PoST-Services found requiring proof, proceeding with timer..." "INFO"
    }
	
    if ($clearServiceLogFiles) {
        Clear-ServiceLogFiles -logDirectory $logDirectory -instances $instances.Keys
    }
}

# Main entry point
Check-And-Run-ProvingInstances
Wait-ForTrigger
