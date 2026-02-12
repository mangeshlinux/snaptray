#!/bin/bash
echo "=========================================="
echo "   SnapPath Release Helper"
echo "=========================================="

# 1. Configure Local Git Identity (bypasses global config error)
echo "[1/4] Configuring Git identity..."
git config user.email "release@snappath.com"
git config user.name "SnapPath Release"

# 2. Add and Commit
echo "[2/4] Committing files..."
git add .
git commit -m "Initial release"

# 3. Extract Version from pubspec.yaml
echo "[3/5] Extracting version from pubspec.yaml..."
VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //')
TAG="v$VERSION"
echo "Found version: $VERSION"
echo "Creating tag: $TAG"

if [ -z "$VERSION" ]; then
  echo "Error: Could not extract version from pubspec.yaml"
  exit 1
fi

# 4. Push Code and Tag
echo "[4/5] Connecting to GitHub..."
echo ""

# Check if origin already exists
if ! git remote | grep -q 'origin'; then
    echo "Please PASTE your GitHub Repository URL below"
    echo "(Right-Click inside this window and select Paste, then hit Enter):"
    read repo_url
    
    if [ -z "$repo_url" ]; then
      echo "Error: URL cannot be empty."
      exit 1
    fi
    git remote add origin "$repo_url"
fi

echo "Pushing main branch..."
git push -u origin main

echo "Pushing tag $TAG..."
git tag "$TAG"
git push origin "$TAG"

echo ""
echo "=========================================="
echo "   Done! Check your GitHub Actions tab."
echo "=========================================="
read -p "Press Enter to close..."
