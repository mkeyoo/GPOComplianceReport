# GPOComplianceReport

Generate readable HTML compliance reports from Active Directory Group Policy Objects.

## Goals

* Produce a single HTML report for all GPOs linked to an OU.
* Present Group Policy settings in a human-readable format.
* Focus on compliance auditing rather than administration.
* Avoid the complexity and clutter of Microsoft's default GPO reports.

## Planned Features

* Administrative Templates
* Security Settings
* Registry Policies
* Group Policy Preferences
* Firewall Rules
* Scheduled Tasks
* Scripts
* Searchable HTML reports
* Change tracking between report versions

## Usage

```powershell
New-GPOComplianceReport `
    -OU "OU=Servers,DC=contoso,DC=com" `
    -OutputPath C:\Reports
```

