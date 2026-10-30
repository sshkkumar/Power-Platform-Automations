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

    # consumed is documented as a single object, but sum defensively in case several entries are returned
    $consumed = @($capacity.consumed | Where-Object { $null -ne $_ })
    $creditsConsumed = if ($consumed) { ($consumed.value | Measure-Object -Sum).Sum } else { $null }

    [pscustomobject]@{
        environmentId                           = $env.environmentId
        environmentType                         = $env.environmentType
        environmentName                         = $env.environmentName
        isManagedEnvironment                    = $env.isManagedEnvironment
        'Credits.Limit'                         = $capacity.allocated.value
        'Credits.AutoAllocated'                 = $capacity.allocated.autoAllocated
        'Credits.Consumed'                      = $creditsConsumed
        'Credits.ConsumptionType'               = $consumed[0].consumptionType
        'Credits.ConsumedLastUpdatedOn'         = if ($consumed[0].lastUpdatedOn) { ([datetime]$consumed[0].lastUpdatedOn).ToUniversalTime().ToString('yyyy-MM-dd') }
        'Capacity.enforcementRules.TenantPool'  = $tenantPoolEnabled
        'Capacity.isTenantPoolGovernedByPolicy' = $capacity.isTenantPoolGovernedByPolicy
        'Capacity.status'                       = $capacity.status
    }
}

$results | Format-Table -AutoSize
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "Exported $(@($results).Count) environment(s) to $csvPath"
