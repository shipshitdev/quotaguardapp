# Task: Homebrew Cask Distribution

**Priority:** P2 (Medium)
**Status:** To Do
**Type:** Feature
**Created:** 2026-01-13
**Updated:** 2026-01-13
**Related PRD:** `../PRDs/prd-homebrew-cask-distribution.md`

## Description

Enable users to install Quota Guard via Homebrew Cask with `brew install --cask quotaguard`. This involves creating a Homebrew tap repository, writing the Cask formula, and automating the release process to update the formula on new releases.

## Acceptance Criteria

- [ ] Create `shipshitdev/homebrew-tap` GitHub repository
- [ ] Write valid Cask formula (`quotaguard.rb`)
- [ ] Users can install via `brew tap shipshitdev/tap && brew install --cask quotaguard`
- [ ] App installs to `/Applications/Quota Guard.app`
- [ ] Formula includes `zap` stanza for clean uninstalls
- [ ] Release workflow creates properly formatted `.zip` artifact
- [ ] Formula auto-updates when new GitHub release is published
- [ ] README documents Homebrew installation method

## Implementation Steps

### Step 1: Create Homebrew Tap Repository

1. Create new GitHub repo: `shipshitdev/homebrew-tap`
2. Initialize with README explaining the tap
3. Create `Casks/` directory for cask formulas

```bash
mkdir -p Casks
```

### Step 2: Write Cask Formula

Create `Casks/quotaguard.rb`:

```ruby
cask "quotaguard" do
  version "1.0.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"

  url "https://github.com/shipshitdev/quotaguardapp/releases/download/v#{version}/QuotaGuard-v#{version}.zip"
  name "Quota Guard"
  desc "Track AI coding assistant usage limits from the menu bar"
  homepage "https://github.com/shipshitdev/quotaguardapp"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "Quota Guard.app"

  zap trash: [
    "~/Library/Preferences/com.agenticindiedev.quotaguard.plist",
    "~/Library/Application Support/QuotaGuard",
    "~/Library/Caches/com.agenticindiedev.quotaguard",
    "~/Library/Group Containers/group.com.agenticindiedev.quotaguard",
  ]
end
```

### Step 3: Update Release Workflow

Modify `.github/workflows/release.yml` to:

1. Build the app with Xcode
2. Create `.zip` with correct naming:
   ```yaml
   - name: Create Release Archive
     run: |
       cd build/Build/Products/Release
       ditto -c -k --keepParent "Quota Guard.app" "QuotaGuard-v${{ github.ref_name }}.zip"
   ```
3. Compute SHA256:
   ```yaml
   - name: Compute SHA256
     run: |
       shasum -a 256 QuotaGuard-v${{ github.ref_name }}.zip | cut -d ' ' -f 1 > sha256.txt
   ```
4. Upload both `.zip` and `sha256.txt` to release

### Step 4: Auto-Update Formula

Add workflow to update formula on release:

```yaml
# .github/workflows/update-homebrew.yml
name: Update Homebrew Formula

on:
  release:
    types: [published]

jobs:
  update-formula:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout homebrew-tap
        uses: actions/checkout@v4
        with:
          repository: shipshitdev/homebrew-tap
          token: ${{ secrets.TAP_GITHUB_TOKEN }}

      - name: Update formula
        run: |
          VERSION="${{ github.event.release.tag_name }}"
          VERSION="${VERSION#v}"  # Remove 'v' prefix
          SHA256=$(curl -sL "https://github.com/shipshitdev/quotaguardapp/releases/download/v${VERSION}/sha256.txt")

          sed -i "s/version \".*\"/version \"${VERSION}\"/" Casks/quotaguard.rb
          sed -i "s/sha256 \".*\"/sha256 \"${SHA256}\"/" Casks/quotaguard.rb

      - name: Commit and push
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add Casks/quotaguard.rb
          git commit -m "Update quotaguard to v${{ github.event.release.tag_name }}"
          git push
```

### Step 5: Update Documentation

Add to README.md:

```markdown
## Installation

### Homebrew (Recommended)

```bash
brew tap shipshitdev/tap
brew install --cask quotaguard
```

### Manual Download

Download the latest release from the [Releases](https://github.com/shipshitdev/quotaguardapp/releases) page.
```

## Testing Checklist

- [ ] Run `brew audit --cask Casks/quotaguard.rb` - no errors
- [ ] Run `brew install --cask quotaguard` - installs successfully
- [ ] Verify app appears in `/Applications/`
- [ ] Launch app from Applications folder
- [ ] Run `brew uninstall quotaguard` - removes cleanly
- [ ] Tag a test release and verify formula updates automatically
- [ ] Run `brew upgrade quotaguard` after formula update

## Files to Create/Modify

**New Repository:**
- `shipshitdev/homebrew-tap/Casks/quotaguard.rb`
- `shipshitdev/homebrew-tap/README.md`

**Modify:**
- `.github/workflows/release.yml` - add zip creation and sha256
- `.github/workflows/update-homebrew.yml` - new workflow
- `README.md` - add Homebrew installation section

## Notes

- Custom tap requires users to run `brew tap` first
- For official `homebrew/homebrew-cask` submission, app must be notarized
- Consider notarizing the app in future to submit to official Cask repo
- SHA256 must be computed from the exact release artifact

## References

- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Creating a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- Related PRD: `../PRDs/prd-homebrew-cask-distribution.md`
