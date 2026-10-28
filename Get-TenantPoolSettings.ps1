#Install-Module -Name Microsoft.PowerApps.Administration.PowerShell

 Import-Module -Name Microsoft.PowerApps.Administration.PowerShell -ErrorAction Stop

$apiBaseUrl = 'https://api.powerplatform.com'
$apiVersion = '1'
$csvPath    = '.\MCSMessages.csv'

$token   = Get-JwtToken -Audience $apiBaseUrl
$headers = @{ Authorization = "Bearer $token" }

# Fetch all pages (follows @odata.nextLink if the API pages results)
$uri  = "$apiBaseUrl/licensing/environments/entitlements/MCSMessages?searchRequest=&api-version=$apiVersion"
$rows = while ($uri) {
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ErrorAction Stop
    $response.value
    $uri = $response.'@odata.nextLink'
}

# Build the result objects once and reuse them for both console output and CSV
$results = foreach ($env in $rows) {
    $capacity   = $env.entitlement.capacity
    $tenantPool = $capacity.enforcementRules | Where-Object ruleType -eq 'TenantPool' | Select-Object -First 1

    # When the setting is checked the API omits/blanks "enabled"; only an explicit false means unchecked
    $tenantPoolEnabled = if ($null -eq $capacity) { $null } else { -not ($tenantPool.enabled -eq $false) }

    [pscustomobject]@{
        environmentId                          = $env.environmentId
        environmentType                        = $env.environmentType
        environmentName                        = $env.environmentName
        isManagedEnvironment                   = $env.isManagedEnvironment
        'Capacity.allocated'                   = $capacity.allocated
        'Capacity.enforcementRules.TenantPool' = $tenantPoolEnabled
        'Capacity.isTenantPoolGovernedByPolicy' = $capacity.isTenantPoolGovernedByPolicy
        'Capacity.status'                      = $capacity.status
    }
}

$results | Format-Table -AutoSize
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "Exported $(@($results).Count) environment(s) to $csvPath"
