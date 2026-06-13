function User_Login {
   
    $Sender = Read-Host "Welcome to SSL Message Sender Login. Please input your name."

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
    $MailboxLocation = "$pwd\users\$UserID\mailbox"
    $MailboxItems = Get-ChildItem "$MailboxLocation"
    
    Write-Host "You Have" (Get-ChildItem -Path "$MailboxLocation").Count "Messages."
        

    $i = 0
    $MailboxItems | ForEach-Object {

        $Parts = $_.Name -split "_"
        $MessageRecipientID = $Parts[0]
        $MessageSenderID = $Parts[1]
        $MessageDate = $Parts[2] + "/" + $Parts[3] + "/" + $Parts[4] + "/" + $Parts[5]
        $MessageTime = $Parts[6] + ":" + $Parts[7]

        $MessagePath = $_.FullName
        $MessageFile = Join-Path $MessagePath "\message.txt"
        $PublicKey = $("$pwd\users\$MessageSenderID\keys\" + "public_key.pem") 
        $SignatureFile = $($MessagePath + "\signature.sign")

        [PSCustomObject]@{
            Index        = $i++
            From = $Users[$MessageSenderID]
            To = $Users[$MessageRecipientID]
            Date = $MessageDate
            Time = $MessageTime
            Name         = $_.Name
            Size = $_.Length          
            MessageVerified = Verify_Message -MessagePath $MessageFile -SignaturePath $SignatureFile -PublicKey $PublicKey
        }
    } | Format-Table
    
    Function_Select
}

function Verify_Message {
        param(
        [string]$MessagePath,
        [string]$SignaturePath,
        [string]$PublicKey
    )

    return openssl dgst -sha256 -verify $PublicKey -signature $SignaturePath $MessagePath
}



function Send_Message {

    Choose_Recipient   

    $Message = Read-Host "What would you like to say?" 

    Write-Host "You are $Sender. You would like to say $Message to $Recipient."

    $Users = Get-Content -Path users.txt
    $UserID = [array]::IndexOf($Users, $Sender)
    $RecipientID = [array]::IndexOf($Users, $Recipient)
    
    $PrivateKey = $("$pwd\users\$UserID\keys\" + "private_key.pem")
    $PublicKey = $("$pwd\users\$UserID\keys\" + "public_key.pem")

    $RecipientMailbox = "$pwd\users\$RecipientID\mailbox"
    $MessageName = "$RecipientID" + "_" + "$UserID" + "_" + (Get-Date -Format "MM_dd_yyyy_HH_mm_ss")
    $MessagePath = Join-Path $RecipientMailbox $MessageName
    $MessageFile = Join-Path $MessagePath "message.txt"

    New-Item -ItemType Directory -Path $MessagePath | Out-Null
    Out-File  -FilePath $MessageFile -InputObject $Message -Encoding UTF8 | Out-Null

    openssl dgst -sha256 -sign $PrivateKey -out "$MessagePath\signature.sign" $MessageFile
    Start-Sleep -Seconds 2
    Write-Host "Message successfully sent with SHA256 signature!"
    Start-Sleep -Seconds 1

    Function_Select
}

Function Choose_Recipient {

    $Global:Recipient = Read-Host "Who would you like to send to?"

    if ($Users -contains $Recipient){
        $Users = Get-Content -Path users.txt
        $UserID = [array]::IndexOf($Users, $Sender)
        $RecipientID = [array]::IndexOf($Users, $Recipient)
        Start-Sleep -Seconds 1
        Write-Host Recipient ID is $RecipientID
        
    } else {
        Write-Host "Recipient is invalid. Please try again."
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
        
        Start-Sleep -Seconds 1
        Write-Host "Mailbox Provisioned Successfully."

        $PrivateKeyName = $("$pwd\users\$UserID\keys\" + "private_key.pem")
        openssl genrsa -out $PrivateKeyName 1024
        Start-Sleep -Seconds 1

        $PublicKeyName = $("$pwd\users\$UserID\keys\" + "public_key.pem")
        openssl rsa -in ($PrivateKeyName) -out ($PublicKeyName) -outform PEM -pubout 
        Start-Sleep -Seconds 2

        Write-Host "Keypair generation successful."
        Start-Sleep -Seconds 1
        Function_Select
        }

function Function_Select {
    $Selection = Read-Host "Welcome to SSL Message Mailbox. WWould you like to READ, SEND or LOGIN?"

    if ($Selection -like "SEND") 
    { 
        Send_Message 
    }
    elseif ($Selection -like "READ")
    {
        Read_Message
    }
    elseif ($Selection -like "LOGIN")
    {
        User_Login
    }    
    else
    {
        $Selection = Read-Host "Selection not recognized. Would you like to READ, SEND or LOGIN?"
        Function_Select
    }
}

$Users = @()
User_Login
