<#
.SYNOPSIS
    Script for managing multiple PoST Proving service instances sequentially based on cycle gaps.
.DESCRIPTION
    This script runs different instances of the PoST Proving service.exe sequentially, waits for each to complete, and handles trigger timing.
.NOTES
    File Name: bbMultiPostSeqSer.ps1
    Author: badbake
    Version: 1.1.1
    Last Updated: 2024-05-20
#>

# Set the window title
$WindowTitle = "Badbakes_Multi Post-tato_Masher__V1.1.1"
$host.ui.RawUI.WindowTitle = $WindowTitle
$grpcurl = Join-Path -Path $PSScriptRoot -ChildPath "grpcurl.exe"

# Define user-customizable parameters
$logDirectory = ".\Logs"
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory
}

$logFileName = "log$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
$logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName

# Define instance configurations for each set of Post Data
$instances = @{
    "Post1" = @{
        Arguments = @("--address=http://localhost:9094", "--dir=../PostData1", "--operator-address=127.0.0.1:50051", "--threads=1", "--nonces=128", "--randomx-mode=fast")
    }
    "Post2" = @{
        Arguments = @("--address=http://localhost:9094", "--dir=../PostData2", "--operator-address=127.0.0.1:50051", "--threads=1", "--nonces=128", "--randomx-mode=fast")
    }
    "Post3" = @{
        Arguments = @("--address=http://localhost:9094", "--dir=../PostData3", "--operator-address=127.0.0.1:50051", "--threads=1", "--nonces=128", "--randomx-mode=fast")
    }
}

# Function to log messages with timestamp
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "$timestamp - $message"
    Write-Host $logMessage
    $logMessage | Out-File -Append -FilePath $logFilePath
}

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
    $serviceLogFileName = "($instanceName)_serviceLog.txt"
    $serviceLogFilePath = Join-Path -Path $logDirectory -ChildPath $serviceLogFileName

    # Extract port number from the address argument
    $addressArgument = ($arguments -like "--address=*")[0]
    $port = $addressArgument.Split(":")[2].Trim("http://")

    # Flag for PROVING state
    $provingStateReached = $false

    Log-Message "$instanceName is starting service.exe"
    $serviceProcess = Start-Process -FilePath ".\service.exe" -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardError $serviceLogFilePath

    # Check if service process started successfully
    if ($serviceProcess -ne $null -and (Get-Process -Id $serviceProcess.Id -ErrorAction SilentlyContinue)) {
        Log-Message "$instanceName has successfully started Post Service."
    } else {
        Log-Message "$instanceName failed to start Post Service."
        return
    }

    $previousState = ""

    # Initial gRPC check
    $response = & "$grpcurl" --plaintext -d '{}' "localhost:$port" spacemesh.v1.PostInfoService.PostStates 2>&1
    Log-Message $response

    do {
        Start-Sleep -Seconds 300

        $response = & "$grpcurl" --plaintext -d '{}' "localhost:$port" spacemesh.v1.PostInfoService.PostStates 2>&1
        Log-Message $response

        if ($response -like "*$provingResponse*" -and $previousState -ne "PROVING") {
            Log-Message "PostService '$instanceName' is in the PROVING state."
            $provingStateReached = $true
            $previousState = "PROVING"
        } elseif ($response -like "*$provingResponse*" -and $previousState -eq "PROVING") {
            Log-Message "PostService '$instanceName' continues to be in the PROVING state."
        } elseif ($response -like "*$idleResponse*" -and $previousState -ne "IDLE" -and -not $provingStateReached) {
            Log-Message "PostService '$instanceName' is in the IDLE state."
            $previousState = "IDLE"
        } elseif ($response -like "*$idleResponse*" -and $previousState -eq "IDLE") {
            Log-Message "PostService '$instanceName' continues to be in the IDLE state."
        } elseif ($response -like "*$idleResponse*" -and $provingStateReached) {
            Log-Message "PostService '$instanceName' has completed PROVING and is now in the IDLE state. Initiating graceful shutdown."
            Stop-Gracefully -process $serviceProcess
            Remove-Item -Path $serviceLogFilePath
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
            Log-Message "Process did not exit gracefully within the timeout period. Forcing termination."
            $process.Kill()
        } else {
            Log-Message "Process exited gracefully."
        }
    } catch {
        Log-Message "An error occurred while attempting to stop the process gracefully: $_"
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
            Start-Sleep -Seconds 10
        } else {
            Start-Sleep -Seconds 10
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
    $initialTriggerDateTimeUtc = [DateTime]::new(2024, 5, 12, 19, 50, 0)

    $initialTriggerDateTimeLocal = $initialTriggerDateTimeUtc.ToLocalTime()
    $currentDateTimeLocal = Get-Date

    if ($currentDateTimeLocal -gt $initialTriggerDateTimeLocal) {
        $timeDifference = $currentDateTimeLocal - $initialTriggerDateTimeLocal
        $fullIntervals = [Math]::Floor($timeDifference.TotalDays / 14)
        $nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal.AddDays(($fullIntervals + 1) * 14)
    } else {
        $nextTriggerDateTimeLocal = $initialTriggerDateTimeLocal
    }

    Log-Message "Next trigger date and time: $nextTriggerDateTimeLocal"
    return $nextTriggerDateTimeLocal
}

# Function to wait for user input to trigger all instances
function Wait-ForTriggerInput {
    Write-Host "Press spacebar to start all instances..."
    do {
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode
    } while ($key -ne 32)

    Run-AllInstances
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
Wait-ForTriggerInput
