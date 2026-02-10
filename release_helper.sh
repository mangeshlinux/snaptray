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

# 3. Branch
echo "[3/4] Renaming branch to main..."
git branch -M main

# 4. Push
echo "[4/4] Connecting to GitHub..."
echo ""
echo "Please PASTE your GitHub Repository URL below"
echo "(Right-Click inside this window and select Paste, then hit Enter):"
read repo_url

if [ -z "$repo_url" ]; then
  echo "Error: URL cannot be empty."
  exit 1
fi

git remote add origin "$repo_url"
git push -u origin main

echo ""
echo "=========================================="
echo "   Done! Check your GitHub Actions tab."
echo "=========================================="
read -p "Press Enter to close..."
