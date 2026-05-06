param(
  [string]$SubscriptionId,
  [string]$Location,
  [string]$ModelName,
  [string]$ModelFormat
)

# Fallback implementation to keep Terraform external data stable.
# In production, query the Azure model catalog and return latest supported version.
$version = "2024-11-20"
@{ version = $version } | ConvertTo-Json -Compress
