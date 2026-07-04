# ----- Edit these Variables for your own Use Case ----- #
$PASSWORD_FOR_USERS = "Password1"
$NAMES_FILE         = ".\names.txt"     # format per line: Full Name,Department
$DEPARTMENTS        = @("IT", "HR", "Management")
# -------------------------------------------------------- #

$password = ConvertTo-SecureString $PASSWORD_FOR_USERS -AsPlainText -Force
$baseDN   = ([ADSI]"").distinguishedName

# ----- Create the OU structure: _USERS > IT / HR / Management ----- #
New-ADOrganizationalUnit -Name "_USERS" -ProtectedFromAccidentalDeletion $false -ErrorAction SilentlyContinue

foreach ($dept in $DEPARTMENTS) {
    New-ADOrganizationalUnit -Name $dept `
        -Path "OU=_USERS,$baseDN" `
        -ProtectedFromAccidentalDeletion $false `
        -ErrorAction SilentlyContinue
}

# ----- Read names.txt and create each user in their department OU ----- #
$usernamesSeen = @{}

Get-Content $NAMES_FILE | Where-Object { $_.Trim() -ne "" } | ForEach-Object {

    $fields = $_ -split ","
    $fullName = $fields[0].Trim()
    $dept     = $fields[1].Trim()

    if ($DEPARTMENTS -notcontains $dept) {
        Write-Host "Skipping '$fullName' - unrecognized department '$dept'" -ForegroundColor Yellow
        return
    }

    $nameParts = $fullName -split " "
    $first = $nameParts[0].ToLower()
    $last  = $nameParts[-1].ToLower()   # last token handles middle names too, e.g. "Sibghat ur Rehman"

    $baseUsername = "$($first.Substring(0,1))$($last)".ToLower()
    $username     = $baseUsername

    # Avoid duplicate sAMAccountNames (e.g. two "S Molder"s) by appending a counter
    $suffix = 1
    while ($usernamesSeen.ContainsKey($username)) {
        $suffix++
        $username = "$baseUsername$suffix"
    }
    $usernamesSeen[$username] = $true

    $ouPath = "OU=$dept,OU=_USERS,$baseDN"

    Write-Host "Creating user: $username ($dept)" -BackgroundColor Black -ForegroundColor Cyan

    New-AdUser -AccountPassword $password `
               -GivenName $first `
               -Surname $last `
               -DisplayName $username `
               -Name $username `
               -EmployeeID $username `
               -Department $dept `
               -PasswordNeverExpires $true `
               -Path $ouPath `
               -Enabled $true
}
