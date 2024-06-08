# Define user-customizable parameters

# Specify the log file directory
$logDirectory = ".\Logs"
# Don't Edit This section
$logFileName = "log$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
$logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName

# Define instance configurations for each set of Post Data
$instances = @{
    "Post1" = @{
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=../data1",
            "--operator-address=127.0.0.1:50051",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    "Post2" = @{
        Arguments = @(
            "--address=http://localhost:9084",
            "--dir=../data2",
            "--operator-address=127.0.0.1:50052",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    "Post3" = @{
        Arguments = @(
            "--address=http://localhost:9074",
            "--dir=../data3",
            "--operator-address=127.0.0.1:50053",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    # Add more Posts with names and arguments for the service as needed
}

# End of user-customizable parameters


# Define a function to run an instance
function RunInstance {
    param (
        [string]$instanceName,
        [string[]]$arguments
    )
	

    # Define the expected responses for grpcurl
    $idleResponse = '"state": "IDLE"'
    $provingResponse = '"state": "PROVING"'

    # Extract operator port number from operator address
    $operatorAddress = ($arguments -like "--operator-address=*")[0]
    $operatorPort = $operatorAddress.Split(":")[1]

    # Construct grpcurl command for the instance
    $grpcUrlCommand = ".\grpcurl.exe --plaintext -d '{}' localhost:$operatorPort spacemesh.v1.PostInfoService.PostStates"
	
	# Flag to track whether the instance has entered the "PROVING" state
    $provingStateReached = $false

    # Start the service.exe process with the current set of arguments and name. Output to log.
	"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Service.exe for instance '$instanceName' has started." | Out-File -Append -FilePath $logFilePath
    $serviceProcess = Start-Process -FilePath ".\service.exe" -ArgumentList $arguments -NoNewWindow -PassThru -Name $instanceName -RedirectStandardOutput $logFilePath
	
	# Write a message indicating that service.exe for the instance has started
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')$instanceName has started service.exe"
	  
	# Flag to track the previous state
    $previousState = ""

    do {
        # Use the specific grpcurl.exe command to check the status of service.exe
        $response = & $grpcUrlCommand

        # Check if response indicates service is in the "PROVING" state
        if ($response -like "*$provingResponse*" -and $previousState -ne "PROVING") {
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - PostService '$instanceName' is in the PROVING state."
			"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - PostService '$instanceName' is in the PROVING state." | Out-File -Append -FilePath $logFilePath
            $provingStateReached = $true
			$previousState = "PROVING"
        }
		elseif ($response -like "*$provingResponse*" -and $previousState -eq "PROVING") {
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - PostService '$instanceName' is in the PROVING state."
        }

        # Check if response indicates service is in the "IDLE" state
        if ($response -like "*$idleResponse*" -and $provingStateReached -eq $false -and $previousState -ne "IDLE") {
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - PostService '$instanceName' is in the IDLE state."
			"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - PostService '$instanceName' is in the IDLE state." | Out-File -Append -FilePath $logFilePath
			$previousState = "IDLE"
        }
		elseif ($response -like "*$idleResponse*" -and $provingStateReached -eq $false -and $previousState -eq "IDLE") {
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - PostService '$instanceName' is in the IDLE state."
        }
        elseif ($response -like "*$idleResponse*" -and $provingStateReached -eq $true) {
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - PostService '$instanceName' is in the IDLE state. Stopping service."
			"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - PostService '$instanceName' is in the IDLE state. Stopping service." | Out-File -Append -FilePath $logFilePath
            # Stop the service.exe process
            Stop-Process -Name $instanceName
			# Reset flags for next iteration
			$provingStateReached = $false
			$previousState = ""
            return  # Exit the function
			
        }

        # Sleep for a short duration before the next attempt (optional)
        Start-Sleep -Seconds 300  # Adjust the duration as needed

    } while ($true)  # Infinite loop
}

# Define a function to wait for the service.exe process to stop and release resources
function WaitForServiceStopped {
    param (
        [string]$instanceName
    )

    do {
        # Check if the service.exe process is still running
        $serviceProcess = Get-Process -Name $instanceName -ErrorAction SilentlyContinue

        if (-not $serviceProcess) {
            # If the process is not found, wait for a brief period to ensure resource release
            Start-Sleep -Seconds 10  # Adjust the duration as needed

            # Check again if the process is still not found
            $serviceProcess = Get-Process -Name $instanceName -ErrorAction SilentlyContinue

            # If the process is still not found, consider it stopped and release resources
            if (-not $serviceProcess) {
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - PostService '$instanceName' has stopped and released resources."
                return  # Exit the function if the service.exe process has stopped and released resources
            }
        }

        # Sleep for a short duration before the next attempt (optional)
        Start-Sleep -Seconds 30  # Adjust the duration as needed

    } while ($true)  # Infinite loop until the service.exe process stops and releases resources
}

# Define a function to run all instances sequentially
function RunAllInstances {
    # Loop through the instances
    foreach ($instanceName in $instances.Keys) {
        $instance = $instances[$instanceName]
        $arguments = $instance.Arguments

        # Call RunInstance function for each instance
        RunInstance -instanceName $instanceName -arguments $arguments

        # Wait for the current instance to stop service.exe before starting the next one
        WaitForServiceStopped -instanceName $instanceName
    }

    # Output a message indicating that all instances have completed
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - All PostServices have completed."
	"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - All PostServices have completed." | Out-File -Append -FilePath $logFilePath
	
    # Get the next trigger time based on the user's local time zone
    $nextTriggerDateTimeLocal = CalculateNextTriggerTime

}

# Define a function to calculate the next trigger time based on the initial indicated trigger date and time
function CalculateNextTriggerTime {
    # Get the initial trigger date and time in UTC
    $initialTriggerDateTimeUtc = [DateTime]::new(2024, 5, 12, 19, 50, 0)

    # Get the current date and time in the user's local time zone
	Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Getting Local Time"
	"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Getting Local Time" | Out-File -Append -FilePath $logFilePath
    $currentDateTimeLocal = Get-Date

    # Convert the initial trigger time to the user's local time zone
    $initialTriggerDateTimeLocal = $initialTriggerDateTimeUtc.ToLocalTime()

    # Calculate the time difference between the current time and the initial trigger time
	Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Calculating time to next Cycle Gap"
	"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Calculating time to next Cycle Gap" | Out-File -Append -FilePath $logFilePath
    $timeDifference = New-TimeSpan -Start $initialTriggerDateTimeLocal -End $currentDateTimeLocal

    # Calculate the number of full two-week intervals that have passed since the initial trigger time
    $fullIntervals = [Math]::Floor($timeDifference.TotalDays / 14)

    # Calculate the next trigger time by adding the appropriate number of two-week intervals to the initial trigger time
    $nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal.AddDays(($fullIntervals + 1) * 14)
	
	# Display the next trigger date and time to the user
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Next trigger date and time: $nextTriggerDateTimeLocal"
	"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Next trigger date and time: $nextTriggerDateTimeLocal" | Out-File -Append -FilePath $logFilePath

    return $nextTriggerDateTimeLocal
}


# Define a function to wait for the trigger command
function WaitForTrigger {

    # Get the next trigger time based on the user's local time zone
    $nextTriggerTime = CalculateNextTriggerTime

    # Calculate the time difference between the current date and time and the next trigger time
    $timeDifference = New-TimeSpan -Start (Get-Date) -End $nextTriggerTime
	
	# Status message: Waiting for trigger command
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Sleeping until PoEt Cycle Gap... $timeDifference"
	"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Sleeping until PoEt Cycle Gap..." | Out-File -Append -FilePath $logFilePath
	
    # Wait for the calculated time difference
    Start-Sleep -Seconds $timeDifference.TotalSeconds

    # Trigger the script to run all instances
    while ($true) {
        RunAllInstances
        # Wait for two weeks before running the instances again
        Start-Sleep -Seconds (2 * 7 * 24 * 60 * 60)  # 2 weeks
    }
}

# Trigger the script to wait for the trigger command
WaitForTrigger