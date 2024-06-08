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
        # Sleep for a short duration before the first/next status check
        Start-Sleep -Seconds 300  # Adjust the duration as needed
		
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

        if ($serviceProcess) {
            # If the process is found, attempt to stop it
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found running instance of service.exe for '$instanceName'. Attempting to stop it."
			"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found running instance of service.exe for '$instanceName'. Attempting to stop it." | Out-File -Append -FilePath $logFilePath
            Stop-Process -Name $instanceName -Force
            # Wait for a brief period to allow the process to stop
            Start-Sleep -Seconds 10  # Adjust the duration as needed
        } else {
            # If the process is not found, wait for a brief period to ensure resource release
            Start-Sleep -Seconds 10  # Adjust the duration as needed
        }

        # Check again if the process is still running
        $serviceProcess = Get-Process -Name $instanceName -ErrorAction SilentlyContinue

        if (-not $serviceProcess) {
            # If the process is not found after the second check, consider it stopped and release resources
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - PostService '$instanceName' has stopped and released resources."
            return  # Exit the function if the service.exe process has stopped and released resources
        }

    } while ($true)  # Infinite loop until the service.exe process stops and releases resources
}

# Define a function to run all instances sequentially
function RunAllInstances {
    # Iterate through the instances and run each one sequentially
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

    # Get the current date and time in UTC
	Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Getting Current Date/Time"
	"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Getting Current Date/Time" | Out-File -Append -FilePath $logFilePath
    $currentDateTimeUtc = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"

    # Check if the initial trigger time is in the past
    if ($currentDateTimeUtc -gt $initialTriggerDateTimeUtc) {
        # Calculate the time difference between the current time and the initial trigger time
        $timeDifference = $currentDateTimeUtc - $initialTriggerDateTimeUtc

        # Calculate the number of full two-week intervals that have passed since the initial trigger time
        $fullIntervals = [Math]::Floor($timeDifference.TotalDays / 14)

        # Calculate the next trigger time by adding the appropriate number of two-week intervals to the initial trigger time
        $nextTriggerDateTimeUtc = $initialTriggerDateTimeUtc.AddDays(($fullIntervals + 1) * 14)
    }
    else {
        # Convert the initial trigger time to the user's local time zone
        $nextTriggerDateTimeUtc = $initialTriggerDateTimeUtc.ToLocalTime()
    }

    # Display the next trigger date and time to the user
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Next trigger date and time: $nextTriggerDateTimeUtc"
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Next trigger date and time: $nextTriggerDateTimeUtc" | Out-File -Append -FilePath $logFilePath
    
    return $nextTriggerDateTimeUtc
}

# Define a function to wait for the trigger command
function WaitForTrigger {
	
    while ($true) {
        # Get the next trigger time based on the user's local time zone
        $nextTriggerTime = CalculateNextTriggerTime

        # Calculate the time difference between the current date and time and the next trigger time
        $timeDifference = $nextTriggerTime - (Get-Date)

        # Status message: Waiting for trigger command
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Sleeping until PoEt Cycle Gap... $timeDifference"

        # Sleep until the next trigger time (PoEt Cycle Gap).
        if ($timeDifference.TotalSeconds -gt 0) {
            Start-Sleep -Seconds $timeDifference.TotalSeconds
        }

        # Trigger the script to run all instances
        RunAllInstances

        # Calculate the next trigger time relative to the current time
        $nextTriggerTime = CalculateNextTriggerTime

        # Calculate the time difference between the current date and time and the next trigger time
        $timeDifference = $nextTriggerTime - (Get-Date)

        # If the next trigger time is still in the future after running instances, sleep until then
        if ($timeDifference.TotalSeconds -gt 0) {
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Sleeping until PoEt Cycle Gap... $timeDifference"
            Start-Sleep -Seconds $timeDifference.TotalSeconds
        }
    }
}




# Trigger the script to wait for the trigger command
WaitForTrigger