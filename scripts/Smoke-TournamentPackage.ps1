#requires -Version 7.0
# Synthetic package API acceptance; correction audit inventory retains contributor ownership.
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$SourceAssemblyPath,
 [Parameter(Mandatory)][string]$ReportPath,
 [int]$Port=5111,
 [int]$ReservedControlPort=2851
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $root 'scripts/lib/FirefoxSmokeCommon.ps1')
$context=New-StmFirefoxSmokeContext -Root $root -Port $Port -MarionettePort $ReservedControlPort -SourceAssemblyPath $SourceAssemblyPath -SkipPack
$checks=[Collections.Generic.List[string]]::new()
function Call([string]$Path,[string]$Method='GET',$Body=$null){
 $requestArguments=@{Uri=$context.BaseUrl+$Path;Method=$Method;NoProxy=$true;TimeoutSec=30;MaximumRedirection=0}
 if($null-ne$Body){$requestArguments.ContentType='application/json';$requestArguments.Body=$Body|ConvertTo-Json -Depth 20 -Compress}
 Invoke-RestMethod @requestArguments
}
function Check([bool]$Value,[string]$Name){if(-not$Value){throw $Name};$checks.Add($Name)}
try{
 if(Test-Path -LiteralPath $ReportPath){throw 'Fresh report path required.'}
 $backend=Start-StmFirefoxBackend $context
 $t=Call '/api/tournaments' POST @{name='<img src=x onerror=synthetic()> Synthetic package';settings=@{format=0;plannedRounds=1}}
 foreach($name in @('<script>synthetic()</script>','Synthetic Other')){$null=Call "/api/tournaments/$($t.id)/players" POST @{name=$name;elo=1600}}
 $null=Call "/api/tournaments/$($t.id)/pairings/next-round" POST
 $null=Call "/api/tournaments/$($t.id)/results" POST @{roundNumber=1;boardNumber=1;result=1;expectedPreviousResult=0}
 $null=Call "/api/tournaments/$($t.id)/results" POST @{roundNumber=1;boardNumber=1;result=3;expectedPreviousResult=1}
 $before=Call "/api/tournaments/$($t.id)"|ConvertTo-Json -Depth 100 -Compress
 $json=Invoke-WebRequest ($context.BaseUrl+"/api/tournaments/$($t.id)/package/export.json") -NoProxy -MaximumRedirection 0
 Check ($json.StatusCode-eq200) 'package JSON route returns 200'
 Check (($json.Headers['Content-Type'] -join ',')-like'application/json*') 'package JSON content type'
 $package=$json.Content|ConvertFrom-Json
 $fields=@($package.PSObject.Properties.Name)
 Check ($fields-contains'tournament') 'package carries tournament object'
 Check ($fields-contains'participants') 'package carries participants'
 Check (@($package.participants).Count-eq2) 'package carries both synthetic participants'
 Check ($fields-contains'standings') 'package carries standings'
 Check ($fields-contains'currentRound') 'package carries current round'
 $html=Invoke-WebRequest ($context.BaseUrl+"/api/tournaments/$($t.id)/package/print/html") -NoProxy -MaximumRedirection 0
 Check ($html.StatusCode-eq200) 'package HTML route returns 200'
 Check (($html.Headers['Content-Type'] -join ',')-like'text/html*') 'package HTML content type'
 Check ($html.Content-notmatch'<img src=x|<script>synthetic') 'HTML package does not execute synthetic participant or tournament markup'
 Check ($html.Content-match'&lt;script&gt;synthetic') 'HTML package retains escaped participant text'
 $after=Call "/api/tournaments/$($t.id)"
 Check (($after|ConvertTo-Json -Depth 100 -Compress)-ceq$before) 'both package exports preserve persisted state'
 Check (($after.rounds[0].pairings[0].result.kind)-eq3) 'result correction persists the new result'
 $missing=Invoke-WebRequest ($context.BaseUrl+'/api/tournaments/11111111-1111-1111-1111-111111111111/package/export.json') -NoProxy -SkipHttpErrorCheck
 Check ($missing.StatusCode-eq404) 'unknown tournament package returns 404'
 $entries=@($after.auditJournal|Where-Object action -eq 21)
 $report=[ordered]@{timeUtc=[DateTime]::UtcNow.ToString('o');sourceAssemblySha256=(Get-FileHash $context.SourceAssemblyPath).Hash;processId=$backend.Process.Id;port=$context.Port;synthetic=$true;packageChecks=$checks;packageStatus='PASS';correctionAuditInventory=@($entries|Select-Object action,summary,details,reason,roundNumber,boardNumber);interpretation='Correction audit feature belongs to contributor STM-FACH-007. This inventories current behaviour and does not approve its full acceptance.'}
 $report|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $ReportPath -Encoding utf8
 Write-Output "PACKAGE_NATIVE=$($checks.Count) PASS"
}catch{$context.Failed=$true;throw}finally{Stop-StmFirefoxSmoke $context}
