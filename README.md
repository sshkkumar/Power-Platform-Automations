# Power Platform Automations

PowerShell automations for administering Microsoft Power Platform.

## Get-TenantPoolSettings.ps1

Exports the **Copilot Studio message capacity** settings for every environment in the tenant, including whether each environment can use the tenant-wide capacity pool. This is the **TenantPool** checkbox in the Power Platform admin center.

It calls the Power Platform licensing API:

```
GET https://api.powerplatform.com/licensing/environments/entitlements/MCSMessages?api-version=1
```

**MCSMessages** stands for **Microsoft Copilot Studio Messages**, the capacity and billing unit for Copilot Studio (now also called *Copilot Credits*). The endpoint returns each environment's entitlement and governance settings for that capacity.

### Output columns

| Field | Meaning |
|---|---|
| `Capacity.allocated` | Copilot Studio messages assigned directly to that environment |
| `enforcementRules` → `TenantPool` | Whether the environment can use the tenant-wide shared pool of messages beyond its own allocation. This is the checkbox in the admin center capacity settings. |
| `isTenantPoolGovernedByPolicy` | Whether that pool setting is controlled by a policy rather than set on the environment itself |
| `Capacity.status` | The environment's capacity state, for example whether it's within or over its allocation |

The CSV also includes `environmentId`, `environmentType`, `environmentName` and `isManagedEnvironment`.

> **Note:** The API leaves `enabled` blank when the TenantPool setting is checked and returns `false` only when it's unchecked. The script writes `True` or `False` accordingly. The column is blank only when an environment has no capacity data.

### Prerequisites

- PowerShell 7+ (Windows PowerShell 5.1 should also work)
- The Power Apps administration module:

  ```powershell
  Install-Module -Name Microsoft.PowerApps.Administration.PowerShell
  ```

- A Power Platform administrator account

### Usage

```powershell
.\Get-TenantPoolSettings.ps1
```

The script:

1. Signs in and gets a token for `https://api.powerplatform.com`.
2. Retrieves every environment, following `@odata.nextLink` when results span multiple pages.
3. Shows a table in the console and exports it to `.\MCSMessages.csv`.

See [`MCSMessages.sample.csv`](MCSMessages.sample.csv) for example output with sanitized IDs and names. Real exports (`MCSMessages.csv`) are excluded by `.gitignore` because they contain tenant and environment identifiers.
