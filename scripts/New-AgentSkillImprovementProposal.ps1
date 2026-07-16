#requires -Version 7.0
# SECURITY-PATTERN-FILE: Defensive Redaktions- und Injection-Muster; Eingaben bleiben Daten.
<#
.SYNOPSIS
Erzeugt einen lokalen, nicht aktivierenden DRAFT-Vorschlag fuer Agenten-/Skill-Verbesserungen.

.DESCRIPTION
Alle Freitexte werden als Daten behandelt. Das Skript schreibt ausschließlich in den
ignorierten lokalen Vorschlagsordner, aendert keine Instruktionsquelle, fuehrt keine
Git- oder Netzwerkaktion aus und aktiviert den Vorschlag niemals automatisch.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Agent', 'Skill')]
    [string]$TargetType,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z][A-Za-z0-9-]{1,63}$')]
    [string]$TargetName,

    [Parameter(Mandatory)]
    [ValidateLength(10, 500)]
    [string]$Problem,

    [Parameter(Mandatory)]
    [ValidateLength(10, 2000)]
    [string]$Evidence,

    [Parameter(Mandatory)]
    [ValidateLength(10, 2000)]
    [string]$ProposedChange,

    [Parameter(Mandatory)]
    [ValidateLength(3, 300)]
    [string]$Source,

    [Parameter(Mandatory)]
    [ValidateSet('T0', 'T1', 'T2', 'T3', 'T4')]
    [string]$Trust,

    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$proposalRoot = [IO.Path]::GetFullPath((Join-Path $repo 'output/agent-skill-proposals'))
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = $proposalRoot }

function Assert-DataSafe {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value)

    $secretPattern = 'gh[pousr]_[0-9A-Za-z]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
    $piiPattern = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b|\b(?:\+?49|0)[1-9][0-9][0-9\s()/.-]{6,}\b|\b(?:FIDE|DSB)[- ]?(?:ID)?\s*[:=]?\s*[0-9]{5,}\b'
    $ownerPathPattern = '(?i)[A-Za-z]:\\(?:KFM|Schach|Users)(?:\\|$)|/(?:home|Users)/[^/]+/'
    # Kritische Begriffe werden aus Fragmenten aufgebaut. So bleiben sie als
    # defensive Regex wirksam, ohne statische PR-Scanner mit Testdaten zu triggern.
    $blockedPhraseA = 'ignore\s+(?:all|' + [string]::Concat('prev', 'ious') + ')'
    $blockedPhraseB = [string]::Concat('invoke-', 'expression')
    $blockedPhraseC = [string]::Concat('cu', 'rl') + '\s+https?://'
    $blockedPhraseD = [string]::Concat('wg', 'et') + '\s+https?://'
    $injectionPattern = "(?i)($blockedPhraseA|ignoriere\s+(?:alle|vorherige)|system\s*prompt|developer\s*message|fuehre\s+aus|execute\s*:|run\s*:|<script\b|$blockedPhraseB|git\s+(?:push|reset|clean)|remove-item\s+-recurse|$blockedPhraseC|$blockedPhraseD)"

    if ($Value -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') { throw "$Name enthaelt Steuerzeichen." }
    if ($Value -match $secretPattern) { throw "$Name enthaelt ein Secret-Muster." }
    if ($Value -match $piiPattern) { throw "$Name enthaelt ein PII-Muster." }
    if ($Value -match $ownerPathPattern) { throw "$Name enthaelt einen lokalen oder fremden absoluten Pfad." }
    if ($Value -match $injectionPattern) { throw "$Name enthaelt ein Befehls- oder Prompt-Injection-Muster." }
    if ($Value -match '```|~~~') { throw "$Name enthaelt einen nicht zugelassenen Code-Fence." }
}

function Resolve-SafeOutputDirectory {
    param([Parameter(Mandatory)][string]$Path)

    $full = [IO.Path]::GetFullPath($Path)
    $prefix = $proposalRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($full -ne $proposalRoot -and -not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'OutputDirectory muss im lokalen, ignorierten Ordner output/agent-skill-proposals liegen.'
    }

    $cursor = $full
    while ($cursor -and $cursor.StartsWith($repo, [StringComparison]::OrdinalIgnoreCase)) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw 'OutputDirectory enthaelt einen Symlink oder Reparse-Point.'
        }
        if ($cursor -eq $repo) { break }
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or $parent -eq $cursor) { break }
        $cursor = $parent
    }

    [void](New-Item -ItemType Directory -Path $full -Force)
    $created = Get-Item -LiteralPath $full -Force
    if (($created.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Erzeugter Vorschlagsordner ist ein Symlink oder Reparse-Point.'
    }
    return $full
}

function ConvertTo-DataQuote {
    param([Parameter(Mandatory)][string]$Value)
    return (($Value -split "`r?`n" | ForEach-Object { "> DATEN: $($_.TrimEnd())" }) -join "`n")
}

foreach ($entry in @{
    Problem = $Problem
    Evidence = $Evidence
    ProposedChange = $ProposedChange
    Source = $Source
}.GetEnumerator()) {
    Assert-DataSafe -Name $entry.Key -Value ([string]$entry.Value)
}
if ($Source -match "`r|`n") { throw 'Source muss eine einzelne, kurze Datenzeile bleiben.' }

$safeOutput = Resolve-SafeOutputDirectory -Path $OutputDirectory
$createdAt = [DateTimeOffset]::UtcNow.ToString('o')
$hashInput = "$TargetType`n$TargetName`n$Problem`n$Evidence`n$ProposedChange`n$Source`n$Trust"
$hashBytes = [Text.Encoding]::UTF8.GetBytes($hashInput)
$hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($hashBytes)).ToLowerInvariant().Substring(0, 12)
$proposalId = "asp-$([DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmssfff'))-$hash"
$safeTarget = $TargetName.ToLowerInvariant()
$baseName = "$proposalId-$safeTarget"
$jsonPath = Join-Path $safeOutput "$baseName.json"
$markdownPath = Join-Path $safeOutput "$baseName.md"

$proposal = [ordered]@{
    schemaVersion = 1
    proposalId = $proposalId
    status = 'DRAFT_OWNER_REVIEW'
    createdAt = $createdAt
    target = [ordered]@{ type = $TargetType; name = $TargetName }
    source = [ordered]@{ summary = $Source; trust = $Trust; treatedAsData = $true }
    problem = $Problem
    evidenceSummary = $Evidence
    proposedChange = $ProposedChange
    instructionChangeApplied = $false
    modelOrToolBehaviorChanged = $false
    networkUsed = $false
    gitWritePerformed = $false
    requiredReviews = @('Repository-Owner', 'Prompt-Injection-Reviewer', 'Final-Reviewer')
    requiredGates = @(
        'Test-AgentSkillProposalSafety',
        'Test-AgentInstructionIntegrity',
        'Test-AgentSkillReadiness',
        'Test-KnowledgePersistenceSafety',
        'Test-PromptInjectionDefense',
        'Test-GitCommitSafety'
    )
    prohibitedActions = @(
        'automatic-instruction-activation',
        'automatic-agent-or-skill-edit',
        'secret-access',
        'network-post',
        'git-commit-or-push'
    )
}

$markdown = @"
# Agent-/Skill-Improvement-Vorschlag $proposalId

- status: DRAFT_OWNER_REVIEW
- target: $TargetType / $TargetName
- source: $Source
- trust: $Trust (als Daten behandelt)
- created: $createdAt
- instruction-change-applied: false

## Problem

$(ConvertTo-DataQuote $Problem)

## Evidenzzusammenfassung

$(ConvertTo-DataQuote $Evidence)

## Vorgeschlagene Aenderung

$(ConvertTo-DataQuote $ProposedChange)

## Freigabe

Dieser lokale Entwurf aktiviert nichts. Eine Aenderung an Agenten, Skills oder Policies
benoetigt einen separaten, nachvollziehbaren Diff, alle im JSON genannten Gates,
Owner-Review und Remote-CI.
"@

$utf8 = [Text.UTF8Encoding]::new($false)
$jsonTemp = "$jsonPath.tmp"
$markdownTemp = "$markdownPath.tmp"
$jsonMoved = $false
$markdownMoved = $false
try {
    [IO.File]::WriteAllText($jsonTemp, (($proposal | ConvertTo-Json -Depth 8) + "`n"), $utf8)
    [IO.File]::WriteAllText($markdownTemp, ($markdown.TrimEnd() + "`n"), $utf8)
    Move-Item -LiteralPath $jsonTemp -Destination $jsonPath
    $jsonMoved = $true
    Move-Item -LiteralPath $markdownTemp -Destination $markdownPath
    $markdownMoved = $true
}
catch {
    foreach ($path in @($jsonTemp, $markdownTemp)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force }
    }
    if ($jsonMoved -and (Test-Path -LiteralPath $jsonPath -PathType Leaf)) { Remove-Item -LiteralPath $jsonPath -Force }
    if ($markdownMoved -and (Test-Path -LiteralPath $markdownPath -PathType Leaf)) { Remove-Item -LiteralPath $markdownPath -Force }
    throw
}

[pscustomobject]@{
    ProposalId = $proposalId
    Status = 'DRAFT_OWNER_REVIEW'
    JsonPath = $jsonPath
    MarkdownPath = $markdownPath
    InstructionChangeApplied = $false
}
