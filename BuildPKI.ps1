function Build_PKI {
    #Generate folders for SSL stuff
    New-Item -ItemType Directory -Path ssl > $null 2>&1
    New-Item -ItemType Directory -Path ssl\root-ca > $null 2>&1
    #Create a new private key for the root CA
    openssl genrsa -out "ssl\root-ca\root_ca.pem" 2048
    
    #Create a new self-signed ceritificate for the root CA
    openssl req -x509 -new -nodes -key "ssl\root-ca\root_ca.pem" -sha512 -days 3650 -subj "/CN=root-ca" -out "ssl\root-ca\root_ca.crt"
    
    if ((Test-Path "ssl\root-ca\root_ca.pem") -and (Test-Path "ssl\root-ca\root_ca.crt")) {
        Write-Host "Key and certificate generated successfully."
    } else {
        Write-Host "Private key and certificate generation failed."
    }
}

#Check if our CA/PKI has been built yet. If not, build it.
if ((Test-Path "ssl\root-ca\root_ca.pem") -and (Test-Path "ssl\root-ca\root_ca.crt") -and (Test-Path "ssl")) {
    Write-Host "PKI exists already. Proceeding"
} else {
    $local:Rebuild = Read-Host "PKI malformed or not present. Would you like to build a new CA? Yes or No?"
    if($Rebuild -eq "YES"){
        Build_PKI
        .\Alice.ps1
    } else {
        Write-Host "Exiting."
    }
}


