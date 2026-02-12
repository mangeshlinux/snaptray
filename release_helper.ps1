# Release Helper (PowerShell)

Write-Host "=========================================="
Write-Host "   SnapPath Release Helper"
Write-Host "=========================================="

# 1. Configure Local Git Identity
Write-Host "[1/5] Configuring Git identity..."
git config user.email "release@snappath.com"
git config user.name "SnapPath Release"

# 2. Add and Commit
Write-Host "[2/5] Committing files..."
git add .
git commit -m "Release update"
# Continue even if nothing to commit

# 3. Extract Version from pubspec.yaml
Write-Host "[3/5] Extracting version from pubspec.yaml..."
$content = Get-Content pubspec.yaml
$versionLine = $content | Select-String "version:"
if (-not $versionLine) {
    Write-Host "Error: Could not extract version from pubspec.yaml" -ForegroundColor Red
    exit 1
}
$version = $versionLine.ToString().Split(":")[1].Trim()
$tag = "v$version"
Write-Host "Found version: $version"
Write-Host "Creating tag: $tag"

# 4. Push Code and Tag
Write-Host "[4/5] Checking Remote..."

# Check if origin exists
$remotes = git remote
if ($remotes -notcontains "origin") {
    Write-Host ""
    $repo_url = Read-Host "Please PASTE your GitHub Repository URL and hit Enter"
    
    if ([string]::IsNullOrWhiteSpace($repo_url)) {
        Write-Host "Error: URL cannot be empty." -ForegroundColor Red
        exit 1
    }
    git remote add origin "$repo_url"
}

Write-Host "Pushing main branch..."
git push -u origin main

Write-Host "Pushing tag $tag..."
git tag "$tag"
git push origin "$tag"

Write-Host ""
Write-Host "=========================================="
Write-Host "   Done! Check your GitHub Actions tab."
Write-Host "=========================================="
Read-Host "Press Enter to close..."
