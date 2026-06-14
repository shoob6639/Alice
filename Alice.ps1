
$Users = @()
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
            PublicKey = ""

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

        #Create the message file and sign it. Set the public key field, so people know which key can be used to verify it.
        $NewMessage.PublicKey = $MessageSender.PublicKey
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


function Read_Message {

    #Validate Session Token before starting
    if (Validate_Token -eq "VALID"){        
    } else {
        Write-Host "Session Token Invalid. Please login again."
        Function_Select
        return $null
    }

    #Set $Messages to an array containing all the .json message files in our mailbox
    $local:Messages = @(Get-ChildItem "users\$($SessionToken.UserID)\mailbox\*.json")
    
    Write-Host "You Have" $Messages.Count "Messages."
    
    #Go through each message in $Messages and pull data from them to display to the terminal.
    $Messages | ForEach-Object {
        
        $Local:Message = @(Get-Content "$($_.FullName)" | ConvertFrom-Json | ForEach-Object { $_ }) 
        
        #Check SSL signing with OpenSSL. $Messages object contains info like where the public key for this message lives and the signature. Suppress errors.
        $Local:MessageVerified = openssl dgst -sha256 -verify $Message.PublicKey -signature $Message.SignatureFile $Message.MessageFile 2> $null

        if($MessageVerified -eq "Verified OK"){
        } else {
            $MessageVerified = "Verfied FAIL"
        }
        [PSCustomObject]@{
            Index        = $i++
            From = $Message.Sender
            To = $Message.Recipient
            Time_Sent = $Message.SentTime
            Subject         = $Message.MessageSubject
            Message_Verified = $MessageVerified
            
        }
    } | Format-Table -AutoSize

    Main_Menu

}

function Login {
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
            Login
        } elseif ($Selection = "NO"){
            Function_Select
        }

    } 
    
    #Ask for a password, verify it. If it's good, issue a session token.
    $local:Password = Read-Host "Please Enter Password: "

    if ($Password -eq $User.Password){
        Issue_Token -UserID $User.UserID -Username $User.Username -Lifetime 5
        Main_Menu
    } elseif ($Password -ne $User.Password){
            $local:Selection = Read-Host "Password invalid. Would you like to try to login again? YES or NO?"
            if ($Selection -eq "YES"){
                Login
                $null = $Selection
            } elseif ($Selection = "NO"){
                Function_Select
                $null = $Selection
            }
        }
    
    $Password = ""
    $Username = ""

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

    Write-Host "Token issued successfully. Valid until $($SessionToken.ValidUntil)"   

}

function Validate_Token{

    #Check and see if a token has expired yet
    if ($SessionToken.ValidUntil -gt (Get-Date)){
        return "VALID" 
    } else {
        $null = $SessionToken
        return "INVALID" 
    }
}

function Generate_User {
        #Confirm users file exists before we start so the whole script doesn't explode
        if (Test-Path "users.json") {
            $Users = @(Get-Content "users.json" -Raw | ConvertFrom-Json | ForEach-Object { $_ })
        } else {
            $Users = @()
        }
        Build our new user object
        $NewUser = [PSCustomObject]@{
            UserID = $Users.Count
            Username = ""
            Password = ""
            PrivateKey = ""
            PublicKey =  ""
            Mailbox = ""
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
    New-Item -ItemType "Directory"  -Path users\$($NewUser.UserID)\keys | Out-Null
    
    if (Test-Path users\$($NewUser.UserID)\mailbox) {
            Write-Host "Mailbox exists already? Skipping."
        } else {
            Write-Host "Mailbox does not exist. Creating one!"
            New-Item -ItemType "Directory"  -Path users\$($NewUser.UserID)\mailbox | Out-Null
        }  


    #Generate a keypair for this user.
    openssl genrsa -out $("users\$($NewUser.UserID)\keys\private_key.pem") 2048
    $NewUser.PrivateKey = $("users\$($NewUser.UserID)\keys\private_key.pem")
    
    openssl rsa -in $NewUser.PrivateKey -out $("users\$($NewUser.UserID)\keys\public_key.pem") -outform PEM -pubout 
    $NewUser.PublicKey = $("users\$($NewUser.UserID)\keys\public_key.pem")

    $Users += $NewUser
    $Users | ConvertTo-Json -Depth 2 |  Set-Content users.json

    $null = $NewUser
    Function_Select
}

function Function_Select {
    $null = $Selection
    $local:Selection = Read-Host "Welcome to SSL Message Mailbox. LOGIN or REGISTER."

    if($Selection -eq "LOGIN")
    {
        Login
        $Selection = $null
        
    }
    elseif ($Selection -eq "REGISTER")
    {
        Generate_User
        $Selection = $null
    }     
    else
    {
        $Selection = Read-Host "Selection not recognized. Please LOGIN or REGISTER."
        Function_Select
    }
}

function Main_Menu {
    $null = $Selection
    $Selection = Read-Host "Welcome Back $($SessionToken.Username). Would you like to READ or SEND a message?"

    if ($Selection -eq "Read")
    {
        Read_Message
        $Selection = $null
    }
    if ($Selection -eq "Send")
    {
        Send_Message
        $Selection = $null
    }     
    else
    {
        $Selection = Read-Host "Selection not recognized. Please READ or SEND."
        Main_Menu
    }
}

Function_Select
