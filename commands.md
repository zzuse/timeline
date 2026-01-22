# Set up and work on the personal timeline notes iOS app project.
## Prompt
```prompt
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md
```
```sh
curl -fsSL https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md
mkdir -p ~/.codex/superpowers && git clone https://github.com/obra/superpowers.git ~/.codex/superpowers
mkdir -p ~/.codex/skills
```
```prompt
开发一个 iOS 应用: 个人时间线笔记:
像 X/Twitter一样发送短笔记, 按时间线浏览, 支持图片和标签, 纯本地存储, SwiftUI + SwiftData, iOS 17+
```
```sh
mkdir -p docs/plans
git status --short
git add docs/plans/2026-01-14-personal-timeline-design.md
git commit -m "Add personal timeline design doc"
ls -d .worktrees 2>/dev/null || ls -d worktrees 2>/dev/null
# rg (ripgrep) command-line tool, the -n (or --line-number)
test -f CLAUDE.md && rg -n "worktree.*director" CLAUDE.md || true
git check-ignore -q .worktrees 2>/dev/null && echo ignored || echo not_ignored
git add .gitignore
git commit -m "Ignore .worktrees directory"
git worktree add .worktrees/timeline-notes -b feature/timeline-notes
git status --short
git ls-tree -r --name-only HEAD | rg 'xcodeproj'
git add .gitignore timeline.xcodeproj/project.pbxproj timeline.xcodeproj/project.xcworkspace/contents.xcworkspacedata
git check-ignore -v timeline.xcodeproj/project.pbxproj
git add -f .gitignore timeline.xcodeproj/project.pbxproj timeline.xcodeproj/project.xcworkspace/contents.xcworkspacedata
git commit -m "Add Xcode project to repo"
git merge main
mkdir -p timeline/Models
xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/ModelTests
xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests
xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' \
  -only-testing:timelineTests/AuthSessionManagerTests.signOutClearsTokenAndState \
  -only-testing:timelineTests/AuthSessionManagerTests.signInSetsSuccessFlag \
  -only-testing:timelineTests/SyncUIStateTests.syncStateStatusStringsFallback \
  -only-testing:timelineTests/SyncUIStateTests.restoreIsDisabledWhenSignedOut \
  -only-testing:timelineTests/timelineTests.repositoryFullResyncEnqueuesAllNotes \
  -only-testing:timelineTests/timelineTests.repositoryUpsertsNotesById \
  -only-testing:timelineTests/NotesyncClientTests.clientFetchesLatestNotes
mv timeline/Models/Note.swift timeline/Note.swift
xcodebuild clean -scheme timeline
git diff --stat
xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineUITests/testDetailViewPinToggle -resultBundlePath /tmp/timeline-detailview.xcresult
xcrun xcresulttool get --legacy --path /tmp/timeline-detailview.xcresult --format json | rg "testDetailViewPinToggle|timelineUITests"
# git status short and branch
git status -sb
git worktree remove /personal_path/timeline/timeline/.worktrees/timeline-notes
git branch -d feature/timeline-notes
git status --porcelain
# resolve a remote PR conflict
git fetch origin settings-resync-restore
git worktree add .worktrees/settings-resync-restore origin/settings-resync-restore
```
## Install gh for create PR
```sh
HOMEBREW_NO_AUTO_UPDATE=1 brew install gh

gh auth login
gh pr create --title "Add notesync frontend sync support" --body "$(cat <<'EOF'
## Summary
- add file-based sync queue, notesync client/manager, and token store for JWT auth
- enqueue sync operations on note changes and add manual sync UI
- add tests and README docs for notesync configuration

## Test Plan
- [x] xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0'
EOF
)"
gh pr create --title "feat: add notesync auth flow and sync wiring" --body "## Summary
- add app configuration and auth login flow scaffolding
- wire sync auth gating and notesync client updates
- update README notesync docs and tests

## Test Plan
- [ ] xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0'"
```

## Xcode Debug
```
Xcode: Window → Devices and Simulators → select your device → click Open Console (or View Device Logs), then filter by your app/bundle id.
macOS Console.app: select your device under “Devices”, then filter for your app name or bundle id.
Terminal (live stream):
log stream --predicate 'subsystem == "zzuse.timeline"' --info
```

## Worktree process
```sh
# show top-level directory of the working tree
git rev-parse --show-toplevel
# Debug gitignore --quiet
git check-ignore -q .worktrees
# Add worktree from branch
git worktree add .worktrees/notesync-frontend-impl -b notesync-frontend-impl
cd /personal_path/timeline/timeline/.worktrees/notesync-frontend-impl
git status -sb
# After developing...
git add
git commit
git push -u origin notesync-frontend-impl 
gh pr create
# After Review...bug fix can still add/commit/push
# No problem, delete branch
git branch --show-current
git worktree remove /personal_path/timeline/timeline/.worktrees/notesync-frontend-impl
git branch -d notesync-frontend-impl
git push origin --delete notesync-frontend-impl

# on the main branch: Update main, if there are changes
git stash -u
git pull --ff-only
git stash pop

# I did a silly stuff, didn't pull from main, but new feature developed, commit met conflict,
# solve some conflit commit again, then remember need pulled main, rebase, skip the conflict commit.
git rebase remotes/origin/main
git add timeline/Services/NotesyncClient.swift timelineTests/NotesyncClientTests.swift
git rebase --continue
GIT_EDITOR=true git rebase --continue
git rebase --skip
git push --force-with-lease
```

## Simulator OAuth test
```sh
xcrun simctl list devices available
xcrun simctl boot "iPhone 15"
xcrun simctl listapps booted | rg -i timeline
open -a Simulator
xcodebuild clean -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild build -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'
# check has the URL types
plutil -p "/Users/z/Library/Developer/Xcode/DerivedData/timeline-fnasnbeufxvtkaefhcctimlelytw/Build/Products/Debug-iphonesimulator/timeline.app/Info.plist" \
| rg -n "CFBundleURLTypes|CFBundleURLSchemes"
# To ensure the URL scheme is included in the generated plist, add it via Xcode’s Info tab (this reliably maps to the generated plist):
# Target → Info → URL Types → + Identifier: zzuse.timeline + URL Schemes: zzuse.timeline
# check info.plist configure success
xcodebuild -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15' -showBuildSettings \
| rg -n "INFOPLIST_KEY_CFBundleURLTypes|GENERATE_INFOPLIST_FILE|INFOPLIST_FILE"
# Installed simulator app contains the scheme:
APP=$(xcrun simctl get_app_container booted zzuse.timeline app)
plutil -p "$APP/Info.plist" | rg -n "CFBundleURLTypes|CFBundleURLSchemes"
# Open app
xcrun simctl openurl booted "zzuse.timeline://auth/callback?code=TEST"
```