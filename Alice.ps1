
$Users = @()
function Init_PKI {
    if ((Test-Path "ssl\root-ca\root_ca.pem") -and (Test-Path "ssl\root-ca\root_ca.crt") -and (Test-Path "ssl")) {
        Write-Host "PKI init success."
        Function_Select
    } else {
        $local:Selection = Read-Host "PKI malformed or not present. Would you like to view the PKI build tool? YES or NO"
        if($Selection -eq "YES"){
            .\BuildPKI.ps1
        } else {
            Write-Host "Exiting."
        }
    }   
}

function Send_Message {
    function Choose_Recipient {
    #Confirm users file exists before we start so the whole script doesn't explode
        if (Test-Path "users.json") {
            $Users = @(Get-Content "users.json" -Raw | ConvertFrom-Json | ForEach-Object { $_ })
        } else {
            $Users = @()
        }   

    #Verifying recipient exists
    $Script:Recipient = $Users | Where-Object { $_.Username -eq (Read-Host "Who would you like to send a message to?")}
        if ( $null -ne $Recipient ){
        } else { 
            Write-Host "User not found. Please input another username. "
            Choose_Recipient
        }
    }    

    function Build_Message {
        #Build PSCustomObject for our new message
        $local:NewMessage = [PSCustomObject]@{
            Sender = $SessionToken.UserName
            Recipient = ""
            MessageID = Get-Random
            SentTime = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
            Message = ""
            MessageSubject = ""
            MessageName = ""
            MessageFile = ""
            SignatureName = ""
            SignatureFile = ""
            Encrypted = ""
            Certificate = ""

        }

        #Fill in properties of new message object
        Choose_Recipient

        $local:NewMessage.Recipient = $Recipient.UserName
        $local:NewMessage.Message = Read-Host "What would you like to say to $($NewMessage.Recipient)?"
        $local:NewMessage.MessageSubject = Read-Host "About What? (Subject)"
        $local:RecipientMailbox = "users\$($Recipient.UserID)\mailbox"

        $local:NewMessage.MessageName = "$($Recipient.UserID)" + "_" + "$($SessionToken.UserID)" + "_" + (Get-Date -Format "MM_dd_yyyy_HH_mm_ss") + ".json"
        $local:NewMessage.MessageFile = Join-Path $RecipientMailbox $NewMessage.MessageName 

        $local:NewMessage.SignatureName = "$($Recipient.UserID)" + "_" + "$($SessionToken.UserID)" + "_" + (Get-Date -Format "MM_dd_yyyy_HH_mm_ss") + ".sign"
        $local:NewMessage.SignatureFile = Join-Path $RecipientMailbox $NewMessage.SignatureName 

        return $NewMessage
        
    }

    #Validate Session Token before continuing
    if (Validate_Token -eq "VALID"){
        Write-Host "Session token is valid. Proceed."
    } else {
        Write-Host "Session token is invalid. Please try again."
        Function_Select
        return $null
    }

    #Get our NewMessage object from the Build_Message function, use that as our primary object to pull data from to actually send our message
    $Global:Recipient = @()
    $local:NewMessage = Build_Message
    $local:MessageSender = $Users | Where-Object { $_.Username -eq $SessionToken.UserName} | Select-Object
    
    #Check if the mailbox exists and is working before doing anything more.
    if (Test-Path "users\$($Recipient.UserID)\mailbox") {
		
		$NewMessage.Certificate = $MessageSender.Certificate
		
        $local:ToEncrypt = Read-Host "Would you like to encrypt the contents of this message? YES or NO"
        if($ToEncrypt -eq "YES"){
			
            $local:NewMessage.Encrypted = "TRUE"
			
			#Encrypt the message if it's requested. Essentially, pull the "Message" field out of the NewMessage object, encrypt THAT, and then shove it back into the message JSON later.
			#OpenSSL is really picky about inputs and I can't pipe variables directly in (At least to my understanding), so I need to create temp files, do my operations and then pipe them back in.
    
            
            $local:UnencryptedFile = "$env:TEMP\message.txt"
            $local:EncryptedFile = "$env:TEMP\message_enc.bin"

            Set-Content -Path "$env:TEMP\message.txt" -Value $NewMessage.message
            openssl pkeyutl -encrypt -certin -inkey $NewMessage.Certificate -in $UnencryptedFile -out $EncryptedFile 

            $NewMessage.Message = [System.IO.File]::ReadAllBytes($EncryptedFile)
            Write-Host "Message encryption complete."
			
        } elseif ($ToEncrypt -eq "NO") {
			
            $local:NewMessage.Encrypted = "FALSE"
			
        } else {
			
            $local:NewMessage.Encrypted = "FALSE"
			
        }

        #Create the message file and sign it. Set the certificate key field on the json object, so people know which cert can be used to verify it.
        Out-File  -FilePath $($NewMessage.MessageFile)
        $NewMessage | ConvertTo-Json |  Set-Content $($NewMessage.MessageFile)
        openssl dgst -sha256 -sign $MessageSender.PrivateKey -out $NewMessage.SignatureFile $NewMessage.MessageFile        

        #Check if it worked.
        if (Test-Path $NewMessage.SignatureFile) {
            Start-Sleep -Seconds 1
            Write-Host "Message successfully sent with SHA256 signature!"
            Start-Sleep -Seconds 1
            Main_Menu
        } else {
            Write-Host "Message send failed. Please try again."
            Main_Menu
        }
    } else {
        Write-Host "Mailbox does not exist. Contract your system administrator for more information."
    }

    $Newmessage = $null
}

function Validate_Certificate {
	
    param(
    [object]$User
    )
	
    if ($User.Certificate) {
		
        $Cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $PSScriptRoot $User.Certificate.Trim())) 
        if($Cert.NotAfter -gt (Get-Date)){
			
            Return "VALID"
			
        } else {
			
            Return "INVALID"
			
        }

    } else {
		
        Write-Host "Certificate is not present."
		
        }   
}

function Read_Messages {
	
	cls
	$Selection = ""
	
	#Message selection menu logic. If it's "" or null, ask for an index. If it's in the array, open the message. If it's neither, ask for input again.
	function Select_Message {
		
		Write-Host $selection
		if ($Selection -eq "exit"){
			
			$Selection = ""
			Main_Menu
			
			
		} elseif (($Selection -eq "") -or ($Selection -eq $null)) {
			
			$Selection =  Read-Host "Welcome Back $($SessionToken.Username). Please input the index of a message you would like to view, or 'EXIT'"
			Select_Message
			
		} elseif($Selection = $MessageArray | Where-Object { $_.Index -eq $Selection } | Select-Object ) {
			
			Open_Message -Message $Selection
			Selection = ""
			
		} else {
			
			$Selection = Read-Host "Selection not found. Please input the index of the message you would like to view, or 'EXIT'"
			Select_Message
			
		} 
	}

	function Open_Message {
		param(
        [object]$Message
		)
		
		cls
		
		Write-Host "From: $($Message.From)"
		Write-Host "To: $($Message.To)"
		Write-Host "Subject: $($Message.Subject)"
		Write-Host "Message Sent: $($Message.Time_Sent)"
		
		if($Message.Message_Verified -eq "Verified OK"){
			Write-Host "Message Verified OK" -ForegroundColor "Green"
		} else {
			Write-Host "Message Verification FAIL" -ForegroundColor "Red"
		}
		
		if($Message.Message_Encrypted -eq "TRUE"){
			Write-Host "Message Encrypted" -ForegroundColor "Cyan"
			
            $local:EncryptedFile = "$env:TEMP\message_enc.bin"
            $EncryptedFile = [System.IO.File]::ReadAllBytes($EncryptedFile)
			
			$local:UnencryptedFile = "$env:TEMP\message.txt"
			$local:CurrentUser = $Users | Where-Object { $_.Username -eq $SessionToken.UserName} | Select-Object
			
			openssl pkeyutl -decrypt -in $EncryptedFile -out $UnencryptedFile -inkey $CurrentUser.PrivateKey > $null 2>&1
			
			$Message.Message = Get-Content $UnencryptedFile
			
		} else {
		}
		
		Write-Host ""
		Write-Host $($Message.Message) 
		
		$local:Selection = Read-Host "When finished, type 'exit'"
	
		if ($local:Selection = "EXIT"){
			Read_Messages
		}
		
	}
	
	
    #Validate Session Token before starting
    if (Validate_Token -eq "VALID"){      

    } else {
		
        Write-Host "Session Token Invalid. Please login again."
        Function_Select
        return $null
		
    }
 
    #Set $Messages to an array containing all the .json message files in our mailbox. Initialize $MessageArray. Reset $I
	$i = 0
	$local:Messages = @() 
    $local:Messages = @(Get-ChildItem "users\$($SessionToken.UserID)\mailbox\*.json")
    $local:MessageArray = @()
    Write-Host "You Have" $Messages.Count "Messages."
    
    #Go through each message in $Messages and pull data from them to display to the terminal.
    $Messages | ForEach-Object {
        
        $Local:Message = @(Get-Content "$($_.FullName)" | ConvertFrom-Json | ForEach-Object { $_ }) 
        
        #Check SSL signing with OpenSSL. OpenSSL doesn't like outputs being piped in directly, so we need to crack the cert for the public .PEM, and then feed that into the verify command.
        $Local:PubKey = openssl x509 -pubkey -noout -in $Message.Certificate
        Set-Content -Path "$env:TEMP\pubkey.pem" -Value $PubKey
        $Local:MessageVerified = openssl dgst -sha256 -verify $env:TEMP\pubkey.pem -signature $Message.SignatureFile $Message.MessageFile

        if($MessageVerified -eq "Verified OK"){
        } else {
            $MessageVerified = "Verfied FAIL"
        }
		
		#Get a PSCustomObject for each message.
        $Local:MessageObject = [PSCustomObject]@{
            Index        = $i++
            From = $Message.Sender
            To = $Message.Recipient
            Time_Sent = $Message.SentTime
            Subject         = $Message.MessageSubject
            Message_Verified = $MessageVerified
            Message_Encrypted = $Message.Encrypted
        }
		
		$local:MessageObject
		
		#Construct $MessageArray out of these objects. This is done AFTER displaying them in the list, so the MessageObject we use later isn't displayed with the message, but has it tacked on after.
		$MessageObject | Add-Member -NotePropertyName "Message" -NotePropertyValue "$($Message.Message)"
		$Local:MessageArray += $MessageObject
		
    } | Format-Table -AutoSize
	
	Select_Message
	$i = 0
	
	
}

function Login {
	
	$Selection = ""
	
    #Confirm users file exists before we start so the whole script doesn't explode
    if (Test-Path "users.json") {
		
            $Users = @(Get-Content "users.json" -Raw | ConvertFrom-Json | ForEach-Object { $_ })
			
        } else {
			
            $Users = @()
        }
		
    
    #Ask for a username, and make sure it exists in the database before proceeding
    $local:Username = Read-Host "Please Enter Username:"

    if ($local:User = $Users | Where-Object { $_.Username -eq $Username } | Select-Object ){
    } else {
		
        $local:Selection = Read-Host "User not found. Would you like to try to login again? YES or NO?"
		
        if ($Selection -eq "YES"){
			
			$Selection = ""
            Login
			
        } elseif ($Selection = "NO"){
			
			$Selection = ""
            Function_Select
			
        }
    } 
    
    #Ask for a password, verify it. If it's good, issue a session token.
    $local:Password = Read-Host "Please Enter Password: "

    if ($Password -eq $User.Password){
        
        Issue_Token -UserID $User.UserID -Username $User.Username -Lifetime 5
		$Selection = ""

        #Check the user's certificate while we're at it.
        if ((Validate_Certificate -User $User) -eq "VALID"){
        } else {
			
            Write-Host (Validate_Certificate -User $User)
            Write-Host "You need a new keypair. Let's make one."
            Generate_Keypair -User $User
		
        } 
        
        Main_Menu
    } elseif ($Password -ne $User.Password){
            $local:Selection = Read-Host "Password invalid. Would you like to try to login again? YES or NO?"
            if ($Selection -eq "YES"){
                Login
                $Selection = ""
            } elseif ($Selection = "NO"){
                Function_Select
                $Selection = ""
            }
        }
    
    $Password = ""
    $Username = ""
	
	$null = $Selection
	
    Main_Menu

}

function Issue_Token {
    param(
        [string]$UserID,
        [string]$Username,
        [int]$Lifetime
    )
    #Build Session Token Object
    $script:SessionToken = [PSCustomObject]@{
            UserID = $UserID
            Username = $Username
            TokenID = Get-Random
            IssuedTime = (Get-Date).addMinutes(0)
            ValidUntil = (Get-Date).addMinutes($Lifetime)
        } 
	
    $Selection = ""
	Write-Host $Selection
    Write-Host "Token issued successfully. Valid until $($SessionToken.ValidUntil)" 
	
	cls

}

function Validate_Token {
    #Check and see if a token has expired yet
    if ($SessionToken.ValidUntil -gt (Get-Date)){
        return "VALID" 
    } else {
        $null = $SessionToken
        return "INVALID" 
    }
}
function Generate_Keypair {
    param(
    [object]$User
    )

    #Generate a new private key and certficate for this user.
    $Local:CertPath = "ssl\$($User.UserID)\$(Get-Date -Format "MM_dd_yyyy")"

    New-Item -ItemType "Directory"  -Path $CertPath\private > $null 2>&1
    $User.PrivateKey = "$CertPath\private\private_key.pem"
    openssl genrsa -out $User.PrivateKey 2048 

    $local:CSR = "$($CertPath)\user_cert.csr"
    openssl req -new -subj "/CN=$($User.Username)" -key $User.PrivateKey -out $CSR 

    $User.Certificate = "$($CertPath)\user_cert.crt"
    openssl x509 -req  -days 30 -in $CSR -CA "ssl\root-ca\root_ca.crt" -CAkey "ssl\root-ca\root_ca.pem" -out $User.Certificate -sha256 2> $null

    #Check to make sure this actually worked.
    if ((Test-Path $User.Certificate) -and (Test-Path $User.PrivateKey)) {
        Write-Host "Keypair generated and signed successfully."
        Remove-Item -Path $CSR
    } else {
        Write-Host "Keypair generation failed. Please try again."
        $null = $User
        Function_Select
    }  
}
function Generate_User {
        #Confirm users file exists before we start so the whole script doesn't explode
        if (Test-Path "users.json") {
            $Users = @(Get-Content "users.json" -Raw | ConvertFrom-Json | ForEach-Object { $_ })
        } else {
            $Users = @()
        }
        #Build our new user object
        $NewUser = [PSCustomObject]@{
            UserID = $Users.Count
            Username = ""
            Password = ""
            PrivateKey = ""
            Certificate =  ""
            DateRegistered = Get-Date -Format "MM_dd_yyyy"
            TimeRegistered = Get-Date -Format "HH_mm_ss"
            
        } 
        
    function New_Username {
        #Ask for a username for our new user

        $Username = Read-Host "Input Username:"
        #Check to see if it's already in use.

        $local:Exists = $Users | Where-Object { $_.Username -eq $Username }
        if ($Exists){
            Write-Host "Username already in use. Please try again." 
            New_Username
        } else { 
            $NewUser.Username = $Username 
            Write-Host "Success. Username registered."
            $null = $Exists 
        }
    }
      
    function New_Password {
        #Ask for a password and verify it
        $Password = Read-Host "Input Password: "
        $VerifyPW = Read-Host "Verify Password: "

        if($Password -eq $VerifyPW){
            Write-Host "Password registration success."
            $NewUser.Password = $Password
        } else {
            Write-Host "Passwords do not match. Try again."
            New_Password
        }
    }
    
    New_Username
    New_Password

    #Create a keys directory for the user, and a mailbox. Check if they already have a mailbox, if they do for some reason.
    New-Item -ItemType "Directory"  -Path ssl\$($NewUser.UserID)\ > $null 2>&1
    
    if (Test-Path users\$($NewUser.UserID)\mailbox) {
        Write-Host "Mailbox exists already? Skipping."
    } else {
        Write-Host "Mailbox does not exist. Creating one!"
        New-Item -ItemType "Directory"  -Path users\$($NewUser.UserID)\mailbox > $null 2>&1
    }  

    Generate_Keypair -User $NewUser

    $Users += $NewUser
    $Users | ConvertTo-Json |  Set-Content users.json

    $null = $NewUser
    Function_Select
}

function Function_Select {
	
    if($Selection -eq "login") {
		
        $Selection = ""
		Login
		
    } elseif ($Selection -eq "REGISTER") {
		
        $Selection = ""		
        Generate_User

		
    } elseif (($Selection -eq "") -or ($Selection -eq $null)) {
		
		$Selection = Read-Host "Welcome to SSL Message Mailbox. LOGIN or REGISTER."
		Function_Select
		
	} else {
		
        $Selection = Read-Host "Selection not recognized. Please LOGIN or REGISTER."
		$Selection = ""
        Function_Select
		
	}
}

function Main_Menu {
	
	if($Selection -eq "Read") {
		
		$Selection = ""
        Read_Messages
		
    } elseif($Selection -eq "Send") {
		
		$Selection = ""
        Send_Message
		
	} elseif (($Selection -eq "") -or ($Selection -eq $null)) {
		
		$Selection =  Read-Host "Welcome Back $($SessionToken.Username). Would you like to READ or SEND a message?"
		Main_Menu
		
	} else {
		
        $Selection = Read-Host "Selection not recognized. Please READ or SEND a message."
		$Selection = ""
        Main_Menu
		
	}
}

Init_PKI
$Selection = ""
