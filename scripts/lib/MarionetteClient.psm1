# Minimaler Marionette-Client (Firefox-Remote-Protokoll).
#
# Wird von Smoke-FirefoxDialogs.ps1 genutzt, um einen echten Firefox gegen die
# laufende WebApp zu fahren. Bewusst ohne npm-Abhaengigkeit (Playwright/Selenium),
# damit der Test auch offline und ohne Registry-Zugriff laeuft.
#
# Protokoll: TCP 127.0.0.1:<port>, Frames im Format "<ByteLaenge>:<UTF8-JSON>".

Set-StrictMode -Version Latest

$script:Client = $null
$script:Stream = $null
$script:MessageId = 0
$script:ElementKey = 'element-6066-11e4-a52e-4f735466cecf'

function Connect-Marionette {
    [CmdletBinding()]
    param([int]$Port = 2828, [int]$TimeoutSeconds = 60)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $client.Connect('127.0.0.1', $Port)
            $script:Client = $client
            $script:Stream = $client.GetStream()
            $script:Stream.ReadTimeout = 60000
            return Read-MarionetteFrame
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    throw "Marionette-Port $Port ist nicht erreichbar."
}

function Read-MarionetteFrame {
    [CmdletBinding()]
    param()

    $lengthText = New-Object System.Text.StringBuilder
    while ($true) {
        $byte = $script:Stream.ReadByte()
        if ($byte -lt 0) { throw 'Marionette-Verbindung wurde geschlossen.' }
        $char = [char]$byte
        if ($char -eq ':') { break }
        [void]$lengthText.Append($char)
    }

    $length = [int]$lengthText.ToString()
    $buffer = New-Object byte[] $length
    $read = 0
    while ($read -lt $length) {
        $chunk = $script:Stream.Read($buffer, $read, $length - $read)
        if ($chunk -le 0) { throw 'Marionette-Datenstrom endete vorzeitig.' }
        $read += $chunk
    }
    return [System.Text.Encoding]::UTF8.GetString($buffer) | ConvertFrom-Json
}

function Invoke-MarionetteCommand {
    [CmdletBinding()]
    param([string]$Command, [hashtable]$Parameters = @{})

    $script:MessageId++
    $payload = ConvertTo-Json @(0, $script:MessageId, $Command, $Parameters) -Depth 12 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $header = [System.Text.Encoding]::UTF8.GetBytes("$($bytes.Length):")
    $script:Stream.Write($header, 0, $header.Length)
    $script:Stream.Write($bytes, 0, $bytes.Length)
    $script:Stream.Flush()

    while ($true) {
        $response = Read-MarionetteFrame
        if ($response[0] -ne 1) { continue }              # asynchrone Events ueberspringen
        if ($response[1] -ne $script:MessageId) { continue }
        if ($null -ne $response[2]) {
            throw "Marionette-Fehler bei ${Command}: $($response[2].error) - $($response[2].message)"
        }
        return $response[3]
    }
}

function Start-MarionetteSession {
    [CmdletBinding()]
    param()
    return Invoke-MarionetteCommand -Command 'WebDriver:NewSession' -Parameters @{ capabilities = @{} }
}

function Open-MarionetteUrl {
    [CmdletBinding()]
    param([string]$Url)
    Invoke-MarionetteCommand -Command 'WebDriver:Navigate' -Parameters @{ url = $Url } | Out-Null
}

function Invoke-MarionetteScript {
    [CmdletBinding()]
    param([string]$Script, [object[]]$Arguments = @())

    $result = Invoke-MarionetteCommand -Command 'WebDriver:ExecuteScript' -Parameters @{
        script  = $Script
        args    = $Arguments
        sandbox = 'default'
    }
    return $result.value
}

function Find-MarionetteElement {
    [CmdletBinding()]
    param([string]$Css, [int]$TimeoutSeconds = 10)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $result = Invoke-MarionetteCommand -Command 'WebDriver:FindElement' -Parameters @{
                using = 'css selector'; value = $Css
            }
            return $result.value.$script:ElementKey
        } catch {
            Start-Sleep -Milliseconds 250
        }
    }
    throw "Element nicht gefunden: $Css"
}

function Test-MarionetteElement {
    [CmdletBinding()]
    param([string]$Css)
    try {
        Invoke-MarionetteCommand -Command 'WebDriver:FindElement' -Parameters @{
            using = 'css selector'; value = $Css
        } | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Invoke-MarionetteClick {
    [CmdletBinding()]
    param([string]$ElementId)
    Invoke-MarionetteCommand -Command 'WebDriver:ElementClick' -Parameters @{ id = $ElementId } | Out-Null
}

function Send-MarionetteKeys {
    [CmdletBinding()]
    param([string]$ElementId, [string]$Text)
    Invoke-MarionetteCommand -Command 'WebDriver:ElementSendKeys' -Parameters @{ id = $ElementId; text = $Text } | Out-Null
}

function Send-MarionetteEscape {
    [CmdletBinding()]
    param()
    Invoke-MarionetteCommand -Command 'WebDriver:PerformActions' -Parameters @{
        actions = @(@{
            type    = 'key'
            id      = 'keyboard'
            actions = @(
                @{ type = 'keyDown'; value = "`u{E00C}" },
                @{ type = 'keyUp';   value = "`u{E00C}" }
            )
        })
    } | Out-Null
}

function Disconnect-Marionette {
    [CmdletBinding()]
    param()
    try { Invoke-MarionetteCommand -Command 'WebDriver:DeleteSession' | Out-Null } catch { }
    if ($script:Stream) { $script:Stream.Dispose(); $script:Stream = $null }
    if ($script:Client) { $script:Client.Dispose(); $script:Client = $null }
}

Export-ModuleMember -Function Connect-Marionette, Start-MarionetteSession, Open-MarionetteUrl,
    Invoke-MarionetteScript, Find-MarionetteElement, Test-MarionetteElement, Invoke-MarionetteClick,
    Send-MarionetteKeys, Send-MarionetteEscape, Invoke-MarionetteCommand, Disconnect-Marionette
