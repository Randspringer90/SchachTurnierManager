#requires -Version 7.0
# Native recovery from isolated read failures; no real participants or databases.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourceAssemblyPath,[string]$FirefoxPath='C:\Program Files\Mozilla Firefox\firefox.exe',[int]$Port=5112,[int]$MarionettePort=2852)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $PSScriptRoot 'lib/MarionetteClient.psm1') -Force -DisableNameChecking
. (Join-Path $PSScriptRoot 'lib/FirefoxSmokeCommon.ps1')
$smoke=New-StmFirefoxSmokeContext -Root $root -Port $Port -MarionettePort $MarionettePort -SourceAssemblyPath $SourceAssemblyPath -SkipPack
$passed=0
function Assert-Projection([bool]$Value,[string]$Name){if(-not$Value){throw "Projection recovery: $Name"};$script:passed++;Write-Host "PASS $Name"}
function Wait-Projection([string]$Script,[string]$Name){$limit=[DateTime]::UtcNow.AddSeconds(30);do{if(Invoke-MarionetteScript $Script){return};Start-Sleep -Milliseconds 150}while([DateTime]::UtcNow-lt$limit);throw "Projection recovery timeout: $Name"}
function Read-ProjectionTournament {Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$script:tournamentId) -NoProxy -MaximumRedirection 0}
function Add-ProjectionPlayer([string]$Name){$body=@{name=$Name;elo=1500}|ConvertTo-Json -Compress; $null=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$tournamentId+'/players') -NoProxy -MaximumRedirection 0 -Method Post -ContentType 'application/json' -Body $body}
try{
 $browserProfile=Join-Path $smoke.DataDirectory 'ff-profile';New-Item -ItemType Directory -Path $browserProfile|Out-Null
 Set-Content (Join-Path $browserProfile 'user.js') -Encoding utf8 -Value @"
user_pref("marionette.port", $MarionettePort);
user_pref("intl.accept_languages", "en-US,en");
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.update.enabled", false);
"@
 $backend=Start-StmFirefoxBackend -Context $smoke
 $created=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments') -NoProxy -Method Post -ContentType 'application/json' -Body '{"name":"Synthetic projection recovery"}'
 $script:tournamentId=[string]$created.id
 Add-ProjectionPlayer 'Synthetic first';Add-ProjectionPlayer 'Synthetic second'
 Start-StmFirefoxBrowser -Context $smoke -Firefox $FirefoxPath -ProfileDirectory $browserProfile|Out-Null
 Connect-Marionette -Port $MarionettePort -TimeoutSeconds 60|Out-Null;Start-MarionetteSession|Out-Null
 Open-MarionetteUrl ($smoke.BaseUrl+'/')
 Wait-Projection 'return !!document.querySelector(".list button.selected") && !document.querySelector(".status-line [aria-busy]");' 'initial projection ready'
 Invoke-MarionetteScript '[...document.querySelectorAll(".tab-bar button")].find(n=>n.textContent.trim()==="Participants").click();return true;'|Out-Null
 Wait-Projection 'return !!document.querySelector(".player-form input");' 'participant editor'
 Invoke-MarionettePageScript '(()=>{const n=document.querySelector(".player-form input");Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,"value").set.call(n,"Synthetic unsaved draft");n.dispatchEvent(new Event("input",{bubbles:true}));document.documentElement.dataset.syntheticProjectionReads="{}";document.documentElement.dataset.syntheticFailNextStanding="1";const original=window.fetch;window.fetch=async function(input,init){const u=new URL(typeof input==="string"?input:input.url,location.href);const match=u.pathname.match(/\/(standings|categories|cross-table|hero-cup|round-diagnostics|audit-journal)$/);if(match){const reads=JSON.parse(document.documentElement.dataset.syntheticProjectionReads);reads[match[1]]=(reads[match[1]]||0)+1;document.documentElement.dataset.syntheticProjectionReads=JSON.stringify(reads);}if(u.pathname.endsWith("/standings")&&document.documentElement.dataset.syntheticFailNextStanding==="1"){document.documentElement.dataset.syntheticFailNextStanding="0";return new Response(JSON.stringify({message:"Synthetic projection failure"}),{status:500,headers:{"Content-Type":"application/json"}});}return original.call(this,input,init);};})();'
 Add-ProjectionPlayer 'Synthetic external update one'
 Wait-Projection 'return document.documentElement.dataset.syntheticFailNextStanding==="0" && document.querySelector(".status-line").textContent.includes("Tournament data could not be loaded");' 'single failed projection becomes visible'
 Assert-Projection ([bool](Invoke-MarionetteScript 'return document.querySelector(".player-form input").value==="Synthetic unsaved draft";')) 'a failed derived read preserves the unsaved participant draft'
 Wait-Projection 'return !document.querySelector(".status-line [aria-busy]") && JSON.parse(document.documentElement.dataset.syntheticProjectionReads||"{}").standings>=2;' 'healthy unchanged polling must recover all projections'
 Assert-Projection ([bool](Invoke-MarionetteScript 'return document.querySelector(".player-form input").value==="Synthetic unsaved draft";')) 'automatic recovery preserves the unsaved draft'
 Assert-Projection ([bool](Invoke-MarionetteScript 'return ["standings","categories","cross-table","hero-cup","round-diagnostics","audit-journal"].every(k=>JSON.parse(document.documentElement.dataset.syntheticProjectionReads||"{}")[k]>=2);')) 'automatic recovery refreshes all six related projections'
 Invoke-MarionetteScript 'document.documentElement.dataset.syntheticFailNextStanding="1";return true;'|Out-Null
 Add-ProjectionPlayer 'Synthetic external update two'
 Wait-Projection 'return document.documentElement.dataset.syntheticFailNextStanding==="0" && !!document.querySelector(".derived-retry");' 'manual retry becomes available after another isolated read failure'
 $before=Read-ProjectionTournament|ConvertTo-Json -Depth 100 -Compress
 Invoke-MarionetteScript 'document.querySelector(".derived-retry").click();return true;'|Out-Null
 Wait-Projection 'return !document.querySelector(".status-line [aria-busy]") && !document.querySelector(".derived-retry");' 'manual retry restores ready state'
 Assert-Projection ([bool](Invoke-MarionetteScript 'return document.querySelector(".player-form input").value==="Synthetic unsaved draft";')) 'manual recovery preserves the unsaved draft'
 Assert-Projection (((Read-ProjectionTournament|ConvertTo-Json -Depth 100 -Compress)-ceq$before)) 'read recovery does not mutate tournament state or add audit events'
 Write-Host "PROJECTION_RECOVERY_BROWSER=$passed PASS; 0 FAIL; 0 SKIP"
}catch{$smoke.Failed=$true;throw}finally{try{Disconnect-Marionette}catch{};Stop-StmFirefoxSmoke -Context $smoke}
