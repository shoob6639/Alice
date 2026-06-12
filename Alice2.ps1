function User_Login {
   
    $Users = Get-Content -Path users.txt
    Write-Host "Current user list is $Users"

    if ($Users -contains $Sender){

        $UserID = [array]::IndexOf($Users, $Sender)
        Write-Host "Welcome back. Your user ID is $UserID"

        Function_Select

    } else {
        Write-Host "User is not already registered. Added to user list."
        Generate_User
    }
}

function Read_Message {
    $UserID = [array]::IndexOf($Users, $Sender)

}

function Send_Message {

    Choose_Recipient   

    $Message = Read-Host "What would you like to say?" 

    Write-Host "You are $Sender. You would like to say $Message to $Recipient."

    $UserID = [array]::IndexOf($Users, $Sender)
    $RecipientID = [array]::IndexOf($Users, $Recipient)
    
    $PrivateKey = $("$pwd\users\$UserID\keys\" + "private_key.pem")
    $PublicKey = $("$pwd\users\$UserID\keys\" + "public_key.pem")

    $RecipientMailbox = "$pwd\users\$RecipientID\mailbox"
    $MessageName = "$UserID" + "_$RecipientID_" + (Get-Date -Format "MM_dd_yyyy_HH_mm")
    $MessagePath = Join-Path $RecipientMailbox $MessageName
    $MessageFile = Join-Path $MessagePath "message.txt"

    New-Item -ItemType Directory -Path $MessagePath | Out-Null

    Out-File  -FilePath $MessageFile -InputObject $Message -Encoding UTF8 | Out-Null

    openssl dgst -sha256 -sign $PrivateKey -out "$MessagePath\signature.sign" $MessageFile

    Write-Host "Message Sent with SHA256 signature."

}

Function Choose_Recipient {

    $Global:Recipient = Read-Host "Who would you like to talk to?"

    if ($Users -contains $Recipient){
        $Users = Get-Content -Path users.txt
        $UserID = [array]::IndexOf($Users, $Sender)
        Write-Host Recipient ID is $RecipientID

    } else {
        Write-Host "User is invalid. Please try again."
        Choose_Recipient
    }

}

function Generate_User {

        Add-Content -Value $Sender -Path users.txt

        $Users = Get-Content -Path users.txt
        $UserID = [array]::IndexOf($Users, $Sender)

        mkdir $pwd\users\$UserID | Out-Null
        mkdir $pwd\users\$UserID\keys | Out-Null 
        mkdir $pwd\users\$UserID\mailbox | Out-Null

        Write-Host "Mailbox Provisioned Successfully."

        $PrivateKeyName = $("$pwd\users\$UserID\keys\" + "private_key.pem")
        openssl genrsa -out $PrivateKeyName 1024

        $PublicKeyName = $("$pwd\users\$UserID\keys\" + "public_key.pem")
        openssl rsa -in ($PrivateKeyName) -out ($PublicKeyName) -outform PEM -pubout 

        Write-Host "Keypair generation successful."
        }

function Function_Select {
    $Selection = Read-Host "Welcome to SSL Message Mailbox. Would you like to READ or SEND?"

    if ($Selection -like "SEND") 
    { 
    Send_Message 
    }
 elseif ($Selection -like "READ")
    {
    Read_Message
    }
 else
    {
    $Selection = Read-Host "Selection not recognized. Please input READ or SEND."
    Function_Select
    }
}

$UserID = 0
$Sender = Read-Host "Welcome to SSL Message Sender. Please Input your name."

User_Login
