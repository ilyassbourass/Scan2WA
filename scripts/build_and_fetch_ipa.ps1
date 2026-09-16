param (
    [string]$RepoName = "Scan2WA"
)

Write-Host "=== Scan2WA Automated Build & Fetch ===" -ForegroundColor Cyan

# 1. Check if git status is clean
git add -A
git commit -m "Update Scan2WA iOS sources" --allow-empty
git push origin main

Write-Host "Dispatched to GitHub Actions. Waiting for run to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 8

# 2. Get latest run ID
$runId = (gh run list --workflow="build_ipa.yml" --limit 1 --json databaseId -q '.[0].databaseId')
if ($runId) {
    Write-Host "Watching GitHub Actions Run: $runId" -ForegroundColor Cyan
    gh run watch $runId
    
    Write-Host "Downloading Scan2WA.ipa artifact..." -ForegroundColor Green
    gh run download $runId --name Scan2WA-ipa --dir .
    Write-Host "Scan2WA.ipa is ready in the current folder!" -ForegroundColor Green
} else {
    Write-Host "Could not find active run ID. Check GitHub repository manually." -ForegroundColor Red
}
