#requires -Version 7.0
# Real local UI/API acceptance; only a generated synthetic FIDE TXT fixture.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceAssemblyPath,
    [int]$Port=5107,
    [int]$MarionettePort=2847,
    [string]$FirefoxPath='C:\Program Files\Mozilla Firefox\firefox.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $PSScriptRoot 'lib/MarionetteClient.psm1') -Force -DisableNameChecking
. (Join-Path $PSScriptRoot 'lib/FirefoxSmokeCommon.ps1')
$smoke=New-StmFirefoxSmokeContext -Root $root -Port $Port -MarionettePort $MarionettePort -SourceAssemblyPath $SourceAssemblyPath -SkipPack
$passed=0
function Assert-Fide([bool]$Condition,[string]$Name){if(-not $Condition){throw "FIDE browser: $Name"};$script:passed++;Write-Host "PASS $Name"}
function Wait-Fide([string]$Script){
    $deadline=[DateTime]::UtcNow.AddSeconds(30)
    do{if(Invoke-MarionetteScript $Script){return};Start-Sleep -Milliseconds 150}while([DateTime]::UtcNow -lt $deadline)
    throw "FIDE browser wait: $Script"
}
function Click-Fide([string]$Selector){
    $found=Invoke-MarionetteScript -Arguments @($Selector) -Script 'const n=document.querySelector(arguments[0]);if(!n||n.disabled)return false;n.click();return true;'
    if(-not $found){throw 'Synthetic FIDE UI control missing or disabled.'}
}
function Set-Fide([string]$Selector,[string]$Value){
    $selectorJson=$Selector|ConvertTo-Json -Compress;$valueJson=$Value|ConvertTo-Json -Compress
    Invoke-MarionettePageScript "(()=>{const n=document.querySelector($selectorJson);Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(n,$valueJson);n.dispatchEvent(new Event('input',{bubbles:true}));})();"
}
function Choose-SyntheticFile([string]$Content){
    $json=$Content|ConvertTo-Json -Compress
    Invoke-MarionettePageScript "(()=>{const file=new File([$json],'synthetic-fide.txt',{type:'text/plain'});const transfer=new DataTransfer();transfer.items.add(file);const n=document.querySelector('.fide-catalog-file');n.files=transfer.files;n.dispatchEvent(new Event('change',{bubbles:true}));})();"
}
function Search-Fide([string]$Query,[string]$Federation=''){
    Set-Fide '.fide-name-query' $Query
    Set-Fide '.fide-federation-query' $Federation
    Invoke-MarionetteScript 'document.querySelector(".fide-name-search").requestSubmit();return true;'|Out-Null
    Wait-Fide 'return !!document.querySelector(".fide-results");'
}
function Get-FideTournament {return Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$script:tournamentId) -NoProxy -MaximumRedirection 0}
try{
    $profile=Join-Path $smoke.DataDirectory 'ff-profile';New-Item -ItemType Directory -Path $profile|Out-Null
    Set-Content (Join-Path $profile 'user.js') -Encoding utf8 -Value @"
user_pref("marionette.port", $MarionettePort);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.update.enabled", false);
"@
    $backend=Start-StmFirefoxBackend -Context $smoke
    $health=Invoke-RestMethod ($smoke.BaseUrl+'/api/health') -NoProxy -MaximumRedirection 0
    Assert-Fide ($health.sqliteVersion -ceq '3.54.1') 'running API reports the pinned native SQLite engine'
    $hostProbe=Invoke-WebRequest ($smoke.BaseUrl+'/api/health') -Headers @{Host=('synthetic-rebinding.invalid:'+$Port)} -NoProxy -MaximumRedirection 0 -SkipHttpErrorCheck
    Assert-Fide ($hostProbe.StatusCode -eq 400) 'untrusted Host is rejected by the running server'
    $foreignProbe=Invoke-WebRequest ($smoke.BaseUrl+'/api/tournaments') -Method Post -ContentType 'application/json' -Body '{"name":"Synthetic forbidden origin"}' -Headers @{Origin='https://synthetic-attacker.invalid'} -NoProxy -MaximumRedirection 0 -SkipHttpErrorCheck
    Assert-Fide ($foreignProbe.StatusCode -eq 403) 'foreign Origin cannot mutate the running API'
    $foreignText=Invoke-WebRequest ($smoke.BaseUrl+'/api/external-players/fide/catalog') -Method Post -ContentType 'text/plain' -Body 'synthetic invalid list' -Headers @{Origin='https://synthetic-attacker.invalid'} -NoProxy -MaximumRedirection 0 -SkipHttpErrorCheck
    Assert-Fide ($foreignText.StatusCode -eq 403) 'simple cross-site text/plain request cannot replace the cache'
    $empty=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments') -NoProxy -MaximumRedirection 0
    Assert-Fide (@($empty).Count -eq 0) 'rejected cross-site creation has no persisted side effect'
    $created=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments') -Method Post -ContentType 'application/json' -Body '{"name":"Synthetic FIDE UI acceptance"}' -NoProxy -MaximumRedirection 0
    $script:tournamentId=[string]$created.id
    $null=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$tournamentId+'/players') -Method Post -ContentType 'application/json' -Body '{"name":"Synthetic Local Kept","fideId":"99900101","federation":"USA","country":"Kept country","title":"CM","elo":1400}' -NoProxy -MaximumRedirection 0
    $before=Get-FideTournament|ConvertTo-Json -Depth 100 -Compress
    Start-StmFirefoxBrowser -Context $smoke -Firefox $FirefoxPath -ProfileDirectory $profile|Out-Null
    Connect-Marionette -Port $MarionettePort -TimeoutSeconds 60|Out-Null;Start-MarionetteSession|Out-Null
    Open-MarionetteUrl ($smoke.BaseUrl+'/')
    Wait-Fide 'return !!document.querySelector(".list button.selected");'
    Invoke-MarionetteScript '[...document.querySelectorAll(".tab-bar button")].find(n=>n.textContent.trim()==="Teilnehmer").click();return true;'|Out-Null
    Wait-Fide 'return !!document.querySelector(".fide-lookup-panel");'
    Search-Fide 'Synthetic'
    Assert-Fide ([bool](Invoke-MarionetteScript 'return document.querySelector(".fide-results").textContent.includes("Offline") && document.querySelectorAll(".fide-result").length===0;')) 'missing cache reports offline without a name network query'
    $header='ID Number     Name                                    Fed SRtng SGm Tit WTit Flag'
    function Row-Fide([string]$Id,[string]$Name,[string]$Federation){return $Id.PadRight(14)+$Name.PadRight(40)+$Federation.PadRight(4)+'1800  '+'1   '+'f   '+'     '}
    $fixture=$header+"`n"+(Row-Fide '99900101' 'Synthetic Alpha' 'GER')+"`n"+(Row-Fide '99900102' 'Synthetic Alpha' 'USA')+"`n"+(Row-Fide '99900103' '<img src=x onerror=alert(1)>' 'GER')+"`n"
    Choose-SyntheticFile $fixture
    Click-Fide '.fide-catalog-import'
    Wait-Fide 'return document.querySelector(".fide-action-status")?.textContent.includes("3 Einträge");'
    Assert-Fide ((Get-FideTournament|ConvertTo-Json -Depth 100 -Compress) -ceq $before) 'loading a list changes no tournament or participant'
    Search-Fide 'Alpha'
    Assert-Fide ([bool](Invoke-MarionetteScript 'return document.querySelectorAll(".fide-result").length===2 && !document.querySelector(".fide-field-review");')) 'ambiguous names remain separate with no automatic selection'
    Search-Fide 'Alpha' 'GER'
    Assert-Fide ([bool](Invoke-MarionetteScript 'return document.querySelectorAll(".fide-result").length===1;')) 'federation filter narrows the actual native UI search'
    Click-Fide '.fide-result button'
    Assert-Fide ([bool](Invoke-MarionetteScript 'return document.querySelectorAll(".fide-field-review input:checked").length===0 && document.querySelector(".fide-apply-selected").disabled;')) 'all fields require explicit selection before any write'
    Click-Fide '[data-fide-field=elo]';Click-Fide '[data-fide-field=federation]'
    Click-Fide '.fide-apply-selected'
    Wait-Fide 'return !!document.querySelector("[role=alertdialog]");'
    Assert-Fide ((Get-FideTournament|ConvertTo-Json -Depth 100 -Compress) -ceq $before) 'field preview and confirmation opening do not mutate data'
    Invoke-MarionetteScript '[...document.querySelectorAll("[role=alertdialog] button")].find(n=>n.textContent.trim()==="Abbrechen").click();return true;'|Out-Null
    Assert-Fide ((Get-FideTournament|ConvertTo-Json -Depth 100 -Compress) -ceq $before) 'declining the field confirmation leaves all data unchanged'
    Click-Fide '.fide-apply-selected'
    Wait-Fide 'return !!document.querySelector("[role=alertdialog]");'
    Invoke-MarionetteScript '[...document.querySelectorAll("[role=alertdialog] button")].find(n=>n.textContent.includes("Ausgewählte Felder bestätigen")).click();return true;'|Out-Null
    Wait-Fide 'return document.querySelector(".fide-action-status")?.textContent.includes("Bestätigte Felder");'
    $updated=Get-FideTournament;$player=$updated.players[0]
    Assert-Fide ($player.rating.elo -eq 1800 -and $player.federation -ceq 'GER') 'confirmed rating and federation are applied'
    Assert-Fide ($player.name -ceq 'Synthetic Local Kept' -and $player.country -ceq 'Kept country' -and $player.title -ceq 'CM') 'unchecked name country and title retain their local values'
    Assert-Fide (@($updated.auditJournal|Where-Object {$_.action -eq 3 -and $_.summary -like '*Felder:*Elo*'}).Count -eq 1) 'successful field adoption has one audit entry naming its changed fields'
    Click-Fide '.fide-result button';Click-Fide '[data-fide-field=elo]'
    $updateBody=@{}
    foreach($property in $player.PSObject.Properties){if($property.Name -notin @('rating','id','isActive')){$updateBody[$property.Name]=$property.Value}}
    foreach($property in $player.rating.PSObject.Properties){$updateBody[$property.Name]=$property.Value}
    $updateBody['elo']=1900
    $null=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$tournamentId+'/players/'+$player.id) -Method Put -ContentType 'application/json' -Body ($updateBody|ConvertTo-Json -Depth 20) -NoProxy -MaximumRedirection 0
    Click-Fide '.fide-apply-selected'
    Wait-Fide 'return !!document.querySelector("[role=alertdialog]");'
    Invoke-MarionetteScript '[...document.querySelectorAll("[role=alertdialog] button")].find(n=>n.textContent.includes("Ausgewählte Felder bestätigen")).click();return true;'|Out-Null
    Wait-Fide 'return document.querySelector(".fide-error")?.textContent.includes("seit der Vorschau");'
    Assert-Fide ((Get-FideTournament).players[0].rating.elo -eq 1900) 'stale confirmed preview cannot overwrite newer local edits'
    Invoke-MarionetteScript '[...document.querySelectorAll("[role=alertdialog] button")].find(n=>n.textContent.trim()==="Abbrechen").click();return true;'|Out-Null
    Search-Fide 'img'
    Assert-Fide ([bool](Invoke-MarionetteScript 'return document.querySelector(".fide-result strong").textContent.includes("<img") && document.querySelectorAll(".fide-results img").length===0;')) 'external HTML-shaped names are displayed as text'
    Choose-SyntheticFile 'synthetic invalid rating list'
    Click-Fide '.fide-catalog-import'
    Wait-Fide 'return !!document.querySelector(".fide-error");'
    Search-Fide 'Alpha'
    Assert-Fide ([bool](Invoke-MarionetteScript 'return document.querySelectorAll(".fide-result").length===2;')) 'failed list replacement preserves the last valid searchable cache'
    Stop-StmFirefoxBackend -Context $smoke -Handle $backend
    $backend=Start-StmFirefoxBackend -Context $smoke
    Open-MarionetteUrl ($smoke.BaseUrl+'/')
    Wait-Fide 'return !!document.querySelector(".fide-lookup-panel");'
    Search-Fide 'Alpha' 'GER'
    Assert-Fide ([bool](Invoke-MarionetteScript 'return document.querySelectorAll(".fide-result").length===1;')) 'local FIDE cache remains searchable after a real server restart'
    Assert-Fide ((Get-FideTournament).players[0].rating.elo -eq 1900) 'restarted SQLite retains the latest local edit'
    Invoke-MarionettePageScript '(()=>{const n=document.querySelector(".language-switcher select");Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype,"value").set.call(n,"en");n.dispatchEvent(new Event("change",{bubbles:true}));})();'
    Wait-Fide 'return document.querySelector(".fide-lookup-panel h3")?.textContent.includes("FIDE name search");'
    Assert-Fide ([bool](Invoke-MarionetteScript 'return document.querySelector(".fide-name-query")?.value==="Alpha";')) 'English language switch preserves unsaved search input'
    Search-Fide 'Alpha' 'GER'
    Assert-Fide ([bool](Invoke-MarionetteScript 'return !!document.querySelector(".fide-results")?.textContent.includes("local matches");')) 'a real search in English displays localized results'
    Choose-SyntheticFile 'synthetic invalid rating list'
    Click-Fide '.fide-catalog-import'
    Wait-Fide 'return document.querySelector(".fide-error")?.textContent.includes("standard TXT list");'
    Assert-Fide ([bool](Invoke-MarionetteScript 'return !document.querySelector(".fide-error").textContent.includes("synthetic invalid");')) 'structured list rejection is localized in English without raw input'
    Stop-StmFirefoxBackend -Context $smoke -Handle $backend
    Set-Fide '.fide-name-query' 'Synthetic offline'
    Invoke-MarionetteScript 'document.querySelector(".fide-name-search").requestSubmit();return true;'|Out-Null
    Wait-Fide 'return !!document.querySelector(".fide-error") && !document.querySelector(".fide-name-query").disabled;'
    Assert-Fide ([bool](Invoke-MarionetteScript 'return document.querySelector(".fide-error").textContent.includes("local server") && !/NetworkError|TypeError/.test(document.querySelector(".fide-error").textContent);')) 'backend loss produces a visible localized failure and restores the controls'
    Write-Host "FIDE_LOOKUP_BROWSER=$passed PASS; 0 FAIL; 0 SKIP"
}
catch{
    $smoke.Failed=$true
    try {
        Invoke-MarionetteScript 'return {language:document.documentElement.lang,hasPanel:!!document.querySelector(".fide-lookup-panel"),hasResults:!!document.querySelector(".fide-results"),query:document.querySelector(".fide-name-query")?.value,tab:document.querySelector(".tab-bar [aria-selected=true]")?.textContent,boundary:!!document.querySelector(".app-error-boundary")};' |
            ConvertTo-Json | Set-Content -LiteralPath (Join-Path $smoke.DataDirectory 'synthetic-ui-digest.json')
    }catch{}
    throw
}
finally{try{Disconnect-Marionette}catch{};Stop-StmFirefoxSmoke -Context $smoke}
