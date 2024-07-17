<#
.SYNOPSIS
    Config for Multi Post-Tato Masher
.DESCRIPTION
    Contains all User configurable information to run Multi-Post-Tato-Masher for their environments.
.NOTES
    File Name: Masher_Config.ps1
#>

#Define location of grpcurl.exe. Default is directory script is ran from.
$grpcurl = ".\grpcurl.exe"

# Define log levels for console and logfile (set to INFO by default, can be set to DEBUG, INFO, WARN, ERROR)
$ConsoleLogLevel = "INFO"
$FileLogLevel = "INFO"

# Set Interval in seconds for Checking Post Service Status while running.
$provingCheckInterval = 60

# Define the variable to clear service log files (set to $false to keep service log files)
$clearServiceLogFiles = $true

#Choose Preset POET Cycle Gap. Set to 0 for Default12Hr Poet. Set to 1 for Team24Standard. Set to 2 for Team24Early. Set to 3 for Testnet13.
$triggerDateSetting = 0



# Define configurations for each set of POST Data. 
$instances = @{
    "Post1" = @{									#Name of each instance must match the identity.key associaited with that POST data set. (Example - Post1 for use with Post1.key.) 
        Arguments = @(
            "--address=http://localhost:9094",		#Node's gRPC address. Ensure it matches the node's grpc-post-listener config option.
            "--dir=./Post1",						#Post Data Directory, Set for each different set of Post Data.
            "--operator-address=127.0.0.1:50051",	#Operator API
            "--threads=1",							#Proving Options based on your hardware (Can be --threads or --pinned-cores, one or the other)
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


    # Add/Remove Posts with names and arguments for all Post Services needed.
}
