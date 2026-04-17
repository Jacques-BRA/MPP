$log = "C:\MPP\pull.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content $log "[$timestamp] Starting pull..."

$checkout = & "C:\Program Files\Git\cmd\git.exe" -C C:\MPP checkout hunter/explore 2>&1
Add-Content $log "Checkout: $checkout"

$fetch = & "C:\Program Files\Git\cmd\git.exe" -C C:\MPP fetch origin hunter/explore 2>&1
Add-Content $log "Fetch: $fetch"

$reset = & "C:\Program Files\Git\cmd\git.exe" -C C:\MPP reset --hard origin/hunter/explore 2>&1
Add-Content $log "Reset: $reset"

Add-Content $log "[$timestamp] Done."
