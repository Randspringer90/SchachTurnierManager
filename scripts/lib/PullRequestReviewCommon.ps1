#requires -Version 7.0
# SECURITY-PATTERN-FILE: Reine defensive Klassifikation; untrusted Inhalte werden niemals ausgefuehrt.

Set-StrictMode -Version Latest

# Every trusted reload has its own compiled type; session-global older types
# and caller variables must not stand in for the current reviewed runtime.
$script:ReviewAsciiPatternType = $null
$script:ReviewAsciiRuntimeNamespace = 'STM.StaticReview.G' + [Guid]::NewGuid().ToString('N')

$artifactVerificationPath = Join-Path $PSScriptRoot 'PullRequestArtifactVerification.ps1'
if (-not (Test-Path -LiteralPath $artifactVerificationPath -PathType Leaf)) {
    throw 'Trusted Artifact-Verification-Library fehlt.'
}
. $artifactVerificationPath

function Get-ReviewPropertyValue {
    param([object]$Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Get-ReviewSha256 {
    param([AllowEmptyString()][string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes(($Text ?? ''))
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return ([Convert]::ToHexString($hash)).ToLowerInvariant()
}

function Get-ReviewObjectSha256 {
    param([Parameter(Mandatory)][AllowNull()]$Value)
    return Get-ReviewSha256 ($Value | ConvertTo-Json -Depth 30 -Compress)
}

function Test-ReviewSha {
    param([string]$Value)
    return [bool]($Value -cmatch '^[0-9a-f]{40}$')
}

function Assert-ReviewRepositoryIdentifier {
    param([Parameter(Mandatory)][string]$Repository)
    if ($Repository -cnotmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw 'Repository muss owner/name ohne Sonder- oder Shellzeichen entsprechen.'
    }
}

function Assert-ReviewBaseBranch {
    param([Parameter(Mandatory)][string]$BaseBranch, [Parameter(Mandatory)]$Policy)
    if ($BaseBranch -cne [string]$Policy.trustedBaseBranch) {
        throw "Nur der konfigurierte Basebranch '$($Policy.trustedBaseBranch)' ist erlaubt."
    }
}

function Get-ReviewRepositoryRoot {
    $root = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $root) { throw 'Kein Git-Repository gefunden.' }
    $full = [IO.Path]::GetFullPath($root.Trim())
    if (-not (Test-Path -LiteralPath (Join-Path $full 'SchachTurnierManager.sln') -PathType Leaf)) {
        throw 'Repository-Root ist nicht der SchachTurnierManager.'
    }
    return $full
}

function Test-OriginMatchesReviewRepository {
    param([Parameter(Mandatory)][string]$Repository, [Parameter(Mandatory)][string]$RepositoryRoot)
    $remote = (& git -C $RepositoryRoot remote get-url origin 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or -not $remote) { return $false }
    $normalized = ($remote.Trim() -replace '\\','/')
    return [bool]($normalized -match ('(?i)(?:github\.com[:/])' + [regex]::Escape($Repository) + '(?:\.git)?$'))
}

function Assert-NoReviewReparseAncestor {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Context)
    $full = [IO.Path]::GetFullPath($Path)
    $current = $full
    while (-not (Test-Path -LiteralPath $current) -and (Split-Path -Parent $current) -ne $current) {
        $current = Split-Path -Parent $current
    }
    while ($current) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw "$Context enthaelt einen unzulaessigen Reparse-Point."
        }
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }
    return $full
}

function Assert-SafeReviewOutputPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [ValidateSet('Directory','File')][string]$TargetType = 'Directory',
        [switch]$AllowBoundReviewDirectory,
        [ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedReviewId
    )
    $full = Assert-NoReviewReparseAncestor -Path $Path -Context 'Review-Ausgabepfad'
    if ($full.StartsWith('\\', [StringComparison]::Ordinal) -or $full.StartsWith('//', [StringComparison]::Ordinal) -or
        $full.StartsWith('\\?\', [StringComparison]::Ordinal) -or $full.StartsWith('\\.\', [StringComparison]::Ordinal)) {
        throw 'UNC- und Device-Pfade sind fuer Review-Ausgaben gesperrt.'
    }
    $pathRoot = [IO.Path]::GetPathRoot($full)
    if ($full.Substring($pathRoot.Length) -match ':') { throw 'Alternate Data Streams sind fuer Review-Ausgaben gesperrt.' }
    $repoFull = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $volumeRoot = [IO.Path]::GetPathRoot($full).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $targetComparable = $full.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if ($targetComparable -eq $repoFull -or $targetComparable -eq $volumeRoot) {
        throw 'Review-Ausgabe darf weder Repository- noch Dateisystem-Root sein.'
    }
    $repoPrefix = $RepositoryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($full.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $relative = $full.Substring($repoPrefix.Length) -replace '\\','/'
        if ($relative -notmatch '^(?:output|tmp)(?:/|$)') {
            throw 'Review-Ausgaben innerhalb des Repositories sind nur unter output/ oder tmp/ erlaubt.'
        }
    }
    if ($full -match '(?i)(?:^|[\\/])(?:\.git|\.secrets|secrets)(?:[\\/]|$)') {
        throw 'Review-Ausgabepfad liegt in einem verbotenen internen Verzeichnis.'
    }
    if ($TargetType -eq 'Directory' -and (Test-Path -LiteralPath $full)) {
        if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw 'Review-Ausgabeziel ist kein Verzeichnis.' }
        $entries = @(Get-ChildItem -LiteralPath $full -Force)
        if ($entries.Count -gt 0) {
            if (-not $AllowBoundReviewDirectory -or -not $ExpectedReviewId) {
                throw 'Review-Ausgabeverzeichnis muss neu oder leer sein; bestehende Daten werden nicht ueberschrieben.'
            }
            $bindingPath = Join-Path $full 'static-review.json'
            if (-not (Test-Path -LiteralPath $bindingPath -PathType Leaf)) {
                throw 'Bestehendes Review-Ausgabeverzeichnis besitzt keinen bindenden statischen Bericht.'
            }
            [void](Assert-NoReviewReparseAncestor -Path $bindingPath -Context 'Bindender statischer Reviewbericht')
            try { $binding = Get-Content -Raw -LiteralPath $bindingPath | ConvertFrom-Json -ErrorAction Stop }
            catch { throw 'Bindender statischer Reviewbericht ist kein gueltiges JSON.' }
            if ([string](Get-ReviewPropertyValue $binding 'reviewId' '') -cne $ExpectedReviewId) {
                throw 'Bestehendes Review-Ausgabeverzeichnis ist nicht an den erwarteten Review gebunden.'
            }
        }
    }
    if ($TargetType -eq 'File' -and (Test-Path -LiteralPath $full)) {
        throw 'Review-Ausgabedatei existiert bereits; Ueberschreiben ist gesperrt.'
    }
    return $full
}

function Write-ReviewUtf8FileCreateNew {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )
    $full = [IO.Path]::GetFullPath($Path)
    $parent = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw 'Review-Ausgabeverzeichnis fehlt.' }
    [void](Assert-NoReviewReparseAncestor -Path $parent -Context 'Review-Ausgabeverzeichnis')
    $encoding = [Text.UTF8Encoding]::new($false)
    $stream = [IO.File]::Open($full, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $writer = [IO.StreamWriter]::new($stream, $encoding)
        try { $writer.Write($Content) }
        finally { $writer.Dispose() }
    }
    finally { $stream.Dispose() }
    return $full
}

function Assert-SafeReviewArtifactPath {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$RepositoryRoot)
    $full = Assert-NoReviewReparseAncestor -Path $Path -Context 'Review-Artefakt'
    if ($full.StartsWith('\\', [StringComparison]::Ordinal) -or $full.StartsWith('//', [StringComparison]::Ordinal) -or
        $full.StartsWith('\\?\', [StringComparison]::Ordinal) -or $full.StartsWith('\\.\', [StringComparison]::Ordinal)) { throw 'UNC- und Device-Pfade sind fuer Review-Artefakte gesperrt.' }
    $artifactRoot = [IO.Path]::GetPathRoot($full)
    if ($full.Substring($artifactRoot.Length) -match ':') { throw 'Alternate Data Streams sind fuer Review-Artefakte gesperrt.' }
    if ($full -match '(?i)(?:^|[\\/])(?:\.git|\.secrets|secrets)(?:[\\/]|$)') { throw 'Review-Artefakt liegt in einem verbotenen internen Verzeichnis.' }
    $repoPrefix = $RepositoryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($full.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $relative = $full.Substring($repoPrefix.Length) -replace '\\','/'
        if ($relative -notmatch '^(?:output|tmp)(?:/|$)') { throw 'Review-Artefakte innerhalb des Repositories duerfen nur unter output/ oder tmp/ liegen.' }
    }
    return $full
}

function Resolve-SafeReviewInputBundle {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$RepositoryRoot)
    $full = Assert-NoReviewReparseAncestor -Path $Path -Context 'Offline-Input-Bundle'
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw 'Offline-Input-Bundle fehlt.' }
    if ($full -match '(?i)(?:^|[\\/])(?:\.git|\.secrets|secrets)(?:[\\/]|$)') { throw 'Offline-Input-Bundle liegt in einem verbotenen Verzeichnis.' }
    foreach ($name in 'metadata.json','changed-files.json','patch.diff') {
        $file = Join-Path $full $name
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Offline-Input fehlt: $name" }
        [void](Assert-NoReviewReparseAncestor -Path $file -Context "Offline-Input $name")
    }
    return $full
}

function ConvertTo-SafeReviewLabel {
    param([AllowEmptyString()][string]$Value, [int]$MaximumLength = 160)
    $text = $Value ?? ''
    $unsafe = $text -match '[\x00-\x1F\x7F-\x9F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]' -or
        $text -match '(?i)\b[a-z][a-z0-9+.-]*:' -or
        $text -match '(?i)(?:^|[\s("''])(?:[a-z]:[\\/]|\\\\|/(?:home|users|var|tmp|etc|opt)/)' -or
        $text -match '(?i)(?:gh[pousr]_[0-9a-z]{20,}|github_pat_[0-9a-z_]{20,}|(?:api[-_ ]?key|token|secret|password|passwd|authorization)\s*[:=]\s*[^\s,;]{4,}|bearer\s+[0-9a-z._~+/-]{8,}|[a-z][a-z0-9+.-]*://[^\s/@:]+:[^\s/@]+@)' -or
        $text -match '(?i)(?<![\w.+-])[a-z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+(?![\w.-])' -or
        $text -match '(?<!\d)(?:\+?\d[\s()./-]*){7,}\d(?!\d)'
    if ($unsafe) { return "[redacted:$((Get-ReviewSha256 $text).Substring(0,12))]" }
    $text = $text -replace '[\r\n\t]+',' '
    if ($text.Length -gt $MaximumLength) { $text = $text.Substring(0, $MaximumLength) + '…' }
    return $text
}

function ConvertTo-SafeReviewPath {
    param([AllowEmptyString()][string]$Value)
    $text = ($Value ?? '') -replace '\\','/'
    if ([string]::IsNullOrWhiteSpace($text) -or $text.Length -gt 500 -or $text -match '[\x00-\x1F\x7F-\x9F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]' -or
        [IO.Path]::IsPathRooted($text) -or $text -match '(^|/)\.\.(/|$)' -or $text -match '[:;&|`$(){}\[\]<>]' -or $text -match '[^\x20-\x7E]' -or
        @($text -split '/' | Where-Object { $_ -match '(?i)^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)|[. ]$' }).Count -gt 0) {
        return "[redacted-path:$((Get-ReviewSha256 $text).Substring(0,12))]"
    }
    return $text
}

function ConvertTo-SafeReviewMarkdown {
    param([AllowEmptyString()][string]$Value, [int]$MaximumLength = 200)
    $text = ConvertTo-SafeReviewLabel -Value ($Value ?? '') -MaximumLength $MaximumLength
    foreach ($codePoint in 92,96,42,95,123,125,91,93,60,62,40,41,35,43,45,46,33,124) {
        $character = [string][char]$codePoint
        $text = $text.Replace($character, ('\' + $character))
    }
    return $text
}

function Test-ReviewPathPattern {
    param([string]$Path, [string]$Pattern)
    $normalized = $Path -replace '\\','/'
    $candidate = if ($Pattern -notmatch '[\\/]') { [IO.Path]::GetFileName($normalized) } else { $normalized }
    $regex = '^' + [regex]::Escape(($Pattern -replace '\\','/')).Replace('\*\.','[^/]*\.').Replace('\*','[^/]*') + '$'
    return [bool]($candidate -match $regex)
}

function Import-PullRequestReviewPolicies {
    param([Parameter(Mandatory)][string]$RepositoryRoot)
    $names = [ordered]@{
        review = 'config/pull-request-review-policy.json'
        artifacts = 'config/pull-request-artifact-attestations.json'
        dependency = 'config/dependency-review-policy.json'
        suspicious = 'config/suspicious-change-patterns.json'
        adoption = 'config/pr-adoption-policy.json'
    }
    $loaded = @{}
    $hashes = [ordered]@{}
    foreach ($entry in $names.GetEnumerator()) {
        $path = Join-Path $RepositoryRoot $entry.Value
        [void](Assert-NoReviewReparseAncestor -Path $path -Context "Policy $($entry.Value)")
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Review-Policy fehlt: $($entry.Value)" }
        $raw = Get-Content -Raw -LiteralPath $path
        try { $loaded[$entry.Key] = $raw | ConvertFrom-Json } catch { throw "Review-Policy ist kein gueltiges JSON: $($entry.Value)" }
        if ([int](Get-ReviewPropertyValue $loaded[$entry.Key] 'schemaVersion' 0) -ne 1) { throw "Unbekannte Policy-Schemaversion: $($entry.Value)" }
        $hashes[$entry.Key] = Get-ReviewSha256 $raw
    }
    [void](Assert-PullRequestArtifactAttestations -ReviewPolicy $loaded.review -Attestations $loaded.artifacts)
    Assert-ReviewSourcePatternContexts -ReviewPolicy $loaded.review -PatternPolicy $loaded.suspicious
    return [pscustomobject]@{
        review = $loaded.review
        artifacts = $loaded.artifacts
        dependency = $loaded.dependency
        suspicious = $loaded.suspicious
        adoption = $loaded.adoption
        hashes = [pscustomobject]$hashes
    }
}

function New-ReviewFinding {
    param(
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][ValidateSet('low','medium','high','critical')][string]$Severity,
        [string]$Path,
        [AllowEmptyString()][string]$Evidence,
        [Parameter(Mandatory)][string]$Detail,
        [string]$RiskClass
    )
    if (-not $RiskClass) { $RiskClass = $Severity.ToUpperInvariant() }
    return [pscustomobject]@{
        code = $Code
        category = $Category
        severity = $Severity.ToUpperInvariant()
        riskClass = $RiskClass.ToUpperInvariant()
        path = if ($Path) { ConvertTo-SafeReviewPath $Path } else { $null }
        evidenceHash = (Get-ReviewSha256 ($Evidence ?? '')).Substring(0,16)
        detail = $Detail
        sourceZone = 'T4'
    }
}

function Get-ReviewPatternCode {
    param([string]$Id)
    $map = @{
        'prompt-injection'='PROMPT_INJECTION'; 'encoded-execution'='ENCODED_EXECUTION';
        'dynamic-expression'='DYNAMIC_EXPRESSION'; 'download-and-execute'='DOWNLOAD_AND_EXECUTE'; 'network-download'='NETWORK_DOWNLOAD';
        'process-launch'='PROCESS_EXECUTION'; 'dynamic-assembly'='DYNAMIC_ASSEMBLY';
        'persistence'='PERSISTENCE_MECHANISM'; 'credential-access'='CREDENTIAL_ACCESS';
        'security-bypass'='SECURITY_BYPASS'; 'path-traversal'='PATH_TRAVERSAL';
        'pull-request-target'='PULL_REQUEST_TARGET'; 'workflow-privilege'='WORKFLOW_PRIVILEGE_EXPANSION';
        'workflow-secret-reference'='WORKFLOW_SECRET_REFERENCE'; 'workflow-write-permission'='WORKFLOW_WRITE_PERMISSION';
        'msbuild-execution-hook'='MSBUILD_EXECUTION_HOOK'; 'package-lifecycle'='PACKAGE_LIFECYCLE_SCRIPT';
        'git-hook'='GIT_HOOK'; 'large-base64'='OBFUSCATED_CONTENT';
        'submodule-mode'='SUBMODULE'; 'symlink-mode'='SYMLINK';
        'external-artifact-publish'='EXTERNAL_ARTIFACT_PUBLISH'; 'github-user-image-host'='GITHUB_USER_IMAGE_HOST'
    }
    if ($map.ContainsKey($Id)) { return $map[$Id] }
    return 'SUSPICIOUS_CHANGE'
}

function Get-ReviewAsciiPatternType {
    $cached = Get-Variable -Name ReviewAsciiPatternType -Scope Script -ErrorAction SilentlyContinue
    if ($cached -and $cached.Value -is [type] -and
        $cached.Value.FullName -ceq ($script:ReviewAsciiRuntimeNamespace + '.AsciiPattern')) { return $cached.Value }
    # This fixed implementation is trusted reviewer code, never PR-provided source.
    $definition = @'
using System;
using System.Diagnostics;
using System.Text.RegularExpressions;
namespace STM.StaticReview {
    public static class AsciiPattern {
        public static bool IsMatch(string text, TimeSpan timeout) {
            const string pattern = "[A-Za-z0-9+/]{800,}={0,2}";
            if (timeout <= TimeSpan.Zero || timeout == Regex.InfiniteMatchTimeout)
                throw new ArgumentOutOfRangeException(nameof(timeout));
            var clock = Stopwatch.StartNew();
            int run = 0;
            for (int index = 0; index < text.Length; index++) {
                if ((index & 1023) == 0 && clock.Elapsed >= timeout)
                    throw new RegexMatchTimeoutException(text, pattern, timeout);
                char value = text[index];
                bool allowed = (value >= 'A' && value <= 'Z') ||
                    (value >= 'a' && value <= 'z') || (value >= '0' && value <= '9') ||
                    value == '+' || value == '/';
                run = allowed ? run + 1 : 0;
                if (run == 800) {
                    if (clock.Elapsed >= timeout)
                        throw new RegexMatchTimeoutException(text, pattern, timeout);
                    return true;
                }
            }
            if (clock.Elapsed >= timeout)
                throw new RegexMatchTimeoutException(text, pattern, timeout);
            return false;
        }
    }
}
'@
    $definition = $definition.Replace('namespace STM.StaticReview {', ('namespace ' + $script:ReviewAsciiRuntimeNamespace + ' {'))
    $script:ReviewAsciiPatternType = Add-Type -PassThru -TypeDefinition $definition
    if ($script:ReviewAsciiPatternType -isnot [type] -or
        $script:ReviewAsciiPatternType.FullName -cne ($script:ReviewAsciiRuntimeNamespace + '.AsciiPattern')) {
        throw 'Trusted pattern runtime type mismatch.'
    }
    return $script:ReviewAsciiPatternType
}

function Test-ReviewPatternMatch {
    param([Parameter(Mandatory)]$Pattern, [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][TimeSpan]$Timeout)
    $literal = [string]$Pattern.pattern
    # Optional padding can contain zero characters: the Boolean regex requires
    # exactly the existence of an 800-character ASCII run. Bind the exact literal.
    if ([string]$Pattern.id -ceq 'large-base64' -and $literal -ceq '[A-Za-z0-9+/]{800,}={0,2}') {
        $matcher = Get-ReviewAsciiPatternType
        return $matcher::IsMatch($Text, $Timeout)
    }
    $options = [Text.RegularExpressions.RegexOptions]::CultureInvariant
    if ([string]$Pattern.id -ceq 'prompt-injection') {
        $options = $options -bor [Text.RegularExpressions.RegexOptions]::Compiled
    }
    return [regex]::new($literal, $options, $Timeout).IsMatch($Text)
}

function Add-PatternFindings {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[object]]$Findings,
        [Parameter(Mandatory)][string]$Scope,
        [AllowEmptyString()][string]$Text,
        [string]$Path,
        [Parameter(Mandatory)]$PatternPolicy
    )
    if ([string]::IsNullOrEmpty($Text)) { return }
    $timeout = [TimeSpan]::FromMilliseconds([int]$PatternPolicy.regexTimeoutMilliseconds)
    foreach ($pattern in $PatternPolicy.patterns) {
        if (@($pattern.appliesTo) -notcontains $Scope) { continue }
        try {
            if (Test-ReviewPatternMatch -Pattern $pattern -Text $Text -Timeout $timeout) {
                $Findings.Add((New-ReviewFinding -Code (Get-ReviewPatternCode $pattern.id) -Category $pattern.category -Severity $pattern.severity -Path $Path -Evidence $Text -Detail "Defensives Muster '$($pattern.id)' erkannt."))
            }
        }
        catch [Text.RegularExpressions.RegexMatchTimeoutException] {
            $Findings.Add((New-ReviewFinding -Code 'SCAN_TIMEOUT' -Category 'unverified' -Severity 'critical' -Path $Path -Evidence $pattern.id -Detail 'Statische Musterpruefung ueberschritt das Zeitlimit.' -RiskClass 'UNVERIFIED'))
        }
    }
}

function Get-ReviewPatternDefinitionHash {
    param([Parameter(Mandatory)]$Pattern)
    $definition = [ordered]@{ id=$Pattern.id; category=$Pattern.category; severity=$Pattern.severity;
        appliesTo=@($Pattern.appliesTo); pattern=$Pattern.pattern }
    return Get-ReviewSha256 ($definition | ConvertTo-Json -Compress -Depth 4)
}

function Assert-ReviewSourcePatternContexts {
    param([Parameter(Mandatory)]$ReviewPolicy, [Parameter(Mandatory)]$PatternPolicy)
    $allowed = @('encoded-execution','dynamic-expression','persistence','credential-access','security-bypass','git-hook')
    $records = @((Get-ReviewPropertyValue $ReviewPolicy 'sourcePatternContexts' @()))
    if ($records.Count -gt 64) { throw 'SOURCE_PATTERN_CONTEXT_LIMIT' }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($record in $records) {
        $path = [string](Get-ReviewPropertyValue $record 'path' '')
        if (-not $path -or (ConvertTo-SafeReviewPath $path) -cne $path -or $path.Contains('*') -or
            -not $seen.Add($path) -or [string]$record.mode -cnotmatch '\A100(?:644|755)\z' -or
            [string]$record.blobSha -cnotmatch '\A[0-9a-f]{40}\z' -or
            [string]$record.reviewHeadSha -cnotmatch '\A[0-9a-f]{40}\z') { throw 'SOURCE_PATTERN_CONTEXT_INVALID' }
        $before = [string](Get-ReviewPropertyValue $record 'beforeBlobSha' '')
        $beforeMode = [string](Get-ReviewPropertyValue $record 'beforeMode' '')
        if (($before -and ($before -cnotmatch '\A[0-9a-f]{40}\z' -or $beforeMode -cnotmatch '\A100(?:644|755)\z')) -or
            (-not $before -and $beforeMode)) { throw 'SOURCE_PATTERN_CONTEXT_BEFORE_INVALID' }
        $bindings = @($record.patterns)
        if ($bindings.Count -lt 1 -or $bindings.Count -gt 6) { throw 'SOURCE_PATTERN_CONTEXT_RULE_INVALID' }
        $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($binding in $bindings) {
            if ($binding.id -cnotin $allowed -or -not $ids.Add([string]$binding.id) -or
                [string]$binding.definitionSha256 -cnotmatch '\A[0-9a-f]{64}\z') { throw 'SOURCE_PATTERN_CONTEXT_RULE_INVALID' }
            $rule = @($PatternPolicy.patterns | Where-Object id -CEQ $binding.id)
            if ($rule.Count -ne 1 -or $rule[0].severity -cne 'critical' -or
                @($rule[0].appliesTo) -cnotcontains 'patch') { throw 'SOURCE_PATTERN_CONTEXT_RULE_INVALID' }
        }
    }
}

function Add-ReviewContextBoundPatchFindings {
    param([Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[object]]$Findings,
        [AllowEmptyString()][string]$Patch, [Parameter(Mandatory)]$Metadata,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Files, [Parameter(Mandatory)]$ReviewPolicy,
        [Parameter(Mandatory)]$PatternPolicy)
    $records = @((Get-ReviewPropertyValue $ReviewPolicy 'sourcePatternContexts' @()))
    $boundHead = [string](Get-ReviewPropertyValue $Metadata 'patternContextHeadSha' '')
    $head = [string](Get-ReviewPropertyValue $Metadata 'headSha' (Get-ReviewPropertyValue $Metadata 'headRefOid' ''))
    if ($records.Count -eq 0 -or -not (Test-ReviewSha $boundHead) -or $boundHead -cne $head -or
        -not [bool](Get-ReviewPropertyValue $Metadata 'gitTreeMetadataComplete' $false)) {
        Add-PatternFindings -Findings $Findings -Scope patch -Text $Patch -PatternPolicy $PatternPolicy
        return
    }
    Assert-ReviewSourcePatternContexts -ReviewPolicy $ReviewPolicy -PatternPolicy $PatternPolicy
    $eligibleIds = @('encoded-execution','dynamic-expression','persistence','credential-access','security-bypass','git-hook')
    $fileMap = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($file in $Files) {
        $path = [string]$file.path
        if ($fileMap.ContainsKey($path)) { throw 'SOURCE_PATTERN_CONTEXT_DUPLICATE_FILE' }
        $fileMap[$path] = $file
    }
    $segments = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $current = $null
    $valid = $true
    $offset=0
    $contentRanges=[Collections.Generic.List[object]]::new()
    foreach ($rawLine in ($Patch ?? '').Split("`n")) {
        $lineStart=$offset; $offset += $rawLine.Length+1
        $line = $rawLine.TrimEnd([char]13)
        if ($line.StartsWith('diff --git ', [StringComparison]::Ordinal)) {
            if ($line -cnotmatch '^diff --git a/(?<old>.+) b/(?<new>.+)$' -or
                -not $fileMap.ContainsKey($Matches.new) -or -not $seen.Add($Matches.new)) { $valid=$false; break }
            $file = $fileMap[$Matches.new]
            $oldPath = [string](Get-ReviewPropertyValue $file 'previousPath' '')
            if (-not $oldPath) { $oldPath=[string]$file.path }
            if ($Matches.old -cne $oldPath -or (ConvertTo-SafeReviewPath ([string]$file.path)) -cne [string]$file.path) { $valid=$false; break }
            $current = [pscustomobject]@{ file=$file; headers=[Text.StringBuilder]::new(); preamble=[Collections.Generic.List[string]]::new(); hunks=[Text.StringBuilder]::new(); content=[Text.StringBuilder]::new(); inHunk=$false; range=$null }
            $segments.Add($current)
            [void]$current.headers.AppendLine($line)
        } elseif ($null -eq $current) {
            if ($line) { $valid=$false; break }
        } elseif ($line.StartsWith('@@ ', [StringComparison]::Ordinal)) {
            $current.inHunk=$true
            $current.range=$null
            [void]$current.hunks.AppendLine($line)
            [void]$current.headers.AppendLine($line)
        } elseif ($current.inHunk) {
            if ($null -eq $current.range) {
                $current.range=[pscustomobject]@{start=$lineStart;end=$lineStart}
                $contentRanges.Add($current.range)
            }
            $current.range.end=[Math]::Min($offset,$Patch.Length)
            [void]$current.hunks.AppendLine($line)
            [void]$current.content.AppendLine($line)
        } else { [void]$current.headers.AppendLine($line); $current.preamble.Add($line) }
    }
    if ($segments.Count -eq 0) { $valid=$false }
    if ($valid) {
        foreach ($segment in $segments) {
            $file=$segment.file
            if (-not [bool]$file.patchAvailable -or -not [bool]$file.patchComplete) { $valid=$false; break }
            $oldPath=[string](Get-ReviewPropertyValue $file 'previousPath' '')
            if (-not $oldPath) { $oldPath=[string]$file.path }
            $oldHeader=if ($file.status -ceq 'added') { '--- /dev/null' } else { '--- a/' + $oldPath }
            $newHeader=if ($file.status -ceq 'removed') { '+++ /dev/null' } else { '+++ b/' + [string]$file.path }
            if ($segment.preamble.Count -ne 2 -or $segment.preamble[0] -cne $oldHeader -or $segment.preamble[1] -cne $newHeader) { $valid=$false; break }
            try {
                [void](Get-ReviewUnifiedHunkStatistics -Patch $segment.hunks.ToString().TrimEnd([char]10,[char]13) -ExpectedAdditions ([int]$file.additions) -ExpectedDeletions ([int]$file.deletions))
            } catch { $valid=$false; break }
        }
        if (@($Files | Where-Object { $_.patchAvailable -and -not $seen.Contains([string]$_.path) }).Count) { $valid=$false }
    }
    if (-not $valid) {
        $Findings.Add((New-ReviewFinding -Code 'SOURCE_PATTERN_CONTEXT_SEGMENTATION_INVALID' -Category unverified -Severity critical -Evidence $Patch -Detail 'Datei-/Hunk-Zuordnung fuer Kontextpruefung ist nicht eindeutig.' -RiskClass UNVERIFIED))
        Add-PatternFindings -Findings $Findings -Scope patch -Text $Patch -PatternPolicy $PatternPolicy
        return
    }
    # All other signals keep their original whole-patch semantics, including
    # cross-file execution, workflow, publication and timeout detection.
    $otherPolicy=[pscustomobject]@{regexTimeoutMilliseconds=$PatternPolicy.regexTimeoutMilliseconds;patterns=@($PatternPolicy.patterns|Where-Object id -CNotIn $eligibleIds)}
    Add-PatternFindings -Findings $Findings -Scope patch -Text $Patch -PatternPolicy $otherPolicy
    $contextPolicy=[pscustomobject]@{regexTimeoutMilliseconds=$PatternPolicy.regexTimeoutMilliseconds;patterns=@($PatternPolicy.patterns|Where-Object id -CIn $eligibleIds)}
    # A match spanning a header/content or file boundary must keep the original
    # whole-patch meaning. Only matches wholly inside one actual hunk-content
    # interval may be considered by the file-bound classification below.
    foreach ($rule in $contextPolicy.patterns) {
        $timeout=[TimeSpan]::FromMilliseconds([int]$PatternPolicy.regexTimeoutMilliseconds)
        # The native per-match timeout is independent of bounded PowerShell
        # enumeration, range attribution and runtime initialization overhead.
        $enumerationBudget=[TimeSpan]::FromSeconds(2)
        $clock=[Diagnostics.Stopwatch]::StartNew(); $rangeIndex=0; $matchesChecked=0
        try {
            $regex=[regex]::new([string]$rule.pattern,[Text.RegularExpressions.RegexOptions]::CultureInvariant,$timeout)
            $match=$regex.Match($Patch)
            while ($match.Success) {
                if ($clock.Elapsed -ge $enumerationBudget -or ++$matchesChecked -gt 10000) { throw [Text.RegularExpressions.RegexMatchTimeoutException]::new() }
                while ($rangeIndex -lt $contentRanges.Count -and $contentRanges[$rangeIndex].end -le $match.Index) {
                    $rangeIndex++
                    if (($rangeIndex -band 127) -eq 0 -and $clock.Elapsed -ge $enumerationBudget) { throw [Text.RegularExpressions.RegexMatchTimeoutException]::new() }
                }
                if ($rangeIndex -ge $contentRanges.Count -or $contentRanges[$rangeIndex].start -gt $match.Index -or
                    $match.Index+$match.Length -gt $contentRanges[$rangeIndex].end) {
                    $Findings.Add((New-ReviewFinding -Code (Get-ReviewPatternCode $rule.id) -Category $rule.category -Severity critical -Evidence $Patch -Detail 'Muster ausserhalb eindeutiger Hunk-Inhaltsgrenzen; keine Kontextklassifikation.'))
                    break
                }
                $match=$match.NextMatch()
            }
        } catch [Text.RegularExpressions.RegexMatchTimeoutException] {
            $Findings.Add((New-ReviewFinding -Code SCAN_TIMEOUT -Category unverified -Severity critical -Evidence $rule.id -Detail 'Grenzpruefung ueberschritt das begrenzte Scanbudget.' -RiskClass UNVERIFIED))
        }
    }
    foreach ($segment in $segments) {
        $file=$segment.file; $path=[string]$file.path
        $record=@($records|Where-Object { [bool](Get-ReviewPropertyValue $file 'modeAvailable' $false) -and $_.path -ceq $path -and $_.mode -ceq [string]$file.mode -and
            $_.blobSha -ceq [string](Get-ReviewPropertyValue $file 'headBlobSha' '') -and
            [string]$_.beforeBlobSha -ceq [string](Get-ReviewPropertyValue $file 'beforeBlobSha' '') -and
            [string]$_.beforeMode -ceq [string](Get-ReviewPropertyValue $file 'beforeMode' '') })
        foreach ($rule in $contextPolicy.patterns) {
            $single=[pscustomobject]@{regexTimeoutMilliseconds=$PatternPolicy.regexTimeoutMilliseconds;patterns=@($rule)}
            $found=[Collections.Generic.List[object]]::new()
            Add-PatternFindings -Findings $found -Scope patch -Text $segment.content.ToString() -Path $path -PatternPolicy $single
            $binding=@(if($record.Count -eq 1){$record[0].patterns|Where-Object { $_.id -ceq $rule.id -and $_.definitionSha256 -ceq (Get-ReviewPatternDefinitionHash $rule) }})
            foreach ($finding in $found) {
                if ($binding.Count -eq 1 -and $finding.code -ceq (Get-ReviewPatternCode $rule.id)) {
                    $finding.severity='HIGH'; $finding.riskClass='HIGH'
                    $finding.detail="Defensives Muster '$($rule.id)': exakter separat gepruefter Pfad-/Modus-/Blob-/Regelkontext; Owner-SHA-Ausfuehrungsfreigabe bleibt erforderlich."
                }
                $Findings.Add($finding)
            }
        }
    }
}

function Get-ReviewUnifiedHunkStatistics {
    param([AllowEmptyString()][string]$Patch, [ValidateRange(0,5242880)][int]$ExpectedAdditions,
        [ValidateRange(0,5242880)][int]$ExpectedDeletions)
    $lines = $Patch.Split("`n")
    $added=0; $removed=0; $oldRemaining=0L; $newRemaining=0L; $hunks=0
    $lastOldEnd=0L; $lastNewEnd=0L; $canMarkNoNewline=$false
    for ($i=0; $i -lt $lines.Length; $i++) {
        $line=$lines[$i]; $header=$line.TrimEnd([char]13)
        if ($i -eq $lines.Length-1 -and $line -eq '') { continue }
        if ($header -cmatch '^@@ -([0-9]+)(?:,([0-9]+))? \+([0-9]+)(?:,([0-9]+))? @@(?: .*)?$') {
            if ($oldRemaining -ne 0 -or $newRemaining -ne 0) { throw 'TEXT_EVIDENCE_HUNK_TRUNCATED' }
            $oldStart=0L; $oldCount=1L; $newStart=0L; $newCount=1L
            if (-not [int64]::TryParse($Matches[1],[ref]$oldStart) -or -not [int64]::TryParse($Matches[3],[ref]$newStart) -or
                ($Matches[2] -and -not [int64]::TryParse($Matches[2],[ref]$oldCount)) -or
                ($Matches[4] -and -not [int64]::TryParse($Matches[4],[ref]$newCount)) -or
                $oldStart -gt 5242880 -or $newStart -gt 5242880 -or $oldCount -gt 5242880 -or $newCount -gt 5242880 -or
                ($oldCount -gt 0 -and $oldStart -eq 0) -or ($newCount -gt 0 -and $newStart -eq 0) -or
                $oldStart -lt $lastOldEnd -or $newStart -lt $lastNewEnd) { throw 'TEXT_EVIDENCE_HUNK_RANGE' }
            $lastOldEnd=$oldStart+$oldCount; $lastNewEnd=$newStart+$newCount
            $oldRemaining=$oldCount; $newRemaining=$newCount; $hunks++; $canMarkNoNewline=$false
            continue
        }
        if ($header -ceq '\ No newline at end of file') {
            if (-not $canMarkNoNewline) { throw 'TEXT_EVIDENCE_NEWLINE_MARKER' }
            $canMarkNoNewline=$false; continue
        }
        if ($hunks -eq 0 -or $line.Length -eq 0) { throw 'TEXT_EVIDENCE_HUNK_BODY' }
        switch ($line[0]) {
            '+' { $newRemaining--; $added++ }
            '-' { $oldRemaining--; $removed++ }
            ' ' { $oldRemaining--; $newRemaining-- }
            default { throw 'TEXT_EVIDENCE_HUNK_BODY' }
        }
        if ($oldRemaining -lt 0 -or $newRemaining -lt 0) { throw 'TEXT_EVIDENCE_HUNK_OVERFLOW' }
        $canMarkNoNewline=$true
    }
    if ($oldRemaining -ne 0 -or $newRemaining -ne 0 -or $added -ne $ExpectedAdditions -or $removed -ne $ExpectedDeletions) {
        throw 'TEXT_EVIDENCE_STATS_MISMATCH'
    }
    [pscustomobject]@{ additions=$added; deletions=$removed; hunks=$hunks }
}

function ConvertTo-SafeReviewTextPatchEvidence {
    param($Evidence,$Metadata)
    if ($null -eq $Evidence) { return $null }
    if ([string](Get-ReviewPropertyValue $Evidence 'status' '') -cne 'VERIFIED' -or
        [string](Get-ReviewPropertyValue $Evidence 'method' '') -cne 'git-no-index-sha1-utf8-v1') { return $null }
    $safe=[ordered]@{status='VERIFIED';method='git-no-index-sha1-utf8-v1'}
    foreach ($name in @('baseSha','headSha','baseTreeSha','headTreeSha','beforeBlobSha','afterBlobSha')) {
        $value=Get-ReviewPropertyValue $Evidence $name $null
        if ($null -eq $value -and $name -in @('beforeBlobSha','afterBlobSha')) { $safe[$name]=$null;continue }
        if ([string]$value -cnotmatch '^[0-9a-f]{40}$') { return $null }
        $safe[$name]=[string]$value
    }
    if ($safe.baseSha -cne [string](Get-ReviewPropertyValue $Metadata 'baseSha' (Get-ReviewPropertyValue $Metadata 'baseRefOid' '')) -or
        $safe.headSha -cne [string](Get-ReviewPropertyValue $Metadata 'headSha' (Get-ReviewPropertyValue $Metadata 'headRefOid' ''))) { return $null }
    foreach ($name in @('beforeSha256','afterSha256','patchSha256')) {
        $value=[string](Get-ReviewPropertyValue $Evidence $name '')
        if ($value -cnotmatch '^[0-9a-f]{64}$') { return $null }
        $safe[$name]=$value
    }
    foreach ($name in @('beforeBytes','afterBytes','additions','deletions')) {
        $value=0L
        if (-not [int64]::TryParse([string](Get-ReviewPropertyValue $Evidence $name ''),[ref]$value) -or
            $value -lt 0 -or $value -gt 5242880) { return $null }
        $safe[$name]=$value
    }
    return [pscustomobject]$safe
}

function ConvertFrom-GitHubPullRequestReviewData {
    param(
        [Parameter(Mandatory)][object[]]$ApiFiles,
        [Parameter(Mandatory)]$HeadTree,
        [Parameter(Mandatory)]$BaseTree
    )
    $treeMetadataComplete = -not [bool](Get-ReviewPropertyValue $HeadTree 'truncated' $true) -and
        -not [bool](Get-ReviewPropertyValue $BaseTree 'truncated' $true)
    $headModes = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    $baseModes = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    $headBlobs = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    $baseBlobs = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    if ($treeMetadataComplete) {
        foreach ($entry in @($HeadTree.tree)) {
            $path = [string](Get-ReviewPropertyValue $entry 'path' '')
            if ($path) { $headModes[$path] = [string](Get-ReviewPropertyValue $entry 'mode' ''); $headBlobs[$path]=[string](Get-ReviewPropertyValue $entry 'sha' '') }
        }
        foreach ($entry in @($BaseTree.tree)) {
            $path = [string](Get-ReviewPropertyValue $entry 'path' '')
            if ($path) { $baseModes[$path] = [string](Get-ReviewPropertyValue $entry 'mode' ''); $baseBlobs[$path]=[string](Get-ReviewPropertyValue $entry 'sha' '') }
        }
    }
    $patchParts = [Collections.Generic.List[string]]::new()
    $files = @($ApiFiles | ForEach-Object {
        $path = [string](Get-ReviewPropertyValue $_ 'filename' '')
        $status = [string](Get-ReviewPropertyValue $_ 'status' '')
        $previousPath = [string](Get-ReviewPropertyValue $_ 'previous_filename' '')
        $filePatchValue = Get-ReviewPropertyValue $_ 'patch' $null
        $filePatch = if ($null -ne $filePatchValue) { [string]$filePatchValue } else { '' }
        $patchComplete = $false
        if ($null -ne $filePatchValue) {
            try {
                [void](Get-ReviewUnifiedHunkStatistics -Patch $filePatch -ExpectedAdditions ([int](Get-ReviewPropertyValue $_ 'additions' 0)) -ExpectedDeletions ([int](Get-ReviewPropertyValue $_ 'deletions' 0)))
                $patchComplete = $true
            } catch { $patchComplete = $false }
        }
        if ($null -ne $filePatchValue) {
            $oldPath = if ($previousPath) { $previousPath } else { $path }
            $patchParts.Add("diff --git a/$oldPath b/$path")
            $patchParts.Add($(if ($status -ceq 'added') { '--- /dev/null' } else { "--- a/$oldPath" }))
            $patchParts.Add($(if ($status -ceq 'removed') { '+++ /dev/null' } else { "+++ b/$path" }))
            $patchParts.Add($filePatch)
        }
        $mode = ''
        $modeAvailable = $false
        if ($treeMetadataComplete) {
            if ($status -eq 'removed') { $modeAvailable = $baseModes.TryGetValue($path, [ref]$mode) }
            else { $modeAvailable = $headModes.TryGetValue($path, [ref]$mode) }
        }
        $previousMode = ''
        $previousModeAvailable = $false
        if ($previousPath -and $treeMetadataComplete) { $previousModeAvailable = $baseModes.TryGetValue($previousPath, [ref]$previousMode) }
        $headBlob=''; $beforeBlob=''; $beforeMode=''
        $beforePath=if($previousPath){$previousPath}else{$path}
        if($treeMetadataComplete){[void]$headBlobs.TryGetValue($path,[ref]$headBlob);[void]$baseBlobs.TryGetValue($beforePath,[ref]$beforeBlob);[void]$baseModes.TryGetValue($beforePath,[ref]$beforeMode)}
        [pscustomobject]@{
            path = $path
            previousPath = $previousPath
            status = $status
            additions = [int](Get-ReviewPropertyValue $_ 'additions' 0)
            deletions = [int](Get-ReviewPropertyValue $_ 'deletions' 0)
            mode = $mode
            modeAvailable = $modeAvailable
            previousMode = $previousMode
            previousModeAvailable = $previousModeAvailable
            headBlobSha = $headBlob
            beforeBlobSha = $beforeBlob
            beforeMode = $beforeMode
            patchAvailable = ($null -ne $filePatchValue)
            patchComplete = $patchComplete
            textPatchEvidence = Get-ReviewPropertyValue $_ 'textPatchEvidence' $null
        }
    })
    return [pscustomobject]@{ files=$files; patch=($patchParts -join "`n"); treeMetadataComplete=$treeMetadataComplete }
}

function Get-PullRequestDependencyDelta {
    param(
        [Parameter(Mandatory)][object[]]$ChangedFiles,
        [AllowEmptyString()][string]$PatchText,
        [Parameter(Mandatory)]$Policy,
        [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[object]]$Findings
    )
    $manifestPaths = [Collections.Generic.List[string]]::new()
    foreach ($file in $ChangedFiles) {
        $path = [string](Get-ReviewPropertyValue $file 'path' (Get-ReviewPropertyValue $file 'filename' ''))
        foreach ($pattern in @($Policy.dependencyManifests)) {
            if (Test-ReviewPathPattern $path $pattern) { $manifestPaths.Add((ConvertTo-SafeReviewPath $path)); break }
        }
    }
    foreach ($manifestPath in @($manifestPaths)) {
        $Findings.Add((New-ReviewFinding -Code 'DEPENDENCY_MANIFEST_CHANGED' -Category 'dependency' -Severity 'high' -Path $manifestPath -Evidence $manifestPath -Detail 'Dependency-, Lock-, Build-, Workflow-, Installer- oder Paketquellenmanifest wurde geaendert und erfordert vertiefte Owner-Pruefung.'))
    }
    $added = [Collections.Generic.List[object]]::new()
    $removed = [Collections.Generic.List[object]]::new()
    $changed = [Collections.Generic.List[object]]::new()
    $usings = [Collections.Generic.List[object]]::new()
    $addedManifestLines = @{}
    $removedManifestLines = @{}
    $changedPaths = @($ChangedFiles | ForEach-Object {
        [string](Get-ReviewPropertyValue $_ 'path' (Get-ReviewPropertyValue $_ 'filename' ''))
    } | Where-Object { $_ })
    $currentPath = if ($changedPaths.Count -eq 1) { $changedPaths[0] } else { '' }
    $knownPackageJsonFields = @(
        'name','version','private','type','description','license','author','main','module','exports',
        'scripts','dependencies','devDependencies','peerDependencies','optionalDependencies',
        'engines','browserslist','files','workspaces','repository','keywords','packageManager'
    )
    $lines = @($PatchText -split "`r?`n")
    foreach ($line in $lines) {
        if ($line -match '^diff --git a/(?:.+) b/(?<path>.+)$') { $currentPath = $Matches.path; continue }
        if ($line -match '^\+\+\+ b/(?<path>.+)$') { $currentPath = $Matches.path; continue }
        $normalizedPath = $currentPath -replace '\\','/'
        $baseName = [IO.Path]::GetFileName($normalizedPath)
        $isNuGetManifest = $baseName -match '(?i)(?:\.csproj$|^Directory\.Packages\.props$|^Directory\.Build\.(?:props|targets)$)'
        $isPackageJson = $baseName -ieq 'package.json'
        $isCSharp = $normalizedPath -match '(?i)\.cs$'
        if ($line -match '^\+(?!\+\+\+)(?<content>.*)$') {
            $content = $Matches.content
            if ($isNuGetManifest -or $isPackageJson) {
                if (-not $addedManifestLines.ContainsKey($normalizedPath)) { $addedManifestLines[$normalizedPath] = [Collections.Generic.List[string]]::new() }
                $addedManifestLines[$normalizedPath].Add($content)
            }
            if ($isNuGetManifest -and $content -match '(?i)<PackageReference\b(?<attributes>[^>]*)>') {
                $attributes = $Matches.attributes
                $nameMatch = [regex]::Match($attributes, '(?i)(?:Include|Update)=["''](?<value>[^"'']+)["'']')
                $versionMatch = [regex]::Match($attributes, '(?i)Version=["''](?<value>[^"'']+)["'']')
                if ($nameMatch.Success) {
                    $name = ConvertTo-SafeReviewLabel $nameMatch.Groups['value'].Value 120
                    $version = if ($versionMatch.Success) { ConvertTo-SafeReviewLabel $versionMatch.Groups['value'].Value 80 } else { 'CENTRAL_OR_UNVERIFIED' }
                    $added.Add([pscustomobject]@{ ecosystem='nuget'; name=$name; version=$version; path=(ConvertTo-SafeReviewPath $normalizedPath) })
                    $Findings.Add((New-ReviewFinding -Code 'NEW_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Neue direkte NuGet-Abhaengigkeit erfordert Begruendung und Owner-Review.'))
                    if ($version -match '^(?:\*|latest|next)$|[\*xX]') { $Findings.Add((New-ReviewFinding -Code 'FLOATING_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Floating Dependency-Version ist unzulaessig.')) }
                    if ($content -match '(?i)OutputItemType\s*=\s*["'']Analyzer|IncludeAssets\s*=\s*["''][^"'']*(?:build|native|runtime)|GeneratePathProperty|buildTransitive') {
                        $Findings.Add((New-ReviewFinding -Code 'DEPENDENCY_BUILD_ASSET' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Dependency bringt Analyzer-, Build-, native oder Runtime-Assets ein und benoetigt vertiefte Pruefung.'))
                    }
                }
            }
            elseif ($isNuGetManifest -and $content -match '(?i)<PackageVersion\b(?<attributes>[^>]*)>') {
                $attributes = $Matches.attributes
                $nameMatch = [regex]::Match($attributes, '(?i)(?:Include|Update)=["''](?<value>[^"'']+)["'']')
                $versionMatch = [regex]::Match($attributes, '(?i)Version=["''](?<value>[^"'']+)["'']')
                if ($nameMatch.Success) {
                    $added.Add([pscustomobject]@{ ecosystem='nuget-central'; name=(ConvertTo-SafeReviewLabel $nameMatch.Groups['value'].Value 120); version=if($versionMatch.Success){ConvertTo-SafeReviewLabel $versionMatch.Groups['value'].Value 80}else{'UNVERIFIED'}; path=(ConvertTo-SafeReviewPath $normalizedPath) })
                    $Findings.Add((New-ReviewFinding -Code 'CENTRAL_PACKAGE_VERSION_CHANGE' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Zentrale NuGet-Version wurde geaendert und erfordert transitive Delta-Pruefung.'))
                }
            }
            elseif ($isPackageJson -and $content -match '^\s*["''](?<name>@?[A-Za-z0-9_.\-/]+)["'']\s*:\s*["''](?<version>[^"'']+)["'']\s*,?') {
                $name = ConvertTo-SafeReviewLabel $Matches.name 120
                $rawVersion = [string]$Matches.version
                $version = ConvertTo-SafeReviewLabel $rawVersion 120
                if ($knownPackageJsonFields -notcontains $name -and @($Policy.npmLifecycleScripts) -notcontains $name) {
                    $added.Add([pscustomobject]@{ ecosystem='npm'; name=$name; version=$version; path=(ConvertTo-SafeReviewPath $normalizedPath) })
                    $Findings.Add((New-ReviewFinding -Code 'NEW_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Neue direkte npm-Abhaengigkeit erfordert Begruendung und Owner-Review.'))
                    if ($rawVersion -match '^(?:\*|latest|next)$|(?:^|[.\-])[xX*](?:$|[.\-])') { $Findings.Add((New-ReviewFinding -Code 'FLOATING_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Floating Dependency-Version ist unzulaessig.')) }
                    if ($rawVersion -match '(?i)^file:(?:\.\.?[\\/]|[A-Za-z]:)') { $Findings.Add((New-ReviewFinding -Code 'LOCAL_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Lokale Paketpfade sind unzulaessig.')) }
                    if ($rawVersion -match '(?i)^(?:git\+|git://|github:|gitlab:|https?://.*\.git(?:#|$))') { $Findings.Add((New-ReviewFinding -Code 'GIT_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Git-Abhaengigkeit ist ohne Owner-Review unzulaessig.')) }
                    if ($rawVersion -match '(?i)^https?://') { $Findings.Add((New-ReviewFinding -Code 'URL_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Direkte URL-Abhaengigkeit ist ohne Owner- und Supply-Chain-Review unzulaessig.')) }
                }
            }
            if ($isPackageJson -and $content -match '(?i)["''](?:preinstall|install|postinstall|prepare)["'']\s*:') {
                $Findings.Add((New-ReviewFinding -Code 'PACKAGE_LIFECYCLE_SCRIPT' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Paketmanager-Lifecycle-Skript erfordert Owner-Review.'))
            }
            if ($isCSharp -and $content -match '^\s*using\s+(?<namespace>[A-Za-z_][A-Za-z0-9_.]*);') {
                $ns = ConvertTo-SafeReviewLabel $Matches.namespace 160
                $origin = if ($ns -eq 'System' -or $ns.StartsWith('System.')) { 'BCL' } elseif ($ns.StartsWith('SchachTurnierManager.')) { 'PROJECT' } else { 'UNVERIFIED' }
                $usings.Add([pscustomobject]@{ namespace=$ns; origin=$origin; path=(ConvertTo-SafeReviewPath $normalizedPath); unusedCheck='ANALYZER_AFTER_STATIC_APPROVAL' })
                if ($origin -eq 'UNVERIFIED') {
                    $Findings.Add((New-ReviewFinding -Code 'UNVERIFIED_USING_NAMESPACE' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Herkunft des neuen Namespace ist statisch nicht als Projekt oder BCL verifiziert.'))
                }
            }
            if ($baseName -ieq 'NuGet.Config') {
                $Findings.Add((New-ReviewFinding -Code 'PACKAGE_SOURCE_CHANGE' -Category 'dependency' -Severity 'high' -Path $normalizedPath -Evidence $content -Detail 'Paketquellen-Aenderung erfordert Owner- und Supply-Chain-Review.'))
            }
        }
        elseif ($line -match '^-(?!---)(?<content>.*)$') {
            $content = $Matches.content
            if ($isNuGetManifest -or $isPackageJson) {
                if (-not $removedManifestLines.ContainsKey($normalizedPath)) { $removedManifestLines[$normalizedPath] = [Collections.Generic.List[string]]::new() }
                $removedManifestLines[$normalizedPath].Add($content)
            }
            if ($isNuGetManifest -and $content -match '(?i)<PackageReference\b(?<attributes>[^>]*)>') {
                $attributes = $Matches.attributes
                $nameMatch = [regex]::Match($attributes, '(?i)(?:Include|Update)=["''](?<value>[^"'']+)["'']')
                $versionMatch = [regex]::Match($attributes, '(?i)Version=["''](?<value>[^"'']+)["'']')
                if ($nameMatch.Success) {
                    $removed.Add([pscustomobject]@{ ecosystem='nuget'; name=(ConvertTo-SafeReviewLabel $nameMatch.Groups['value'].Value 120); version=if($versionMatch.Success){ConvertTo-SafeReviewLabel $versionMatch.Groups['value'].Value 80}else{'CENTRAL_OR_UNVERIFIED'}; path=(ConvertTo-SafeReviewPath $normalizedPath) })
                }
            }
            elseif ($isNuGetManifest -and $content -match '(?i)<PackageVersion\b(?<attributes>[^>]*)>') {
                $attributes = $Matches.attributes
                $nameMatch = [regex]::Match($attributes, '(?i)(?:Include|Update)=["''](?<value>[^"'']+)["'']')
                $versionMatch = [regex]::Match($attributes, '(?i)Version=["''](?<value>[^"'']+)["'']')
                if ($nameMatch.Success) {
                    $removed.Add([pscustomobject]@{ ecosystem='nuget-central'; name=(ConvertTo-SafeReviewLabel $nameMatch.Groups['value'].Value 120); version=if($versionMatch.Success){ConvertTo-SafeReviewLabel $versionMatch.Groups['value'].Value 80}else{'UNVERIFIED'}; path=(ConvertTo-SafeReviewPath $normalizedPath) })
                }
            }
            elseif ($isPackageJson -and $content -match '^\s*["''](?<name>@?[A-Za-z0-9_.\-/]+)["'']\s*:\s*["''](?<version>[^"'']+)["'']\s*,?') {
                $name = ConvertTo-SafeReviewLabel $Matches.name 120
                if ($knownPackageJsonFields -notcontains $name -and @($Policy.npmLifecycleScripts) -notcontains $name) {
                    $removed.Add([pscustomobject]@{ ecosystem='npm'; name=$name; version=(ConvertTo-SafeReviewLabel $Matches.version 120); path=(ConvertTo-SafeReviewPath $normalizedPath) })
                }
            }
        }
    }
    foreach ($entry in $addedManifestLines.GetEnumerator()) {
        $joined = @($entry.Value) -join "`n"
        foreach ($match in [regex]::Matches($joined, '(?is)<PackageReference\b(?<attributes>[^>]*?)(?:/\s*>|>(?<body>.*?)</PackageReference\s*>)')) {
            $attributes = $match.Groups['attributes'].Value
            $body = $match.Groups['body'].Value
            $nameMatch = [regex]::Match($attributes, '(?i)(?:Include|Update)\s*=\s*["''](?<value>[^"'']+)["'']')
            $versionMatch = [regex]::Match($attributes, '(?i)Version\s*=\s*["''](?<value>[^"'']+)["'']')
            if (-not $versionMatch.Success) { $versionMatch = [regex]::Match($body, '(?is)<Version\s*>(?<value>[^<]+)</Version\s*>') }
            if ($nameMatch.Success) {
                $name = ConvertTo-SafeReviewLabel $nameMatch.Groups['value'].Value 120
                $rawVersion = if ($versionMatch.Success) { $versionMatch.Groups['value'].Value.Trim() } else { 'CENTRAL_OR_UNVERIFIED' }
                $version = ConvertTo-SafeReviewLabel $rawVersion 80
                if (@($added | Where-Object { $_.ecosystem -eq 'nuget' -and $_.name -eq $name -and $_.path -eq (ConvertTo-SafeReviewPath $entry.Key) }).Count -eq 0) {
                    $added.Add([pscustomobject]@{ ecosystem='nuget'; name=$name; version=$version; path=(ConvertTo-SafeReviewPath $entry.Key) })
                    $Findings.Add((New-ReviewFinding -Code 'NEW_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $entry.Key -Evidence $match.Value -Detail 'Neue mehrzeilige NuGet-Abhaengigkeit erfordert Begruendung und Owner-Review.'))
                }
                if ($rawVersion -match '^(?:\*|latest|next)$|[\*xX]') {
                    $Findings.Add((New-ReviewFinding -Code 'FLOATING_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $entry.Key -Evidence $match.Value -Detail 'Floating Dependency-Version ist unzulaessig.'))
                }
                if (($attributes + "`n" + $body) -match '(?is)OutputItemType\s*=\s*["'']Analyzer|<OutputItemType\s*>\s*Analyzer\s*</OutputItemType>|IncludeAssets\s*=\s*["''][^"'']*(?:build|native|runtime)|<IncludeAssets\s*>[^<]*(?:build|native|runtime)[^<]*</IncludeAssets>|GeneratePathProperty|buildTransitive|<PrivateAssets\s*>\s*all\s*</PrivateAssets>') {
                    $Findings.Add((New-ReviewFinding -Code 'DEPENDENCY_BUILD_ASSET' -Category 'dependency' -Severity 'high' -Path $entry.Key -Evidence $match.Value -Detail 'Dependency bringt Analyzer-, Build-, native oder Runtime-Assets ein und benoetigt vertiefte Pruefung.'))
                }
            }
        }
        foreach ($match in [regex]::Matches($joined, '(?is)<PackageVersion\b(?<attributes>[^>]*?)(?:/\s*>|>(?<body>.*?)</PackageVersion\s*>)')) {
            $attributes = $match.Groups['attributes'].Value
            $body = $match.Groups['body'].Value
            $nameMatch = [regex]::Match($attributes, '(?i)(?:Include|Update)\s*=\s*["''](?<value>[^"'']+)["'']')
            $versionMatch = [regex]::Match($attributes, '(?i)Version\s*=\s*["''](?<value>[^"'']+)["'']')
            if (-not $versionMatch.Success) { $versionMatch = [regex]::Match($body, '(?is)<Version\s*>(?<value>[^<]+)</Version\s*>') }
            if ($nameMatch.Success) {
                $name = ConvertTo-SafeReviewLabel $nameMatch.Groups['value'].Value 120
                $rawVersion = if ($versionMatch.Success) { $versionMatch.Groups['value'].Value.Trim() } else { 'UNVERIFIED' }
                if (@($added | Where-Object { $_.ecosystem -eq 'nuget-central' -and $_.name -eq $name -and $_.path -eq (ConvertTo-SafeReviewPath $entry.Key) }).Count -eq 0) {
                    $added.Add([pscustomobject]@{ ecosystem='nuget-central'; name=$name; version=(ConvertTo-SafeReviewLabel $rawVersion 80); path=(ConvertTo-SafeReviewPath $entry.Key) })
                    $Findings.Add((New-ReviewFinding -Code 'CENTRAL_PACKAGE_VERSION_CHANGE' -Category 'dependency' -Severity 'high' -Path $entry.Key -Evidence $match.Value -Detail 'Mehrzeilige zentrale NuGet-Version wurde geaendert und erfordert transitive Delta-Pruefung.'))
                }
                if ($rawVersion -match '^(?:\*|latest|next)$|[\*xX]') {
                    $Findings.Add((New-ReviewFinding -Code 'FLOATING_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $entry.Key -Evidence $match.Value -Detail 'Floating zentrale Dependency-Version ist unzulaessig.'))
                }
            }
        }
        if ([IO.Path]::GetFileName([string]$entry.Key) -ieq 'package.json') {
            foreach ($match in [regex]::Matches($joined, '(?im)["''](?<name>@?[A-Za-z0-9_.\-/]+)["'']\s*:\s*["''](?<version>[^"'']+)["'']')) {
                $name = ConvertTo-SafeReviewLabel $match.Groups['name'].Value 120
                $rawVersion = $match.Groups['version'].Value
                if ($knownPackageJsonFields -contains $name -or @($Policy.npmLifecycleScripts) -contains $name) { continue }
                if (@($added | Where-Object { $_.ecosystem -eq 'npm' -and $_.name -eq $name -and $_.path -eq (ConvertTo-SafeReviewPath $entry.Key) }).Count -eq 0) {
                    $added.Add([pscustomobject]@{ ecosystem='npm'; name=$name; version=(ConvertTo-SafeReviewLabel $rawVersion 120); path=(ConvertTo-SafeReviewPath $entry.Key) })
                    $Findings.Add((New-ReviewFinding -Code 'NEW_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $entry.Key -Evidence $match.Value -Detail 'Neue zeilenuebergreifende npm-Abhaengigkeit erfordert Begruendung und Owner-Review.'))
                }
                if ($rawVersion -match '^(?:\*|latest|next)$|(?:^|[.\-])[xX*](?:$|[.\-])') { $Findings.Add((New-ReviewFinding -Code 'FLOATING_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $entry.Key -Evidence $match.Value -Detail 'Floating Dependency-Version ist unzulaessig.')) }
                if ($rawVersion -match '(?i)^file:') { $Findings.Add((New-ReviewFinding -Code 'LOCAL_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $entry.Key -Evidence $match.Value -Detail 'Lokale Paketpfade sind unzulaessig.')) }
                if ($rawVersion -match '(?i)^(?:git\+|git://|github:|gitlab:|https?://.*\.git(?:#|$))') { $Findings.Add((New-ReviewFinding -Code 'GIT_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $entry.Key -Evidence $match.Value -Detail 'Git-Abhaengigkeit ist ohne Owner-Review unzulaessig.')) }
                if ($rawVersion -match '(?i)^https?://') { $Findings.Add((New-ReviewFinding -Code 'URL_DEPENDENCY' -Category 'dependency' -Severity 'high' -Path $entry.Key -Evidence $match.Value -Detail 'Direkte URL-Abhaengigkeit ist ohne Owner- und Supply-Chain-Review unzulaessig.')) }
            }
        }
    }
    foreach ($entry in $removedManifestLines.GetEnumerator()) {
        $joined = @($entry.Value) -join "`n"
        foreach ($match in [regex]::Matches($joined, '(?is)<PackageReference\b(?<attributes>[^>]*?)(?:/\s*>|>(?<body>.*?)</PackageReference\s*>)')) {
            $attributes = $match.Groups['attributes'].Value
            $body = $match.Groups['body'].Value
            $nameMatch = [regex]::Match($attributes, '(?i)(?:Include|Update)\s*=\s*["''](?<value>[^"'']+)["'']')
            $versionMatch = [regex]::Match($attributes, '(?i)Version\s*=\s*["''](?<value>[^"'']+)["'']')
            if (-not $versionMatch.Success) { $versionMatch = [regex]::Match($body, '(?is)<Version\s*>(?<value>[^<]+)</Version\s*>') }
            if ($nameMatch.Success -and @($removed | Where-Object { $_.ecosystem -eq 'nuget' -and $_.name -eq $nameMatch.Groups['value'].Value -and $_.path -eq (ConvertTo-SafeReviewPath $entry.Key) }).Count -eq 0) {
                $removed.Add([pscustomobject]@{ ecosystem='nuget'; name=(ConvertTo-SafeReviewLabel $nameMatch.Groups['value'].Value 120); version=if($versionMatch.Success){ConvertTo-SafeReviewLabel $versionMatch.Groups['value'].Value 80}else{'CENTRAL_OR_UNVERIFIED'}; path=(ConvertTo-SafeReviewPath $entry.Key) })
            }
        }
        foreach ($match in [regex]::Matches($joined, '(?is)<PackageVersion\b(?<attributes>[^>]*?)(?:/\s*>|>(?<body>.*?)</PackageVersion\s*>)')) {
            $attributes = $match.Groups['attributes'].Value
            $body = $match.Groups['body'].Value
            $nameMatch = [regex]::Match($attributes, '(?i)(?:Include|Update)\s*=\s*["''](?<value>[^"'']+)["'']')
            $versionMatch = [regex]::Match($attributes, '(?i)Version\s*=\s*["''](?<value>[^"'']+)["'']')
            if (-not $versionMatch.Success) { $versionMatch = [regex]::Match($body, '(?is)<Version\s*>(?<value>[^<]+)</Version\s*>') }
            if ($nameMatch.Success -and @($removed | Where-Object { $_.ecosystem -eq 'nuget-central' -and $_.name -eq $nameMatch.Groups['value'].Value -and $_.path -eq (ConvertTo-SafeReviewPath $entry.Key) }).Count -eq 0) {
                $removed.Add([pscustomobject]@{ ecosystem='nuget-central'; name=(ConvertTo-SafeReviewLabel $nameMatch.Groups['value'].Value 120); version=if($versionMatch.Success){ConvertTo-SafeReviewLabel $versionMatch.Groups['value'].Value 80}else{'UNVERIFIED'}; path=(ConvertTo-SafeReviewPath $entry.Key) })
            }
        }
        if ([IO.Path]::GetFileName([string]$entry.Key) -ieq 'package.json') {
            foreach ($match in [regex]::Matches($joined, '(?im)["''](?<name>@?[A-Za-z0-9_.\-/]+)["'']\s*:\s*["''](?<version>[^"'']+)["'']')) {
                $name = ConvertTo-SafeReviewLabel $match.Groups['name'].Value 120
                if ($knownPackageJsonFields -contains $name -or @($Policy.npmLifecycleScripts) -contains $name) { continue }
                if (@($removed | Where-Object { $_.ecosystem -eq 'npm' -and $_.name -eq $name -and $_.path -eq (ConvertTo-SafeReviewPath $entry.Key) }).Count -eq 0) {
                    $removed.Add([pscustomobject]@{ ecosystem='npm'; name=$name; version=(ConvertTo-SafeReviewLabel $match.Groups['version'].Value 120); path=(ConvertTo-SafeReviewPath $entry.Key) })
                }
            }
        }
    }
    foreach ($newPackage in @($added)) {
        $oldPackage = @($removed | Where-Object { $_.ecosystem -eq $newPackage.ecosystem -and $_.name -eq $newPackage.name -and $_.path -eq $newPackage.path } | Select-Object -First 1)
        if ($oldPackage.Count -gt 0 -and $oldPackage[0].version -ne $newPackage.version) {
            $changed.Add([pscustomobject]@{ ecosystem=$newPackage.ecosystem; name=$newPackage.name; from=$oldPackage[0].version; to=$newPackage.version; path=$newPackage.path })
            $Findings.Add((New-ReviewFinding -Code 'DEPENDENCY_VERSION_CHANGE' -Category 'dependency' -Severity 'high' -Path $newPackage.path -Evidence "$($oldPackage[0].version)/$($newPackage.version)" -Detail 'Dependency-Versionsaenderung erfordert Delta-, Lizenz- und Vulnerability-Review.'))
        }
    }
    $changedKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($changed)) { [void]$changedKeys.Add("$($item.ecosystem)|$($item.name)|$($item.path)") }
    $addedOutput = @($added | Where-Object { -not $changedKeys.Contains("$($_.ecosystem)|$($_.name)|$($_.path)") } | Group-Object ecosystem,name,version,path | ForEach-Object { $_.Group[0] })
    $removedOutput = @($removed | Where-Object { -not $changedKeys.Contains("$($_.ecosystem)|$($_.name)|$($_.path)") } | Group-Object ecosystem,name,version,path | ForEach-Object { $_.Group[0] })
    $normalizedManifests = @($manifestPaths | ForEach-Object { ([string]$_) -replace '\\','/' })
    foreach ($packageManifest in @($normalizedManifests | Where-Object { [IO.Path]::GetFileName($_) -ieq 'package.json' })) {
        $directory = if ($packageManifest.Contains('/')) { $packageManifest.Substring(0, $packageManifest.LastIndexOf('/')) } else { '' }
        $prefix = if ($directory) { "$directory/" } else { '' }
        $matchingLock = @($normalizedManifests | Where-Object { $_ -in @("${prefix}package-lock.json","${prefix}npm-shrinkwrap.json","${prefix}pnpm-lock.yaml","${prefix}yarn.lock") })
        if ($matchingLock.Count -eq 0) {
            $Findings.Add((New-ReviewFinding -Code 'LOCKFILE_DELTA_MISSING' -Category 'dependency' -Severity 'high' -Path $packageManifest -Evidence 'package-manifest-without-same-directory-lockfile' -Detail 'Package-Manifest wurde ohne Lockfile-Delta im selben Verzeichnis geaendert.'))
        }
    }
    if ($added.Count -gt 0 -and [string]$Policy.projectLicenseStatus -eq 'UNVERIFIED') {
        $Findings.Add((New-ReviewFinding -Code 'DEPENDENCY_LICENSE_UNVERIFIED' -Category 'dependency' -Severity 'high' -Evidence 'project-license-unverified' -Detail 'Projektlizenz oder Dependency-Kompatibilitaet ist nicht verifiziert.'))
    }
    return [pscustomobject]@{
        schemaVersion = 1
        changedManifests = @($manifestPaths | Sort-Object -Unique)
        newDirectDependencies = $addedOutput
        removedDependencies = $removedOutput
        changedDirectDependencies = @($changed)
        newUsings = @($usings)
        transitiveDeltaInspected = $false
        licensesInspectedOnline = $false
        vulnerabilitiesInspectedOnline = $false
        deprecatedPackagesInspectedOnline = $false
        onlineAuditAllowedAtThisStage = $false
        status = if (@($Findings | Where-Object { $_.category -eq 'dependency' -and $_.severity -in @('HIGH','CRITICAL') }).Count -gt 0) { 'OWNER_REVIEW_REQUIRED' } elseif ($manifestPaths.Count -eq 0 -and $usings.Count -eq 0) { 'NOT_APPLICABLE' } else { 'STATIC_REVIEWED' }
    }
}

function Invoke-PullRequestStaticAnalysis {
    param(
        [Parameter(Mandatory)]$Metadata,
        [Parameter(Mandatory)][object[]]$ChangedFiles,
        [AllowEmptyString()][string]$PatchText,
        [Parameter(Mandatory)]$Policies,
        [string[]]$BaseFiles = @()
    )
    $findings = [Collections.Generic.List[object]]::new()
    $title = [string](Get-ReviewPropertyValue $Metadata 'title' '')
    $body = [string](Get-ReviewPropertyValue $Metadata 'body' '')
    $branch = [string](Get-ReviewPropertyValue $Metadata 'headRefName' '')
    $metadataText = $title + "`n" + $body
    if ($metadataText.Length -gt [int]$Policies.review.maxMetadataTextLength) {
        $findings.Add((New-ReviewFinding -Code 'METADATA_TOO_LARGE' -Category 'unverified' -Severity 'critical' -Evidence ([string]$metadataText.Length) -Detail 'PR-Metadaten ueberschreiten das statische Prueflimit.' -RiskClass 'UNVERIFIED'))
        $metadataText = $metadataText.Substring(0, [int]$Policies.review.maxMetadataTextLength)
    }
    if ($metadataText -match '[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]') {
        $findings.Add((New-ReviewFinding -Code 'BIDI_CONTROL' -Category 'unicode' -Severity 'critical' -Evidence $metadataText -Detail 'Unicode-Bidi-Steuerzeichen in PR-Metadaten erkannt.' -RiskClass 'UNVERIFIED'))
    }
    Add-PatternFindings -Findings $findings -Scope metadata -Text $metadataText -PatternPolicy $Policies.suspicious
    if ($branch -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._/-]{0,199}$' -or $branch -match '(?:^|/)\.\.(?:/|$)|[;&|`$(){}\[\]<>\s]') {
        $findings.Add((New-ReviewFinding -Code 'UNSAFE_REF_NAME' -Category 'repository' -Severity 'critical' -Evidence $branch -Detail 'PR-Branchname enthaelt unzulaessige Zeichen.' -RiskClass 'UNVERIFIED'))
    }
    $baseSha = [string](Get-ReviewPropertyValue $Metadata 'baseSha' (Get-ReviewPropertyValue $Metadata 'baseRefOid' ''))
    $currentBaseSha = [string](Get-ReviewPropertyValue $Metadata 'currentTrustedBaseSha' $baseSha)
    if (-not (Test-ReviewSha $currentBaseSha) -or $currentBaseSha -cne $baseSha) {
        $findings.Add((New-ReviewFinding -Code 'BASE_SHA_DRIFT' -Category 'unverified' -Severity 'critical' -Evidence "$baseSha/$currentBaseSha" -Detail 'Gepruefter PR-Base-SHA entspricht nicht dem aktuellen vertrauenswuerdigen Basebranch.' -RiskClass 'UNVERIFIED'))
    }
    $baseTreeAvailable = [bool](Get-ReviewPropertyValue $Metadata 'baseTreeAvailable' $true)
    if (-not $baseTreeAvailable) {
        $findings.Add((New-ReviewFinding -Code 'BASE_TREE_UNAVAILABLE' -Category 'unverified' -Severity 'critical' -Evidence $baseSha -Detail 'Base-Baum ist lokal nicht fuer den Logik- und Duplikatvergleich verfuegbar.' -RiskClass 'UNVERIFIED'))
    }
    if ($ChangedFiles.Count -gt [int]$Policies.review.maxChangedFiles) {
        $findings.Add((New-ReviewFinding -Code 'TOO_MANY_CHANGED_FILES' -Category 'unverified' -Severity 'critical' -Evidence ([string]$ChangedFiles.Count) -Detail 'Dateianzahl ueberschreitet das statische Prueflimit.' -RiskClass 'UNVERIFIED'))
    }
    $declaredCount = Get-ReviewPropertyValue $Metadata 'changedFiles' $null
    if ($null -ne $declaredCount -and [int]$declaredCount -ne $ChangedFiles.Count) {
        $findings.Add((New-ReviewFinding -Code 'INCOMPLETE_FILE_LIST' -Category 'unverified' -Severity 'critical' -Evidence "$declaredCount/$($ChangedFiles.Count)" -Detail 'GitHub-Dateiliste ist unvollstaendig.' -RiskClass 'UNVERIFIED'))
    }
    if (-not [bool](Get-ReviewPropertyValue $Metadata 'gitTreeMetadataComplete' $true)) {
        $findings.Add((New-ReviewFinding -Code 'GIT_TREE_METADATA_INCOMPLETE' -Category 'unverified' -Severity 'critical' -Evidence 'git-tree-truncated-or-unavailable' -Detail 'SHA-gebundene Git-Tree-Modi sind unvollstaendig; Symlinks und Gitlinks koennen nicht sicher klassifiziert werden.' -RiskClass 'UNVERIFIED'))
    }
    foreach ($artifactError in @((Get-ReviewPropertyValue $Metadata 'artifactAttestationErrors' @()))) {
        $findings.Add((New-ReviewFinding -Code 'ARTIFACT_ATTESTATION_MISMATCH' -Category 'binary' -Severity 'critical' -Evidence ([string]$artifactError) -Detail 'SHA-/Pfad-/Head-gebundene Artifact-Attestation stimmt nicht vollstaendig mit dem PR ueberein.' -RiskClass 'UNVERIFIED'))
    }
    $patchBytes = [Text.Encoding]::UTF8.GetByteCount(($PatchText ?? ''))
    $scanPatch = $PatchText ?? ''
    if ($patchBytes -gt [int]$Policies.review.maxPatchBytes) {
        $findings.Add((New-ReviewFinding -Code 'PATCH_TOO_LARGE' -Category 'unverified' -Severity 'critical' -Evidence ([string]$PatchText.Length) -Detail 'Patch ueberschreitet das statische Prueflimit.' -RiskClass 'UNVERIFIED'))
        $scanPatch = ''
    }
    if ($scanPatch -match '[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]') {
        $findings.Add((New-ReviewFinding -Code 'BIDI_CONTROL' -Category 'unicode' -Severity 'critical' -Evidence $scanPatch -Detail 'Unicode-Bidi-Steuerzeichen im Patchinhalt erkannt.' -RiskClass 'UNVERIFIED'))
    }
    $patchPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($patchLine in @($scanPatch -split "`r?`n")) {
        if ($patchLine -cmatch '^diff --git a/(?:.*?) b/(?<path>.+)$') { [void]$patchPaths.Add($Matches.path) }
    }
    $baseSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($baseFile in $BaseFiles) { [void]$baseSet.Add(($baseFile -replace '\\','/')) }
    $safeFiles = [Collections.Generic.List[object]]::new()
    $filesToScan = @($ChangedFiles | Select-Object -First ([int]$Policies.review.maxChangedFiles))
    foreach ($file in $filesToScan) {
        $rawPath = [string](Get-ReviewPropertyValue $file 'path' (Get-ReviewPropertyValue $file 'filename' ''))
        $previousPath = [string](Get-ReviewPropertyValue $file 'previousPath' (Get-ReviewPropertyValue $file 'previous_filename' ''))
        $safePath = ConvertTo-SafeReviewPath $rawPath
        $mode = [string](Get-ReviewPropertyValue $file 'mode' '')
        $modeAvailable = [bool](Get-ReviewPropertyValue $file 'modeAvailable' ([bool]$mode))
        $previousMode = [string](Get-ReviewPropertyValue $file 'previousMode' '')
        $previousModeAvailable = [bool](Get-ReviewPropertyValue $file 'previousModeAvailable' (-not $previousPath -or [bool]$previousMode))
        $patchAvailable = [bool](Get-ReviewPropertyValue $file 'patchAvailable' $true)
        $patchComplete = [bool](Get-ReviewPropertyValue $file 'patchComplete' $false)
        $artifactVerification = Get-ReviewPropertyValue $file 'artifactVerification' $null
        $artifactStatus = [string](Get-ReviewPropertyValue $artifactVerification 'status' '')
        $artifactKind = [string](Get-ReviewPropertyValue $artifactVerification 'kind' '')
        $artifactVerified = $artifactStatus -ceq 'VERIFIED' -and
            [int](Get-ReviewPropertyValue $artifactVerification 'pullRequestNumber' 0) -eq [int](Get-ReviewPropertyValue $Metadata 'number' 0) -and
            [string](Get-ReviewPropertyValue $artifactVerification 'headSha' '') -ceq [string](Get-ReviewPropertyValue $Metadata 'headSha' (Get-ReviewPropertyValue $Metadata 'headRefOid' '')) -and
            [string](Get-ReviewPropertyValue $artifactVerification 'path' '') -ceq $rawPath
        $modeValid = $modeAvailable -and $mode -cmatch '^(?:100644|100755|120000|160000)$'
        $previousModeValid = -not $previousPath -or ($previousModeAvailable -and $previousMode -cmatch '^(?:100644|100755|120000|160000)$')
        $safeFiles.Add([pscustomobject]@{
            path=$safePath; previousPath=if($previousPath){ConvertTo-SafeReviewPath $previousPath}else{$null}
            status=(ConvertTo-SafeReviewLabel ([string](Get-ReviewPropertyValue $file 'status' 'unknown')) 40)
            mode=if($modeValid){$mode}else{'UNVERIFIED'}; previousMode=if($previousModeValid -and $previousPath){$previousMode}else{$null}
            patchAvailable=$patchAvailable; patchComplete=$patchComplete
            textPatchEvidence=ConvertTo-SafeReviewTextPatchEvidence -Evidence (Get-ReviewPropertyValue $file 'textPatchEvidence' $null) -Metadata $Metadata
            artifactVerification=if($artifactVerification){[pscustomobject]@{
                status=$artifactStatus; approvalId=(ConvertTo-SafeReviewLabel ([string](Get-ReviewPropertyValue $artifactVerification 'approvalId' '')) 80)
                kind=$artifactKind; mimeType=(ConvertTo-SafeReviewLabel ([string](Get-ReviewPropertyValue $artifactVerification 'mimeType' '')) 80)
                gitBlobSha=(ConvertTo-SafeReviewLabel ([string](Get-ReviewPropertyValue $artifactVerification 'gitBlobSha' '')) 40)
                size=[int64](Get-ReviewPropertyValue $artifactVerification 'size' 0); sha256=(ConvertTo-SafeReviewLabel ([string](Get-ReviewPropertyValue $artifactVerification 'sha256' '')) 64)
                errors=@((Get-ReviewPropertyValue $artifactVerification 'errors' @()) | ForEach-Object { ConvertTo-SafeReviewLabel ([string]$_) 80 })
            }}else{$null}
        })
        if ($rawPath -match '[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]') {
            $findings.Add((New-ReviewFinding -Code 'BIDI_CONTROL' -Category 'unicode' -Severity 'high' -Path $rawPath -Evidence $rawPath -Detail 'Unicode-Bidi-Steuerzeichen im Pfad erkannt.'))
        }
        if ([string]::IsNullOrWhiteSpace($rawPath) -or [IO.Path]::IsPathRooted($rawPath) -or $rawPath -match '(^|[\\/])\.\.([\\/]|$)' -or
            $rawPath -match '[\x00-\x1F\x7F-\x9F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]' -or $rawPath -match '[:;&|`$(){}\[\]<>]' -or $rawPath -match '[^\x20-\x7E]' -or
            @($rawPath -split '[\\/]' | Where-Object { $_ -match '(?i)^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)|[. ]$' }).Count -gt 0) {
            $findings.Add((New-ReviewFinding -Code 'UNSAFE_FILE_NAME' -Category 'repository' -Severity 'critical' -Path $rawPath -Evidence $rawPath -Detail 'Dateipfad enthaelt unzulaessige, mehrdeutige oder nicht sicher darstellbare Zeichen.' -RiskClass 'UNVERIFIED'))
        }
        if (-not $modeValid -or -not $previousModeValid) {
            $findings.Add((New-ReviewFinding -Code 'FILE_MODE_UNVERIFIED' -Category 'unverified' -Severity 'critical' -Path $rawPath -Evidence "$mode/$previousMode" -Detail 'SHA-gebundener Datei- oder Rename-Modus fehlt beziehungsweise ist ungueltig.' -RiskClass 'UNVERIFIED'))
        }
        if ($previousPath -and ([string]::IsNullOrWhiteSpace($previousPath) -or [IO.Path]::IsPathRooted($previousPath) -or $previousPath -match '(^|[\\/])\.\.([\\/]|$)' -or
            $previousPath -match '[\x00-\x1F\x7F-\x9F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]' -or $previousPath -match '[:;&|`$(){}\[\]<>]' -or $previousPath -match '[^\x20-\x7E]' -or
            @($previousPath -split '[\\/]' | Where-Object { $_ -match '(?i)^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)|[. ]$' }).Count -gt 0)) {
            $findings.Add((New-ReviewFinding -Code 'UNSAFE_FILE_NAME' -Category 'repository' -Severity 'critical' -Path $previousPath -Evidence $previousPath -Detail 'Vorheriger Rename-Pfad enthaelt unzulaessige oder mehrdeutige Zeichen.' -RiskClass 'UNVERIFIED'))
        }
        Add-PatternFindings -Findings $findings -Scope path -Text $rawPath -Path $rawPath -PatternPolicy $Policies.suspicious
        if ($mode -eq '120000') { $findings.Add((New-ReviewFinding -Code 'SYMLINK' -Category 'repository' -Severity 'critical' -Path $rawPath -Evidence $mode -Detail 'Symlink ist in der statischen Phase blockiert.' -RiskClass 'UNVERIFIED')) }
        if ($mode -eq '160000' -or $rawPath -eq '.gitmodules') { $findings.Add((New-ReviewFinding -Code 'SUBMODULE' -Category 'repository' -Severity 'critical' -Path $rawPath -Evidence $mode -Detail 'Submodule ist in der statischen Phase blockiert.' -RiskClass 'UNVERIFIED')) }
        $extension = [IO.Path]::GetExtension($rawPath).ToLowerInvariant()
        if ($artifactStatus -and -not $artifactVerified) {
            $findings.Add((New-ReviewFinding -Code 'ARTIFACT_ATTESTATION_MISMATCH' -Category 'binary' -Severity 'critical' -Path $rawPath -Evidence $artifactStatus -Detail 'Artifact-Verifikation ist fehlgeschlagen oder nicht exakt an PR, Head und Pfad gebunden.' -RiskClass 'UNVERIFIED'))
        }
        elseif ($artifactVerified) {
            $verifiedCode = if ($artifactKind -ceq 'third-party-build-wrapper') { 'VERIFIED_THIRD_PARTY_BUILD_WRAPPER' } else { 'VERIFIED_ATTESTED_ARTIFACT' }
            $findings.Add((New-ReviewFinding -Code $verifiedCode -Category 'build' -Severity 'high' -Path $rawPath -Evidence ([string](Get-ReviewPropertyValue $artifactVerification 'sha256' '')) -Detail 'Artefakt ist exakt verifiziert, bleibt aber Owner-Review-pflichtig und wird nicht ausgefuehrt.'))
        }
        if (@($Policies.review.archiveFileTypes) -contains $extension) {
            if (-not ($artifactVerified -and $artifactKind -ceq 'gradle-wrapper-jar')) {
                $findings.Add((New-ReviewFinding -Code 'BLOCKED_ARCHIVE' -Category 'binary' -Severity 'critical' -Path $rawPath -Evidence $extension -Detail 'Archivdatei kann statisch nicht sicher verifiziert werden.' -RiskClass 'UNVERIFIED'))
            }
        }
        elseif (@($Policies.review.blockedFileTypes) -contains $extension) {
            $findings.Add((New-ReviewFinding -Code 'BLOCKED_BINARY' -Category 'binary' -Severity 'critical' -Path $rawPath -Evidence $extension -Detail 'Binaerdatei kann statisch nicht sicher verifiziert werden.' -RiskClass 'UNVERIFIED'))
        }
        elseif (-not $patchAvailable -or -not $patchComplete -or -not $patchPaths.Contains($rawPath)) {
            if (-not ($artifactVerified -and $artifactKind -ceq 'android-png')) {
                $findings.Add((New-ReviewFinding -Code 'INCOMPLETE_PATCH' -Category 'unverified' -Severity 'critical' -Path $rawPath -Evidence 'patch-unavailable' -Detail 'Patch ist fuer eine geaenderte Textdatei unvollstaendig.' -RiskClass 'UNVERIFIED'))
            }
        }
        foreach ($candidatePath in @($rawPath,$previousPath) | Where-Object { $_ }) {
            foreach ($highRisk in @($Policies.review.highRiskPaths)) {
                $isHighRisk = if ($highRisk.EndsWith('/')) { $candidatePath.StartsWith($highRisk, [StringComparison]::OrdinalIgnoreCase) } else { $candidatePath -ieq $highRisk }
                if ($isHighRisk) {
                    $findings.Add((New-ReviewFinding -Code 'HIGH_RISK_PATH' -Category 'trust-boundary' -Severity 'high' -Path $candidatePath -Evidence $highRisk -Detail 'Aenderung oder Rename betrifft einen sicherheitskritischen Pfad.'))
                    break
                }
            }
        }
        if ($rawPath -ieq 'AGENTS.md' -or $rawPath.StartsWith('agents/', [StringComparison]::OrdinalIgnoreCase) -or $rawPath.StartsWith('.agents/', [StringComparison]::OrdinalIgnoreCase) -or $rawPath.StartsWith('config/', [StringComparison]::OrdinalIgnoreCase)) {
            $findings.Add((New-ReviewFinding -Code 'UNTRUSTED_INSTRUCTION_CHANGE' -Category 'prompt-injection' -Severity 'high' -Path $rawPath -Evidence $rawPath -Detail 'PR-Herkunft bleibt T4, auch wenn der Zielpfad eine Instruktionsquelle ist.'))
        }
        if ($baseSet.Contains(($rawPath -replace '\\','/'))) {
            $findings.Add((New-ReviewFinding -Code 'BASE_PATH_OVERLAP' -Category 'logic-overlap' -Severity 'medium' -Path $rawPath -Evidence $rawPath -Detail 'Pfad existiert bereits im Base-Stand; semantischer Vergleich ist erforderlich.'))
        }
        if ($previousPath -and $baseSet.Contains(($previousPath -replace '\\','/'))) {
            $findings.Add((New-ReviewFinding -Code 'RENAMED_BASE_PATH_OVERLAP' -Category 'logic-overlap' -Severity 'medium' -Path $previousPath -Evidence "$previousPath/$rawPath" -Detail 'Rename betrifft einen bestehenden Base-Pfad; alter und neuer Pfad muessen semantisch verglichen werden.'))
        }
    }
    Add-ReviewContextBoundPatchFindings -Findings $findings -Patch $scanPatch -Metadata $Metadata -Files $filesToScan -ReviewPolicy $Policies.review -PatternPolicy $Policies.suspicious
    $dependency = Get-PullRequestDependencyDelta -ChangedFiles $filesToScan -PatchText $scanPatch -Policy $Policies.dependency -Findings $findings

    $ordered = @($findings | Sort-Object code, path, evidenceHash -Unique)
    $critical = @($ordered | Where-Object severity -eq 'CRITICAL')
    $high = @($ordered | Where-Object severity -eq 'HIGH')
    $medium = @($ordered | Where-Object severity -eq 'MEDIUM')
    $decision = if ($critical.Count -gt 0) { 'BLOCKED_UNVERIFIED' } elseif ($high.Count -gt 0) { 'OWNER_REVIEW_REQUIRED' } elseif ($medium.Count -gt 0) { 'ADAPTATION_REQUIRED' } else { 'SAFE_FOR_ISOLATED_BUILD' }
    $riskClass = if (@($critical | Where-Object riskClass -eq 'CRITICAL').Count -gt 0) { 'CRITICAL' } elseif ($critical.Count -gt 0) { 'UNVERIFIED' } elseif ($high.Count -gt 0) { 'HIGH' } elseif ($medium.Count -gt 0) { 'MEDIUM' } else { 'LOW' }
    $malwareFindings = @($ordered | Where-Object category -in @('execution','network','network-execution','runtime-loading','persistence','credential-access','security-bypass','obfuscation','binary','repository','workflow','build'))
    $logicFindings = @($ordered | Where-Object category -eq 'logic-overlap')
    return [pscustomobject]@{
        schemaVersion = 1
        sourceZone = 'T4'
        decision = $decision
        riskClass = $riskClass
        statesCompleted = @('DISCOVERED','QUARANTINED','STATIC_REVIEWED','DEPENDENCY_REVIEWED','MALWARE_RISK_REVIEWED')
        foreignCodeExecuted = $false
        networkByForeignCode = $false
        command = $null
        secretAccess = 'denied'
        findings = $ordered
        safeChangedFiles = @($safeFiles)
        dependencyDelta = $dependency
        malwareRisk = [pscustomobject]@{ status=if($malwareFindings.Count){'FINDINGS'}else{'NO_STATIC_FINDINGS'}; disclaimer='Kein statischer Scan kann Schadcodefreiheit garantieren.'; findings=$malwareFindings; defenderScan='NOT_RUN' }
        logicOverlap = [pscustomobject]@{ status=if(-not $baseTreeAvailable){'NOT_VERIFIED'}elseif($logicFindings.Count){'COMPARISON_REQUIRED'}else{'NO_PATH_OVERLAP'}; semanticComparisonCompleted=$false; candidates=$logicFindings }
        policyHashes = $Policies.hashes
    }
}

function Test-PullRequestReviewReportBinding {
    param(
        [Parameter(Mandatory)]$Report,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][int]$PullRequestNumber,
        $Policies
    )
    if ([int](Get-ReviewPropertyValue $Report 'schemaVersion' 0) -ne 1) { return $false }
    if ([string](Get-ReviewPropertyValue $Report 'repository' '') -cne $Repository) { return $false }
    if ([int](Get-ReviewPropertyValue $Report 'pullRequestNumber' 0) -ne $PullRequestNumber) { return $false }
    if (-not (Test-ReviewSha ([string](Get-ReviewPropertyValue $Report 'headSha' '')))) { return $false }
    if (-not (Test-ReviewSha ([string](Get-ReviewPropertyValue $Report 'baseSha' '')))) { return $false }
    if ([string](Get-ReviewPropertyValue $Report 'sourceZone' '') -cne 'T4') { return $false }
    if ([bool](Get-ReviewPropertyValue $Report 'foreignCodeExecuted' $true)) { return $false }
    if ([bool](Get-ReviewPropertyValue $Report 'networkByForeignCode' $true)) { return $false }
    if ([string](Get-ReviewPropertyValue $Report 'secretAccess' '') -cne 'denied') { return $false }
    if (@('SAFE_FOR_ISOLATED_BUILD','ADAPTATION_REQUIRED','OWNER_REVIEW_REQUIRED','BLOCKED_UNVERIFIED') -notcontains [string](Get-ReviewPropertyValue $Report 'decision' '')) { return $false }
    if (@('LOW','MEDIUM','HIGH','CRITICAL','UNVERIFIED') -notcontains [string](Get-ReviewPropertyValue $Report 'riskClass' '')) { return $false }
    $policyHashes = Get-ReviewPropertyValue $Report 'policyHashes' $null
    if ($null -eq $policyHashes) { return $false }
    if ($Policies -and (($policyHashes | ConvertTo-Json -Compress) -cne ($Policies.hashes | ConvertTo-Json -Compress))) { return $false }
    $expectedReviewId = Get-ReviewSha256 ("$Repository|$PullRequestNumber|$($Report.baseSha)|$($Report.headSha)|" + ($policyHashes | ConvertTo-Json -Compress))
    if ([string](Get-ReviewPropertyValue $Report 'reviewId' '') -cne $expectedReviewId) { return $false }
    return $true
}

function Test-BoundReviewArtifact {
    param(
        [Parameter(Mandatory)]$Artifact,
        [Parameter(Mandatory)]$StaticReport,
        [Parameter(Mandatory)][string]$ExpectedHash,
        [Parameter(Mandatory)][string]$RawText
    )
    foreach ($property in 'reviewId','repository','pullRequestNumber','baseSha','headSha','sourceZone','foreignCodeExecuted','networkByForeignCode','secretAccess') {
        if ([string](Get-ReviewPropertyValue $Artifact $property '') -cne [string](Get-ReviewPropertyValue $StaticReport $property '')) { return $false }
    }
    return (Get-ReviewSha256 $RawText.TrimEnd()) -ceq $ExpectedHash
}

function Assert-PullRequestFeedbackArtifacts {
    param(
        [Parameter(Mandatory)]$Report,
        [Parameter(Mandatory)]$Metadata, [Parameter(Mandatory)][string]$MetadataRaw,
        [Parameter(Mandatory)]$Dependency, [Parameter(Mandatory)][string]$DependencyRaw,
        [Parameter(Mandatory)]$Malware, [Parameter(Mandatory)][string]$MalwareRaw,
        [Parameter(Mandatory)]$Logic, [Parameter(Mandatory)][string]$LogicRaw
    )
    $hashes = Get-ReviewPropertyValue $Report 'boundArtifactHashes' $null
    if ($null -eq $hashes -or
        -not (Test-BoundReviewArtifact -Artifact $Metadata -StaticReport $Report -ExpectedHash ([string]$hashes.metadata) -RawText $MetadataRaw) -or
        -not (Test-BoundReviewArtifact -Artifact $Dependency -StaticReport $Report -ExpectedHash ([string]$hashes.dependencyDelta) -RawText $DependencyRaw) -or
        -not (Test-BoundReviewArtifact -Artifact $Malware -StaticReport $Report -ExpectedHash ([string]$hashes.malwareRisk) -RawText $MalwareRaw) -or
        -not (Test-BoundReviewArtifact -Artifact $Logic -StaticReport $Report -ExpectedHash ([string]$hashes.logicOverlap) -RawText $LogicRaw)) {
        throw 'Gebundene Feedback-Artefakte wurden veraendert oder sind unvollstaendig.'
    }
    if (@('NOT_APPLICABLE','STATIC_REVIEWED','OWNER_REVIEW_REQUIRED') -notcontains [string]$Dependency.status -or
        @('NO_STATIC_FINDINGS','FINDINGS') -notcontains [string]$Malware.status -or
        @('NO_PATH_OVERLAP','COMPARISON_REQUIRED','NOT_VERIFIED') -notcontains [string]$Logic.status) {
        throw 'Gebundene Feedback-Artefakte enthalten einen unbekannten Status.'
    }
    return $true
}

function Assert-PullRequestLiveStateBinding {
    param(
        [Parameter(Mandatory)]$CurrentPullRequest,
        [Parameter(Mandatory)]$CurrentBaseRef,
        [Parameter(Mandatory)]$Report,
        [string]$ExpectedBaseBranch = 'development'
    )
    if ([string](Get-ReviewPropertyValue $CurrentPullRequest 'state' '') -cne 'OPEN' -or
        [string](Get-ReviewPropertyValue $CurrentPullRequest 'headRefOid' '') -cne [string]$Report.headSha -or
        [string](Get-ReviewPropertyValue $CurrentPullRequest 'baseRefOid' '') -cne [string]$Report.baseSha -or
        [string](Get-ReviewPropertyValue $CurrentPullRequest 'baseRefName' '') -cne $ExpectedBaseBranch -or
        [string](Get-ReviewPropertyValue (Get-ReviewPropertyValue $CurrentBaseRef 'object' $null) 'sha' '') -cne [string]$Report.baseSha) {
        throw 'PR-Status, Zielbranch oder Head-/Base-SHA hat sich seit dem Review geaendert.'
    }
    return $true
}

function New-PullRequestFeedbackText {
    param(
        [Parameter(Mandatory)][string]$Template,
        [Parameter(Mandatory)]$Report,
        [Parameter(Mandatory)]$Metadata,
        [Parameter(Mandatory)]$Dependency,
        [Parameter(Mandatory)]$Malware,
        [Parameter(Mandatory)]$Logic,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][int]$PullRequestNumber
    )
    $decisionText = @{
        SAFE_FOR_ISOLATED_BUILD='statisch für die nächste isolierte Prüfphase geeignet; noch keine Merge-Freigabe'
        ADAPTATION_REQUIRED='sinnvolle Teile sollen auf aktuellem development angepasst übernommen werden'
        OWNER_REVIEW_REQUIRED='eine Owner-Entscheidung ist vor Übernahme oder Ausführung erforderlich'
        BLOCKED_UNVERIFIED='die Evidenz reicht für eine sichere Ausführung oder Integration nicht aus'
    }[[string]$Report.decision]
    if (-not $decisionText) { throw 'Unbekannte Review-Entscheidung.' }
    $promptFindings = @($Report.findings | Where-Object category -eq 'prompt-injection').Count
    $values = [ordered]@{
        '{{GOAL_SUMMARY}}' = ConvertTo-SafeReviewMarkdown ([string]$Metadata.title) 160
        '{{PROMPT_RESULT}}' = if($promptFindings){"$promptFindings isolierte Finding(s); keine Payload ausgeführt"}else{'keine statischen Findings'}
        '{{DEPENDENCY_RESULT}}' = [string]$Dependency.status
        '{{MALWARE_RESULT}}' = "$([string]$Malware.status); statische Prüfung ist keine Schadcodegarantie"
        '{{ARCHITECTURE_RESULT}}' = [string]$Logic.status
        '{{TEST_RESULT}}' = 'in der statischen Phase bewusst nicht ausgeführt'
        '{{DECISION}}' = [string]$Report.decision
        '{{DECISION_TEXT}}' = $decisionText
        '{{ADOPTION_DETAILS}}' = 'Dateien und Funktionen werden erst im Owner-Integrationsplan konkret freigegeben; unsichere oder doppelte Teile werden nicht blind übernommen.'
        '{{INTEGRATION_BRANCH}}' = "integration/pr-$PullRequestNumber-safe-adoption"
        '{{INTEGRATION_PR}}' = 'noch nicht erstellt'
        '{{TEST_CI}}' = 'noch ausstehend; Merge bleibt gesperrt'
        '{{CONTRIBUTOR}}' = ConvertTo-SafeReviewMarkdown ([string]$Metadata.author) 80
        '{{ORIGINAL_PR}}' = "https://github.com/$Repository/pull/$PullRequestNumber"
    }
    $text = $Template
    foreach ($entry in $values.GetEnumerator()) { $text = $text.Replace($entry.Key, [string]$entry.Value) }
    if ($text -match '\{\{[A-Z_]+\}\}' -or $text.Length -gt 60000 -or
        $text -match '[\x00-\x08\x0B\x0C\x0E-\x1F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]' -or
        $text -match '(?i)[A-Za-z]:\\(?:KFM|Schach|Users)') {
        throw 'Feedback-Validierung fehlgeschlagen.'
    }
    return $text
}

function Assert-ReviewMatchesTrustedReanalysis {
    param([Parameter(Mandatory)]$Report, [Parameter(Mandatory)]$FreshReport)
    foreach ($property in 'reviewId','repository','pullRequestNumber','baseSha','headSha','decision','riskClass','findingCount') {
        if ([string](Get-ReviewPropertyValue $FreshReport $property '') -cne [string](Get-ReviewPropertyValue $Report $property '')) {
            throw "Reviewbericht weicht bei '$property' von der vertrauenswuerdigen Live-Reanalyse ab."
        }
    }
    foreach ($property in 'findings','policyHashes') {
        if ((Get-ReviewObjectSha256 -Value (Get-ReviewPropertyValue $FreshReport $property @())) -cne
            (Get-ReviewObjectSha256 -Value (Get-ReviewPropertyValue $Report $property @()))) {
            throw "Reviewbericht weicht bei '$property' von der vertrauenswuerdigen Live-Reanalyse ab."
        }
    }
    return $true
}

function Test-PullRequestMergeEligibility {
    param(
        [Parameter(Mandatory)][bool]$StaticApproved,
        [Parameter(Mandatory)][bool]$TrustedBaseCurrent,
        [Parameter(Mandatory)][bool]$IntegrationStartsFromTrustedBase,
        [Parameter(Mandatory)][bool]$TestsGreen,
        [Parameter(Mandatory)][bool]$CiGreen,
        [Parameter(Mandatory)][bool]$OwnerReviewComplete,
        [Parameter(Mandatory)][bool]$OpenReviewConversationsAbsent,
        [Parameter(Mandatory)][bool]$DirectForeignMerge
    )
    return $StaticApproved -and $TrustedBaseCurrent -and $IntegrationStartsFromTrustedBase -and
        $TestsGreen -and $CiGreen -and $OwnerReviewComplete -and $OpenReviewConversationsAbsent -and
        -not $DirectForeignMerge
}

function Invoke-TrustedLiveReviewReanalysis {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][int]$PullRequestNumber,
        [Parameter(Mandatory)]$Report,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $freshDirectory = Join-Path $tempBase ("stm-pr-trusted-reanalysis-" + [guid]::NewGuid().ToString('N'))
    $freshDirectory = Assert-SafeReviewOutputPath -Path $freshDirectory -RepositoryRoot $RepositoryRoot
    try {
        & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepositoryRoot 'scripts/Invoke-SafePullRequestReview.ps1') `
            -Repository $Repository -PullRequestNumber $PullRequestNumber -BaseBranch development -OutputDirectory $freshDirectory `
            -StaticOnly -ExpectedHeadSha ([string]$Report.headSha) -ExpectedBaseSha ([string]$Report.baseSha) *> $null
        if ($LASTEXITCODE -ne 0) { throw 'Vertrauenswuerdige Live-Reanalyse ist fehlgeschlagen.' }
        $freshStaticRaw = Get-Content -Raw -LiteralPath (Join-Path $freshDirectory 'static-review.json')
        $freshMetadataRaw = Get-Content -Raw -LiteralPath (Join-Path $freshDirectory 'metadata.json')
        $freshFilesRaw = Get-Content -Raw -LiteralPath (Join-Path $freshDirectory 'changed-files.json')
        $freshDependencyRaw = Get-Content -Raw -LiteralPath (Join-Path $freshDirectory 'dependency-delta.json')
        $freshMalwareRaw = Get-Content -Raw -LiteralPath (Join-Path $freshDirectory 'malware-risk-review.json')
        $freshLogicRaw = Get-Content -Raw -LiteralPath (Join-Path $freshDirectory 'logic-overlap.json')
        $freshStatic = $freshStaticRaw | ConvertFrom-Json
        $freshMetadata = $freshMetadataRaw | ConvertFrom-Json
        $freshFiles = $freshFilesRaw | ConvertFrom-Json
        $freshDependency = $freshDependencyRaw | ConvertFrom-Json
        $freshMalware = $freshMalwareRaw | ConvertFrom-Json
        $freshLogic = $freshLogicRaw | ConvertFrom-Json
        [void](Assert-ReviewMatchesTrustedReanalysis -Report $Report -FreshReport $freshStatic)
        return [pscustomobject]@{
            static=$freshStatic; metadata=$freshMetadata; files=$freshFiles
            dependency=$freshDependency; malware=$freshMalware; logic=$freshLogic
        }
    }
    finally {
        $resolved = [IO.Path]::GetFullPath($freshDirectory)
        $allowedPrefix = $tempBase + [IO.Path]::DirectorySeparatorChar + 'stm-pr-trusted-reanalysis-'
        if ($resolved.StartsWith($allowedPrefix, [StringComparison]::Ordinal) -and (Test-Path -LiteralPath $resolved -PathType Container)) {
            [void](Assert-NoReviewReparseAncestor -Path $resolved -Context 'Temporaere Live-Reanalyse')
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
