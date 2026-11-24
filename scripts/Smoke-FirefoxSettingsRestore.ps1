#requires -Version 7.0
# Native UI acceptance with synthetic data and an isolated SQLite database.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceAssemblyPath,
    [int]$Port = 5105,
    [int]$MarionettePort = 2845,
    [string]$FirefoxPath = 'C:\Program Files\Mozilla Firefox\firefox.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $PSScriptRoot 'lib/MarionetteClient.psm1') -Force -DisableNameChecking
. (Join-Path $PSScriptRoot 'lib/FirefoxSmokeCommon.ps1')
$smoke = New-StmFirefoxSmokeContext -Root $root -Port $Port -MarionettePort $MarionettePort -SourceAssemblyPath $SourceAssemblyPath -SkipPack
$passed = 0
function Wait-Ui([string]$Script) {
    $deadline = [DateTime]::UtcNow.AddSeconds(25)
    do {
        if (Invoke-MarionetteScript $Script) { return }
        Start-Sleep -Milliseconds 150
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Native settings/restore condition timed out: $Script"
}
function Assert-Ui([bool]$Condition,[string]$Name) {
    if (-not $Condition) { throw "Native settings/restore: $Name" }
    $script:passed++; Write-Host "PASS $Name"
}
function Click-Ui([string]$Text) {
    $result=Invoke-MarionetteScript -Arguments @($Text) -Script 'const n=[...document.querySelectorAll("button")].find(b=>b.textContent.trim()===arguments[0]&&!b.disabled);if(!n)return false;n.click();return true;'
    if (-not $result) { throw "Expected native UI control: $Text" }
}
function Set-Ui([string]$Selector,[string]$Value) {
    $selectorJson=$Selector | ConvertTo-Json -Compress
    $valueJson=$Value | ConvertTo-Json -Compress
    Invoke-MarionettePageScript @"
(()=>{const n=document.querySelector($selectorJson);if(!n)throw new Error('Synthetic test control missing');
const p=n.tagName==='SELECT'?HTMLSelectElement.prototype:n.tagName==='TEXTAREA'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;
Object.getOwnPropertyDescriptor(p,'value').set.call(n,$valueJson);n.dispatchEvent(new Event(n.tagName==='SELECT'?'change':'input',{bubbles:true}));})();
"@
}
function Open-Area([string]$Name) {
    Click-Ui 'Mehr'
    $nameJson=$Name | ConvertTo-Json -Compress
    $result=Invoke-MarionetteScript "const n=[...document.querySelectorAll('.more-link')].find(b=>b.querySelector('strong').textContent.trim()===$nameJson);if(!n)return false;n.click();return true;"
    if (-not $result) { throw 'Expected application area missing.' }
}
function Get-SyntheticTournament([string]$Id) {
    return Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$Id) -NoProxy -MaximumRedirection 0
}
try {
    $profile=Join-Path $smoke.DataDirectory 'ff-profile'
    New-Item -ItemType Directory -Path $profile | Out-Null
    Set-Content -LiteralPath (Join-Path $profile 'user.js') -Encoding utf8 -Value @"
user_pref("marionette.port", $MarionettePort);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.update.enabled", false);
"@
    $backend=Start-StmFirefoxBackend -Context $smoke
    Start-StmFirefoxBrowser -Context $smoke -Firefox $FirefoxPath -ProfileDirectory $profile | Out-Null
    Connect-Marionette -Port $MarionettePort -TimeoutSeconds 60 | Out-Null
    Start-MarionetteSession | Out-Null
    Open-MarionetteUrl ($smoke.BaseUrl+'/')
    Wait-Ui 'return !!document.querySelector(".tournament-start-actions button") && !document.querySelector(".tournament-start-actions button").disabled;'
    $createdIds=[Collections.Generic.List[string]]::new()
    foreach ($case in @(@{strategy=0;colour=1},@{strategy=1;colour=1},@{strategy=1;colour=2})) {
        $name='Synthetic UI Settings '+$case.strategy+'-'+$case.colour
        Invoke-MarionetteScript 'if(!document.querySelector(".create-tournament-form"))document.querySelector(".tournament-start-actions button").click();return true;' | Out-Null
        Wait-Ui 'return !!document.querySelector(".create-tournament-form");'
        Set-Ui '.create-tournament-form input' $name
        Set-Ui '.create-tournament-form > label select' '1'
        Wait-Ui 'return !!document.querySelector(".create-tournament-form details");'
        Invoke-MarionetteScript 'document.querySelector(".create-tournament-form details").open=true;return true;' | Out-Null
        Set-Ui '.create-tournament-form details select' ([string]$case.strategy)
        if ($case.strategy -eq 1) {
            Wait-Ui 'return document.querySelectorAll(".create-tournament-form details select").length===2;'
            Set-Ui '.create-tournament-form details label:last-child select' ([string]$case.colour)
        }
        Invoke-MarionetteScript 'document.querySelector(".create-tournament-form").requestSubmit();return true;' | Out-Null
        $nameJson=$name | ConvertTo-Json -Compress
        Wait-Ui "return document.querySelector('.list button.selected')?.textContent.startsWith($nameJson);"
        $all=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments') -NoProxy -MaximumRedirection 0
        $item=@($all | Where-Object name -CEQ $name)
        Assert-Ui ($item.Count -eq 1) 'UI creates exactly one intended synthetic tournament'
        $id=[string]$item[0].id; $createdIds.Add($id)
        $state=Get-SyntheticTournament $id
        Assert-Ui ($state.settings.format -eq 1 -and $state.settings.pairingStrategy -eq $case.strategy -and $state.settings.swissInitialColour -eq $case.colour) ('actual create payload persists strategy/colour '+$case.strategy+'/'+$case.colour)
        Open-Area 'Verwaltung & Audit'
        Wait-Ui 'return !!document.querySelector(".settings-form");'
        $opposite=if($case.colour -eq 1){2}else{1}
        Set-Ui '.settings-form label:nth-child(2) select' '1'
        Wait-Ui 'return document.querySelector(".settings-form label:nth-child(3)")?.textContent.includes("Anfangsfarbe");'
        Set-Ui '.settings-form label:nth-child(3) select' ([string]$opposite)
        Invoke-MarionetteScript 'document.querySelector(".settings-form").requestSubmit();return true;' | Out-Null
        Wait-Ui 'return document.querySelector(".status-line")?.textContent.toLowerCase().includes("einstellungen gespeichert");'
        $state=Get-SyntheticTournament $id
        Assert-Ui ($state.settings.pairingStrategy -eq 1 -and $state.settings.swissInitialColour -eq $opposite) 'pre-round settings edits persist through the real form'
        if ($case.strategy -eq 0) {
            Set-Ui '.settings-form label:nth-child(2) select' '0'
            Invoke-MarionetteScript 'document.querySelector(".settings-form").requestSubmit();return true;' | Out-Null
            # The old success text is identical for both saves; await the new
            # persisted value instead of accepting the preceding save's status.
            $savedDeadline=[DateTime]::UtcNow.AddSeconds(15)
            do {
                if ((Get-SyntheticTournament $id).settings.pairingStrategy -eq 0) { break }
                Start-Sleep -Milliseconds 100
            } while ([DateTime]::UtcNow -lt $savedDeadline)
            Assert-Ui ((Get-SyntheticTournament $id).settings.pairingStrategy -eq 0) 'the real form can switch from Dutch back to Optimal V2 before round one'
        }
        foreach ($number in 1..4) {
            $null=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$id+'/players') -Method Post -ContentType 'application/json' -Body (@{name=('Synthetic Player '+$number);elo=(2000-$number*100)}|ConvertTo-Json) -NoProxy -MaximumRedirection 0
        }
        Click-Ui 'Runde'
        # A poll can change readiness between two Marionette roundtrips. Check
        # eligibility and perform the one actual click in the same browser task.
        Wait-Ui 'const n=document.querySelector(".panel-header .actions button:not(.secondary)");if(!n||n.disabled)return false;n.click();return true;'
        Wait-Ui 'return !!document.querySelector("select[aria-label=\"Ergebnis: Runde 1, Brett 1\"]");'
        $state=Get-SyntheticTournament $id
        Assert-Ui ($state.rounds.Count -eq 1 -and $state.rounds[0].pairings.Count -eq 2) 'real UI pairing produces one complete first round'
        $top=@($state.players|Sort-Object {$_.rating.elo} -Descending)[0]
        $topBoard=@($state.rounds[0].pairings|Where-Object {$_.whitePlayerId -eq $top.id -or $_.blackPlayerId -eq $top.id})[0]
        if ($case.strategy -eq 0) {
            Assert-Ui ($state.rounds[0].audit.algorithm -ceq 'Swiss-ScoreGroup-Optimal-V2') 'actual round audit proves the selected Optimal V2 strategy executed'
        } else {
            Assert-Ui ($(if($opposite -eq 1){$topBoard.whitePlayerId -eq $top.id}else{$topBoard.blackPlayerId -eq $top.id})) 'selected Dutch initial colour reaches actual first-round pairing'
        }
        Open-Area 'Verwaltung & Audit'
        Wait-Ui 'return !!document.querySelector(".settings-form");'
        Assert-Ui ([bool](Invoke-MarionetteScript 'const labels=[...document.querySelectorAll(".settings-form label")];const colour=labels.find(n=>n.textContent.trim().startsWith("Anfangsfarbe"));return labels.slice(0,2).every(n=>n.querySelector("select").disabled)&&(!colour||colour.querySelector("select").disabled);')) 'format strategy and any applicable initial colour are locked after round one'
    }
    $existingId=$createdIds[0]
    $before=Get-SyntheticTournament $existingId | ConvertTo-Json -Depth 100 -Compress
    $existingName=(Get-SyntheticTournament $existingId).name
    Invoke-MarionetteScript -Arguments @($existingName) -Script 'const n=[...document.querySelectorAll(".list button")].find(n=>n.textContent.startsWith(arguments[0]));n.click();return true;' | Out-Null
    Wait-Ui 'return !!document.querySelector(".settings-form");'
    Set-Ui '.settings-form input[type=number]' '17'
    Open-Area 'Turnierassistent'
    Wait-Ui 'return !!document.querySelector(".assistant-form");'
    Set-Ui '.assistant-form input[type=number]' '6'
    Click-Ui 'Empfehlung übernehmen'
    Wait-Ui 'return !!document.querySelector(".create-tournament-form") && !!document.querySelector(".settings-form");'
    Assert-Ui ([bool](Invoke-MarionetteScript 'return document.querySelector(".settings-form input[type=number]").value==="17";')) 'recommendation preserves an existing unsaved settings draft'
    Set-Ui '.create-tournament-form input' 'Synthetic Recommendation Payload'
    Invoke-MarionetteScript 'document.querySelector(".create-tournament-form").requestSubmit();return true;' | Out-Null
    Wait-Ui 'return document.querySelector(".list button.selected")?.textContent.startsWith("Synthetic Recommendation Payload");'
    $all=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments') -NoProxy -MaximumRedirection 0
    $recommended=@($all|Where-Object name -CEQ 'Synthetic Recommendation Payload')[0]
    $state=Get-SyntheticTournament $recommended.id
    Assert-Ui ($state.settings.format -eq 0 -and $state.settings.plannedRounds -eq 5) 'recommendation sends its actual format and round count in create payload'
    Assert-Ui ((Get-SyntheticTournament $existingId|ConvertTo-Json -Depth 100 -Compress) -ceq $before) 'recommendation leaves the stored existing tournament unchanged'
    Open-Area 'Druck, Export & Backup'
    Wait-Ui 'return !!document.querySelector("textarea[placeholder^=\"Backup-JSON\"]");'
    Set-Ui 'textarea[placeholder^="Backup-JSON"]' '{"synthetic-private-marker":"must-not-appear",'
    Click-Ui 'Backup importieren'
    Wait-Ui 'return !!document.querySelector(".error");'
    Assert-Ui ([bool](Invoke-MarionetteScript 'return !document.querySelector(".error").textContent.includes("synthetic-private-marker");')) 'malformed backup error never echoes its content'
    $backup=Get-SyntheticTournament $recommended.id
    $backup.name='Synthetic Restored UI Backup'
    $backupText=$backup|ConvertTo-Json -Depth 100 -Compress
    Set-Ui 'textarea[placeholder^="Backup-JSON"]' $backupText
    Click-Ui 'Backup importieren'
    Wait-Ui 'return !!document.querySelector("[role=alertdialog] input");'
    Assert-Ui ((Get-SyntheticTournament $recommended.id).name -ceq 'Synthetic Recommendation Payload') 'existing backup target is unchanged before explicit typed confirmation'
    Click-Ui 'Abbrechen'
    Assert-Ui ((Get-SyntheticTournament $recommended.id).name -ceq 'Synthetic Recommendation Payload') 'cancelling restore preserves the existing tournament'
    Click-Ui 'Backup importieren'
    Wait-Ui 'return !!document.querySelector("[role=alertdialog] input");'
    Set-Ui '[role=alertdialog] input' 'Synthetic Recommendation Payload'
    Invoke-MarionetteScript 'const n=[...document.querySelectorAll("[role=alertdialog] button")].find(n=>n.textContent.includes("Durch dieses Backup ersetzen")&&!n.disabled);if(!n)throw new Error("Typed restore is not enabled");n.click();return true;' | Out-Null
    Wait-Ui 'return document.querySelector(".list button.selected")?.textContent.startsWith("Synthetic Restored UI Backup");'
    Assert-Ui ((Get-SyntheticTournament $recommended.id).name -ceq 'Synthetic Restored UI Backup') 'explicitly confirmed restore persists the intended backup'
    $beforeRestart=Get-SyntheticTournament $createdIds[2] | ConvertTo-Json -Depth 100 -Compress
    Stop-StmFirefoxBackend -Context $smoke -Handle $backend
    $backend=Start-StmFirefoxBackend -Context $smoke
    Open-MarionetteUrl ($smoke.BaseUrl+'/')
    Wait-Ui 'return document.querySelectorAll(".list button").length===4;'
    Assert-Ui ((Get-SyntheticTournament $createdIds[2]|ConvertTo-Json -Depth 100 -Compress) -ceq $beforeRestart) 'SQLite restart preserves selected strategy colour and actual round'
    Write-Host "SETTINGS_RESTORE_BROWSER=$passed PASS; 0 FAIL; 0 SKIP"
}
catch {
    $smoke.Failed=$true
    try {
        $ui=Invoke-MarionetteScript 'return {language:document.documentElement.lang,selected:document.querySelector(".list button.selected")?.textContent,tab:document.querySelector(".tab-bar [aria-selected=true]")?.textContent,status:document.querySelector(".status-line")?.textContent,errors:[...document.querySelectorAll(".error")].map(n=>n.textContent),resultLabels:[...document.querySelectorAll("select[aria-label]")].map(n=>n.getAttribute("aria-label")),boundary:!!document.querySelector(".app-error-boundary")};'
        $states=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments') -NoProxy -MaximumRedirection 0
        [ordered]@{ui=$ui;syntheticStates=@($states|ForEach-Object {[ordered]@{name=$_.name;rounds=@($_.rounds).Count;players=@($_.players).Count;strategy=$_.settings.pairingStrategy;colour=$_.settings.swissInitialColour}})} |
            ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $smoke.DataDirectory 'synthetic-settings-digest.json')
    }catch{}
    throw
}
finally {
    try { Disconnect-Marionette } catch { }
    Stop-StmFirefoxSmoke -Context $smoke
}
