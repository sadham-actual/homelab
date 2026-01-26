# Git Basics for Homelab Documentation

## Overview

This guide covers essential Git commands and workflows for maintaining your homelab documentation. Git provides version control, allowing you to track changes, revert mistakes, and collaborate effectively.

**Why Git for Homelab?**
- Track every change to documentation and configs
- Revert mistakes easily
- See what changed and when
- Work on multiple improvements simultaneously (branches)
- Backup and sync across devices (GitHub)
- Share your journey with others

## Prerequisites

**Install Git:**

**Windows:**
```powershell
# Using Chocolatey
choco install git

# Or download from: https://git-scm.com/download/win
```

**macOS:**
```bash
# Using Homebrew
brew install git

# Or use built-in (may be older)
git --version
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install git -y
```

**Verify installation:**
```bash
git --version
# Should show: git version 2.x.x
```

## Initial Git Configuration

**Set your identity:**
```bash
# Your name (shows in commits)
git config --global user.name "Your Name"

# Your email (use GitHub email)
git config --global user.email "your.email@example.com"

# Set default branch name to 'main'
git config --global init.defaultBranch main

# Use VS Code as default editor (optional)
git config --global core.editor "code --wait"

# Verify settings
git config --global --list
```

**Configure line endings (important for cross-platform):**
```bash
# Windows
git config --global core.autocrlf true

# macOS/Linux
git config --global core.autocrlf input
```

## Creating Your First Repository

### Local Repository (Already Done)

Your homelab repo is already set up, but here's how it was created:

```bash
# Create directory
mkdir homelab
cd homelab

# Initialize Git repository
git init

# Create initial file
echo "# Homelab Documentation" > README.md

# Stage file
git add README.md

# Commit file
git commit -m "Initial commit"
```

### Connecting to GitHub

```bash
# Add GitHub as remote
git remote add origin https://github.com/yourusername/homelab.git

# Push to GitHub
git push -u origin main
```

**Using SSH instead of HTTPS (recommended):**
```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key
cat ~/.ssh/id_ed25519.pub
# Add to GitHub: Settings → SSH and GPG keys → New SSH key

# Use SSH remote URL
git remote set-url origin git@github.com:yourusername/homelab.git
```

## Basic Git Workflow

### The Three States

Files in Git exist in three states:
1. **Working Directory:** Your actual files on disk (modified)
2. **Staging Area (Index):** Files ready to be committed
3. **Repository:** Committed snapshots (history)

**Workflow:**
```
Working Directory → (git add) → Staging Area → (git commit) → Repository → (git push) → GitHub
```

### Daily Workflow

**1. Check status:**
```bash
git status
# Shows:
# - Modified files (red)
# - Staged files (green)
# - Untracked files (red)
```

**2. Stage changes:**
```bash
# Stage specific file
git add docs/03-truenas/snapshots-backup.md

# Stage multiple files
git add docs/03-truenas/*.md

# Stage all changes
git add .

# Stage all in current directory
git add docs/
```

**3. Commit changes:**
```bash
# Commit with message
git commit -m "Add TrueNAS snapshot configuration guide"

# Commit with detailed message
git commit -m "Add TrueNAS snapshot configuration guide

- Document automated snapshot tasks
- Add rollback procedures
- Include replication strategies"

# Shortcut: stage and commit modified files
git commit -am "Update network documentation"
```

**4. Push to GitHub:**
```bash
# Push to main branch
git push origin main

# Or just (after first push with -u)
git push
```

### Example Session

```bash
# Start work
cd ~/homelab

# Check what changed
git status

# Create new file
code docs/04-proxmox/templates.md
# [edit file]

# Stage and commit
git add docs/04-proxmox/templates.md
git commit -m "Add Proxmox VM templates guide"

# Push to GitHub
git push
```

## Viewing History

**See commit history:**
```bash
# Full history
git log

# Compact view (one line per commit)
git log --oneline

# Last 5 commits
git log -5

# With file changes
git log --stat

# Graphical view (branches)
git log --oneline --graph --all
```

**See what changed:**
```bash
# Changes in working directory (not staged)
git diff

# Changes in staging area (staged but not committed)
git diff --staged

# Changes in specific file
git diff docs/README.md

# Changes between commits
git diff abc123 def456

# Changes in last commit
git show HEAD
```

**Search history:**
```bash
# Find commits by message
git log --grep="proxmox"

# Find commits that changed specific file
git log docs/04-proxmox/installation.md

# Find when text was added/removed
git log -S "k3s installation"
```

## Undoing Changes

### Before Staging (Working Directory)

**Discard changes to file:**
```bash
# Discard changes (DESTRUCTIVE, can't undo!)
git restore docs/README.md

# Or old syntax
git checkout -- docs/README.md
```

### After Staging (Staging Area)

**Unstage file (keep changes):**
```bash
# Unstage file
git restore --staged docs/README.md

# Or old syntax
git reset HEAD docs/README.md
```

### After Committing (Repository)

**Amend last commit (change message or add files):**
```bash
# Change commit message
git commit --amend -m "New message"

# Add forgotten file to last commit
git add forgotten-file.md
git commit --amend --no-edit
```

**Undo last commit (keep changes):**
```bash
# Undo commit, keep changes staged
git reset --soft HEAD~1

# Undo commit, keep changes unstaged
git reset HEAD~1

# Undo commit, discard changes (DESTRUCTIVE!)
git reset --hard HEAD~1
```

**Revert commit (safe, creates new commit):**
```bash
# Revert specific commit (creates opposite commit)
git revert abc123

# Safe for shared branches (doesn't rewrite history)
```

## Branching

### Why Use Branches?

- Work on new feature without affecting main documentation
- Experiment safely
- Collaborate on different topics simultaneously
- Keep main branch stable

### Branch Basics

**List branches:**
```bash
# Local branches
git branch

# Remote branches
git branch -r

# All branches
git branch -a
```

**Create and switch branches:**
```bash
# Create new branch
git branch feature-proxmox-templates

# Switch to branch
git switch feature-proxmox-templates

# Or old syntax
git checkout feature-proxmox-templates

# Create and switch in one command
git switch -c feature-proxmox-templates

# Or old syntax
git checkout -b feature-proxmox-templates
```

**Work on branch:**
```bash
# Make changes
code docs/04-proxmox/templates.md

# Commit on branch
git add .
git commit -m "Add VM templates documentation"

# Push branch to GitHub
git push origin feature-proxmox-templates
```

**Merge branch:**
```bash
# Switch back to main
git switch main

# Merge feature branch
git merge feature-proxmox-templates

# Push merged changes
git push

# Delete branch (optional)
git branch -d feature-proxmox-templates
git push origin --delete feature-proxmox-templates
```

### Typical Branching Workflow

```bash
# Start new feature
git switch -c add-kubernetes-docs

# Work and commit
git add docs/05-kubernetes/deployments.md
git commit -m "Add Kubernetes deployment guide"

# More work
git add docs/05-kubernetes/services.md
git commit -m "Add Kubernetes services guide"

# Switch back to main to check something
git switch main

# Switch back to feature
git switch add-kubernetes-docs

# Finish feature, merge
git switch main
git merge add-kubernetes-docs

# Push to GitHub
git push
```

## Pulling Changes from GitHub

**Update local repo with GitHub changes:**
```bash
# Fetch changes (doesn't merge)
git fetch origin

# Pull changes (fetch + merge)
git pull origin main

# Or just (after setting upstream)
git pull
```

**If you have local commits:**
```bash
# Pull with rebase (cleaner history)
git pull --rebase origin main
```

## Handling Conflicts

**Conflicts occur when:**
- Same file edited in two places (different branches or GitHub vs. local)
- Git can't automatically merge

**Resolving conflicts:**
```bash
# Pull or merge causes conflict
git pull origin main
# CONFLICT (content): Merge conflict in docs/README.md

# Check status
git status
# Shows conflicted files

# Open conflicted file
code docs/README.md

# File contains:
<<<<<<< HEAD
Your local changes
=======
Changes from GitHub
>>>>>>> origin/main

# Edit to resolve (keep one version or combine)
# Remove conflict markers (<<<<, ====, >>>>)

# Stage resolved file
git add docs/README.md

# Complete merge
git commit -m "Resolve merge conflict in README"

# Push
git push
```

## .gitignore

**Ignore files you don't want in Git:**

```bash
# Create .gitignore
code .gitignore
```

**Example .gitignore for homelab:**
```
# Secrets and sensitive data
*.secret
*.key
*.pem
secrets/
credentials/

# Environment files with passwords
.env
*.env.local

# Backup files
*.bak
*.backup
*~

# OS files
.DS_Store
Thumbs.db
desktop.ini

# Editor files
.vscode/
.idea/
*.swp

# Logs
*.log
logs/

# Temp files
tmp/
temp/
*.tmp
```

**Commands:**
```bash
# Add and commit .gitignore
git add .gitignore
git commit -m "Add gitignore for sensitive files"

# Remove already-tracked file from Git (but keep locally)
git rm --cached secrets.txt
git commit -m "Remove secrets from Git"
```

## Useful Git Aliases

**Create shortcuts for common commands:**

```bash
# Add to ~/.gitconfig or use git config

# Status shortcut
git config --global alias.st status

# Log shortcuts
git config --global alias.lg "log --oneline --graph --all"
git config --global alias.last "log -1 HEAD"

# Commit shortcuts
git config --global alias.cm "commit -m"
git config --global alias.cma "commit -am"

# Branch shortcuts
git config --global alias.br branch
git config --global alias.co checkout
git config --global alias.sw switch

# Use aliases
git st
git lg
git cm "My commit message"
```

## GitHub-Specific Features

### Pushing to GitHub

**First push:**
```bash
git push -u origin main
# -u sets upstream, future pushes just need: git push
```

**Force push (dangerous!):**
```bash
# Only use if you know what you're doing
# Rewrites GitHub history
git push --force origin main
```

### Pull Requests (For Collaboration)

If working with others or using feature branches on GitHub:

1. Push branch to GitHub
2. Go to GitHub repo
3. Click "Compare & pull request"
4. Review changes
5. Merge pull request
6. Delete branch

### GitHub Desktop (GUI Alternative)

If command line is overwhelming:
- Download: https://desktop.github.com/
- Visual interface for commits, branches, pushes
- Good for beginners
- Still learn CLI eventually (more powerful)

## Common Scenarios

### Scenario 1: Adding New Documentation

```bash
cd ~/homelab

# Create new file
code docs/04-proxmox/storage.md
# [write documentation]

# Check status
git status

# Stage file
git add docs/04-proxmox/storage.md

# Commit
git commit -m "Add Proxmox storage configuration guide"

# Push to GitHub
git push
```

### Scenario 2: Updating Existing File

```bash
# Edit file
code docs/README.md
# [make changes]

# See what changed
git diff docs/README.md

# Stage and commit
git add docs/README.md
git commit -m "Update README with new services"

# Push
git push
```

### Scenario 3: Made Mistake, Need to Revert

```bash
# Oh no, I committed wrong information!

# See last commit
git log -1

# Undo commit, keep changes
git reset HEAD~1

# Fix the file
code docs/04-proxmox/storage.md

# Recommit correctly
git add docs/04-proxmox/storage.md
git commit -m "Add correct Proxmox storage configuration"
git push
```

### Scenario 4: Working on Multiple Computers

**On Computer 1:**
```bash
# Make changes
git add .
git commit -m "Add monitoring documentation"
git push
```

**On Computer 2:**
```bash
# Pull changes
git pull

# Continue working
# [edit files]
git add .
git commit -m "Update monitoring with Grafana setup"
git push
```

**Back on Computer 1:**
```bash
# Pull latest before starting work
git pull

# Now up to date!
```

## Troubleshooting

### "fatal: not a git repository"

**Problem:** Not in Git repository directory

**Solution:**
```bash
cd ~/homelab
# Or wherever your repo is
```

### "fatal: remote origin already exists"

**Problem:** Trying to add remote that already exists

**Solution:**
```bash
# Remove existing remote
git remote remove origin

# Add correct remote
git remote add origin https://github.com/yourusername/homelab.git
```

### "Your branch is ahead of 'origin/main' by X commits"

**Problem:** Local commits not pushed to GitHub

**Solution:**
```bash
git push
```

### "Your branch is behind 'origin/main' by X commits"

**Problem:** GitHub has changes you don't have locally

**Solution:**
```bash
git pull
```

### "Merge conflict"

**Problem:** Same file edited in two places

**Solution:** See "Handling Conflicts" section above

### Accidentally committed sensitive data

**Problem:** Pushed passwords or keys to GitHub

**Solution:**
```bash
# Remove from Git history (complex, see GitHub docs)
# Or delete repo and start fresh (if just started)

# Prevent future: Add to .gitignore
echo "secrets.txt" >> .gitignore
git add .gitignore
git commit -m "Add secrets to gitignore"
```

## Best Practices for Homelab Documentation

1. **Commit Often, Push Regularly**
   - Commit after completing each document
   - Push daily or after major work session
   - Small commits are easier to understand and revert

2. **Write Good Commit Messages**
   - Good: "Add Proxmox networking guide with VLAN configuration"
   - Bad: "update", "fix", "stuff"
   - Use present tense: "Add" not "Added"

3. **Use Branches for Major Work**
   - Working on complex guide? Use branch
   - Keep main branch stable
   - Merge when complete

4. **Keep .gitignore Updated**
   - Add any sensitive files immediately
   - Don't wait until after committing

5. **Pull Before Starting Work**
   - Especially if using multiple computers
   - Avoids conflicts

6. **Review Changes Before Committing**
   - Use `git diff` to see what changed
   - Catch mistakes before they're in history

7. **Don't Commit Generated Files**
   - No build artifacts, compiled files
   - Only source documentation (Markdown, configs)

8. **Tag Important Milestones**
   ```bash
   # Tag major version
   git tag -a v1.0 -m "Initial complete documentation"
   git push origin v1.0
   ```

9. **Regular Backups**
   - GitHub is backup #1
   - But also: `git clone` to external drive occasionally
   - GitHub free tier might have limits (unlikely for docs)

10. **Learn as You Go**
    - Don't need to master Git immediately
    - Learn commands as you need them
    - This guide covers 90% of daily use

## Git Cheat Sheet

**Essential Commands:**
```bash
git status                    # Check status
git add file.md               # Stage file
git add .                     # Stage all changes
git commit -m "message"       # Commit with message
git push                      # Push to GitHub
git pull                      # Pull from GitHub
git log --oneline             # View history
git diff                      # See changes

git branch                    # List branches
git switch -c new-branch      # Create and switch to branch
git switch main               # Switch to main branch
git merge other-branch        # Merge branch

git restore file.md           # Discard changes
git restore --staged file.md  # Unstage file
git reset HEAD~1              # Undo last commit

git remote -v                 # Show remotes
git fetch origin              # Fetch without merging
```

## Learning Resources

- **Official Git Book:** https://git-scm.com/book/en/v2 (free, comprehensive)
- **GitHub Git Handbook:** https://guides.github.com/introduction/git-handbook/
- **Interactive Tutorial:** https://learngitbranching.js.org/
- **Git Cheat Sheet:** https://education.github.com/git-cheat-sheet-education.pdf
- **Oh Shit, Git!?!** https://ohshitgit.com/ (fixing mistakes)

## Next Steps

1. Practice basic workflow (edit, add, commit, push)
2. Try creating a feature branch
3. Experiment with `git log` and `git diff`
4. Set up helpful aliases
5. Learn more advanced features as needed

Remember: Git seems complex at first, but daily use involves just 5-10 commands. You'll get comfortable quickly!

---

*Last Updated: 2025-01-26*