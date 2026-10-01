#Requires -Version 7.0
param([string]$GatePath = (Join-Path $PSScriptRoot 'Test-DependencySupplyChainSafety.ps1'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$executable = (Get-Process -Id $PID).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('stm-dependency-test-' + [guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)
$sri = 'sha512-' + [Convert]::ToBase64String([byte[]]::new(64))

function Write-Fixture([string]$Path, [string]$Text) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

$cases = @(
    @{ name = 'valid-reference'; expected = 0 },
    @{ name = 'no-package-reference'; expected = 0; project = '<Project><ItemGroup><ProjectReference Include="Synthetic.csproj" /></ItemGroup></Project>' },
    @{ name = 'missing-optional-section'; expected = 0; mutate = { param($p, $l) $p.Remove('devDependencies'); $l['packages'][''].Remove('devDependencies') } },
    @{ name = 'wildcard'; expected = 1; centralVersion = '1.*'; code = 'NON_EXACT_VERSION' },
    @{ name = 'range'; expected = 1; centralVersion = '[1.0.0,2.0.0)'; code = 'NON_EXACT_VERSION' },
    @{ name = 'tag'; expected = 1; centralVersion = 'stable'; code = 'NON_EXACT_VERSION' },
    @{ name = 'newline-version'; expected = 1; mutate = { param($p, $l) $p['dependencies']['synthetic-package'] = "1.2.3`n" }; code = 'NON_EXACT_VERSION' },
    @{ name = 'valid-prerelease'; expected = 0; centralVersion = '1.2.3-preview.1' },
    @{ name = 'cpm-disabled'; expected = 1; enabled = 'false'; code = 'CPM_NOT_UNCONDITIONALLY_ENABLED' },
    @{ name = 'cpm-project-disabled'; expected = 1; project = '<Project><PropertyGroup><ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally></PropertyGroup></Project>'; code = 'CPM_DISABLED_BY_PROJECT' },
    @{ name = 'version-attribute'; expected = 1; project = '<Project><ItemGroup><PackageReference Include="Synthetic.Package" Version="1.2.3" /></ItemGroup></Project>'; code = 'CPM_VERSION_OVERRIDE' },
    @{ name = 'version-child'; expected = 1; project = '<Project><ItemGroup><PackageReference Include="Synthetic.Package"><Version>1.2.3</Version></PackageReference></ItemGroup></Project>'; code = 'CPM_VERSION_OVERRIDE' },
    @{ name = 'version-override'; expected = 1; project = '<Project><ItemGroup><PackageReference Include="Synthetic.Package" VersionOverride="1.2.3" /></ItemGroup></Project>'; code = 'CPM_VERSION_OVERRIDE' },
    @{ name = 'central-missing'; expected = 1; project = '<Project><ItemGroup><PackageReference Include="Unknown.Package" /></ItemGroup></Project>'; code = 'CENTRAL_VERSION_MISSING' },
    @{ name = 'root-drift'; expected = 1; mutate = { param($p, $l) $l['version'] = '9.0.0' }; code = 'ROOT_IDENTITY_MISMATCH' },
    @{ name = 'lock-version-string'; expected = 1; mutate = { param($p, $l) $l['lockfileVersion'] = '3' }; code = 'INVALID_LOCKFILE_VERSION' },
    @{ name = 'installed-drift'; expected = 1; mutate = { param($p, $l) $l['packages']['node_modules/synthetic-package']['version'] = '9.0.0' }; code = 'INSTALLED_VERSION_MISMATCH' },
    @{ name = 'optional-range'; expected = 1; mutate = { param($p, $l) $p['optionalDependencies'] = @{other = '^1.0.0'}; $l['packages']['']['optionalDependencies'] = @{other = '^1.0.0'} }; code = 'NON_EXACT_VERSION' },
    @{ name = 'root-install'; expected = 1; mutate = { param($p, $l) $p['scripts'] = @{install = 'synthetic'} }; code = 'ROOT_LIFECYCLE_SCRIPT' },
    @{ name = 'unknown-license'; expected = 1; mutate = { param($p, $l) $l['packages']['node_modules/synthetic-package']['license'] = 'Unknown' }; code = 'UNKNOWN_LICENSE' },
    @{ name = 'host-spoof'; expected = 1; mutate = { param($p, $l) $l['packages']['node_modules/synthetic-package']['resolved'] = 'https://registry.npmjs.org.example.invalid/a/-/a.tgz' }; code = 'UNTRUSTED_REGISTRY_URI' },
    @{ name = 'userinfo'; expected = 1; mutate = { param($p, $l) $l['packages']['node_modules/synthetic-package']['resolved'] = 'https://example@registry.npmjs.org/a/-/a.tgz' }; code = 'UNTRUSTED_REGISTRY_URI' },
    @{ name = 'invalid-integrity'; expected = 1; mutate = { param($p, $l) $l['packages']['node_modules/synthetic-package']['integrity'] = 'sha512-not-a-digest' }; code = 'INVALID_INTEGRITY' },
    @{ name = 'source-only'; expected = 1; mutate = { param($p, $l) $l['packages']['node_modules/synthetic-package'].Remove('integrity') }; code = 'INCOMPLETE_TARBALL_METADATA' },
    @{ name = 'missing-provenance-visible'; expected = 0; mutate = { param($p, $l) $l['packages']['node_modules/synthetic-package'].Remove('integrity'); $l['packages']['node_modules/synthetic-package'].Remove('resolved') }; code = 'DEPENDENCY_PROVENANCE=PARTIAL' },
    @{ name = 'missing-provenance-required'; expected = 1; strict = $true; mutate = { param($p, $l) $l['packages']['node_modules/synthetic-package'].Remove('integrity'); $l['packages']['node_modules/synthetic-package'].Remove('resolved') }; code = 'PROVENANCE_REQUIRED' },
    @{ name = 'new-lifecycle'; expected = 1; mutate = { param($p, $l) $l['packages']['node_modules/synthetic-package']['hasInstallScript'] = $true }; code = 'UNREVIEWED_LIFECYCLE_SCRIPT' },
    @{ name = 'invalid-boolean'; expected = 1; mutate = { param($p, $l) $l['packages']['node_modules/synthetic-package']['hasInstallScript'] = 'false' }; code = 'INVALID_BOOLEAN_METADATA' },
    @{ name = 'linked-package'; expected = 1; mutate = { param($p, $l) $l['packages']['node_modules/synthetic-package']['link'] = $true }; code = 'UNSUPPORTED_LINK_OR_BUNDLE' },
    @{ name = 'path-traversal'; expected = 1; mutate = { param($p, $l) $l['packages']['node_modules/../outside'] = @{} }; code = 'INVALID_LOCKFILE_PATH' },
    @{ name = 'shrinkwrap'; expected = 1; shrinkwrap = $true; code = 'SHRINKWRAP_OVERRIDES_LOCKFILE' },
    @{ name = 'dtd-prohibited'; expected = 1; project = '<!DOCTYPE Project [<!ENTITY test "synthetic">]><Project>&test;</Project>' }
)

try {
    $index = 0
    foreach ($case in $cases) {
        $index++
        Write-Progress -Activity 'Dependency-Safety-Vertrag' -Status $case['name'] -PercentComplete (100 * ($index - 1) / $cases.Count)
        $fixture = Join-Path $testRoot $case['name']
        $web = Join-Path $fixture 'src/SchachTurnierManager.WebApp'
        [IO.Directory]::CreateDirectory((Join-Path $fixture 'tests')) | Out-Null
        $centralVersion = if ($case.ContainsKey('centralVersion')) { $case['centralVersion'] } else { '1.2.3' }
        $enabled = if ($case.ContainsKey('enabled')) { $case['enabled'] } else { 'true' }
        Write-Fixture (Join-Path $fixture 'Directory.Packages.props') "<Project><PropertyGroup><ManagePackageVersionsCentrally>$enabled</ManagePackageVersionsCentrally></PropertyGroup><ItemGroup><PackageVersion Include=`"Synthetic.Package`" Version=`"$centralVersion`" /></ItemGroup></Project>"
        $project = if ($case.ContainsKey('project')) { $case['project'] } else { '<Project><ItemGroup><ProjectReference Include="Other.csproj" /></ItemGroup><ItemGroup><PackageReference Include="Synthetic.Package" /></ItemGroup></Project>' }
        Write-Fixture (Join-Path $fixture 'src/Synthetic.csproj') $project
        $manifest = @{name = 'synthetic-app'; version = '1.0.0'; dependencies = @{'synthetic-package' = '1.2.3'}; devDependencies = @{}}
        $lockedRoot = $manifest | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        $lockfile = @{name = 'synthetic-app'; version = '1.0.0'; lockfileVersion = 3; packages = @{
            '' = $lockedRoot
            'node_modules/synthetic-package' = @{version = '1.2.3'; license = 'MIT'; resolved = 'https://registry.npmjs.org/synthetic-package/-/synthetic-package-1.2.3.tgz'; integrity = $sri}
        }}
        if ($case.ContainsKey('mutate')) { $mutation = $case['mutate']; & $mutation $manifest $lockfile | Out-Null }
        Write-Fixture (Join-Path $web 'package.json') ($manifest | ConvertTo-Json -Depth 30)
        Write-Fixture (Join-Path $web 'package-lock.json') ($lockfile | ConvertTo-Json -Depth 30)
        if ($case.ContainsKey('shrinkwrap')) { Write-Fixture (Join-Path $web 'npm-shrinkwrap.json') '{}' }
        $before = @(Get-ChildItem -LiteralPath $fixture -Recurse -File | Sort-Object FullName | Get-FileHash -Algorithm SHA256 | ForEach-Object { $_.Hash }) -join ':'
        $invokeArguments = @('-NoLogo', '-NoProfile', '-File', $GatePath, '-Root', $fixture)
        if ($case.ContainsKey('strict')) { $invokeArguments += '-RequireCompleteProvenance' }
        $output = (& $executable @invokeArguments 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
        $after = @(Get-ChildItem -LiteralPath $fixture -Recurse -File | Sort-Object FullName | Get-FileHash -Algorithm SHA256 | ForEach-Object { $_.Hash }) -join ':'
        if (($case['expected'] -eq 0 -and $exitCode -ne 0) -or ($case['expected'] -ne 0 -and $exitCode -eq 0)) { throw "Case $($case['name']): unexpected exit $exitCode. $output" }
        if ($case.ContainsKey('code') -and -not $output.Contains($case['code'])) { throw "Case $($case['name']): expected diagnostic missing. $output" }
        if ($before -cne $after) { throw "Case $($case['name']): fixture changed." }
        Write-Host "PASS=$($case['name'])"
    }
    Write-Host "DEPENDENCY_READINESS=PASS; CASES=$($cases.Count)"
} finally {
    Write-Progress -Activity 'Dependency-Safety-Vertrag' -Completed
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
