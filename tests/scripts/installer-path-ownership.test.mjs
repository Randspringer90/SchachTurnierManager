import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';

const repository = fileURLToPath(new URL('../../', import.meta.url));
const script = join(repository, 'scripts/Uninstall-ColleagueDesktopApp.ps1');
const linkBytes = 'synthetic owned shortcut bytes';
const linkHash = createHash('sha256').update(linkBytes).digest('hex').toUpperCase();
const harness = String.raw`
$ErrorActionPreference='Stop'
$global:outsideRemovals=0
$global:ownedTestRoot=[IO.Path]::GetFullPath($env:STM_UNINSTALL_ROOT).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
function Remove-Item {
  [CmdletBinding()]
  param([string]$LiteralPath, [switch]$Force, [switch]$Recurse)
  $full=[IO.Path]::GetFullPath($LiteralPath)
  if(-not $full.StartsWith($global:ownedTestRoot,[StringComparison]::OrdinalIgnoreCase)) {
    $global:outsideRemovals++
    return # Never execute an attempted deletion outside the synthetic fixture.
  }
  Microsoft.PowerShell.Management\Remove-Item -LiteralPath $full -Force:$Force -Recurse:$Recurse -ErrorAction Stop
}
$failed=$false
try {
  & $env:STM_UNINSTALL_SCRIPT -InstallDirectory (Join-Path $env:STM_UNINSTALL_ROOT 'installed-app') -ShortcutDirectory (Join-Path $env:STM_UNINSTALL_ROOT 'shortcuts') -UserDataDirectory (Join-Path $env:STM_UNINSTALL_ROOT 'user-data') -Quiet
} catch { $failed=$true }
[ordered]@{ outsideRemovals=$global:outsideRemovals; failed=$failed
 installExists=(Test-Path -LiteralPath (Join-Path $env:STM_UNINSTALL_ROOT 'installed-app'))
 unrelatedShortcutFileExists=(Test-Path -LiteralPath (Join-Path $env:STM_UNINSTALL_ROOT 'shortcuts/unrelated.txt'))
 userDataExists=(Test-Path -LiteralPath (Join-Path $env:STM_UNINSTALL_ROOT 'user-data/keep.txt'))
} | ConvertTo-Json -Compress
`;
for (const mode of ['owned', 'missing-manifest', 'wrong-manifest']) test(`uninstall path ownership: ${mode}`, () => {
  const root = mkdtempSync(join(tmpdir(), 'stm-uninstall-ownership-'));
  try {
    const install = join(root, 'installed-app'), shortcuts = join(root, 'shortcuts');
    mkdirSync(join(install, 'app'), { recursive: true }); mkdirSync(shortcuts); mkdirSync(join(root, 'user-data'));
    writeFileSync(join(install, 'SchachTurnierManager.bat'), 'synthetic starter, never executed');
    writeFileSync(join(install, 'app/SchachTurnierManager.WebApi.exe'), 'synthetic package marker, never executed');
    writeFileSync(join(shortcuts, 'SchachTurnierManager.lnk'), linkBytes);
    writeFileSync(join(shortcuts, 'unrelated.txt'), 'synthetic unrelated user file');
    writeFileSync(join(root, 'user-data/keep.txt'), 'synthetic user data');
    if (mode !== 'missing-manifest') writeFileSync(join(install, 'INSTALLATION_MANIFEST.txt'), [
      'SchachTurnierManager Installation', 'AppId=SchachTurnierManager',
      `InstallDirectory=${mode === 'wrong-manifest' ? join(root, 'another-app') : install}`,
      `StartMenuShortcut=${join(shortcuts, 'SchachTurnierManager.lnk')}`, `StartMenuShortcutSha256=${linkHash}`,
      'DesktopShortcut=', 'DesktopShortcutSha256=', '',
    ].join('\n'));
    const harnessPath = join(root, 'harness.ps1'); writeFileSync(harnessPath, harness);
    const run = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', harnessPath], {
      cwd: repository, encoding: 'utf8', timeout: 20000, windowsHide: true,
      env: { ...process.env, STM_UNINSTALL_ROOT: root, STM_UNINSTALL_SCRIPT: script },
    });
    assert.ifError(run.error); assert.equal(run.status, 0, run.stdout + run.stderr);
    const result = JSON.parse(run.stdout);
    assert.equal(result.outsideRemovals, 0, 'an isolated uninstall must not touch the real desktop shortcut');
    assert.equal(result.unrelatedShortcutFileExists, true, 'a shared shortcut directory may contain unrelated files');
    assert.equal(result.userDataExists, true, 'default uninstall preserves data');
    assert.equal(result.failed, mode !== 'owned');
    assert.equal(result.installExists, mode !== 'owned');
  } finally { rmSync(root, { recursive: true, force: true, maxRetries: 3 }); }
});

for (const ownedExisting of [false, true]) test(`install ${ownedExisting ? 'updates its own validated app directory' : 'refuses a directory without ownership evidence'}`, () => {
  const root = mkdtempSync(join(tmpdir(), 'stm-install-ownership-'));
  try {
    const install = join(root, 'installed-app'), packages = join(root, 'package');
    mkdirSync(install); mkdirSync(packages);
    writeFileSync(join(install, 'unrelated.txt'), 'synthetic unrelated work');
    if (ownedExisting) writeFileSync(join(install, 'INSTALLATION_MANIFEST.txt'),
      `SchachTurnierManager Installation\nAppId=SchachTurnierManager\nInstallDirectory=${install}\n`);
    const harnessPath = join(root, 'install.ps1');
    writeFileSync(harnessPath, String.raw`
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$file=Join-Path $env:STM_INSTALL_PACKAGES 'SchachTurnierManager_Desktop_synthetic.zip'
$archive=[IO.Compression.ZipFile]::Open($file,[IO.Compression.ZipArchiveMode]::Create)
try {
 foreach($name in @('SchachTurnierManager.bat','app/SchachTurnierManager.WebApi.exe','app/wwwroot/index.html')) {
  $entry=$archive.CreateEntry($name)
  $writer=[IO.StreamWriter]::new($entry.Open())
  try{$writer.Write('Synthetic marker, never executed.')}finally{$writer.Dispose()}
 }
}finally{$archive.Dispose()}
try {
 & $env:STM_INSTALL_SCRIPT -PackageDirectory $env:STM_INSTALL_PACKAGES -InstallDirectory $env:STM_INSTALL_TARGET -ShortcutDirectory (Join-Path $env:STM_INSTALL_ROOT 'shortcuts') -Quiet
 'REFUSED=false'
}catch{'REFUSED=true'}
`);
    const run = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', harnessPath], {
      cwd: repository, encoding: 'utf8', timeout: 20000, windowsHide: true,
      env: { ...process.env, STM_INSTALL_ROOT: root, STM_INSTALL_PACKAGES: packages, STM_INSTALL_TARGET: install,
        STM_INSTALL_SCRIPT: join(repository, 'scripts/Install-ColleagueDesktopApp.ps1') },
    });
    assert.ifError(run.error); assert.equal(run.status, 0, run.stdout + run.stderr);
    assert.equal(existsSync(join(install, 'unrelated.txt')), !ownedExisting, 'only a validated existing app directory may be replaced');
    assert.match(run.stdout, ownedExisting ? /REFUSED=false/ : /REFUSED=true/);
    if (ownedExisting) assert.equal(existsSync(join(install, 'app/SchachTurnierManager.WebApi.exe')), true);
  } finally { rmSync(root, { recursive: true, force: true, maxRetries: 3 }); }
});

for (const mode of ['symlink-entry', 'reserved-device', 'duplicate-case', 'trailing-dot', 'foreign-shortcut']) test(`installer rejects ${mode} before replacing existing files`, () => {
  const root = mkdtempSync(join(tmpdir(), 'stm-install-archive-'));
  try {
    const install = join(root, 'installed-app'), packages = join(root, 'package'), shortcuts = join(root, 'shortcuts');
    mkdirSync(install); mkdirSync(packages); mkdirSync(shortcuts);
    writeFileSync(join(install, 'keep.txt'), 'synthetic old installation');
    writeFileSync(join(install, 'INSTALLATION_MANIFEST.txt'), `SchachTurnierManager Installation\nAppId=SchachTurnierManager\nInstallDirectory=${install}\n`);
    if (mode === 'foreign-shortcut') writeFileSync(join(shortcuts, 'SchachTurnierManager.lnk'), 'synthetic unrelated shortcut');
    const harnessPath = join(root, 'archive.ps1');
    writeFileSync(harnessPath, String.raw`
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::Open((Join-Path $env:STM_TEST_PACKAGE 'SchachTurnierManager_Desktop_synthetic.zip'),[IO.Compression.ZipArchiveMode]::Create)
try {
 $names=@('SchachTurnierManager.bat','app/SchachTurnierManager.WebApi.exe','app/wwwroot/index.html')
 switch($env:STM_TEST_MODE){
  'symlink-entry' {$names+= 'app/link'}
  'reserved-device' {$names+= 'app/CON.txt'}
  'duplicate-case' {$names+= 'APP/wwwroot/INDEX.HTML'}
  'trailing-dot' {$names+= 'app/ambiguous.'}
 }
 foreach($name in $names){
  $entry=$archive.CreateEntry($name)
  if($name -eq 'app/link'){$entry.ExternalAttributes=[int](-1610612736)}
  $writer=[IO.StreamWriter]::new($entry.Open())
  try{$writer.Write('Synthetic marker, never executed.')}finally{$writer.Dispose()}
 }
}finally{$archive.Dispose()}
try {
 & $env:STM_TEST_SCRIPT -PackageDirectory $env:STM_TEST_PACKAGE -InstallDirectory $env:STM_TEST_INSTALL -ShortcutDirectory $env:STM_TEST_SHORTCUTS -Quiet
 'REFUSED=false'
}catch{'REFUSED=true'}
`);
    const run = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', harnessPath], {
      cwd: repository, encoding: 'utf8', timeout: 20000, windowsHide: true,
      env: { ...process.env, STM_TEST_MODE: mode, STM_TEST_PACKAGE: packages, STM_TEST_INSTALL: install,
        STM_TEST_SHORTCUTS: shortcuts, STM_TEST_SCRIPT: join(repository, 'scripts/Install-ColleagueDesktopApp.ps1') },
    });
    assert.ifError(run.error); assert.equal(run.status, 0, run.stdout + run.stderr);
    assert.match(run.stdout, /REFUSED=true/);
    assert.equal(existsSync(join(install, 'keep.txt')), true, 'all archive/shortcut checks precede replacement');
    if (mode === 'foreign-shortcut') assert.equal(readFileSync(join(shortcuts, 'SchachTurnierManager.lnk'), 'utf8'), 'synthetic unrelated shortcut');
  } finally { rmSync(root, { recursive: true, force: true, maxRetries: 3 }); }
});
