param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Error "[DependencySafety] $Message"
    exit 1
}

function Assert-ExactVersion {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$Kind
    )

    if ([string]::IsNullOrWhiteSpace($Version)) {
        Fail "$Kind '$Name' hat keine Version."
    }

    if ($Version -match '(?i)^(?:\*|latest|next|workspace:|file:|link:|git\+|git://|github:|gitlab:|https?://)' -or
        $Version -match '[\^~><=| ]') {
        Fail "$Kind '$Name' ist nicht exakt gepinnt: '$Version'."
    }
}

$directoryPackagesPath = Join-Path $Root 'Directory.Packages.props'
$webAppPath = Join-Path $Root 'src/SchachTurnierManager.WebApp'
$packageJsonPath = Join-Path $webAppPath 'package.json'
$packageLockPath = Join-Path $webAppPath 'package-lock.json'

foreach ($required in @($directoryPackagesPath, $packageJsonPath, $packageLockPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        Fail "Pflichtdatei fehlt: $required"
    }
}

[xml]$centralPackages = Get-Content -LiteralPath $directoryPackagesPath -Raw
$versionMap = @{}
foreach ($node in @($centralPackages.Project.ItemGroup.PackageVersion)) {
    if ($null -eq $node) {
        continue
    }

    $name = [string]$node.Include
    $version = [string]$node.Version
    if ([string]::IsNullOrWhiteSpace($name)) {
        Fail 'Directory.Packages.props enthaelt PackageVersion ohne Include.'
    }

    Assert-ExactVersion -Name $name -Version $version -Kind 'NuGet PackageVersion'
    if ($versionMap.ContainsKey($name)) {
        Fail "NuGet-Paket '$name' ist mehrfach in Directory.Packages.props definiert."
    }

    $versionMap[$name] = $version
}

if ($versionMap.Count -eq 0) {
    Fail 'Directory.Packages.props enthaelt keine zentralen Paketversionen.'
}

$projectFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $Root 'src') -Filter '*.csproj' -Recurse -File
    Get-ChildItem -LiteralPath (Join-Path $Root 'tests') -Filter '*.csproj' -Recurse -File
)

foreach ($projectFile in $projectFiles) {
    [xml]$project = Get-Content -LiteralPath $projectFile.FullName -Raw
    foreach ($reference in @($project.Project.ItemGroup.PackageReference)) {
        if ($null -eq $reference) {
            continue
        }

        $name = [string]$reference.Include
        if ([string]::IsNullOrWhiteSpace($name)) {
            Fail "PackageReference ohne Include in '$($projectFile.FullName)'."
        }

        if ($reference.Version -or $reference.VersionOverride) {
            Fail "PackageReference '$name' in '$($projectFile.FullName)' umgeht Central Package Management."
        }

        if (-not $versionMap.ContainsKey($name)) {
            Fail "PackageReference '$name' in '$($projectFile.FullName)' hat keine zentrale PackageVersion."
        }
    }
}

$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
$packageLock = Get-Content -LiteralPath $packageLockPath -Raw | ConvertFrom-Json -AsHashtable

if ([int]$packageLock.lockfileVersion -ne 3) {
    Fail "Unerwartete npm lockfileVersion '$($packageLock.lockfileVersion)'; erwartet wird 3."
}

$rootPackage = $packageLock.packages['']
if ($null -eq $rootPackage) {
    Fail 'package-lock.json enthaelt keinen Root-Package-Eintrag.'
}

$directSections = @('dependencies', 'devDependencies')
foreach ($section in $directSections) {
    $declared = $packageJson.$section
    $locked = $rootPackage[$section]

    if ($null -eq $declared) {
        if ($null -ne $locked -and $locked.Count -gt 0) {
            Fail "package-lock.json enthaelt unerwartete Root-Abhaengigkeiten in '$section'."
        }
        continue
    }

    foreach ($property in $declared.PSObject.Properties) {
        $name = [string]$property.Name
        $version = [string]$property.Value
        Assert-ExactVersion -Name $name -Version $version -Kind "npm $section"

        if ($null -eq $locked -or -not $locked.ContainsKey($name)) {
            Fail "Direkte npm-Abhaengigkeit '$name' fehlt im Root-Eintrag von package-lock.json."
        }

        if ([string]$locked[$name] -cne $version) {
            Fail "npm-Version fuer '$name' stimmt zwischen package.json ('$version') und package-lock.json ('$($locked[$name])') nicht ueberein."
        }
    }

    if ($null -ne $locked) {
        foreach ($name in $locked.Keys) {
            if ($null -eq $declared.PSObject.Properties[$name]) {
                Fail "package-lock.json enthaelt direkte npm-Abhaengigkeit '$name' in '$section', die in package.json fehlt."
            }
        }
    }
}

$allowedLicenses = @(
    '0BSD',
    'Apache-2.0',
    'BSD-3-Clause',
    'ISC',
    'MIT',
    'MPL-2.0'
)

$reviewedLifecyclePackages = @{
    'node_modules/fsevents' = @{
        version = '2.3.3'
        optional = $true
        license = 'MIT'
    }
}

foreach ($entry in $packageLock.packages.GetEnumerator()) {
    $path = [string]$entry.Key
    if ([string]::IsNullOrEmpty($path)) {
        continue
    }

    $metadata = $entry.Value
    $version = [string]$metadata.version
    if ([string]::IsNullOrWhiteSpace($version)) {
        Fail "Lockfile-Paket '$path' hat keine Version."
    }

    $license = [string]$metadata.license
    if ([string]::IsNullOrWhiteSpace($license)) {
        Fail "Lockfile-Paket '$path' hat keine Lizenzangabe."
    }

    if ($allowedLicenses -notcontains $license) {
        Fail "Lockfile-Paket '$path' verwendet nicht freigegebene Lizenz '$license'."
    }

    $resolved = [string]$metadata.resolved
    if (-not [string]::IsNullOrWhiteSpace($resolved)) {
        if ($resolved -notmatch '^https://registry\.npmjs\.org/') {
            Fail "Lockfile-Paket '$path' stammt nicht aus registry.npmjs.org: '$resolved'."
        }

        $integrity = [string]$metadata.integrity
        if ([string]::IsNullOrWhiteSpace($integrity)) {
            Fail "Lockfile-Paket '$path' hat trotz Registry-Tarball keine Integrity-Metadaten."
        }

        if ($integrity -notmatch '^sha512-') {
            Fail "Lockfile-Paket '$path' verwendet unerwartetes Integrity-Format '$integrity'."
        }
    }

    if ($metadata.hasInstallScript -eq $true) {
        if (-not $reviewedLifecyclePackages.ContainsKey($path)) {
            Fail "Lifecycle-Skript fuer '$path' ist nicht explizit reviewt."
        }

        $review = $reviewedLifecyclePackages[$path]
        if ([string]$review.version -cne $version -or
            [string]$review.license -cne $license -or
            [bool]$review.optional -ne [bool]$metadata.optional) {
            Fail "Review-Bindung fuer Lifecycle-Paket '$path' passt nicht zur aktuellen Lockfile-Metadatenlage."
        }
    }
}

Write-Host "[DependencySafety] Gruen: $($versionMap.Count) zentrale NuGet-Paketversionen, $($packageLock.packages.Count - 1) npm-Lockfile-Pakete."
Write-Host '[DependencySafety] Offline/read-only; keine Dependency-, Restore- oder Netzwerkaktion ausgefuehrt.'
