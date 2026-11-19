param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_][A-Za-z0-9_.-]*@[A-Za-z0-9][A-Za-z0-9.-]*$')]
    [string] $Mac,

    [Parameter(Mandatory = $true)]
    [string] $IdentityFile,

    [ValidateSet('first', 'second')]
    [string] $Slot = 'first'
)

$ErrorActionPreference = 'Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'AbkoKeyboard.cs')
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Devices.Bluetooth.BluetoothLEDevice, Windows.Devices.Bluetooth, ContentType=WindowsRuntime]
$null = [Windows.Devices.Enumeration.DeviceInformation, Windows.Devices.Enumeration, ContentType=WindowsRuntime]
$returnType = [Windows.Devices.Enumeration.DeviceInformationCollection, Windows.Devices.Enumeration, ContentType=WindowsRuntime]
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and $_.GetParameters().Count -eq 1
} | Select-Object -First 1
$asTask = $asTask.MakeGenericMethod($returnType)
$selector = [Windows.Devices.Bluetooth.BluetoothLEDevice]::GetDeviceSelectorFromConnectionStatus(
    [Windows.Devices.Bluetooth.BluetoothConnectionStatus]::Connected
)

$identity = (Resolve-Path -LiteralPath $IdentityFile).ProviderPath
$start = New-Object System.Diagnostics.ProcessStartInfo
$start.FileName = Join-Path $env:WINDIR 'System32/OpenSSH/ssh.exe'
$start.Arguments = ('-T -i "{0}" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes ' +
    '-o ConnectTimeout=3 -o ServerAliveInterval=2 -o ServerAliveCountMax=2 {1} ' +
    '/usr/bin/nc -U ~/Applications/MacInputSwitch/keyboard.sock') -f $identity, $Mac
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardInput = $true
$start.RedirectStandardOutput = $true

while ($true) {
    $connection = [System.Diagnostics.Process]::Start($start)
    $keyboard = New-Object AbkoKeyboard
    $reader = $keyboard.Start($connection.StandardOutput)
    try {
        $connection.StandardInput.NewLine = "`n"
        $connection.StandardInput.AutoFlush = $true
        $connection.StandardInput.WriteLine("HELLO $Slot")
        $previous = $null
        while (-not $connection.HasExited -and $reader.IsAlive) {
            try {
                $task = $asTask.Invoke($null, @([Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($selector)))
                if (-not $task.Wait(1200)) { throw 'Bluetooth query timed out' }
                $mouse = @($task.Result | Where-Object { $_.Name -cmatch '^MX Master 4(?: B)?$' })
                $present = [int]($mouse.Count -eq 1)
            } catch {
                $present = 0
            }
            $connection.StandardInput.WriteLine("PRESENT $present")
            if ($previous -ne $present) {
                Write-Output "Mouse presence on $($Slot): $present"
                $previous = $present
            }
            Start-Sleep -Milliseconds 400
        }
    } catch [IO.IOException] {
        # SSH may exit while a heartbeat is in progress.
    } finally {
        if (-not $connection.HasExited) { $connection.Kill() }
        $null = $reader.Join(3000)
        $connection.Dispose()
    }
    Start-Sleep -Seconds 1
}
