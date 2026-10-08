#requires -Version 7.0
# Read-only release trust checks. Never extract, launch or sign a payload.
Set-StrictMode -Version Latest

function Resolve-StmReleasePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Boundary,
        [ValidateSet('Any', 'File', 'Directory')][string]$Kind = 'Any',
        [switch]$AllowMissing
    )
    $full = [IO.Path]::GetFullPath($Path)
    $pathRoot = [IO.Path]::GetPathRoot($full)
    if ($IsWindows -and $pathRoot -notmatch '^[A-Za-z]:[\\/]+$') {
        throw 'Release trust checks require a local drive path.'
    }
    if ($Boundary) {
        $boundaryFull = [IO.Path]::GetFullPath($Boundary).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $prefix = $boundaryFull + [IO.Path]::DirectorySeparatorChar
        $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
        if (-not $full.Equals($boundaryFull, $comparison) -and -not $full.StartsWith($prefix, $comparison)) {
            throw 'Release path leaves its approved boundary.'
        }
    }
    $parts = $full.Substring($pathRoot.Length).Split([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar), [StringSplitOptions]::RemoveEmptyEntries)
    $cursor = $pathRoot
    $rootItem = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
    if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Reparse points are forbidden in release paths.'
    }
    $item = $rootItem
    for ($i = 0; $i -lt $parts.Length; $i++) {
        if ($parts[$i] -match '[:*?"<>|\x00-\x1f]' -or ($IsWindows -and $parts[$i] -match '[. ]$')) {
            throw 'Release path contains an unsafe component.'
        }
        $cursor = Join-Path $cursor $parts[$i]
        try { $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop }
        catch [Management.Automation.ItemNotFoundException] {
            if (-not $AllowMissing) { throw }
            $item = $null
        }
        if ($null -ne $item) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Reparse points are forbidden in release paths.'
            }
            if ($i -lt $parts.Length - 1 -and -not $item.PSIsContainer) {
                throw 'An intermediate release path is not a directory.'
            }
        }
    }
    if ($null -ne $item) {
        if ($Kind -eq 'File' -and $item.PSIsContainer) { throw 'Release path is not a file.' }
        if ($Kind -eq 'Directory' -and -not $item.PSIsContainer) { throw 'Release path is not a directory.' }
    }
    return $full
}

function ConvertTo-StmSignerThumbprint {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $normalized = ($Value -replace '\s+', '').ToUpperInvariant()
    if ($normalized -notmatch '^[A-F0-9]{40}$') {
        throw 'ExpectedSignerThumbprint must contain exactly 40 hexadecimal characters.'
    }
    return $normalized
}

function Assert-StmReleaseSignature {
    param(
        [Parameter(Mandatory)]$Signature,
        [Parameter(Mandatory)][string]$ExpectedSignerThumbprint
    )
    $expected = ConvertTo-StmSignerThumbprint -Value $ExpectedSignerThumbprint
    if ([string]$Signature.Status -cne 'Valid' -or $null -eq $Signature.SignerCertificate) {
        throw 'Release executable has no valid Authenticode signer.'
    }
    $actual = ConvertTo-StmSignerThumbprint -Value ([string]$Signature.SignerCertificate.Thumbprint)
    if ($actual -cne $expected) { throw 'Release executable has an unexpected signer.' }
    $ekuOids = @($Signature.SignerCertificate.Extensions |
        Where-Object { $_ -is [Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension] } |
        ForEach-Object { $_.EnhancedKeyUsages | ForEach-Object { $_.Value } })
    if ($ekuOids -notcontains '1.3.6.1.5.5.7.3.3') {
        throw 'Release signer has no Code-Signing EKU.'
    }
}

function Get-StmCheckedAuthenticodeSignature {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSignerThumbprint
    )
    $expected = ConvertTo-StmSignerThumbprint -Value $ExpectedSignerThumbprint
    $full = Resolve-StmReleasePath -Path $Path -Kind File
    if (-not $IsWindows -or -not (Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue)) {
        throw 'Authenticode verification is unavailable; signed release acceptance is blocked.'
    }
    $signature = Get-AuthenticodeSignature -FilePath $full
    Assert-StmReleaseSignature -Signature $signature -ExpectedSignerThumbprint $expected
    return $signature
}

function Get-StmBoundedStreamSha256 {
    param(
        [Parameter(Mandatory)][IO.Stream]$Stream,
        [Parameter(Mandatory)][long]$MaximumBytes,
        [long]$ExpectedBytes = -1
    )
    if ($MaximumBytes -lt 0 -or $ExpectedBytes -gt $MaximumBytes) { throw 'Package stream size limit exceeded.' }
    if ($ExpectedBytes -ge 0) { $MaximumBytes = $ExpectedBytes }
    $hash = [Security.Cryptography.SHA256]::Create()
    $buffer = [byte[]]::new(65536)
    [long]$count = 0
    try {
        while ($count -lt $MaximumBytes) {
            $request = [int][Math]::Min($buffer.Length, $MaximumBytes - $count)
            $read = $Stream.Read($buffer, 0, $request)
            if ($read -eq 0) { break }
            $count += $read
            [void]$hash.TransformBlock($buffer, 0, $read, $buffer, 0)
        }
        # One bounded end probe rejects streams that expand beyond the byte budget.
        if ($count -eq $MaximumBytes -and $Stream.ReadByte() -ne -1) { throw 'Package stream size limit exceeded.' }
        if ($ExpectedBytes -ge 0 -and $count -ne $ExpectedBytes) { throw 'Package file length does not match ZIP metadata.' }
        [void]$hash.TransformFinalBlock([byte[]]::new(0), 0, 0)
        return [pscustomobject]@{ Bytes = $count; Sha256 = [BitConverter]::ToString($hash.Hash).Replace('-', '') }
    }
    finally { [Array]::Clear($buffer, 0, $buffer.Length); $hash.Dispose() }
}

function Get-StmPackageEntryKey {
    param([Parameter(Mandatory)][string]$Name)
    if ($Name.Length -gt 4096 -or $Name.Contains('\') -or $Name.StartsWith('/')) {
        throw 'ZIP contains an unsafe entry path.'
    }
    $key = if ($Name.EndsWith('/')) { $Name.Substring(0, $Name.Length - 1) } else { $Name }
    $parts = @($key.Split('/'))
    if (-not $key -or $parts.Count -gt 64 -or $key -match '[:*?"<>|\x00-\x1f]' -or
        @($parts | Where-Object {
            -not $_ -or $_ -in @('.', '..') -or $_ -match '[. ]$' -or
            $_ -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$'
        }).Count -gt 0) {
        throw 'ZIP contains an unsafe entry path.'
    }
    return $key
}

function Assert-StmZipExtraFields {
    param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes)
    $stream = [IO.MemoryStream]::new($Bytes, $false)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        while ($stream.Position -lt $stream.Length) {
            if ($stream.Length - $stream.Position -lt 4) { throw 'ZIP extra field is truncated.' }
            $id = $reader.ReadUInt16()
            $length = $reader.ReadUInt16()
            if ($length -gt $stream.Length - $stream.Position) { throw 'ZIP extra field is truncated.' }
            if ($id -in @(0x0001, 0x000d, 0x7075, 0x756e)) {
                throw 'ZIP entry uses ZIP64, links or an alternate path extra field.'
            }
            [void]$stream.Seek($length, [IO.SeekOrigin]::Current)
        }
    }
    finally { $reader.Dispose(); $stream.Dispose() }
}

function Get-StmBoundedZipDirectory {
    param(
        [Parameter(Mandatory)][IO.FileStream]$Stream,
        [ValidateRange(1, 4096)][int]$MaximumEntries = 4096
    )
    # Parse the actual bounded central directory before ZipArchive creates any entry objects.
    $tail = [byte[]]::new([int][Math]::Min(65557, $Stream.Length))
    [void]$Stream.Seek(-$tail.Length, [IO.SeekOrigin]::End)
    $offset = 0
    while ($offset -lt $tail.Length) {
        $read = $Stream.Read($tail, $offset, $tail.Length - $offset)
        if ($read -eq 0) { throw 'ZIP metadata is truncated.' }
        $offset += $read
    }
    for ($i = $tail.Length - 22; $i -ge 0; $i--) {
        if ($tail[$i] -ne 0x50 -or $tail[$i + 1] -ne 0x4b -or $tail[$i + 2] -ne 0x05 -or $tail[$i + 3] -ne 0x06) { continue }
        $memory = [IO.MemoryStream]::new($tail, $false)
        $reader = [IO.BinaryReader]::new($memory)
        try {
            $memory.Position = $i + 4
            $disk = $reader.ReadUInt16()
            $centralDisk = $reader.ReadUInt16()
            $diskCount = $reader.ReadUInt16()
            $count = $reader.ReadUInt16()
            [long]$centralBytes = $reader.ReadUInt32()
            [long]$centralOffset = $reader.ReadUInt32()
            $commentBytes = $reader.ReadUInt16()
            if ($i + 22 + $commentBytes -ne $tail.Length) { continue }
            [long]$endOffset = $Stream.Length - $tail.Length + $i
            if ($disk -ne 0 -or $centralDisk -ne 0 -or $diskCount -ne $count -or
                $count -lt 1 -or $count -gt $MaximumEntries -or $count -eq 65535 -or
                $centralBytes -lt 46 -or $centralBytes -gt 8MB -or
                $centralOffset -eq [uint32]::MaxValue -or $centralBytes -eq [uint32]::MaxValue -or
                $centralOffset + $centralBytes -ne $endOffset) {
                throw 'ZIP is split, ZIP64, too complex or has invalid directory metadata.'
            }
        }
        finally { $reader.Dispose(); $memory.Dispose() }

        $central = [byte[]]::new([int]$centralBytes)
        $Stream.Position = $centralOffset
        $offset = 0
        while ($offset -lt $central.Length) {
            $read = $Stream.Read($central, $offset, $central.Length - $offset)
            if ($read -eq 0) { throw 'ZIP central directory is truncated.' }
            $offset += $read
        }
        $directoryStream = [IO.MemoryStream]::new($central, $false)
        $directoryReader = [IO.BinaryReader]::new($directoryStream)
        $records = [Collections.Generic.List[object]]::new()
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $utf8 = [Text.UTF8Encoding]::new($false, $true)
        try {
            for ($recordIndex = 0; $recordIndex -lt $count; $recordIndex++) {
                if ($directoryStream.Length - $directoryStream.Position -lt 46 -or $directoryReader.ReadUInt32() -ne 0x02014b50) {
                    throw 'ZIP central directory record is truncated or invalid.'
                }
                $madeBy = $directoryReader.ReadUInt16()
                $needed = $directoryReader.ReadUInt16()
                $flags = $directoryReader.ReadUInt16()
                $method = $directoryReader.ReadUInt16()
                [void]$directoryReader.ReadUInt16()
                [void]$directoryReader.ReadUInt16()
                $crc = $directoryReader.ReadUInt32()
                [long]$compressed = $directoryReader.ReadUInt32()
                [long]$length = $directoryReader.ReadUInt32()
                $nameBytes = $directoryReader.ReadUInt16()
                $extraBytes = $directoryReader.ReadUInt16()
                $entryCommentBytes = $directoryReader.ReadUInt16()
                $startDisk = $directoryReader.ReadUInt16()
                [void]$directoryReader.ReadUInt16()
                $attributes = $directoryReader.ReadUInt32()
                [long]$localOffset = $directoryReader.ReadUInt32()
                [long]$variableBytes = [long]$nameBytes + $extraBytes + $entryCommentBytes
                if ($nameBytes -lt 1 -or $nameBytes -gt 4096 -or $variableBytes -gt $directoryStream.Length - $directoryStream.Position) {
                    throw 'ZIP central directory variable fields are truncated or too complex.'
                }
                if ($needed -gt 20 -or ($flags -band 0xF7F1) -ne 0 -or $method -notin @(0, 8) -or
                    $startDisk -ne 0 -or $compressed -eq [uint32]::MaxValue -or $length -eq [uint32]::MaxValue -or
                    $localOffset -eq [uint32]::MaxValue -or $localOffset + 30 + $compressed -gt $centralOffset) {
                    throw 'ZIP entry uses split, ZIP64, encrypted or unsupported metadata.'
                }
                $nameBuffer = $directoryReader.ReadBytes($nameBytes)
                if (($flags -band 0x0800) -ne 0) { $name = $utf8.GetString($nameBuffer) }
                else {
                    if (@($nameBuffer | Where-Object { $_ -ge 128 }).Count -gt 0) { throw 'ZIP entry name has an unsupported encoding.' }
                    $name = [Text.Encoding]::ASCII.GetString($nameBuffer)
                }
                $key = Get-StmPackageEntryKey -Name $name
                if (-not $seen.Add($key)) { throw 'ZIP contains duplicate or case-alias entries.' }
                if ((($attributes -shr 16) -band 0xF000) -eq 0xA000 -or
                    ($attributes -band [uint32][IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw 'ZIP contains a link or reparse entry.'
                }
                $extraBuffer = $directoryReader.ReadBytes($extraBytes)
                Assert-StmZipExtraFields -Bytes $extraBuffer
                [void]$directoryStream.Seek($entryCommentBytes, [IO.SeekOrigin]::Current)
                $records.Add([pscustomobject]@{
                    Name = $name
                    Key = $key
                    Length = $length
                    CompressedLength = $compressed
                    Crc32 = $crc
                    Flags = $flags
                    Method = $method
                    Needed = $needed
                    LocalOffset = $localOffset
                    NameBytes = $nameBuffer
                    IsDirectory = $name.EndsWith('/')
                })
            }
            if ($directoryStream.Position -ne $directoryStream.Length) {
                throw 'ZIP central directory has extra records or trailing metadata.'
            }
            return [pscustomobject]@{ Entries = $records.ToArray(); Count = $records.Count; CentralOffset = $centralOffset }
        }
        finally { $directoryReader.Dispose(); $directoryStream.Dispose(); [Array]::Clear($central, 0, $central.Length) }
    }
    throw 'ZIP end-of-directory metadata is missing.'
}

function Assert-StmBoundedZipLocalHeaders {
    param(
        [Parameter(Mandatory)][IO.FileStream]$Stream,
        [Parameter(Mandatory)]$Metadata
    )
    $ranges = [Collections.Generic.List[object]]::new()
    [long]$headerBytes = 0
    $reader = [IO.BinaryReader]::new($Stream, [Text.Encoding]::UTF8, $true)
    try {
        foreach ($record in $Metadata.Entries) {
            if ($record.LocalOffset -lt 0 -or $record.LocalOffset + 30 -gt $Metadata.CentralOffset) {
                throw 'ZIP local header lies outside the bounded file area.'
            }
            $Stream.Position = $record.LocalOffset
            if ($reader.ReadUInt32() -ne 0x04034b50) { throw 'ZIP local header signature is invalid.' }
            $needed = $reader.ReadUInt16()
            $flags = $reader.ReadUInt16()
            $method = $reader.ReadUInt16()
            [void]$reader.ReadUInt16()
            [void]$reader.ReadUInt16()
            $crc = $reader.ReadUInt32()
            [long]$compressed = $reader.ReadUInt32()
            [long]$length = $reader.ReadUInt32()
            $nameBytes = $reader.ReadUInt16()
            $extraBytes = $reader.ReadUInt16()
            if ($needed -ne $record.Needed -or $flags -ne $record.Flags -or $method -ne $record.Method) {
                throw 'ZIP local header version, flags or method differs from the central directory.'
            }
            if ($nameBytes -ne $record.NameBytes.Length -or $nameBytes -lt 1 -or $nameBytes -gt 4096) {
                throw 'ZIP local entry name differs from the central directory.'
            }
            [long]$dataStart = $record.LocalOffset + 30 + $nameBytes + $extraBytes
            [long]$dataEnd = $dataStart + $record.CompressedLength
            $headerBytes += 30 + $nameBytes + $extraBytes
            if ($headerBytes -gt 8MB -or $dataStart -gt $Metadata.CentralOffset -or $dataEnd -gt $Metadata.CentralOffset) {
                throw 'ZIP local header or payload exceeds its bounded file area.'
            }
            $nameBuffer = $reader.ReadBytes($nameBytes)
            if ($nameBuffer.Length -ne $nameBytes) { throw 'ZIP local header name is truncated.' }
            for ($i = 0; $i -lt $nameBytes; $i++) {
                if ($nameBuffer[$i] -ne $record.NameBytes[$i]) { throw 'ZIP local entry name differs from the central directory.' }
            }
            $extraBuffer = $reader.ReadBytes($extraBytes)
            if ($extraBuffer.Length -ne $extraBytes) { throw 'ZIP local header extra field is truncated.' }
            Assert-StmZipExtraFields -Bytes $extraBuffer
            $usesDescriptor = ($flags -band 8) -ne 0
            if (-not $usesDescriptor) {
                if ($crc -ne $record.Crc32 -or $compressed -ne $record.CompressedLength -or $length -ne $record.Length) {
                    throw 'ZIP local header CRC or sizes differ from the central directory.'
                }
            }
            else {
                # Classic ZIP descriptors have exactly 12 bytes, or 16 including their signature.
                # Header fields may be zero until the descriptor or already equal the final values.
                if (($crc -ne 0 -and $crc -ne $record.Crc32) -or
                    ($compressed -ne 0 -and $compressed -ne $record.CompressedLength) -or
                    ($length -ne 0 -and $length -ne $record.Length)) {
                    throw 'ZIP descriptor header CRC or sizes differ from the central directory.'
                }
                if ($dataEnd + 12 -gt $Metadata.CentralOffset) { throw 'ZIP data descriptor is truncated.' }
                $Stream.Position = $dataEnd
                $descriptorCrc = $reader.ReadUInt32()
                if ($descriptorCrc -eq 0x08074b50) {
                    if ($dataEnd + 16 -gt $Metadata.CentralOffset) { throw 'ZIP data descriptor is truncated.' }
                    $descriptorCrc = $reader.ReadUInt32()
                    $dataEnd += 16
                }
                else { $dataEnd += 12 }
                [long]$descriptorCompressed = $reader.ReadUInt32()
                [long]$descriptorLength = $reader.ReadUInt32()
                if ($descriptorCrc -ne $record.Crc32 -or $descriptorCompressed -ne $record.CompressedLength -or $descriptorLength -ne $record.Length) {
                    throw 'ZIP data descriptor CRC or sizes differ from the central directory.'
                }
            }
            $ranges.Add([pscustomobject]@{ Start = $record.LocalOffset; End = $dataEnd })
        }
        # Canonical release ZIPs contain only their listed contiguous local records.
        # Reject overlaps, prefixes, gaps and an unlisted/ZIP64 descriptor suffix.
        [long]$previousEnd = 0
        foreach ($range in @($ranges | Sort-Object Start)) {
            if ($range.Start -lt $previousEnd) { throw 'ZIP local entry ranges overlap.' }
            if ($range.Start -ne $previousEnd) { throw 'ZIP local file area contains unlisted bytes.' }
            $previousEnd = $range.End
        }
        if ($previousEnd -ne $Metadata.CentralOffset) { throw 'ZIP local file area contains unlisted bytes.' }
    }
    finally { $reader.Dispose() }
}

function Assert-StmReleaseArchivePayload {
    param(
        [Parameter(Mandatory)][string]$ArchivePath,
        [Parameter(Mandatory)][string]$StagingExePath,
        [Parameter(Mandatory)][string]$Boundary,
        [Parameter(Mandatory)][string]$ExpectedSignerThumbprint,
        [ValidateRange(1, 268435456)][long]$MaximumExeBytes = 256MB,
        [ValidateRange(1, 268435456)][long]$MaximumFileBytes = 256MB,
        [ValidateRange(1, 536870912)][long]$MaximumArchiveBytes = 512MB,
        [ValidateRange(1, 1073741824)][long]$MaximumTotalStreamBytes = 1GB,
        [ValidateRange(1, 4096)][int]$MaximumEntries = 4096
    )
    $expected = ConvertTo-StmSignerThumbprint -Value $ExpectedSignerThumbprint
    $zipPath = Resolve-StmReleasePath -Path $ArchivePath -Boundary $Boundary -Kind File
    $exePath = Resolve-StmReleasePath -Path $StagingExePath -Boundary $Boundary -Kind File
    $packageRoot = Resolve-StmReleasePath -Path ([IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($exePath))) -Boundary $Boundary -Kind Directory
    $exeRelative = [IO.Path]::GetRelativePath($packageRoot, $exePath).Replace('\', '/')
    if ($exeRelative -cne 'app/SchachTurnierManager.WebApi.exe') { throw 'Staging application path is not canonical.' }
    $files = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    $directories = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    $allNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($packageRoot)
    $zipStream = $null
    $zip = $null
    [long]$stagingBytes = 0
    [long]$streamBytes = 0
    $nodeCount = 0
    try {
        # Enumerate one directory at a time; reject reparse components before descending.
        # Keep every trusted staging file read-locked until the archive comparison completes.
        while ($pending.Count -gt 0) {
            $directory = Resolve-StmReleasePath -Path $pending.Pop() -Boundary $packageRoot -Kind Directory
            foreach ($path in [IO.Directory]::EnumerateFileSystemEntries($directory)) {
                $nodeCount++
                if ($nodeCount -gt 2 * $MaximumEntries) { throw 'Staging package is too complex.' }
                $full = Resolve-StmReleasePath -Path $path -Boundary $packageRoot
                $relative = [IO.Path]::GetRelativePath($packageRoot, $full).Replace('\', '/')
                $key = Get-StmPackageEntryKey -Name $relative
                if (-not $allNames.Add($key)) { throw 'Staging package has duplicate or case-alias paths.' }
                $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
                if ($item.PSIsContainer) {
                    if ($directories.Count -ge $MaximumEntries) { throw 'Staging package is too complex.' }
                    $directories.Add($key, $relative)
                    $pending.Push($full)
                    continue
                }
                if ($files.Count -ge $MaximumEntries) { throw 'Staging package is too complex.' }
                $stream = [IO.File]::Open($full, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
                try {
                    $file = [pscustomobject]@{ RelativePath = $relative; FullPath = $full; Length = $stream.Length; Stream = $stream; Sha256 = $null }
                    $files.Add($key, $file)
                }
                catch { $stream.Dispose(); throw }
                if ($stream.Length -gt $MaximumFileBytes) { throw 'Staging package file size limit exceeded.' }
                if ($relative -ceq $exeRelative -and ($stream.Length -lt 1 -or $stream.Length -gt $MaximumExeBytes)) {
                    throw 'Executable size limit exceeded.'
                }
                $stagingBytes += $stream.Length
                if ($stagingBytes -gt [Math]::Floor($MaximumTotalStreamBytes / 2.0)) { throw 'Package total stream size limit exceeded.' }
            }
        }
        if (-not $files.ContainsKey($exeRelative)) { throw 'Staging application executable is missing.' }
        Get-StmCheckedAuthenticodeSignature -Path $exePath -ExpectedSignerThumbprint $expected | Out-Null
        foreach ($file in $files.Values) {
            $budget = [long][Math]::Min($MaximumFileBytes, $MaximumTotalStreamBytes - $streamBytes)
            $hash = Get-StmBoundedStreamSha256 -Stream $file.Stream -MaximumBytes $budget -ExpectedBytes $file.Length
            $streamBytes += $hash.Bytes
            $file.Sha256 = $hash.Sha256
        }
        $zipStream = [IO.File]::Open($zipPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        if ($zipStream.Length -lt 1 -or $zipStream.Length -gt $MaximumArchiveBytes) { throw 'ZIP size limit exceeded.' }
        $metadata = Get-StmBoundedZipDirectory -Stream $zipStream -MaximumEntries $MaximumEntries
        Assert-StmBoundedZipLocalHeaders -Stream $zipStream -Metadata $metadata
        $zipStream.Position = 0
        $zip = [IO.Compression.ZipArchive]::new($zipStream, [IO.Compression.ZipArchiveMode]::Read, $true)
        if ($zip.Entries.Count -ne $metadata.Count) { throw 'ZIP entry count does not match directory metadata.' }
        $seenFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        for ($entryIndex = 0; $entryIndex -lt $metadata.Count; $entryIndex++) {
            $entry = $zip.Entries[$entryIndex]
            $record = $metadata.Entries[$entryIndex]
            if ($entry.FullName -cne $record.Name -or $entry.Length -ne $record.Length -or $entry.CompressedLength -ne $record.CompressedLength) {
                throw 'ZIP entry differs from its validated central directory.'
            }
            if ($record.IsDirectory) {
                if ($record.Length -ne 0 -or -not $directories.ContainsKey($record.Key) -or $directories[$record.Key] -cne $record.Key) {
                    throw 'ZIP directory is absent from verified staging or not canonical.'
                }
                continue
            }
            if (-not $files.ContainsKey($record.Key)) { throw 'ZIP contains an extra file absent from verified staging.' }
            $file = $files[$record.Key]
            if ($record.Name -cne $file.RelativePath -or $record.Length -ne $file.Length) {
                throw 'ZIP package file differs in path or length from verified staging.'
            }
            [void]$seenFiles.Add($record.Key)
            $payload = $entry.Open()
            try {
                $budget = [long][Math]::Min($MaximumFileBytes, $MaximumTotalStreamBytes - $streamBytes)
                $payloadHash = Get-StmBoundedStreamSha256 -Stream $payload -MaximumBytes $budget -ExpectedBytes $record.Length
                $streamBytes += $payloadHash.Bytes
                if ($payloadHash.Sha256 -cne $file.Sha256) { throw 'ZIP package file differs from verified staging.' }
            }
            finally { $payload.Dispose() }
        }
        if ($seenFiles.Count -ne $files.Count) { throw 'ZIP is missing a file from verified staging.' }
    }
    finally {
        if ($null -ne $zip) { $zip.Dispose() }
        if ($null -ne $zipStream) { $zipStream.Dispose() }
        foreach ($file in $files.Values) { $file.Stream.Dispose() }
    }
}
