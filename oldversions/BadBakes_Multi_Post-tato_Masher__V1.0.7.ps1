<#
.SYNOPSIS
    Script for waiting for PoEt Cycle Gaps to run different Post services 1 at a time on the same system in order. Then repeat the wait/run cycle.
.DESCRIPTION
    This script defines user-customizable parameters, functions to run different instances of the PoST Proving service.exe, waits for each iteration of the service to complete and stop,
    run all instances sequentially, calculates the next trigger time (Cycle Gap), and waits for a trigger command. For 1:N configurations


.NOTES
    File Name: bbMultiPostSeqSer.ps1
    Author: badbake
    Version: 1.0.7
    Last Updated: 5-13-2024

#>


# Set the window title
$WindowTitle = "Badbakes_Multi Post-tato_Masher__V1.0.7"
$host.ui.RawUI.WindowTitle = $WindowTitle
# Define user-customizable parameters

# Specify the log file directory
$logDirectory = ".\Logs"
# Don't Edit This section
$logFileName = "log$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
$logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName

# Define instance configurations for each set of Post Data. 
$instances = @{
    "Post1" = @{
        Arguments = @(
            "--address=http://localhost:9094",		#Node's gRPC address. Ensure it matches the node's grpc-post-listener config option.
            "--dir=../PostData1",					#Post Data Directory, Set for each different set of Post Data.
            "--operator-address=127.0.0.1:50051",	#Operator API (Can be the same for each instance since they run 1 at a time)
            "--threads=1",							#Proving Options based on your hardware
            "--nonces=128",							#Proving Options based on your hardware
            "--randomx-mode=fast"					#Proving Options based on your hardware
        )
    }
    "Post2" = @{
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=../PostData2",					#Set for Post DataDirectory 2
            "--operator-address=127.0.0.1:50051",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    "Post3" = @{
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=../PostData3",					#Set for Post DataDirectory 3
            "--operator-address=127.0.0.1:50051",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    # Add more Posts with names and arguments for all Post Services needed.
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

    # Extract port number from the address argument
    $addressArgument = ($arguments -like "--address=*")[0]
    $port = $addressArgument.Split(":")[2].Trim("http://")

    # Construct grpcurl command for the instance
    $grpcUrlCommand = ".\grpcurl.exe --plaintext -d '{}' localhost:$port spacemesh.v1.PostInfoService.PostStates"
    
    # Flag to track whether the instance has entered the "PROVING" state
    $provingStateReached = $false

    # Start the service.exe process with the current set of arguments and name.
	$serviceProcess = Start-Process -FilePath ".\service.exe" -ArgumentList $arguments -NoNewWindow -PassThru -Name $instanceName
	
	# Write a message indicating that service.exe for the instance has started, output to log.
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')$instanceName has started service.exe"
	"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')$instanceName has started service.exe" | Out-File -Append -FilePath $logFilePath
	
	# Create stream readers for both standard output and standard error streams of the process
	$outputStream = $serviceProcess.StandardOutput
	$errorStream = $serviceProcess.StandardError
	$outputStreamReader = [System.IO.StreamReader]::new($outputStream)
	$errorStreamReader = [System.IO.StreamReader]::new($errorStream)

	# Start asynchronously reading from the standard output and standard error streams
	while (-not ($outputStreamReader.EndOfStream -and $errorStreamReader.EndOfStream)) {
		if (-not $outputStreamReader.EndOfStream) {
			$outputLine = $outputStreamReader.ReadLine()
			$outputLine | Tee-Object -FilePath $logFilePath -Append
			Write-Host $outputLine
		}
		if (-not $errorStreamReader.EndOfStream) {
			$errorLine = $errorStreamReader.ReadLine()
			$errorLine | Tee-Object -FilePath $logFilePath -Append
			Write-Host $errorLine -ForegroundColor Red
		}
	}


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
        $serviceProcess = Get-Process -Name $instanceName 

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
        $serviceProcess = Get-Process -Name $instanceName 

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
	
}

# Define a function to calculate the next trigger time based on the user's local time zone
function CalculateNextTriggerTime {
    # Get the initial trigger date and time in UTC
    $initialTriggerDateTimeUtc = [DateTime]::new(2024, 5, 12, 19, 50, 0)		#Currently set to start trigger 10 minutes before the actual stated cycle gap time

    # Convert the initial trigger time to the user's local time zone
    $initialTriggerDateTimeLocal = $initialTriggerDateTimeUtc.ToLocalTime()

    # Get the current date and time in the user's local time zone
	Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Getting Current Date/Time"
	"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Getting Current Date/Time" | Out-File -Append -FilePath $logFilePath
    $currentDateTimeLocal = Get-Date

    # Check if the current time is greater than the initial trigger time
    if ($currentDateTimeLocal -gt $initialTriggerDateTimeLocal) {
        # Calculate the time difference between the current time and the initial trigger time
        $timeDifference = $currentDateTimeLocal - $initialTriggerDateTimeLocal

        # Calculate the number of full two-week intervals that have passed since the initial trigger time
        $fullIntervals = [Math]::Floor($timeDifference.TotalDays / 14)

        # Calculate the next trigger time by adding the appropriate number of two-week intervals to the initial trigger time
        $nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal.AddDays(($fullIntervals + 1) * 14)
    }
    else {
        # If the initial trigger time hasn't passed yet, set the next trigger time to the initial trigger time
        $nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal
    }

    # Display the next trigger date and time to the user in their local time zone
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Next trigger date and time: $nextTriggerDateTimeLocal"
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Next trigger date and time: $nextTriggerDateTimeLocal" | Out-File -Append -FilePath $logFilePath	

    return $nextTriggerDateTimeLocal
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

        }
    }



# Trigger the script to wait for the trigger command
WaitForTrigger