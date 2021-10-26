using module "..\Classes\Logger.psm1"
using module "..\Classes\RemoteHostInteractor.psm1"

$logger = [Logger]::new('Trace')
$config = [PSCustomObject]@{
    Credential = $null
    UseSSL = $false
    IgnoreSSLCert = $false
}
$impersonator = [RemoteHostInteractor]::new($config, $logger)

try {
    $impersonator.ExecuteRemotely({
            param(
                [string]$SomeArg1,
                [string]$SomeArg2
            )

            Write-Host "HostName='$([System.Net.Dns]::GetHostName())'"
            Write-Host "123 SomeArg1='$SomeArg1', SomeArg2='$SomeArg2'"
            "some output"
        },
        @("SomeArg1Value", "SomeArg2Value"),
        @("localhost")
    )
} finally {
    $impersonator.CloseConnections()
}
