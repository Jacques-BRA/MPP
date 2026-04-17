$git = "C:\Program Files\Git\cmd\git.exe"
$repo = "C:\MPP"
$log = "C:\MPP\pull.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$changed = $false

Add-Content $log "[$timestamp] Starting sync..."

# Ensure correct branch
& $git -C $repo checkout hunter/explore 2>&1 | Out-Null

# Check for local changes (Designer saves, etc.)
$status = & $git -C $repo status --porcelain 2>&1
if ($status) {
    Add-Content $log "Local changes detected - committing..."
    & $git -C $repo add "ignition/" 2>&1 | Out-Null
    $commitMsg = "Designer auto-save [$timestamp]"
    $commit = & $git -C $repo commit -m $commitMsg 2>&1
    Add-Content $log "Commit: $commit"
    $changed = $true
}

# Capture commit hash before pull
$hashBefore = & $git -C $repo rev-parse HEAD 2>&1

# Pull remote changes and rebase local commits on top
$pull = & $git -C $repo pull --rebase origin hunter/explore 2>&1
Add-Content $log "Pull: $pull"

# Capture commit hash after pull
$hashAfter = & $git -C $repo rev-parse HEAD 2>&1

# If hash changed, remote had new commits
if ($hashBefore -ne $hashAfter) {
    $changed = $true
}

# Push everything back up
$push = & $git -C $repo push origin hunter/explore 2>&1
Add-Content $log "Push: $push"

# Trigger Ignition gateway scan only if something changed
if ($changed) {
    Add-Content $log "Changes detected - triggering Ignition file system scan..."
    $token = Get-Content "C:\Users\admin\Documents\git-sync-api-key.txt" -Raw
    $token = $token.Trim()
    $headers = @{ "X-Ignition-API-Token" = $token }
    try {
        $scan = Invoke-WebRequest -Uri "http://localhost:8088/data/api/v1/scan/config" -Method POST -Headers $headers
        Add-Content $log "Scan response: $($scan.StatusCode)"
    } catch {
        Add-Content $log "Scan error: $_"
    }
} else {
    Add-Content $log "No changes — skipping scan."
}

Add-Content $log "[$timestamp] Sync complete."
