$git = "C:\Program Files\Git\cmd\git.exe"
$repo = "C:\MPP"
$log = "C:\MPP\pull.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Add-Content $log "[$timestamp] Starting sync..."

# Ensure correct branch
& $git -C $repo checkout hunter/explore 2>&1 | Out-Null

# Check for local changes (Designer saves, etc.)
$status = & $git -C $repo status --porcelain 2>&1
if ($status) {
    Add-Content $log "Local changes detected — committing..."
    & $git -C $repo add "ignition/" 2>&1 | Out-Null
    $commitMsg = "Designer auto-save [$timestamp]"
    $commit = & $git -C $repo commit -m $commitMsg 2>&1
    Add-Content $log "Commit: $commit"
}

# Pull remote changes and rebase local commits on top
$pull = & $git -C $repo pull --rebase origin hunter/explore 2>&1
Add-Content $log "Pull: $pull"

# Push everything back up
$push = & $git -C $repo push origin hunter/explore 2>&1
Add-Content $log "Push: $push"

Add-Content $log "[$timestamp] Sync complete."
