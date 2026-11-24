#requires -Version 7.0
# Real operator-language checks; synthetic tournaments, isolated SQLite and owned processes.
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$SourceAssemblyPath,
 [string]$FirefoxPath='C:\Program Files\Mozilla Firefox\firefox.exe',
 [int]$Port=5110,
 [int]$MarionettePort=2850,
 [switch]$RtlOnly,
 [switch]$ValidationOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $PSScriptRoot 'lib/MarionetteClient.psm1') -Force -DisableNameChecking
. (Join-Path $PSScriptRoot 'lib/FirefoxSmokeCommon.ps1')
$smoke=New-StmFirefoxSmokeContext -Root $root -Port $Port -MarionettePort $MarionettePort -SourceAssemblyPath $SourceAssemblyPath -SkipPack
$passed=0
function Assert-Language([bool]$Value,[string]$Name){if(-not $Value){throw "Operator languages: $Name"};$script:passed++;Write-Host "PASS $Name"}
function Wait-Language([string]$Script){
 $deadline=[DateTime]::UtcNow.AddSeconds(30)
 do{if(Invoke-MarionetteScript $Script){return};Start-Sleep -Milliseconds 150}while([DateTime]::UtcNow -lt $deadline)
 throw 'Operator language browser condition timed out.'
}
function Choose-Language([string]$Code){
 $json=$Code|ConvertTo-Json -Compress
 Invoke-MarionettePageScript "(()=>{const n=document.querySelector('.language-switcher select');n.value=$json;n.dispatchEvent(new Event('change',{bubbles:true}));})();"
 Wait-Language "return document.documentElement.lang===$json;"
}
function Open-LanguageArea([string]$More,[string]$Destination,[string]$Selector){
 $moreJson=$More|ConvertTo-Json -Compress
 $destinationJson=$Destination|ConvertTo-Json -Compress
 Invoke-MarionetteScript "[...document.querySelectorAll('.tab-bar button')].find(n=>n.textContent.trim()===$moreJson).click();return true;"|Out-Null
 Wait-Language 'return !!document.querySelector(".more-grid");'
 Invoke-MarionetteScript "[...document.querySelectorAll('.more-grid button')].find(n=>n.querySelector('strong')?.textContent.trim()===$destinationJson).click();return true;"|Out-Null
 $selectorJson=$Selector|ConvertTo-Json -Compress
 Wait-Language "return !!document.querySelector($selectorJson);"
}
try{
 $profile=Join-Path $smoke.DataDirectory 'ff-profile';New-Item -ItemType Directory -Path $profile|Out-Null
 Set-Content -LiteralPath (Join-Path $profile 'user.js') -Encoding utf8 -Value @"
user_pref("marionette.port", $MarionettePort);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.update.enabled", false);
"@
 $backend=Start-StmFirefoxBackend -Context $smoke
 $created=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments') -NoProxy -Method Post -ContentType 'application/json' -Body '{"name":"Synthetic operator languages","settings":{"format":1,"pairingStrategy":0,"plannedRounds":3}}'
 foreach($number in 1..2){
  $payload=@{name="Synthetic language player $number";elo=(1800-$number)}|ConvertTo-Json -Compress
  $null=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id+'/players') -NoProxy -Method Post -ContentType 'application/json' -Body $payload
 }
 $before=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id) -NoProxy|ConvertTo-Json -Depth 100 -Compress
 Start-StmFirefoxBrowser -Context $smoke -Firefox $FirefoxPath -ProfileDirectory $profile|Out-Null
 Connect-Marionette -Port $MarionettePort -TimeoutSeconds 60|Out-Null;Start-MarionetteSession|Out-Null
 Open-MarionetteUrl ($smoke.BaseUrl+'/')
 Wait-Language 'return !!document.querySelector(".list button.selected");'
 if($ValidationOnly){
  Choose-Language 'en'
  Open-LanguageArea 'More' 'Administration & audit' '.settings-card'
  Invoke-MarionetteScript '[...document.querySelectorAll(".settings-card button")].find(n=>n.textContent.trim()==="Save settings").click();return true;'|Out-Null
  Wait-Language 'return document.body.textContent.includes("Tournament settings saved.") || document.body.textContent.includes("Turniereinstellungen gespeichert.");'
  Assert-Language ([bool](Invoke-MarionetteScript 'return document.body.textContent.includes("Tournament settings saved. Standings and tie-breaks recalculated.") && !document.body.textContent.includes("Turniereinstellungen gespeichert.");')) 'successful settings save is confirmed in English'
  $invalidName=Invoke-WebRequest ($smoke.BaseUrl+'/api/tournaments') -NoProxy -SkipHttpErrorCheck -Method Post -ContentType 'application/json' -Body '{"name":" "}'
  $nameError=$invalidName.Content|ConvertFrom-Json
  Assert-Language ($invalidName.StatusCode -eq 400 -and $nameError.code -ceq 'TOURNAMENT_NAME_REQUIRED' -and $nameError.error.Contains('Turniername')) 'actual API keeps the original error and adds the stable validation code'
  Invoke-MarionettePageScript '(()=>{const select=document.querySelector(".settings-form select");select.value="0";select.dispatchEvent(new Event("change",{bubbles:true}));})();'
  Invoke-MarionettePageScript '(()=>{const original=window.fetch.bind(window);window.fetch=async(input,init)=>{if(String(input).endsWith("/settings") && init?.method==="PUT"){document.documentElement.dataset.validationSavePending="true";await new Promise(resolve=>document.addEventListener("stm-validation-release",resolve,{once:true}));}return original(input,init);};})();'
  Invoke-MarionetteScript '[...document.querySelectorAll(".settings-card button")].find(n=>n.textContent.trim()==="Save settings").click();return true;'|Out-Null
  Wait-Language 'return document.documentElement.dataset.validationSavePending==="true";'
  $null=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id+'/pairings/next-round') -NoProxy -Method Post -ContentType 'application/json' -Body '{}'
  $beforeRejectedSave=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id) -NoProxy|ConvertTo-Json -Depth 100 -Compress
  Invoke-MarionetteScript 'document.dispatchEvent(new Event("stm-validation-release"));return true;'|Out-Null
  Wait-Language 'return document.body.textContent.includes("The tournament format cannot be changed after rounds have been paired.");'
  Assert-Language ([bool](Invoke-MarionetteScript 'return document.body.textContent.includes("The tournament format cannot be changed after rounds have been paired.") && !document.body.textContent.includes("Das Turnierformat kann nach");')) 'real stale-client settings rejection is readable in English'
  $afterRejectedSave=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id) -NoProxy|ConvertTo-Json -Depth 100 -Compress
  Assert-Language ($beforeRejectedSave -ceq $afterRejectedSave) 'rejected settings leave the stored round, results and audit unchanged'
  Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".settings-form select").value==="0";')) 'failed save preserves the unsaved settings draft'
  Write-Host "OPERATOR_VALIDATION_BROWSER=$passed PASS; 0 FAIL; 0 SKIP"
  return
 }
 if($RtlOnly){
  $null=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id+'/pairings/next-round') -NoProxy -Method Post
  $beforeRtl=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id) -NoProxy|ConvertTo-Json -Depth 100 -Compress
  Open-MarionetteUrl ($smoke.BaseUrl+'/?dice='+$created.id+'&round=1&board=1')
  Wait-Language 'return !!document.querySelector(".board-dice-roller");'
  Choose-Language 'ar'
  Assert-Language ([bool](Invoke-MarionetteScript 'return document.documentElement.lang==="ar" && document.documentElement.dir==="rtl";')) 'Arabic really uses the right-to-left interface'
  Invoke-MarionetteScript 'document.querySelector(".board-dice-roller button").click();return true;'|Out-Null
  Wait-Language 'return document.querySelectorAll(".board-dice-square").length===8;'
  $leftEdges=@(Invoke-MarionetteScript 'return [...document.querySelectorAll(".board-dice-square")].map(n=>n.getBoundingClientRect().left);')
  Write-Host "RTL_DICE_LAYOUT_FIRST_LEFT=$($leftEdges[0]) LAST_LEFT=$($leftEdges[7])"
  Assert-Language ($leftEdges[0] -lt $leftEdges[7]) 'Chess960 a-to-h squares keep their authoritative left-to-right order under Arabic'
  $afterRtl=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id) -NoProxy|ConvertTo-Json -Depth 100 -Compress
  Assert-Language ($beforeRtl -ceq $afterRtl) 'RTL preview and language change do not mutate saved tournament data'
  Write-Host "RTL_DICE_BROWSER=$passed PASS; 0 FAIL; 0 SKIP"
  return
 }
 Choose-Language 'en'
 Open-LanguageArea 'More' 'Administration & audit' '.settings-card'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".settings-card h3").textContent==="Tournament settings";')) 'English settings heading'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".admin-danger-card h3").textContent==="Dangerous actions";')) 'English destructive-action heading'
 Assert-Language ([bool](Invoke-MarionetteScript 'return [...document.querySelectorAll(".settings-form select option")].some(n=>n.textContent==="Round robin");')) 'existing tournament format options translated'
 Assert-Language ([bool](Invoke-MarionetteScript 'return [...document.querySelectorAll(".settings-form select option")].some(n=>n.textContent.includes("Exclude forfeits"));')) 'forfeit policy meaning translated'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".settings-card").textContent.includes("Direct encounter");')) 'tie-break labels translated'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".audit-journal-card h3").textContent==="Audit journal";')) 'English audit journal heading'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".audit-journal-card").textContent.includes("Tournament created") && document.querySelector(".audit-journal-card").textContent.includes("Player added");')) 'persisted numeric audit actions have English labels'
 Open-LanguageArea 'More' 'Print, export & backup' '.csv-reimport-note'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.body.textContent.includes("Check import") && document.body.textContent.includes("Replace existing participants");')) 'English CSV import controls'
 Open-LanguageArea 'More' 'Administration & audit' '.settings-card'
 Choose-Language 'de'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".settings-card h3").textContent==="Turniereinstellungen" && document.querySelector(".audit-journal-card h3").textContent==="Audit-Journal";')) 'switching back restores German operator headings'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".audit-journal-card").textContent.includes("Turnier angelegt");')) 'German audit action meaning preserved'
 Choose-Language 'en'
 Open-LanguageArea 'More' 'Tournament assistant' '.assistant-card'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".assistant-card h3").textContent==="Which format fits?";')) 'English assistant heading'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".assistant-result").textContent.includes("round(s)");')) 'English recommendation retains visible round count'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".assistant-card").textContent.includes("Save audit evidence and a backup after each round");')) 'English tournament-day checklist'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".knowledge-quick-actions button").textContent==="How do I start a tournament?";')) 'English quick questions are actual local help inputs'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".knowledge-welcome").textContent.startsWith("I am your local tournament help.");')) 'initial help greeting follows the current UI language'
 Invoke-MarionetteScript '[...document.querySelectorAll(".knowledge-quick-actions button")].find(n=>n.textContent==="What data is sent to AI?").click();return true;'|Out-Null
 Wait-Language 'return [...document.querySelectorAll(".knowledge-message.assistant")].at(-1)?.textContent.includes("AI help and privacy");'
 Assert-Language ([bool](Invoke-MarionetteScript 'return [...document.querySelectorAll(".knowledge-message.assistant")].at(-1).textContent.includes("No tournament data was sent to external AI services") && [...document.querySelectorAll(".knowledge-message.assistant")].at(-1).querySelector("strong").textContent==="Tournament help";')) 'English privacy answer and speaker label come from local language data'
 Invoke-MarionettePageScript '(()=>{const n=document.querySelector(".knowledge-chat-input input");Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,"value").set.call(n,"Synthetic unsent language draft");n.dispatchEvent(new Event("input",{bubbles:true}));})();'
 Choose-Language 'de'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".knowledge-chat-input input").value==="Synthetic unsent language draft" && document.querySelector(".knowledge-quick-actions button").textContent==="Wie starte ich ein Turnier?";')) 'German language switch preserves the unsent help draft and translates quick questions'
 Invoke-MarionetteScript '[...document.querySelectorAll(".knowledge-quick-actions button")].find(n=>n.textContent==="Welche Daten gehen an KI?").click();return true;'|Out-Null
 Wait-Language 'return [...document.querySelectorAll(".knowledge-message.assistant")].at(-1)?.textContent.includes("KI-Chatbot und Datenschutz");'
 Assert-Language ([bool](Invoke-MarionetteScript 'return [...document.querySelectorAll(".knowledge-message.assistant")].at(-1).textContent.includes("Diese Antwort kommt aus der lokalen Wissensbasis");')) 'German local help remains available after a real language switch'
 Choose-Language 'en'
 Invoke-MarionetteScript '[...document.querySelectorAll(".knowledge-quick-actions button")].find(n=>n.textContent==="How do I use QR/mobile?").click();return true;'|Out-Null
 Wait-Language 'return [...document.querySelectorAll(".knowledge-message.assistant")].at(-1)?.textContent.includes("QR/mobile and Chess960");'
 Assert-Language ([bool](Invoke-MarionetteScript 'const text=[...document.querySelectorAll(".knowledge-message.assistant")].at(-1).textContent;return text.includes("up to 200") && text.includes("TLS") && text.includes("blocked by the secure defaults");')) 'mobile help describes the implemented queue and actual secure LAN boundary'
 Assert-Language ([bool](Invoke-MarionetteScript 'return [...document.querySelectorAll(".knowledge-message.assistant")][0].textContent.includes("AI help and privacy");')) 'language switches retain earlier chat history without rewriting it'
 $after=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id) -NoProxy|ConvertTo-Json -Depth 100 -Compress
 Assert-Language ($after -ceq $before) 'language switches and assistant viewing do not mutate the tournament'
 Open-MarionetteUrl ($smoke.BaseUrl+'/')
 Wait-Language 'return !!document.querySelector(".list button.selected") && document.documentElement.lang==="en";'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".language-switcher select").value==="en";')) 'English choice persists after a real page reload'
 $null=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id+'/pairings/next-round') -NoProxy -Method Post
 Open-MarionetteUrl ($smoke.BaseUrl+'/?dice='+$created.id+'&round=1&board=1')
 Wait-Language 'return !!document.querySelector(".board-dice-roller") && document.documentElement.lang==="en";'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".mobile-dice-header").textContent.includes("Round 1 · Board 1") && document.querySelector(".dice-result-line").textContent==="Ready to roll for this board.";')) 'mobile board inherits English and shows the actual round and board'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".mobile-dice-foot").textContent.includes("TLS") && document.querySelector(".mobile-dice-foot").textContent.includes("same Wi-Fi alone is insufficient");')) 'mobile board explains the actual protected LAN requirement'
 Invoke-MarionettePageScript '(()=>{const original=window.fetch;window.fetch=function(input,options){if(options?.method==="POST" && String(input).includes("/chess960/start-positions/")){document.body.dataset.dicePayload=options.body;}return original.call(this,input,options);};})();'
 Invoke-MarionetteScript 'document.querySelector(".board-dice-roller button").click();return true;'|Out-Null
 Wait-Language 'return !![...document.querySelectorAll(".board-dice-roller button")].find(n=>n.textContent.includes("Save for board"));'
 $englishPreview=[string](Invoke-MarionetteScript 'return document.querySelector(".dice-result-line").textContent;')
 Assert-Language ($englishPreview -match '^Result: [RNBQK]{8} · SP \d+$') 'English dice reveal contains the authoritative position-number input'
 Choose-Language 'de'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".dice-result-line").textContent.startsWith("Ergebnis:") && [...document.querySelectorAll(".board-dice-roller button")].some(n=>n.textContent.includes("Für Brett speichern"));')) 'German dice controls remain available without resetting the preview'
 $germanPreview=[string](Invoke-MarionetteScript 'return document.querySelector(".dice-result-line").textContent;')
 Assert-Language (($englishPreview -replace '^Result: ','') -ceq ($germanPreview -replace '^Ergebnis: ','')) 'switching language preserves the exact generated back rank and position number'
 Choose-Language 'en'
 Invoke-MarionetteScript '[...document.querySelectorAll(".board-dice-roller button")].find(n=>n.textContent.includes("Save for board")).click();return true;'|Out-Null
 Wait-Language 'return document.querySelector(".board-dice-ok")?.textContent.startsWith("Saved: SP");'
 $firstPayload=([string](Invoke-MarionetteScript 'return document.body.dataset.dicePayload;'))|ConvertFrom-Json
 $savedTournament=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id) -NoProxy
 $savedPosition=$savedTournament.rounds[0].pairings[0].chess960StartPosition
 Assert-Language ($firstPayload.overwriteExisting -eq $false -and $savedPosition.positionNumber -eq $firstPayload.positionNumber) 'English save sends unchanged typed false and persists the selected position number'
 Assert-Language ($englishPreview -ceq "Result: $($savedPosition.whiteBackRank) · SP $($savedPosition.positionNumber)") 'backend-derived saved back rank matches the displayed preview'
 $beforeCancel=$savedTournament|ConvertTo-Json -Depth 100 -Compress
 Invoke-MarionetteScript 'document.querySelector(".board-dice-roller button").click();return true;'|Out-Null
 Wait-Language 'return !![...document.querySelectorAll(".board-dice-roller button")].find(n=>n.textContent.includes("Save for board"));'
 Invoke-MarionetteScript '[...document.querySelectorAll(".board-dice-roller button")].find(n=>n.textContent.includes("Save for board")).click();return true;'|Out-Null
 Wait-Language 'return !!document.querySelector(".confirm-dialog");'
 Assert-Language ([bool](Invoke-MarionetteScript 'const dialog=document.querySelector(".confirm-dialog");return dialog.querySelector("h3").textContent==="Board 1: overwrite starting position?" && dialog.textContent.includes("Previous:") && dialog.textContent.includes("New:");')) 'English overwrite confirmation explains the old and new positions'
 Invoke-MarionetteScript '[...document.querySelectorAll(".confirm-dialog button")].find(n=>n.textContent==="Cancel").click();return true;'|Out-Null
 Wait-Language 'return !document.querySelector(".confirm-dialog");'
 $afterCancel=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id) -NoProxy|ConvertTo-Json -Depth 100 -Compress
 Assert-Language ($beforeCancel -ceq $afterCancel) 'cancelling the English overwrite leaves the persisted tournament unchanged'
 Open-MarionetteUrl ($smoke.BaseUrl+'/?dice='+$created.id+'&round=1&board=999')
 Wait-Language 'return document.querySelector(".board-dice-error")?.textContent.includes("This board was not found");'
 Assert-Language ([bool](Invoke-MarionetteScript 'return !document.querySelector(".board-dice-roller");')) 'missing mobile board shows a translated error without mutation controls'
 Open-MarionetteUrl ($smoke.BaseUrl+'/')
 Wait-Language 'return !!document.querySelector(".list button.selected");'
 Invoke-MarionetteScript '[...document.querySelectorAll(".tab-bar button")].find(n=>n.textContent.trim()==="Round").click();return true;'|Out-Null
 Wait-Language 'return !!document.querySelector(".board-dice-button");'
 Invoke-MarionetteScript 'document.querySelector(".chess960-dice-panel").open=true;document.querySelector(".board-dice-button").click();return true;'|Out-Null
 Wait-Language 'return !!document.querySelector(".board-dice-tabs");'
 Invoke-MarionetteScript '[...document.querySelectorAll(".board-dice-tabs button")].find(n=>n.textContent.includes("QR")).click();return true;'|Out-Null
 Wait-Language 'return !!document.querySelector(".qr-svg");'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".qr-svg").getAttribute("aria-label")==="QR code for the local dice page" && document.querySelector(".qr-url-row button").textContent==="Copy URL";')) 'desktop QR accessibility and copy controls are English'
 Assert-Language ([bool](Invoke-MarionetteScript 'return document.querySelector(".qr-hints").textContent.includes("TLS") && document.querySelector(".qr-hints").textContent.includes("same Wi-Fi alone is insufficient");')) 'desktop QR also states the actual protected LAN boundary'
 $afterQr=Invoke-RestMethod ($smoke.BaseUrl+'/api/tournaments/'+$created.id) -NoProxy|ConvertTo-Json -Depth 100 -Compress
 Assert-Language ($beforeCancel -ceq $afterQr) 'viewing QR and changing board-page language do not change saved tournament data'
 Invoke-MarionetteScript '[...document.querySelectorAll(".board-dice-modal button")].find(n=>n.textContent==="Close").click();return true;'|Out-Null
 Write-Host "OPERATOR_LANGUAGES_BROWSER=$passed PASS; 0 FAIL; 0 SKIP"
}
catch{$smoke.Failed=$true;throw}
finally{try{Disconnect-Marionette}catch{};Stop-StmFirefoxSmoke -Context $smoke}
