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

# Define log levels for console and logfile (set to INFO by default, can be set to DEBUG, WARN, ERROR)
$ConsoleLogLevel = "INFO"
$FileLogLevel = "DEBUG"

# Set Interval in seconds for Checking Post Service Status while running.
$provingCheckInterval = 30

# Define the variable to clear service log files
$clearServiceLogFiles = $true


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
