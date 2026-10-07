#Requires -Version 7.0
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$RequireCompleteProvenance,
    [switch]$RequireExactNuGetPins
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Code) {
    throw "[DependencySafety] $Code"
}

function Assert-ExactVersion([object]$Version, [switch]$NuGet) {
    # NuGet reads a bare "1.2.3" as the inclusive minimum ">= 1.2.3" (resolved to the
    # lowest available match); only the bracketed range "[1.2.3]" pins exactly one
    # version. Both single-version forms are accepted; the caller reports which one.
    $pattern = if ($NuGet) {
        '\A(?:\[(?<v>[0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)\]|[0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)\z'
    } else {
        '\A(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?\z'
    }
    if ($Version -isnot [string] -or $Version -cnotmatch $pattern) { Fail 'NON_EXACT_VERSION' }
}

function Read-SafeXml([string]$Path) {
    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create($Path, $settings)
    try {
        $document = [System.Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.Load($reader)
        return ,$document
    } finally { $reader.Dispose() }
}

function Assert-Map([object]$Value) {
    if ($Value -isnot [System.Collections.IDictionary]) { Fail 'EXPECTED_OBJECT' }
}

function Assert-Sri([object]$Value) {
    if ($Value -isnot [string] -or $Value -cnotmatch '\Asha512-[A-Za-z0-9+/]{86}==\z') { Fail 'INVALID_INTEGRITY' }
    try { $bytes = [Convert]::FromBase64String($Value.Substring(7)) } catch { Fail 'INVALID_INTEGRITY' }
    if ($bytes.Length -ne 64 -or [Convert]::ToBase64String($bytes) -cne $Value.Substring(7)) { Fail 'INVALID_INTEGRITY' }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
$directoryPackagesPath = Join-Path $Root 'Directory.Packages.props'
$webAppPath = Join-Path $Root 'src/SchachTurnierManager.WebApp'
$packageJsonPath = Join-Path $webAppPath 'package.json'
$packageLockPath = Join-Path $webAppPath 'package-lock.json'
foreach ($required in @($directoryPackagesPath, $packageJsonPath, $packageLockPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { Fail 'REQUIRED_FILE_MISSING' }
    if ((Get-Item -LiteralPath $required).Attributes -band [IO.FileAttributes]::ReparsePoint) { Fail 'LINKED_MANIFEST' }
}
if (Test-Path -LiteralPath (Join-Path $webAppPath 'npm-shrinkwrap.json')) { Fail 'SHRINKWRAP_OVERRIDES_LOCKFILE' }

$centralPackages = Read-SafeXml $directoryPackagesPath
$management = @($centralPackages.SelectNodes('/Project/PropertyGroup/ManagePackageVersionsCentrally'))
if ($management.Count -ne 1 -or $management[0].InnerText.Trim() -cne 'true' -or
    $management[0].HasAttribute('Condition') -or $management[0].ParentNode.HasAttribute('Condition')) { Fail 'CPM_NOT_UNCONDITIONALLY_ENABLED' }
$versionMap = @{}
$minimumOnlyNuGet = 0
foreach ($node in $centralPackages.SelectNodes('/Project/ItemGroup/PackageVersion')) {
    $name = $node.GetAttribute('Include')
    if ([string]::IsNullOrWhiteSpace($name) -or $node.HasAttribute('Update') -or
        $node.HasAttribute('Condition') -or $node.ParentNode.HasAttribute('Condition')) { Fail 'UNSUPPORTED_CENTRAL_DECLARATION' }
    $version = $node.GetAttribute('Version')
    Assert-ExactVersion $version -NuGet
    if (-not $version.StartsWith('[')) { $minimumOnlyNuGet++ }
    if ($versionMap.ContainsKey($name)) { Fail 'DUPLICATE_CENTRAL_PACKAGE' }
    $versionMap[$name] = $version
}
if ($versionMap.Count -eq 0) { Fail 'CENTRAL_VERSIONS_MISSING' }

$projectFiles = @(
    foreach ($directory in @('src', 'tests')) {
        Get-ChildItem -LiteralPath (Join-Path $Root $directory) -Filter '*.csproj' -Recurse -File |
            Where-Object { $_.FullName -notmatch '[/\\](?:bin|obj|node_modules)[/\\]' }
    }
)
if ($projectFiles.Count -eq 0) { Fail 'PROJECTS_MISSING' }
foreach ($projectFile in $projectFiles) {
    if ($projectFile.Attributes -band [IO.FileAttributes]::ReparsePoint) { Fail 'LINKED_PROJECT' }
    $project = Read-SafeXml $projectFile.FullName
    foreach ($setting in $project.SelectNodes('/Project/PropertyGroup/ManagePackageVersionsCentrally')) {
        if ($setting.InnerText.Trim() -cne 'true') { Fail 'CPM_DISABLED_BY_PROJECT' }
    }
    foreach ($reference in $project.SelectNodes('/Project/ItemGroup/PackageReference')) {
        $name = $reference.GetAttribute('Include')
        if ([string]::IsNullOrWhiteSpace($name) -or $reference.HasAttribute('Update')) { Fail 'UNSUPPORTED_PACKAGE_REFERENCE' }
        if ($reference.HasAttribute('Version') -or $reference.HasAttribute('VersionOverride') -or
            $null -ne $reference.SelectSingleNode('Version|VersionOverride')) { Fail 'CPM_VERSION_OVERRIDE' }
        if (-not $versionMap.ContainsKey($name)) { Fail 'CENTRAL_VERSION_MISSING' }
    }
}

$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json -AsHashtable
$packageLock = Get-Content -LiteralPath $packageLockPath -Raw | ConvertFrom-Json -AsHashtable
Assert-Map $packageJson
Assert-Map $packageLock
if ($packageLock['lockfileVersion'] -isnot [long] -and $packageLock['lockfileVersion'] -isnot [int]) { Fail 'INVALID_LOCKFILE_VERSION' }
if ($packageLock['lockfileVersion'] -ne 3) { Fail 'INVALID_LOCKFILE_VERSION' }
$packages = $packageLock['packages']
Assert-Map $packages
$rootPackage = $packages['']
Assert-Map $rootPackage
foreach ($field in @('name', 'version')) {
    if ($packageJson[$field] -isnot [string] -or [string]::IsNullOrWhiteSpace($packageJson[$field]) -or
        $packageJson[$field] -cne $rootPackage[$field] -or $packageJson[$field] -cne $packageLock[$field]) { Fail 'ROOT_IDENTITY_MISMATCH' }
}
foreach ($manifest in @($packageJson, $rootPackage)) {
    if ($manifest.Contains('scripts')) {
        Assert-Map $manifest['scripts']
        # `dependencies` runs after any change to node_modules, so it is an install hook too.
        foreach ($hook in @('preinstall', 'install', 'postinstall', 'prepare', 'prepublish', 'preprepare', 'postprepare', 'dependencies')) {
            if ($manifest['scripts'].Contains($hook)) { Fail 'ROOT_LIFECYCLE_SCRIPT' }
        }
    }
}
$directVersions = @{}
foreach ($section in @('dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies')) {
    $declared = if ($packageJson.Contains($section)) { $packageJson[$section] } else { @{} }
    $locked = if ($rootPackage.Contains($section)) { $rootPackage[$section] } else { @{} }
    Assert-Map $declared
    Assert-Map $locked
    if ($declared.Count -ne $locked.Count) { Fail 'ROOT_DEPENDENCY_MISMATCH' }
    foreach ($name in $declared.Keys) {
        if ($name -cnotmatch '\A(?:@[a-z0-9._-]+/)?[a-z0-9._-]+\z' -or $name -in @('.', '..')) { Fail 'INVALID_PACKAGE_NAME' }
        Assert-ExactVersion $declared[$name]
        if (-not $locked.Contains($name) -or $locked[$name] -cne $declared[$name]) { Fail 'ROOT_DEPENDENCY_MISMATCH' }
        if ($directVersions.ContainsKey($name) -and $directVersions[$name] -cne $declared[$name]) { Fail 'CONFLICTING_DIRECT_VERSION' }
        $directVersions[$name] = $declared[$name]
        $installed = $packages["node_modules/$name"]
        if ($null -eq $installed -and $section -eq 'peerDependencies') { continue }
        Assert-Map $installed
        if ($installed['version'] -cne $declared[$name]) { Fail 'INSTALLED_VERSION_MISMATCH' }
    }
}

# These are accepted metadata identifiers, NOT legal approval or a vulnerability audit.
$allowedLicenses = @('0BSD', 'Apache-2.0', 'BSD-3-Clause', 'ISC', 'MIT', 'MPL-2.0')
$reviewedLifecyclePackages = @{
    'node_modules/fsevents' = @{
        version = '2.3.3'
        resolved = 'https://registry.npmjs.org/fsevents/-/fsevents-2.3.3.tgz'
        integrity = 'sha512-5xoDfX+fL7faATnagmWPpbFtwh/R77WmMMqqHGS65C3vvB0YHrgF+B1YmZ3441tMj5n63k0212XNoJwzlhffQw=='
    }
}
$missingProvenance = 0
foreach ($path in ($packages.Keys | Sort-Object -CaseSensitive)) {
    if ($path -ceq '') { continue }
    if ($path -cnotmatch '\Anode_modules/(?:@[a-z0-9._-]+/)?[a-z0-9._-]+(?:/node_modules/(?:@[a-z0-9._-]+/)?[a-z0-9._-]+)*\z' -or
        $path -match '(^|/)\.{1,2}(/|$)') { Fail 'INVALID_LOCKFILE_PATH' }
    $metadata = $packages[$path]
    Assert-Map $metadata
    if ($metadata.Contains('link') -or $metadata.Contains('inBundle')) { Fail 'UNSUPPORTED_LINK_OR_BUNDLE' }
    Assert-ExactVersion $metadata['version']
    if ($metadata['license'] -isnot [string] -or $allowedLicenses -cnotcontains $metadata['license']) { Fail 'UNKNOWN_LICENSE' }
    foreach ($flag in @('hasInstallScript', 'optional')) {
        if ($metadata.Contains($flag) -and $metadata[$flag] -isnot [bool]) { Fail 'INVALID_BOOLEAN_METADATA' }
    }
    $hasSource = $metadata.Contains('resolved')
    $hasIntegrity = $metadata.Contains('integrity')
    if ($hasSource -ne $hasIntegrity) { Fail 'INCOMPLETE_TARBALL_METADATA' }
    if (-not $hasSource) {
        $missingProvenance++
    } else {
        $resolved = $metadata['resolved']
        # registry\.npmjs\.org must be the actual URI host, not a prefix.
        $uri = $null
        if ($resolved -isnot [string] -or -not [uri]::TryCreate($resolved, [UriKind]::Absolute, [ref]$uri)) { Fail 'INVALID_REGISTRY_URI' }
        if ($uri.Scheme -cne 'https' -or $uri.Host -cne 'registry.npmjs.org' -or -not $uri.IsDefaultPort -or
            $uri.UserInfo -ne '' -or $uri.Query -ne '' -or $uri.Fragment -ne '' -or
            $uri.AbsolutePath -notlike '*/-/*.tgz' -or $resolved.Contains('\')) { Fail 'UNTRUSTED_REGISTRY_URI' }
        # The tarball must belong to exactly this lockfile entry (alias entries carry their real name).
        $identity = if ($metadata.Contains('name')) { $metadata['name'] } else { $path.Substring($path.LastIndexOf('node_modules/') + 13) }
        if ($identity -isnot [string] -or $identity -cnotmatch '\A(?:@[a-z0-9._-]+/)?[a-z0-9._-]+\z') { Fail 'INVALID_PACKAGE_NAME' }
        $tarballBase = $identity.Substring($identity.LastIndexOf('/') + 1)
        if ($uri.AbsolutePath -cne "/$identity/-/$tarballBase-$($metadata['version']).tgz") { Fail 'RESOLVED_IDENTITY_MISMATCH' }
        Assert-Sri $metadata['integrity']
    }
    if ($metadata['hasInstallScript'] -eq $true) {
        if (-not $reviewedLifecyclePackages.ContainsKey($path)) { Fail 'UNREVIEWED_LIFECYCLE_SCRIPT' }
        $review = $reviewedLifecyclePackages[$path]
        foreach ($field in @('version', 'resolved', 'integrity')) {
            if ($metadata[$field] -cne $review[$field]) { Fail 'LIFECYCLE_BASELINE_MISMATCH' }
        }
        if ($metadata['license'] -cne 'MIT' -or $metadata['optional'] -ne $true -or
            $metadata['os'] -isnot [array] -or $metadata['os'].Count -ne 1 -or $metadata['os'][0] -cne 'darwin') { Fail 'LIFECYCLE_PLATFORM_MISMATCH' }
    }
}

# Every transitive edge must resolve to a lockfile entry via Node's lookup order
# (own node_modules first, then each ancestor, then the root). Optional edges may
# be absent. Version ranges are not evaluated here; npm ci enforces them.
$edgeCount = 0
foreach ($path in ($packages.Keys | Sort-Object -CaseSensitive)) {
    if ($path -ceq '') { continue }
    $segments = @($path.Substring(13) -split '/node_modules/')
    foreach ($section in @('dependencies', 'optionalDependencies')) {
        if (-not $packages[$path].Contains($section)) { continue }
        $edges = $packages[$path][$section]
        Assert-Map $edges
        foreach ($dependency in $edges.Keys) {
            if ($dependency -cnotmatch '\A(?:@[a-z0-9._-]+/)?[a-z0-9._-]+\z') { Fail 'INVALID_PACKAGE_NAME' }
            $found = $false
            for ($depth = $segments.Count; $depth -ge 0 -and -not $found; $depth--) {
                $candidate = if ($depth -eq 0) { "node_modules/$dependency" } else { 'node_modules/' + ($segments[0..($depth - 1)] -join '/node_modules/') + "/node_modules/$dependency" }
                $found = $packages.Contains($candidate)
            }
            if (-not $found -and $section -eq 'dependencies') { Fail 'UNRESOLVED_TRANSITIVE_DEPENDENCY' }
            $edgeCount++
        }
    }
}

Write-Host "DEPENDENCY_NUGET_CENTRAL_COUNT=$($versionMap.Count)"
if ($minimumOnlyNuGet -gt 0) {
    Write-Host "DEPENDENCY_NUGET_PINNING=MINIMUM_ONLY; COUNT=$minimumOnlyNuGet"
    if ($RequireExactNuGetPins) { Fail 'NUGET_EXACT_PIN_REQUIRED' }
    Write-Warning 'Zentrale NuGet-Versionen ohne [x.y.z] sind Mindestversionen, keine exakten Pins.'
} else { Write-Host 'DEPENDENCY_NUGET_PINNING=EXACT' }
Write-Host "DEPENDENCY_NPM_EDGE_COUNT=$edgeCount"
Write-Host "DEPENDENCY_NPM_PACKAGE_COUNT=$($packages.Count - 1)"
Write-Host "DEPENDENCY_MISSING_PROVENANCE_COUNT=$missingProvenance"
if ($missingProvenance -gt 0) {
    Write-Host 'DEPENDENCY_PROVENANCE=PARTIAL'
    if ($RequireCompleteProvenance) { Fail 'PROVENANCE_REQUIRED' }
    Write-Warning 'Registry/Integrity fehlen bei bestehenden Lockfile-Eintraegen. Keine vollstaendige Herkunftsfreigabe.'
} else { Write-Host 'DEPENDENCY_PROVENANCE=METADATA_COMPLETE' }
Write-Host 'DEPENDENCY_STRUCTURE=PASS'
Write-Host '[DependencySafety] Offline/read-only; kein Paketcode und keine Netzwerkaktion ausgefuehrt.'
