#requires -Version 7.0
# SECURITY-PATTERN-FILE: Defensive In-Memory-Pruefung eng attestierter PR-Binaerdaten; kein Payload wird ausgefuehrt oder entpackt.

Set-StrictMode -Version Latest

function Get-PullRequestArtifactSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes))).ToLowerInvariant()
}

function Test-PullRequestArtifactPath {
    param([AllowEmptyString()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.Length -gt 500 -or
        [IO.Path]::IsPathRooted($Path) -or $Path -match '[\\]' -or $Path -match '(^|/)\.\.(/|$)' -or
        $Path -match '[\x00-\x1F\x7F-\x9F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]' -or
        $Path -match '[:;&|`$(){}\[\]<>]' -or $Path -match '[^\x20-\x7E]') { return $false }
    return @($Path -split '/' | Where-Object { $_ -match '(?i)^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)|[. ]$' }).Count -eq 0
}

function Assert-PullRequestArtifactAttestations {
    param(
        [Parameter(Mandatory)]$ReviewPolicy,
        [Parameter(Mandatory)]$Attestations
    )
    $artifactPolicy = $ReviewPolicy.verifiedArtifactPolicy
    if ($null -eq $artifactPolicy -or [string]$artifactPolicy.attestationFile -cne 'config/pull-request-artifact-attestations.json') {
        throw 'Verified-Artifact-Policy fehlt oder verweist auf einen unerwarteten Pfad.'
    }
    foreach ($required in 'requireExactPullRequestNumber','requireExactHeadSha','requireExactGitBlobSha','requireExactSha256','requireExactSize','requireOwnerReview') {
        if ($artifactPolicy.$required -ne $true) { throw "Verified-Artifact-Policy muss $required erzwingen." }
    }
    if ([int]$artifactPolicy.maximumArtifactBytes -lt 1024 -or [int]$artifactPolicy.maximumArtifactBytes -gt 1048576) {
        throw 'Verified-Artifact-Maximalgroesse ist ungueltig.'
    }
    $allowedKinds = @($artifactPolicy.allowedKinds)
    foreach ($requiredKind in 'android-png','gradle-wrapper-jar','gradle-wrapper-properties','third-party-build-wrapper') {
        if ($allowedKinds -cnotcontains $requiredKind) { throw "Verified-Artifact-Kind fehlt: $requiredKind" }
    }
    if ([int]$Attestations.schemaVersion -ne 1 -or $null -eq $Attestations.approvals) {
        throw 'Artifact-Attestation-Schema ist ungueltig.'
    }
    $approvalKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($approval in @($Attestations.approvals)) {
        $approvalId = [string]$approval.approvalId
        $pullRequestNumber = [int]$approval.pullRequestNumber
        $headSha = [string]$approval.headSha
        if ($approvalId -cnotmatch '^[a-z0-9][a-z0-9._-]{2,79}$' -or $pullRequestNumber -lt 1 -or
            $headSha -cnotmatch '^[0-9a-f]{40}$' -or $approval.ownerReviewRequired -ne $true) {
            throw 'Artifact-Attestation besitzt keine gueltige ID, PR-/Head-Bindung oder Owner-Review-Pflicht.'
        }
        if (-not $approvalKeys.Add("$pullRequestNumber|$headSha")) { throw 'Artifact-Attestation enthaelt eine doppelte PR-/Head-Bindung.' }
        $artifacts = @($approval.artifacts)
        if ($artifacts.Count -lt 1 -or $artifacts.Count -gt 256) { throw 'Artifact-Attestation muss 1 bis 256 Artefakte enthalten.' }
        $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($artifact in $artifacts) {
            $path = [string]$artifact.path
            $kind = [string]$artifact.kind
            $mimeType = [string]$artifact.mimeType
            $gitBlobSha = [string]$artifact.gitBlobSha
            $sha256 = [string]$artifact.sha256
            $size = [int64]$artifact.size
            if (-not (Test-PullRequestArtifactPath $path) -or -not $paths.Add($path)) { throw 'Artifact-Attestation enthaelt einen unsicheren oder doppelten Pfad.' }
            if ($allowedKinds -cnotcontains $kind -or $gitBlobSha -cnotmatch '^[0-9a-f]{40}$' -or
                $sha256 -cnotmatch '^[0-9a-f]{64}$' -or $size -lt 1 -or $size -gt [int]$artifactPolicy.maximumArtifactBytes) {
                throw "Artifact-Attestation ist fuer $path nicht exakt genug gebunden."
            }
            $expectedMime = switch ($kind) {
                'android-png' { 'image/png' }
                'gradle-wrapper-jar' { 'application/java-archive' }
                'gradle-wrapper-properties' { 'text/x-java-properties' }
                'third-party-build-wrapper' { @('text/x-shellscript','text/x-msdos-batch') }
            }
            if ($expectedMime -is [array]) {
                if ($expectedMime -cnotcontains $mimeType) { throw "Unerwarteter MIME-Typ fuer $path." }
            }
            elseif ($mimeType -cne $expectedMime) { throw "Unerwarteter MIME-Typ fuer $path." }

            $provenance = $artifact.provenance
            $targetAndroidPrefix = 'src/SchachTurnierManager.WebApp/android/'
            if ($null -eq $provenance -or -not $path.StartsWith($targetAndroidPrefix, [StringComparison]::Ordinal)) {
                throw "Artifact-Provenienz ist fuer $path nicht auf das offizielle Capacitor-Template gebunden."
            }
            $sourceSize = [int64]$provenance.sourceSize
            $sourceSha256 = [string]$provenance.sourceSha256
            $derivation = [string]$provenance.derivation
            $expectedSourcePath = 'android-template/' + $path.Substring($targetAndroidPrefix.Length)
            if ([string]$provenance.sourceRepository -cne 'ionic-team/capacitor' -or
                [string]$provenance.sourceRef -cne '7.4.3' -or
                [string]$provenance.sourceCommitSha -cne 'e12818ac2254583fb11c3ea96853d01cb4978438' -or
                [string]$provenance.sourcePath -cne $expectedSourcePath -or
                [string]$provenance.sourceGitBlobSha -cnotmatch '^[0-9a-f]{40}$' -or
                $sourceSize -lt 1 -or $sourceSize -gt [int]$artifactPolicy.maximumArtifactBytes -or
                $sourceSha256 -cnotmatch '^[0-9a-f]{64}$' -or
                [string]$provenance.generator -cne 'Capacitor CLI' -or
                [string]$provenance.generatorVersion -cne [string]$provenance.sourceRef -or
                [string]::IsNullOrWhiteSpace($derivation) -or $derivation.Length -gt 300 -or
                $derivation -match '[\x00-\x1F\x7F-\x9F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]') {
                throw "Artifact-Provenienz ist fuer $path nicht auf das offizielle Capacitor-Template gebunden."
            }
            if ($kind -in @('android-png','gradle-wrapper-jar') -or $path -ceq 'src/SchachTurnierManager.WebApp/android/gradlew') {
                if ([string]$provenance.sourceGitBlobSha -cne $gitBlobSha -or $sourceSize -ne $size -or
                    $sourceSha256 -cne $sha256 -or $derivation -cne 'Byte-identical file generated by the Capacitor CLI 7.4.3 Android template.') {
                    throw "Als byte-identisch attestierte Provenienz stimmt fuer $path nicht exakt ueberein."
                }
            }

            $validation = $artifact.validation
            if ($null -eq $validation) { throw "Artifact-Validierung fehlt fuer $path." }
            switch ($kind) {
                'android-png' {
                    if ($path -cnotmatch '^src/SchachTurnierManager\.WebApp/android/app/src/main/res/(?:drawable(?:-land|-port)?-(?:mdpi|hdpi|xhdpi|xxhdpi|xxxhdpi)|drawable|mipmap-(?:mdpi|hdpi|xhdpi|xxhdpi|xxxhdpi))/(?:splash|ic_launcher|ic_launcher_foreground|ic_launcher_round)\.png$' -or
                        [int]$validation.width -lt 1 -or [int]$validation.width -gt 4096 -or
                        [int]$validation.height -lt 1 -or [int]$validation.height -gt 4096) {
                        throw "PNG-Attestation ist fuer $path ausserhalb des engen Android-Resource-Scope."
                    }
                    $chunkTypes = @($validation.chunkTypes)
                    if ($chunkTypes.Count -lt 3 -or $chunkTypes[0] -cne 'IHDR' -or $chunkTypes[-1] -cne 'IEND' -or
                        @($chunkTypes | Where-Object { $_ -cnotmatch '^[A-Za-z]{4}$' }).Count -gt 0) {
                        throw "PNG-Chunk-Attestation ist fuer $path ungueltig."
                    }
                    foreach ($metadata in @($validation.textMetadata)) {
                        if ([string]$metadata.keyword -cnotmatch '^[A-Za-z0-9 ._-]{1,79}$' -or
                            [int]$metadata.valueLength -lt 0 -or [string]$metadata.valueSha256 -cnotmatch '^[0-9a-f]{64}$') {
                            throw "PNG-Metadaten-Attestation ist fuer $path ungueltig."
                        }
                    }
                }
                'gradle-wrapper-jar' {
                    if ($path -cne 'src/SchachTurnierManager.WebApp/android/gradle/wrapper/gradle-wrapper.jar' -or
                        [string]$validation.gradleVersion -cne '8.11.1' -or
                        $sha256 -cne '2db75c40782f5e8ba1fc278a5574bab070adccb2d21ca5a6e5ed840888448046' -or
                        [string]$validation.officialWrapperSha256 -cne '2db75c40782f5e8ba1fc278a5574bab070adccb2d21ca5a6e5ed840888448046' -or
                        [string]$validation.distributionSha256Sum -cne '89d4e70e4e84e2d2dfbb63e4daa53e21b25017cc70c37e4eea31ee51fb15098a') {
                        throw 'Gradle-Wrapper-JAR-Attestation ist ungueltig.'
                    }
                }
                'gradle-wrapper-properties' {
                    if ($path -cne 'src/SchachTurnierManager.WebApp/android/gradle/wrapper/gradle-wrapper.properties' -or
                        [string]$validation.distributionUrl -cne 'https\://services.gradle.org/distributions/gradle-8.11.1-all.zip' -or
                        [string]$validation.distributionSha256Sum -cne '89d4e70e4e84e2d2dfbb63e4daa53e21b25017cc70c37e4eea31ee51fb15098a' -or
                        $validation.validateDistributionUrl -ne $true -or
                        $derivation -cne 'Capacitor CLI 7.4.3 template with the official Gradle 8.11.1 all-distribution SHA-256 added; validateDistributionUrl=true was already present.') {
                        throw 'Gradle-Wrapper-Properties-Attestation ist ungueltig.'
                    }
                }
                'third-party-build-wrapper' {
                    if ($path -cnotin @('src/SchachTurnierManager.WebApp/android/gradlew','src/SchachTurnierManager.WebApp/android/gradlew.bat') -or
                        [string]$validation.role -cne 'third-party-build-wrapper' -or
                        [string]$validation.gradleVersion -cne '8.11.1' -or
                        [string]$validation.lineEndings -cne 'lf' -or
                        ($path -ceq 'src/SchachTurnierManager.WebApp/android/gradlew.bat' -and
                            $derivation -cne 'Capacitor CLI 7.4.3 template content normalized by Git from CRLF to LF; no semantic content change.')) {
                        throw "Build-Wrapper-Attestation ist fuer $path ungueltig."
                    }
                }
            }
        }
    }
    return $true
}

function Read-PullRequestArtifactBeUInt32 {
    param([Parameter(Mandatory)][byte[]]$Bytes, [Parameter(Mandatory)][int]$Offset)
    return [uint64]((([uint64]$Bytes[$Offset]) -shl 24) -bor (([uint64]$Bytes[$Offset + 1]) -shl 16) -bor
        (([uint64]$Bytes[$Offset + 2]) -shl 8) -bor ([uint64]$Bytes[$Offset + 3]))
}

function Get-PullRequestArtifactCrc32 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    [uint64]$crc = 0xFFFFFFFFL
    foreach ($value in $Bytes) {
        $crc = $crc -bxor [uint64]$value
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 1L) -ne 0) { $crc = (($crc -shr 1) -bxor 0xEDB88320L) -band 0xFFFFFFFFL }
            else { $crc = ($crc -shr 1) -band 0xFFFFFFFFL }
        }
    }
    return [uint32](($crc -bxor 0xFFFFFFFFL) -band 0xFFFFFFFFL)
}

function Test-PullRequestPngArtifact {
    param([Parameter(Mandatory)][byte[]]$Bytes, [Parameter(Mandatory)]$Validation)
    $errors = [Collections.Generic.List[string]]::new()
    $signature = [byte[]](137,80,78,71,13,10,26,10)
    if ($Bytes.Length -lt 33) { $errors.Add('PNG_TOO_SHORT'); return [pscustomobject]@{ valid=$false; errors=@($errors); facts=$null } }
    for ($i = 0; $i -lt 8; $i++) { if ($Bytes[$i] -ne $signature[$i]) { $errors.Add('PNG_SIGNATURE'); break } }
    if ($errors.Count -gt 0) { return [pscustomobject]@{ valid=$false; errors=@($errors); facts=$null } }
    $offset = 8
    $chunks = [Collections.Generic.List[string]]::new()
    $metadataFacts = [Collections.Generic.List[object]]::new()
    $width = 0
    $height = 0
    $sawIend = $false
    while ($offset -lt $Bytes.Length) {
        if ($offset + 12 -gt $Bytes.Length) { $errors.Add('PNG_TRUNCATED_HEADER'); break }
        $length64 = Read-PullRequestArtifactBeUInt32 -Bytes $Bytes -Offset $offset
        if ($length64 -gt [int]::MaxValue) { $errors.Add('PNG_CHUNK_TOO_LARGE'); break }
        $length = [int]$length64
        $chunkEnd64 = [int64]$offset + 12L + [int64]$length
        if ($chunkEnd64 -gt $Bytes.Length) { $errors.Add('PNG_TRUNCATED_CHUNK'); break }
        $typeBytes = [byte[]]$Bytes[($offset + 4)..($offset + 7)]
        $type = [Text.Encoding]::ASCII.GetString($typeBytes)
        if ($type -cnotmatch '^[A-Za-z]{4}$') { $errors.Add('PNG_CHUNK_TYPE'); break }
        $chunks.Add($type)
        $crcInput = [byte[]]::new(4 + $length)
        [Array]::Copy($typeBytes, 0, $crcInput, 0, 4)
        if ($length -gt 0) { [Array]::Copy($Bytes, $offset + 8, $crcInput, 4, $length) }
        $expectedCrc = [uint32](Read-PullRequestArtifactBeUInt32 -Bytes $Bytes -Offset ($offset + 8 + $length))
        if ((Get-PullRequestArtifactCrc32 -Bytes $crcInput) -ne $expectedCrc) { $errors.Add('PNG_CRC') }
        if ($type -ceq 'IHDR') {
            if ($chunks.Count -ne 1 -or $length -ne 13) { $errors.Add('PNG_IHDR') }
            else {
                $width = [int](Read-PullRequestArtifactBeUInt32 -Bytes $Bytes -Offset ($offset + 8))
                $height = [int](Read-PullRequestArtifactBeUInt32 -Bytes $Bytes -Offset ($offset + 12))
            }
        }
        elseif ($type -ceq 'tEXt') {
            $data = if ($length -gt 0) { [byte[]]$Bytes[($offset + 8)..($offset + 7 + $length)] } else { [byte[]]@() }
            $nul = [Array]::IndexOf($data, [byte]0)
            if ($nul -lt 1) { $errors.Add('PNG_TEXT_METADATA') }
            else {
                $keyword = [Text.Encoding]::Latin1.GetString($data, 0, $nul)
                $valueLength = $length - $nul - 1
                $valueBytes = [byte[]]::new($valueLength)
                if ($valueLength -gt 0) { [Array]::Copy($data, $nul + 1, $valueBytes, 0, $valueLength) }
                $metadataFacts.Add([pscustomobject]@{ keyword=$keyword; valueLength=$valueLength; valueSha256=(Get-PullRequestArtifactSha256 -Bytes $valueBytes) })
            }
        }
        elseif ($type -ceq 'IEND') {
            if ($length -ne 0) { $errors.Add('PNG_IEND_LENGTH') }
            $sawIend = $true
        }
        $offset = [int]$chunkEnd64
        if ($sawIend) { break }
    }
    if (-not $sawIend) { $errors.Add('PNG_IEND_MISSING') }
    if ($offset -ne $Bytes.Length) { $errors.Add('PNG_TRAILING_BYTES') }
    if ($width -ne [int]$Validation.width -or $height -ne [int]$Validation.height) { $errors.Add('PNG_DIMENSIONS') }
    $expectedChunks = @($Validation.chunkTypes)
    if (($chunks -join ',') -cne ($expectedChunks -join ',')) { $errors.Add('PNG_CHUNKS') }
    $expectedMetadata = @($Validation.textMetadata)
    if ($metadataFacts.Count -ne $expectedMetadata.Count) { $errors.Add('PNG_METADATA_COUNT') }
    else {
        for ($i = 0; $i -lt $metadataFacts.Count; $i++) {
            if ([string]$metadataFacts[$i].keyword -cne [string]$expectedMetadata[$i].keyword -or
                [int]$metadataFacts[$i].valueLength -ne [int]$expectedMetadata[$i].valueLength -or
                [string]$metadataFacts[$i].valueSha256 -cne [string]$expectedMetadata[$i].valueSha256) {
                $errors.Add('PNG_METADATA')
                break
            }
        }
    }
    return [pscustomobject]@{
        valid = $errors.Count -eq 0
        errors = @($errors)
        facts = [pscustomobject]@{ width=$width; height=$height; chunkTypes=@($chunks); textMetadata=@($metadataFacts); trailingBytes=($Bytes.Length - $offset) }
    }
}

function Test-PullRequestPropertiesArtifact {
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)]$Validation)
    $values = [ordered]@{}
    foreach ($line in @($Text -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#') -or $line.TrimStart().StartsWith('!')) { continue }
        if ($line -cnotmatch '^([^=]+)=(.*)$') { return [pscustomobject]@{ valid=$false; errors=@('PROPERTIES_SYNTAX'); facts=$null } }
        $key = $Matches[1].Trim()
        if ($values.Contains($key)) { return [pscustomobject]@{ valid=$false; errors=@('PROPERTIES_DUPLICATE_KEY'); facts=$null } }
        $values[$key] = $Matches[2].Trim()
    }
    $errors = [Collections.Generic.List[string]]::new()
    $distributionUrl = [string]$values['distributionUrl']
    $distributionSha256Sum = [string]$values['distributionSha256Sum']
    $validateDistributionUrl = [string]$values['validateDistributionUrl']
    if ($distributionUrl -cne [string]$Validation.distributionUrl) { $errors.Add('GRADLE_DISTRIBUTION_URL') }
    if ($distributionSha256Sum -cne [string]$Validation.distributionSha256Sum) { $errors.Add('GRADLE_DISTRIBUTION_SHA256') }
    if ($validateDistributionUrl -cne 'true') { $errors.Add('GRADLE_VALIDATE_URL') }
    return [pscustomobject]@{ valid=$errors.Count -eq 0; errors=@($errors); facts=[pscustomobject]@{ distributionUrl=$distributionUrl; distributionSha256Sum=$distributionSha256Sum; validateDistributionUrl=$validateDistributionUrl } }
}

function Test-PullRequestArtifactBytes {
    param([Parameter(Mandatory)][byte[]]$Bytes, [Parameter(Mandatory)]$Artifact)
    $errors = [Collections.Generic.List[string]]::new()
    if ($Bytes.Length -ne [int64]$Artifact.size) { $errors.Add('SIZE_MISMATCH') }
    $sha256 = Get-PullRequestArtifactSha256 -Bytes $Bytes
    if ($sha256 -cne [string]$Artifact.sha256) { $errors.Add('SHA256_MISMATCH') }
    if ($errors.Count -gt 0) { return [pscustomobject]@{ valid=$false; errors=@($errors); facts=[pscustomobject]@{ size=$Bytes.Length; sha256=$sha256 } } }
    switch ([string]$Artifact.kind) {
        'android-png' {
            $result = Test-PullRequestPngArtifact -Bytes $Bytes -Validation $Artifact.validation
            return [pscustomobject]@{ valid=$result.valid; errors=$result.errors; facts=[pscustomobject]@{ size=$Bytes.Length; sha256=$sha256; png=$result.facts } }
        }
        'gradle-wrapper-jar' {
            if ($Bytes.Length -lt 4 -or $Bytes[0] -ne 0x50 -or $Bytes[1] -ne 0x4B -or $Bytes[2] -ne 0x03 -or $Bytes[3] -ne 0x04) { $errors.Add('JAR_MAGIC') }
            return [pscustomobject]@{ valid=$errors.Count -eq 0; errors=@($errors); facts=[pscustomobject]@{ size=$Bytes.Length; sha256=$sha256; magic='504b0304' } }
        }
        'gradle-wrapper-properties' {
            try { $text = [Text.UTF8Encoding]::new($false, $true).GetString($Bytes) }
            catch { return [pscustomobject]@{ valid=$false; errors=@('UTF8_INVALID'); facts=[pscustomobject]@{ size=$Bytes.Length; sha256=$sha256 } } }
            if ($text -match '[\x00\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]') { return [pscustomobject]@{ valid=$false; errors=@('TEXT_CONTROL_CHARACTER'); facts=[pscustomobject]@{ size=$Bytes.Length; sha256=$sha256 } } }
            $result = Test-PullRequestPropertiesArtifact -Text $text -Validation $Artifact.validation
            return [pscustomobject]@{ valid=$result.valid; errors=$result.errors; facts=[pscustomobject]@{ size=$Bytes.Length; sha256=$sha256; properties=$result.facts } }
        }
        'third-party-build-wrapper' {
            try { $text = [Text.UTF8Encoding]::new($false, $true).GetString($Bytes) }
            catch { return [pscustomobject]@{ valid=$false; errors=@('UTF8_INVALID'); facts=[pscustomobject]@{ size=$Bytes.Length; sha256=$sha256 } } }
            if ($text -match '[\x00\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]') { $errors.Add('TEXT_CONTROL_CHARACTER') }
            $hasCrlf = $text.Contains("`r`n")
            $hasBareLf = [regex]::IsMatch($text, "(?<!`r)`n")
            $actualLineEndings = if ($hasCrlf -and -not $hasBareLf) { 'crlf' } elseif (-not $hasCrlf -and $hasBareLf) { 'lf' } else { 'mixed-or-none' }
            if ($actualLineEndings -cne [string]$Artifact.validation.lineEndings) { $errors.Add('LINE_ENDINGS') }
            $encodedSwitch = [regex]::Escape(('Encoded' + 'Command'))
            $wrapperExecutionPattern = "(?i)\b(?:curl|wget|Invoke-WebRequest|Start-BitsTransfer|certutil|bitsadmin|powershell|pwsh)\b|-(?:$encodedSwitch|enc)\b"
            if ($text -match $wrapperExecutionPattern) { $errors.Add('WRAPPER_DOWNLOAD_OR_SHELL') }
            return [pscustomobject]@{ valid=$errors.Count -eq 0; errors=@($errors); facts=[pscustomobject]@{ size=$Bytes.Length; sha256=$sha256; lineEndings=$actualLineEndings; role='third-party-build-wrapper' } }
        }
        default { return [pscustomobject]@{ valid=$false; errors=@('KIND_UNSUPPORTED'); facts=[pscustomobject]@{ size=$Bytes.Length; sha256=$sha256 } } }
    }
}

function Add-PullRequestArtifactVerifications {
    param(
        [Parameter(Mandatory)]$Metadata,
        [Parameter(Mandatory)][object[]]$Files,
        [Parameter(Mandatory)]$HeadTree,
        [Parameter(Mandatory)]$ReviewPolicy,
        [Parameter(Mandatory)]$Attestations,
        [Parameter(Mandatory)][scriptblock]$BlobProvider
    )
    $pullRequestNumber = [int]$Metadata.number
    $headSha = [string]$Metadata.headRefOid
    $approvalMatches = @($Attestations.approvals | Where-Object { [int]$_.pullRequestNumber -eq $pullRequestNumber -and [string]$_.headSha -ceq $headSha })
    if ($approvalMatches.Count -eq 0) {
        $Metadata | Add-Member -NotePropertyName artifactAttestationStatus -NotePropertyValue 'NO_MATCHING_APPROVAL' -Force
        $Metadata | Add-Member -NotePropertyName artifactAttestationErrors -NotePropertyValue @() -Force
        return $Files
    }
    if ($approvalMatches.Count -ne 1) { throw 'Mehrdeutige Artifact-Attestation trotz validierter Policy.' }
    $approval = $approvalMatches[0]
    $errors = [Collections.Generic.List[string]]::new()
    $filesByPath = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($file in $Files) { $filesByPath[[string]$file.path] = $file }
    $treeByPath = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($entry in @($HeadTree.tree)) { if ([string]$entry.type -eq 'blob') { $treeByPath[[string]$entry.path] = $entry } }
    foreach ($artifact in @($approval.artifacts)) {
        $path = [string]$artifact.path
        $file = $null
        $treeEntry = $null
        if (-not $filesByPath.TryGetValue($path, [ref]$file)) { $errors.Add("ATTESTED_PATH_NOT_CHANGED:$path"); continue }
        if (-not $treeByPath.TryGetValue($path, [ref]$treeEntry)) {
            $errors.Add("ATTESTED_BLOB_MISSING:$path")
            $file | Add-Member -NotePropertyName artifactVerification -NotePropertyValue ([pscustomobject]@{ status='FAILED'; approvalId=[string]$approval.approvalId; kind=[string]$artifact.kind; path=$path; errors=@('BLOB_MISSING') }) -Force
            continue
        }
        $verificationErrors = [Collections.Generic.List[string]]::new()
        if ([string]$treeEntry.sha -cne [string]$artifact.gitBlobSha) { $verificationErrors.Add('GIT_BLOB_SHA_MISMATCH') }
        if ([int64]$treeEntry.size -ne [int64]$artifact.size) { $verificationErrors.Add('TREE_SIZE_MISMATCH') }
        $result = $null
        if ($verificationErrors.Count -eq 0) {
            try {
                [byte[]]$bytes = @(& $BlobProvider ([string]$artifact.gitBlobSha) ([int64]$artifact.size))
                $result = Test-PullRequestArtifactBytes -Bytes $bytes -Artifact $artifact
                foreach ($code in @($result.errors)) { $verificationErrors.Add([string]$code) }
            }
            catch { $verificationErrors.Add('BLOB_READ_FAILED') }
        }
        $status = if ($verificationErrors.Count -eq 0 -and $null -ne $result -and $result.valid) { 'VERIFIED' } else { 'FAILED' }
        $file | Add-Member -NotePropertyName artifactVerification -NotePropertyValue ([pscustomobject]@{
            status=$status; approvalId=[string]$approval.approvalId; pullRequestNumber=$pullRequestNumber; headSha=$headSha;
            path=$path; kind=[string]$artifact.kind; mimeType=[string]$artifact.mimeType; gitBlobSha=[string]$artifact.gitBlobSha;
            size=[int64]$artifact.size; sha256=[string]$artifact.sha256; provenance=[pscustomobject]@{
                sourceRepository=[string]$artifact.provenance.sourceRepository; sourceRef=[string]$artifact.provenance.sourceRef;
                sourceCommitSha=[string]$artifact.provenance.sourceCommitSha; sourcePath=[string]$artifact.provenance.sourcePath;
                sourceGitBlobSha=[string]$artifact.provenance.sourceGitBlobSha; generator=[string]$artifact.provenance.generator;
                generatorVersion=[string]$artifact.provenance.generatorVersion
            }; errors=@($verificationErrors); facts=if($result){$result.facts}else{$null}
        }) -Force
        if ($status -ne 'VERIFIED') { $errors.Add("ARTIFACT_VERIFICATION_FAILED:$path") }
    }
    $attestationStatus = if ($errors.Count -eq 0) { 'VERIFIED' } else { 'FAILED' }
    $Metadata | Add-Member -NotePropertyName artifactAttestationStatus -NotePropertyValue $attestationStatus -Force
    $Metadata | Add-Member -NotePropertyName artifactAttestationApprovalId -NotePropertyValue ([string]$approval.approvalId) -Force
    $Metadata | Add-Member -NotePropertyName artifactAttestationErrors -NotePropertyValue @($errors) -Force
    return $Files
}
