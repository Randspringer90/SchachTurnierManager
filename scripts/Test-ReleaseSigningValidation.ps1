#requires -Version 7.0
[CmdletBinding()]
param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $Root 'scripts/lib/ReleaseTrustValidation.ps1')

# Synthetic contract tests only. No certificate store, signing, extraction or payload execution.
$checks = 0
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Assert-Fails([scriptblock]$Action, [string]$ExpectedMessage) {
    try { & $Action | Out-Null }
    catch {
        if (-not $_.Exception.Message.Contains($ExpectedMessage)) { throw }
        $script:checks++
        return
    }
    throw "Expected rejection did not occur: $ExpectedMessage"
}
$oidCollection = [Security.Cryptography.OidCollection]::new()
[void]$oidCollection.Add([Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.3'))
$eku = [Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($oidCollection, $false)
$expected = 'A' * 40
$script:syntheticSignature = [pscustomobject]@{
    Status = 'Valid'
    SignerCertificate = [pscustomobject]@{ Thumbprint = $expected; Extensions = @($eku) }
}
Assert-StmReleaseSignature -Signature $syntheticSignature -ExpectedSignerThumbprint $expected
Assert-True $true 'Expected synthetic signer should pass the pure contract.'
Assert-Fails { Assert-StmReleaseSignature -Signature $syntheticSignature -ExpectedSignerThumbprint ('B' * 40) } 'unexpected signer'
Assert-Fails { ConvertTo-StmSignerThumbprint '' } 'ExpectedSignerThumbprint'
Assert-Fails { ConvertTo-StmSignerThumbprint ('A' * 41) } 'ExpectedSignerThumbprint'
Assert-Fails { Assert-StmReleaseSignature -Signature ([pscustomobject]@{ Status = 'Valid'; SignerCertificate = $null }) -ExpectedSignerThumbprint $expected } 'no valid Authenticode signer'
Assert-Fails { Assert-StmReleaseSignature -Signature ([pscustomobject]@{ Status = 'NotSigned'; SignerCertificate = $syntheticSignature.SignerCertificate }) -ExpectedSignerThumbprint $expected } 'no valid Authenticode signer'
Assert-Fails { Assert-StmReleaseSignature -Signature ([pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Thumbprint = $expected; Extensions = @() } }) -ExpectedSignerThumbprint $expected } 'Code-Signing EKU'

$runRoot = Join-Path ([IO.Path]::GetTempPath()) ("stm-signing-validation-" + [Guid]::NewGuid().ToString('N'))
$runRootFull = [IO.Path]::GetFullPath($runRoot)
$links = [Collections.Generic.List[string]]::new()
$originalSignatureCheck = (Get-Item Function:\Get-StmCheckedAuthenticodeSignature).ScriptBlock
try {
    [void][IO.Directory]::CreateDirectory($runRootFull)
    $artifactRoot = Join-Path $runRootFull 'output'
    $stagingDirectory = Join-Path $artifactRoot 'desktop/app'
    [void][IO.Directory]::CreateDirectory($stagingDirectory)
    $staging = Join-Path $stagingDirectory 'SchachTurnierManager.WebApi.exe'
    $bytes = [Text.Encoding]::UTF8.GetBytes('synthetic reviewed staging bytes')
    [IO.File]::WriteAllBytes($staging, $bytes)
    $dllBytes = [Text.Encoding]::UTF8.GetBytes('synthetic reviewed managed library')
    $launcherBytes = [Text.Encoding]::UTF8.GetBytes('synthetic reviewed launcher text; never executed')
    [IO.File]::WriteAllBytes((Join-Path $stagingDirectory 'Application.dll'), $dllBytes)
    [IO.File]::WriteAllBytes((Join-Path ([IO.Path]::GetDirectoryName($stagingDirectory)) 'Start-SchachTurnierManager.cmd'), $launcherBytes)
    $archivePath = Join-Path $artifactRoot 'synthetic.zip'
    $script:signatureCalls = 0
    function Get-StmCheckedAuthenticodeSignature([string]$Path, [string]$ExpectedSignerThumbprint) {
        $script:signatureCalls++
        Assert-StmReleaseSignature -Signature $script:syntheticSignature -ExpectedSignerThumbprint $ExpectedSignerThumbprint
        return $script:syntheticSignature
    }
    function Write-SyntheticZip([object[]]$Entries) {
        $stream = [IO.File]::Open($archivePath, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($record in $Entries) {
                $entry = $zip.CreateEntry($record.Name, [IO.Compression.CompressionLevel]::Optimal)
                if ($record.PSObject.Properties.Name -contains 'Attributes') { $entry.ExternalAttributes = $record.Attributes }
                $payload = $entry.Open()
                try { $payload.Write($record.Bytes, 0, $record.Bytes.Length) }
                finally { $payload.Dispose() }
            }
        }
        finally { $zip.Dispose(); $stream.Dispose() }
    }
    function Check-Archive {
        Assert-StmReleaseArchivePayload -ArchivePath $archivePath -StagingExePath $staging -Boundary $artifactRoot -ExpectedSignerThumbprint $expected
    }
    $application = [pscustomobject]@{ Name = 'app/SchachTurnierManager.WebApi.exe'; Bytes = $bytes }
    $library = [pscustomobject]@{ Name = 'app/Application.dll'; Bytes = $dllBytes }
    $launcher = [pscustomobject]@{ Name = 'Start-SchachTurnierManager.cmd'; Bytes = $launcherBytes }
    $baseline = @($application, $library, $launcher)
    Write-SyntheticZip $baseline
    Check-Archive
    Assert-True ($signatureCalls -eq 1) 'The actual staging signer contract was not called.'
    Assert-Fails { Assert-StmReleaseArchivePayload -ArchivePath $archivePath -StagingExePath $staging -Boundary $artifactRoot -ExpectedSignerThumbprint ('B' * 40) } 'unexpected signer'

    Write-SyntheticZip @([pscustomobject]@{ Name = $application.Name; Bytes = [Text.Encoding]::UTF8.GetBytes('different application length') }, $library, $launcher)
    Assert-Fails { Check-Archive } 'differs'
    $changed = $bytes.Clone(); $changed[0] = $changed[0] -bxor 1
    Write-SyntheticZip @([pscustomobject]@{ Name = $application.Name; Bytes = $changed }, $library, $launcher)
    Assert-Fails { Check-Archive } 'differs from verified staging'
    $changedDll = $dllBytes.Clone(); $changedDll[0] = $changedDll[0] -bxor 1
    Write-SyntheticZip @($application, [pscustomobject]@{ Name = $library.Name; Bytes = $changedDll }, $launcher)
    Assert-Fails { Check-Archive } 'differs from verified staging'
    $changedLauncher = $launcherBytes.Clone(); $changedLauncher[0] = $changedLauncher[0] -bxor 1
    Write-SyntheticZip @($application, $library, [pscustomobject]@{ Name = $launcher.Name; Bytes = $changedLauncher })
    Assert-Fails { Check-Archive } 'differs from verified staging'
    Write-SyntheticZip @($application, $launcher)
    Assert-Fails { Check-Archive } 'missing a file'
    Write-SyntheticZip @($application, $library)
    Assert-Fails { Check-Archive } 'missing a file'
    Write-SyntheticZip ($baseline + @([pscustomobject]@{ Name = 'unreviewed.ps1'; Bytes = $bytes }))
    Assert-Fails { Check-Archive } 'extra file'
    Write-SyntheticZip ($baseline + @($application))
    Assert-Fails { Check-Archive } 'duplicate or case-alias'
    Write-SyntheticZip ($baseline + @([pscustomobject]@{ Name = 'APP/SCHACHTURNIERMANAGER.WEBAPI.EXE'; Bytes = $bytes }))
    Assert-Fails { Check-Archive } 'duplicate or case-alias'
    Write-SyntheticZip ($baseline + @([pscustomobject]@{ Name = '../escape.txt'; Bytes = $bytes }))
    Assert-Fails { Check-Archive } 'unsafe entry path'
    Write-SyntheticZip ($baseline + @([pscustomobject]@{ Name = 'app/linked.txt'; Bytes = $bytes; Attributes = (0xA000 -shl 16) }))
    Assert-Fails { Check-Archive } 'link or reparse'
    Write-SyntheticZip ($baseline + @([pscustomobject]@{ Name = 'app/'; Bytes = [byte[]]::new(0) }))
    Check-Archive
    Assert-True $true 'A canonical existing staging directory should pass.'
    Write-SyntheticZip ($baseline + @([pscustomobject]@{ Name = 'unreviewed/'; Bytes = [byte[]]::new(0) }))
    Assert-Fails { Check-Archive } 'directory is absent'
    Write-SyntheticZip $baseline
    Assert-Fails { Assert-StmReleaseArchivePayload -ArchivePath $archivePath -StagingExePath $staging -Boundary $artifactRoot -ExpectedSignerThumbprint $expected -MaximumEntries 2 } 'too complex'
    Assert-Fails { Assert-StmReleaseArchivePayload -ArchivePath $archivePath -StagingExePath $staging -Boundary $artifactRoot -ExpectedSignerThumbprint $expected -MaximumArchiveBytes 1 } 'ZIP size limit'
    Assert-Fails { Assert-StmReleaseArchivePayload -ArchivePath $archivePath -StagingExePath $staging -Boundary $artifactRoot -ExpectedSignerThumbprint $expected -MaximumExeBytes 1 } 'Executable size limit'
    Assert-Fails { Assert-StmReleaseArchivePayload -ArchivePath $archivePath -StagingExePath $staging -Boundary $artifactRoot -ExpectedSignerThumbprint $expected -MaximumFileBytes 1 } 'package file size limit'
    [long]$allFileBytes = $bytes.Length + $dllBytes.Length + $launcherBytes.Length
    Assert-Fails { Assert-StmReleaseArchivePayload -ArchivePath $archivePath -StagingExePath $staging -Boundary $artifactRoot -ExpectedSignerThumbprint $expected -MaximumTotalStreamBytes (2 * $allFileBytes - 1) } 'total stream size limit'
    Assert-StmReleaseArchivePayload -ArchivePath $archivePath -StagingExePath $staging -Boundary $artifactRoot -ExpectedSignerThumbprint $expected -MaximumTotalStreamBytes (2 * $allFileBytes)
    Assert-True $true 'Exact total staging and ZIP stream byte budget should pass.'
    $memory = [IO.MemoryStream]::new([byte[]]::new(65537), $false)
    try { Assert-Fails { Get-StmBoundedStreamSha256 -Stream $memory -MaximumBytes 65536 } 'stream size limit' }
    finally { $memory.Dispose() }

    function Assert-DirectoryRejected([byte[]]$ZipBytes, [string]$Message) {
        [IO.File]::WriteAllBytes($archivePath, $ZipBytes)
        $stream = [IO.File]::OpenRead($archivePath)
        try { Assert-Fails { Get-StmBoundedZipDirectory -Stream $stream } $Message }
        finally { $stream.Dispose() }
    }
    # Metadata forgery fixtures never reach ZipArchive or execute their payload bytes.
    Write-SyntheticZip $baseline
    $validZip = [IO.File]::ReadAllBytes($archivePath)
    $end = $validZip.Length - 22
    $centralOffset = [BitConverter]::ToUInt32($validZip, $end + 16)
    $centralBytes = [BitConverter]::ToUInt32($validZip, $end + 12)
    $fewerDeclared = $validZip.Clone()
    [BitConverter]::GetBytes([uint16]2).CopyTo($fewerDeclared, $end + 8)
    [BitConverter]::GetBytes([uint16]2).CopyTo($fewerDeclared, $end + 10)
    Assert-DirectoryRejected $fewerDeclared 'extra records'
    $moreDeclared = $validZip.Clone()
    [BitConverter]::GetBytes([uint16]4).CopyTo($moreDeclared, $end + 8)
    [BitConverter]::GetBytes([uint16]4).CopyTo($moreDeclared, $end + 10)
    Assert-DirectoryRejected $moreDeclared 'record is truncated'
    $invalidHeader = $validZip.Clone(); $invalidHeader[$centralOffset] = 0
    Assert-DirectoryRejected $invalidHeader 'record is truncated or invalid'
    $oversizedName = $validZip.Clone()
    [BitConverter]::GetBytes([uint16]65535).CopyTo($oversizedName, $centralOffset + 28)
    Assert-DirectoryRejected $oversizedName 'variable fields are truncated or too complex'
    $oversizedExtra = $validZip.Clone()
    [BitConverter]::GetBytes([uint16]65535).CopyTo($oversizedExtra, $centralOffset + 30)
    Assert-DirectoryRejected $oversizedExtra 'variable fields are truncated or too complex'
    $oversizedComment = $validZip.Clone()
    [BitConverter]::GetBytes([uint16]65535).CopyTo($oversizedComment, $centralOffset + 32)
    Assert-DirectoryRejected $oversizedComment 'variable fields are truncated or too complex'
    $zip64Entry = $validZip.Clone()
    [BitConverter]::GetBytes([uint32]::MaxValue).CopyTo($zip64Entry, $centralOffset + 24)
    Assert-DirectoryRejected $zip64Entry 'ZIP64'
    $zip64End = $validZip.Clone()
    [BitConverter]::GetBytes([uint16]65535).CopyTo($zip64End, $end + 8)
    [BitConverter]::GetBytes([uint16]65535).CopyTo($zip64End, $end + 10)
    Assert-DirectoryRejected $zip64End 'ZIP64'
    $gap = [byte[]]::new($validZip.Length + 1)
    [Array]::Copy($validZip, 0, $gap, 0, $end)
    [Array]::Copy($validZip, $end, $gap, $end + 1, 22)
    Assert-DirectoryRejected $gap 'invalid directory metadata'
    $trailingCentral = [byte[]]::new($validZip.Length + 1)
    [Array]::Copy($validZip, 0, $trailingCentral, 0, $end)
    [Array]::Copy($validZip, $end, $trailingCentral, $end + 1, 22)
    [BitConverter]::GetBytes([uint32]($centralBytes + 1)).CopyTo($trailingCentral, $end + 1 + 12)
    Assert-DirectoryRejected $trailingCentral 'extra records or trailing metadata'
    # A real additional record must be rejected even if a forged EOCD underreports it.
    Write-SyntheticZip ($baseline + @([pscustomobject]@{ Name = 'extra.bin'; Bytes = $bytes }))
    $extraRecord = [IO.File]::ReadAllBytes($archivePath)
    [BitConverter]::GetBytes([uint16]3).CopyTo($extraRecord, $extraRecord.Length - 22 + 8)
    [BitConverter]::GetBytes([uint16]3).CopyTo($extraRecord, $extraRecord.Length - 22 + 10)
    Assert-DirectoryRejected $extraRecord 'extra records'
    Write-SyntheticZip $baseline

    function Assert-LocalHeadersRejected([byte[]]$ZipBytes, [string]$Message) {
        [IO.File]::WriteAllBytes($archivePath, $ZipBytes)
        $stream = [IO.File]::OpenRead($archivePath)
        try {
            Assert-Fails {
                $metadata = Get-StmBoundedZipDirectory -Stream $stream
                Assert-StmBoundedZipLocalHeaders -Stream $stream -Metadata $metadata
            } $Message
        }
        finally { $stream.Dispose() }
    }
    function Add-SyntheticZipBytes([byte[]]$ZipBytes, [int]$Position, [byte[]]$InsertedBytes) {
        $oldEnd = $ZipBytes.Length - 22
        $oldCentral = [BitConverter]::ToUInt32($ZipBytes, $oldEnd + 16)
        if ($Position -lt 0 -or $Position -gt $oldCentral) { throw 'Invalid synthetic insertion position.' }
        $result = [byte[]]::new($ZipBytes.Length + $InsertedBytes.Length)
        [Array]::Copy($ZipBytes, 0, $result, 0, $Position)
        [Array]::Copy($InsertedBytes, 0, $result, $Position, $InsertedBytes.Length)
        [Array]::Copy($ZipBytes, $Position, $result, $Position + $InsertedBytes.Length, $ZipBytes.Length - $Position)
        $newEnd = $result.Length - 22
        $newCentral = $oldCentral + $InsertedBytes.Length
        [BitConverter]::GetBytes([uint32]$newCentral).CopyTo($result, $newEnd + 16)
        $recordOffset = $newCentral
        $count = [BitConverter]::ToUInt16($result, $newEnd + 10)
        for ($i = 0; $i -lt $count; $i++) {
            $localOffset = [BitConverter]::ToUInt32($result, $recordOffset + 42)
            if ($localOffset -ge $Position) {
                [BitConverter]::GetBytes([uint32]($localOffset + $InsertedBytes.Length)).CopyTo($result, $recordOffset + 42)
            }
            $recordOffset += 46 + [BitConverter]::ToUInt16($result, $recordOffset + 28) +
                [BitConverter]::ToUInt16($result, $recordOffset + 30) + [BitConverter]::ToUInt16($result, $recordOffset + 32)
        }
        return ,$result
    }
    function New-SyntheticDescriptorZip([byte[]]$ZipBytes, [switch]$Unsigned) {
        $oldEnd = $ZipBytes.Length - 22
        $central = [BitConverter]::ToUInt32($ZipBytes, $oldEnd + 16)
        $localOffset = [BitConverter]::ToUInt32($ZipBytes, $central + 42)
        $flags = [BitConverter]::ToUInt16($ZipBytes, $localOffset + 6)
        if (($flags -band 8) -ne 0) { throw 'Synthetic baseline unexpectedly contains a data descriptor.' }
        $crc = [BitConverter]::ToUInt32($ZipBytes, $central + 16)
        $compressed = [BitConverter]::ToUInt32($ZipBytes, $central + 20)
        $length = [BitConverter]::ToUInt32($ZipBytes, $central + 24)
        $dataEnd = $localOffset + 30 + [BitConverter]::ToUInt16($ZipBytes, $localOffset + 26) +
            [BitConverter]::ToUInt16($ZipBytes, $localOffset + 28) + $compressed
        $descriptorLength = if ($Unsigned) { 12 } else { 16 }
        $descriptor = [byte[]]::new($descriptorLength)
        $fieldOffset = 0
        if (-not $Unsigned) {
            [BitConverter]::GetBytes([uint32]0x08074b50).CopyTo($descriptor, 0)
            $fieldOffset = 4
        }
        [BitConverter]::GetBytes($crc).CopyTo($descriptor, $fieldOffset)
        [BitConverter]::GetBytes($compressed).CopyTo($descriptor, $fieldOffset + 4)
        [BitConverter]::GetBytes($length).CopyTo($descriptor, $fieldOffset + 8)
        $result = Add-SyntheticZipBytes $ZipBytes $dataEnd $descriptor
        [BitConverter]::GetBytes([uint16]($flags -bor 8)).CopyTo($result, $localOffset + 6)
        [BitConverter]::GetBytes([uint32]0).CopyTo($result, $localOffset + 14)
        [BitConverter]::GetBytes([uint32]0).CopyTo($result, $localOffset + 18)
        [BitConverter]::GetBytes([uint32]0).CopyTo($result, $localOffset + 22)
        $newCentral = [BitConverter]::ToUInt32($result, $result.Length - 22 + 16)
        [BitConverter]::GetBytes([uint16]($flags -bor 8)).CopyTo($result, $newCentral + 8)
        return ,$result
    }
    # The central directory is unchanged: local-only path/flags/method tampering must fail first.
    $validLocalZip = [IO.File]::ReadAllBytes($archivePath)
    $end = $validLocalZip.Length - 22
    $central = [BitConverter]::ToUInt32($validLocalZip, $end + 16)
    $localOffset = [BitConverter]::ToUInt32($validLocalZip, $central + 42)
    $changedLocalName = $validLocalZip.Clone()
    $changedLocalName[$localOffset + 30] = $changedLocalName[$localOffset + 30] -bxor 1
    Assert-LocalHeadersRejected $changedLocalName 'local entry name differs'
    $changedLocalFlags = $validLocalZip.Clone()
    [BitConverter]::GetBytes([uint16]([BitConverter]::ToUInt16($changedLocalFlags, $localOffset + 6) -bxor 1)).CopyTo($changedLocalFlags, $localOffset + 6)
    Assert-LocalHeadersRejected $changedLocalFlags 'flags or method differs'
    $changedLocalMethod = $validLocalZip.Clone()
    [BitConverter]::GetBytes([uint16]99).CopyTo($changedLocalMethod, $localOffset + 8)
    Assert-LocalHeadersRejected $changedLocalMethod 'flags or method differs'
    $changedLocalLength = $validLocalZip.Clone()
    [BitConverter]::GetBytes([uint32]::MaxValue).CopyTo($changedLocalLength, $localOffset + 22)
    Assert-LocalHeadersRejected $changedLocalLength 'CRC or sizes differ'
    $changedLocalExtraLength = $validLocalZip.Clone()
    [BitConverter]::GetBytes([uint16]65535).CopyTo($changedLocalExtraLength, $localOffset + 28)
    Assert-LocalHeadersRejected $changedLocalExtraLength 'bounded file area'
    $dataStart = $localOffset + 30 + [BitConverter]::ToUInt16($validLocalZip, $localOffset + 26) +
        [BitConverter]::ToUInt16($validLocalZip, $localOffset + 28)
    $alternatePathExtra = [byte[]]::new(9)
    [BitConverter]::GetBytes([uint16]0x7075).CopyTo($alternatePathExtra, 0)
    [BitConverter]::GetBytes([uint16]5).CopyTo($alternatePathExtra, 2)
    $alternatePathExtra[4] = 1
    $localAlternatePath = Add-SyntheticZipBytes $validLocalZip $dataStart $alternatePathExtra
    [BitConverter]::GetBytes([uint16]([BitConverter]::ToUInt16($validLocalZip, $localOffset + 28) + 9)).CopyTo($localAlternatePath, $localOffset + 28)
    Assert-LocalHeadersRejected $localAlternatePath 'alternate path extra field'
    $nextCentral = $central + 46 + [BitConverter]::ToUInt16($validLocalZip, $central + 28) +
        [BitConverter]::ToUInt16($validLocalZip, $central + 30) + [BitConverter]::ToUInt16($validLocalZip, $central + 32)
    $nextLocal = [BitConverter]::ToUInt32($validLocalZip, $nextCentral + 42)
    $overlappingZip = $validLocalZip.Clone()
    $overlapCompressed = [uint32]($nextLocal - $dataStart + 1)
    [BitConverter]::GetBytes($overlapCompressed).CopyTo($overlappingZip, $central + 20)
    [BitConverter]::GetBytes($overlapCompressed).CopyTo($overlappingZip, $localOffset + 18)
    Assert-LocalHeadersRejected $overlappingZip 'ranges overlap'
    $unlistedBytes = Add-SyntheticZipBytes $validLocalZip $central ([byte[]]::new(1))
    Assert-LocalHeadersRejected $unlistedBytes 'unlisted bytes'

    $signedDescriptorZip = New-SyntheticDescriptorZip $validLocalZip
    [IO.File]::WriteAllBytes($archivePath, $signedDescriptorZip)
    Check-Archive
    Assert-True $true 'A classic signed 16-byte data descriptor should pass.'
    $unsignedDescriptorZip = New-SyntheticDescriptorZip $validLocalZip -Unsigned
    [IO.File]::WriteAllBytes($archivePath, $unsignedDescriptorZip)
    Check-Archive
    Assert-True $true 'A classic unsigned 12-byte data descriptor should pass.'
    $descriptorStart = $dataStart + [BitConverter]::ToUInt32($validLocalZip, $central + 20)
    $changedDescriptor = $signedDescriptorZip.Clone()
    [BitConverter]::GetBytes([uint32]::MaxValue).CopyTo($changedDescriptor, $descriptorStart + 8)
    Assert-LocalHeadersRejected $changedDescriptor 'data descriptor CRC or sizes differ'
    $zip64Descriptor = Add-SyntheticZipBytes $signedDescriptorZip ($descriptorStart + 12) ([byte[]]::new(4))
    $zip64Descriptor = Add-SyntheticZipBytes $zip64Descriptor ($descriptorStart + 20) ([byte[]]::new(4))
    Assert-LocalHeadersRejected $zip64Descriptor 'data descriptor CRC or sizes differ'
    Write-SyntheticZip $baseline

    $otherDirectory = Join-Path $runRootFull 'other'
    [void][IO.Directory]::CreateDirectory($otherDirectory)
    [IO.File]::WriteAllBytes((Join-Path $otherDirectory 'payload.exe'), $bytes)
    $link = Join-Path $artifactRoot 'linked'
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $link -Target $otherDirectory | Out-Null
    $links.Add($link)
    Assert-Fails { Resolve-StmReleasePath -Path (Join-Path $link 'payload.exe') -Boundary $artifactRoot -Kind File } 'Reparse points'
    Assert-Fails { Resolve-StmReleasePath -Path (Join-Path $link 'missing/new.json') -Boundary $artifactRoot -AllowMissing } 'Reparse points'
    Assert-Fails { Resolve-StmReleasePath -Path $link -Kind Directory } 'Reparse points'
    Assert-Fails { Resolve-StmReleasePath -Path (Join-Path $otherDirectory 'payload.exe') -Boundary $artifactRoot -Kind File } 'approved boundary'
    $packageLink = Join-Path ([IO.Path]::GetDirectoryName($stagingDirectory)) 'linked'
    New-Item -ItemType $linkType -Path $packageLink -Target $otherDirectory | Out-Null
    $links.Add($packageLink)
    Assert-Fails { Check-Archive } 'Reparse points'

    foreach ($scriptName in @('Test-ReleaseUpdateManifest.ps1', 'Invoke-ReleaseTrustReadiness.ps1')) {
        $arguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', (Join-Path $Root "scripts/$scriptName"), '-ArtifactRoot', $artifactRoot, '-RequireSignedArtifacts')
        if ($scriptName -eq 'Test-ReleaseUpdateManifest.ps1') { $arguments += @('-ManifestPath', (Join-Path $artifactRoot 'does-not-exist.json')) }
        else { $arguments += @('-Root', $runRootFull) }
        $output = (& pwsh @arguments 2>&1 | Out-String)
        $exit = $LASTEXITCODE
        Assert-True ($exit -ne 0 -and $output.Contains('RequireSignedArtifacts verlangt -ExpectedSignerThumbprint.')) 'Missing expected signer was not rejected before reading inputs.'
    }
    Write-Output "RELEASE_SIGNING_VALIDATION=PASS assertions=$checks AUTHENTICODE_REAL=NOT_RUN"
}
finally {
    Set-Item Function:\Get-StmCheckedAuthenticodeSignature -Value $originalSignatureCheck
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $runRootFull.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($runRootFull) -notmatch '^stm-signing-validation-[a-f0-9]{32}$') {
        throw 'Synthetic cleanup path is not the exact owned temporary directory.'
    }
    foreach ($link in $links) {
        $fullLink = [IO.Path]::GetFullPath($link)
        if (-not $fullLink.StartsWith($runRootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Synthetic link leaves its temporary directory.' }
        [IO.Directory]::Delete($fullLink, $false)
    }
    if (Test-Path -LiteralPath $runRootFull) {
        $runItem = Get-Item -LiteralPath $runRootFull -Force
        if (($runItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Synthetic cleanup root became a reparse point.' }
        Remove-Item -LiteralPath $runRootFull -Recurse -Force
    }
}
