<#
.SYNOPSIS
    Configuration file for Multi Post-tato Masher.
.DESCRIPTION
    This script defines the configurations for each instance of the PoST Proving service used by Multi Post-tato Masher.
#>

# Configuration for each set of POST Data. 
$instances = @{
    "Post1" = @{                                    # Name of each instance must match the identity.key associated with that POST data set.
        Arguments = @(
            "--address=http://localhost:9094",       # Node's gRPC address. Ensure it matches the node's grpc-post-listener config option.
            "--dir=./Post1",                         # Post Data Directory, Set for each different set of Post Data.
            "--operator-address=127.0.0.1:50051",    # Operator API
            "--threads=1",                           # Proving Options based on your hardware
            "--nonces=128",                          # Proving Options based on your hardware
            "--randomx-mode=fast"                    # Proving Options based on your hardware
        )
    }
    "Post2" = @{                                    # Example - Post2 name for use with Post2.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post2",                         # Set for Post DataDirectory 2
            "--operator-address=127.0.0.1:50052",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    "Post3" = @{                                    # Example - Post3 name for use with Post3.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post3",                         # Set for Post DataDirectory 3
            "--operator-address=127.0.0.1:50053",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    "Post4" = @{                                    # Example - Post4 name for use with Post4.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post4",                         # Set for Post DataDirectory 4
            "--operator-address=127.0.0.1:50054",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    "Post5" = @{                                    # Example - Post5 name for use with Post5.key
        Arguments = @(
            "--address=http://localhost:9094",
            "--dir=./Post5",                         # Set for Post DataDirectory 5
            "--operator-address=127.0.0.1:50055",
            "--threads=1",
            "--nonces=128",
            "--randomx-mode=fast"
        )
    }
    # Add more Posts with names and arguments for all Post Services needed.
}
return $instances
