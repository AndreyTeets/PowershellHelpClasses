using module "..\Classes\Logger.psm1"
using module "..\Classes\WinImpersonator.psm1"

$logger = [Logger]::new('Trace')
$config = [PSCustomObject]@{
    UserName = "SomeDomain\SomeUser"
    Password = "SomePassword"
}
$impersonator = [WinImpersonator]::new($config, $logger)

$result = $impersonator.ExecuteScriptBlockAsUser({ Write-Host "123"; return "bla bla" })
Write-Host "ExecuteScriptBlockAsUser result='$result'"

$output = $impersonator.ExecuteProcessAsUser("C:\Windows\System32\cmd.exe", @("/c", "echo 456"), 0)
Write-Host "ExecuteProcessAsUser output='$output'"
