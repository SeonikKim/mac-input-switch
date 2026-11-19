[CmdletBinding(DefaultParameterSetName = 'Relay')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Relay')]
    [ValidatePattern('^[A-Za-z0-9_][A-Za-z0-9_.-]*@[A-Za-z0-9][A-Za-z0-9.-]*$')]
    [string] $Mac,

    [Parameter(Mandatory = $true, ParameterSetName = 'Relay')]
    [string] $IdentityFile,

    [ValidateSet('first', 'second')]
    [string] $Slot = 'first',

    [ValidateNotNullOrEmpty()]
    [string] $MouseName = 'MX Master 4',

    [string] $LocalMouseName,

    [Parameter(ParameterSetName = 'Relay')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Language')]
    [ValidateSet('en', 'ko')]
    [string] $Language,

    [Parameter(Mandatory = $true, ParameterSetName = 'Language')]
    [switch] $SetLanguage
)

$ErrorActionPreference = 'Stop'
$languagePath = Join-Path $env:LOCALAPPDATA 'MacInputSwitch/language'
$saveLanguage = [bool]$Language
if (-not $Language -and (Test-Path -LiteralPath $languagePath -PathType Leaf)) {
    $saved = ([IO.File]::ReadAllText($languagePath)).Trim()
    if ($saved -in 'en', 'ko') { $Language = $saved }
}
if (-not $Language -and -not [Console]::IsInputRedirected -and
    -not ([Environment]::GetCommandLineArgs() -match '^-(?:NonInteractive|NonI)$')) {
    try {
        $choice = Read-Host 'Choose language / 언어 선택 (1 English, 2 한국어) [1]'
        switch ($choice) {
            '' { $Language = 'en' }
            '1' { $Language = 'en' }
            '2' { $Language = 'ko' }
            default { throw 'Enter 1 or 2. / 1 또는 2를 입력하세요.' }
        }
        $saveLanguage = $true
    } catch [Management.Automation.Host.HostException] {
        # Hosts without a prompt use the locale below.
    }
}
if (-not $Language) {
    $Language = if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'ko') { 'ko' } else { 'en' }
}
if ($saveLanguage) {
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $languagePath))
    [IO.File]::WriteAllText($languagePath, $Language)
}
if ($SetLanguage) {
    if ($Language -eq 'ko') { Write-Output '한국어로 저장했습니다.' } else { Write-Output 'English saved.' }
    return
}

Add-Type -Path (Join-Path $PSScriptRoot 'AbkoKeyboard.cs')
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Devices.Bluetooth.BluetoothLEDevice, Windows.Devices.Bluetooth, ContentType=WindowsRuntime]
$null = [Windows.Devices.Bluetooth.BluetoothDevice, Windows.Devices.Bluetooth, ContentType=WindowsRuntime]
$null = [Windows.Devices.Enumeration.DeviceInformation, Windows.Devices.Enumeration, ContentType=WindowsRuntime]
$returnType = [Windows.Devices.Enumeration.DeviceInformationCollection, Windows.Devices.Enumeration, ContentType=WindowsRuntime]
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and $_.GetParameters().Count -eq 1
} | Select-Object -First 1
$asTask = $asTask.MakeGenericMethod($returnType)
$selector = [Windows.Devices.Bluetooth.BluetoothLEDevice]::GetDeviceSelectorFromConnectionStatus(
    [Windows.Devices.Bluetooth.BluetoothConnectionStatus]::Connected
)
$classicSelector = [Windows.Devices.Bluetooth.BluetoothDevice]::GetDeviceSelectorFromConnectionStatus(
    [Windows.Devices.Bluetooth.BluetoothConnectionStatus]::Connected
)

function Get-MouseModel([string] $Name) {
    $model = ($Name.Trim() -replace '^(Logitech|Logi) ', '').ToLowerInvariant()
    if ($model -eq 'mx master 4 b') { return 'mx master 4' }
    return $model
}

$model = Get-MouseModel $MouseName
if (-not $model -or [Text.Encoding]::UTF8.GetByteCount($model) -gt 240) {
    throw 'MouseName must contain a Bluetooth model name of up to 240 UTF-8 bytes.'
}
$localModel = $model
if ($LocalMouseName) { $localModel = Get-MouseModel $LocalMouseName }
$hello = "HELLO $Slot"
if ($model -ne 'mx master 4') { $hello += ' ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($model)) }

function Get-MatchingMouseCount([string] $Filter) {
    $task = $asTask.Invoke($null, @([Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($Filter)))
    if (-not $task.Wait(850)) { throw 'Bluetooth query timed out' }
    return @($task.Result | Where-Object { (Get-MouseModel $_.Name) -eq $localModel }).Count
}

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
        $connection.StandardInput.WriteLine($hello)
        $previous = $null
        while (-not $connection.HasExited -and $reader.IsAlive) {
            try {
                $matches = Get-MatchingMouseCount $selector
                if ($matches -eq 0) { $matches = Get-MatchingMouseCount $classicSelector }
                $present = [int]($matches -eq 1)
            } catch {
                $present = 0
            }
            $connection.StandardInput.WriteLine("PRESENT $present")
            if ($previous -ne $present) {
                if ($Language -eq 'ko') {
                    $status = if ($present) { '연결됨' } else { '연결 해제됨' }
                    Write-Output "$Slot 윈도우 마우스 $status"
                } else {
                    $status = if ($present) { 'connected' } else { 'disconnected' }
                    Write-Output "Mouse on $Slot Windows PC is $status."
                }
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
