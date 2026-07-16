#requires -Version 7.0
# SECURITY-PATTERN-FILE: Contract-Test mit ausschliesslich synthetischen, nicht ausgefuehrten Risikomustern.

Describe 'STM-SEC-005 Pull-Request-Sicherheitsreview' {
    It 'besteht den providerunabhaengigen Readiness-Gate' {
        $repo = (& git rev-parse --show-toplevel).Trim()
        & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'scripts/Test-PullRequestReviewReadiness.ps1') -NoArchive
        if ($LASTEXITCODE -ne 0) {
            throw "Test-PullRequestReviewReadiness.ps1 endete mit Exitcode $LASTEXITCODE."
        }
    }
}
