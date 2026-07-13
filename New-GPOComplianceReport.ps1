Import-Module GroupPolicy -ErrorAction Stop

param(

    [string]$XmlPath,
    
    [string]$OU,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

if (-not $XmlPath -and -not $OU)
{
    throw "Specify either -XmlPath or -OU."
}

if ($XmlPath -and $OU)
{
    throw "Specify either -XmlPath or -OU, not both."
}

function Get-GPOGeneral {

    param([xml]$Xml)

    [PSCustomObject]@{
        Name     = $Xml.GPO.Name
        Owner    = $Xml.GPO.SecurityDescriptor.Owner.Name.'#text'
        Created  = [datetime]$Xml.GPO.CreatedTime
        Modified = [datetime]$Xml.GPO.ModifiedTime

        Status = switch ($true) {

            ($Xml.GPO.Computer.Enabled -and
             $Xml.GPO.User.Enabled)
            {
                "Enabled"
                break
            }

            ($Xml.GPO.Computer.Enabled)
            {
                "Computer Only"
                break
            }

            ($Xml.GPO.User.Enabled)
            {
                "User Only"
                break
            }

            default
            {
                "Disabled"
            }
        }
    }
}

function Get-GPOLinks {

    param([xml]$Xml)

    foreach($Link in $Xml.GPO.LinksTo){

        [PSCustomObject]@{

            Name = $Link.SOMName

            Path = $Link.SOMPath

            Enabled = [bool]$Link.Enabled

            Enforced = [bool]$Link.NoOverride
        }
    }
}

function Get-GPOSecurityFiltering {

    param([xml]$Xml)

    $results = @()

    foreach($Permission in
        $Xml.GPO.SecurityDescriptor.Permissions.TrusteePermissions)
    {
        if($Permission.Standard.GPOGroupedAccessEnum -eq
            "Apply Group Policy")
        {
            $results +=
                $Permission.Trustee.Name.InnerText
        }
    }

    return $results
}

function Get-GPODelegation {

    param([xml]$Xml)

    $results = @()

    foreach($Permission in
        $Xml.GPO.SecurityDescriptor.Permissions.TrusteePermissions)
    {
        $results += [PSCustomObject]@{

            Trustee =
                $Permission.Trustee.Name.InnerText

            Permission =
                $Permission.Standard.
                    GPOGroupedAccessEnum

            Inherited =
                $Permission.Inherited
        }
    }

    return $results
}

function Get-AdministrativeTemplates {

    param([xml]$Xml)

    $policies = @()

    foreach($Extension in
        $Xml.GPO.Computer.ExtensionData.Extension)
    {
        foreach($Policy in $Extension.Policy)
        {
            $settings = @()

            if($Policy.DropDownList)
            {
                foreach($Drop in $Policy.DropDownList)
                {
                    $settings += [PSCustomObject]@{
                        Name  = $Drop.Name
                        Value = $Drop.Value.Name
                    }
                }
            }

            $category = $Policy.Category -split '/'

            $subCategory = $null

            if ($category.Count -gt 1)
            {
                $subCategory = $category[1]
            }
            $policies += [PSCustomObject]@{

                Type        = "AdministrativeTemplate"
                
                Category    = $category[0]

                SubCategory = $subCategory

                Name        = $Policy.Name

                State       = $Policy.State

                Explain     = $Policy.Explain

                Settings    = $settings
            }
        }
    }

    return $policies
}

function Write-GPOHtmlSection {

    param(
        $General,
        $Links,
        $SecurityFiltering,
        $Delegation,
        $Policies
    )

 $html = @"

<section class='gpo'>

<a id='$($General.Name.Replace(" ","_"))'></a>

<h1>$($General.Name)</h1>

"@

    $html += "<h1>$($General.Name)</h1>"

    $enabledPolicies =
    ($Policies |
        Where-Object State -eq "Enabled").Count

$disabledPolicies =
    ($Policies |
        Where-Object State -eq "Disabled").Count

$configuredSettings = 0

foreach($Policy in $Policies)
{
    $configuredSettings +=
        $Policy.Settings.Count
}

$html += @"

<h2>Summary</h2>

<table>

<tr>
    <th>Generated</th>
    <td>$(Get-Date)</td>
</tr>

<tr>
    <th>Policy Count</th>
    <td>$($Policies.Count)</td>
</tr>

<tr>
    <th>Configured Settings</th>
    <td>$configuredSettings</td>
</tr>

<tr>
    <th>Enabled Policies</th>
    <td>$enabledPolicies</td>
</tr>

<tr>
    <th>Disabled Policies</th>
    <td>$disabledPolicies</td>
</tr>

<tr>
    <th>Links</th>
    <td>$($Links.Count)</td>
</tr>

<tr>
    <th>Enforced Links</th>
    <td>$(
        ($Links |
            Where-Object Enforced).Count
    )</td>
</tr>

</table>

"@

    #
    # General
    #

    $html += "<h2>General</h2>"

    $html += @"

<table>

<tr><th>Owner</th><td>$($General.Owner)</td></tr>

<tr><th>Created</th><td>$($General.Created)</td></tr>

<tr><th>Modified</th><td>$($General.Modified)</td></tr>

<tr><th>Status</th><td>$($General.Status)</td></tr>

</table>

"@

    #
    # Links
    #

    $html += "<h2>Links</h2>"

    $html += @"

<table>

<tr>
    <th>Name</th>
    <th>Path</th>
    <th>Enabled</th>
    <th>Enforced</th>
</tr>

"@

    foreach($Link in $Links)
    {
        $html += @"

<tr>
    <td>$($Link.Name)</td>
    <td>$($Link.Path)</td>
    <td>$($Link.Enabled)</td>
    <td>$($Link.Enforced)</td>
</tr>

"@
    }
   
    #
    # Security Filtering
    #

$html += "<h2>Security Filtering</h2>"

if($SecurityFiltering.Count)
{
    $html += "<ul>"

    foreach($Item in $SecurityFiltering)
    {
        $html += "<li>$Item</li>"
    }

    $html += "</ul>"
}
else
{
    $html += "<p>None</p>"
}

    $html += "</table>"

    #
    # Delegation
    #

    $html += "<h2>Delegation</h2>"

$html += @"

<table>

<tr>

<th>Trustee</th>

<th>Permission</th>

<th>Inherited</th>

</tr>

"@

foreach($Entry in $Delegation)
{
    $html += @"

<tr>

<td>$($Entry.Trustee)</td>

<td>$($Entry.Permission)</td>

<td>$($Entry.Inherited)</td>

</tr>

"@
}

$html += "</table>"

    #
    # Policies
    #

    $html += "<h2>Computer Configuration</h2>"

    $categories = $Policies |
        Group-Object Category

    foreach($Category in $categories)
    {
        $html += "<h3>$($Category.Name)</h3>"

        $subCategories =
            $Category.Group |
            Group-Object SubCategory

        foreach($SubCategory in $subCategories)
        {
            $html += "<h4>$($SubCategory.Name)</h4>"

            foreach($Policy in $SubCategory.Group)
            {
                $stateClass = switch($Policy.State)
                {
                "Enabled"              { "enabled" }
                "Disabled"             { "disabled" }
                "Success"              { "success" }
                "Failure"              { "failure" }
                "Success and Failure"  { "successfailure" }
                default                { "" }
                }


                $html += @"

<details class='policy'>

<summary>

<<<<<<< Updated upstream
<b>$($Policy.Name)</b>

-
<span class='$stateClass'>
$($Policy.State)
</span>
=======
$($Policy.Name) <span class='$stateClass'>($($Policy.State))</span>
>>>>>>> Stashed changes

</summary>

"@

                foreach($Setting in $Policy.Settings)
                {
                    $html += @"

<div class='setting'>

<b>$($Setting.Name)</b>

<br>

$($Setting.Value)

</div>

"@
if($Policy.Explain)
{
    $html += @"

<details>

<summary>

Explanation

</summary>

<pre>

$($Policy.Explain)

</pre>

</details>

"@
}
                }

                $html += "</details>"
            }
        }
    }

$html += "<h2>User Configuration</h2>"

$html += @"

<p>

No configured settings.

</p>

"@

<<<<<<< Updated upstream
=======
$html += @"

<p style='text-align:right; margin-top:20px;'>
<a href='#top'>Return to Table of Contents</a>
</p>

"@

$html += "</section>"

>>>>>>> Stashed changes
return $html
}

function Get-LinkedGPOs {

    param(
        [string]$OU
    )

    $inheritance = Get-GPInheritance -Target $OU

    return $inheritance.GpoLinks |
        Where-Object { $_.Enabled }
}

function Get-GPOXml {

    param(
        [Guid]$Guid
    )

    [xml](Get-GPOReport `
        -Guid $Guid `
        -ReportType Xml)
}

function Process-GPOXml {

    param(
        [xml]$Xml
    )

    $General = Get-GPOGeneral $Xml

    $Links = Get-GPOLinks $Xml

    $SecurityFiltering = Get-GPOSecurityFiltering $Xml

    $Delegation = Get-GPODelegation $Xml

    $Policies = Get-AdministrativeTemplates $Xml

    return Write-GPOHtmlReport `
        -General $General `
        -Links $Links `
        -SecurityFiltering $SecurityFiltering `
        -Delegation $Delegation `
        -Policies $Policies
}


if (!(Test-Path $XmlPath))
{
    throw "File not found: $XmlPath"
}

$file = Get-Item $XmlPath

if ($file.Length -eq 0)
{
    throw "XML file is empty: $XmlPath"
}

$raw = Get-Content $XmlPath -Raw

<<<<<<< Updated upstream
if ([string]::IsNullOrWhiteSpace($raw))
=======
body {
    font-family: Segoe UI, Arial, sans-serif;
    margin: 20px;
}

table {
    border-collapse: collapse;
    margin-bottom: 15px;
}

th,
td {
    border: 1px solid #ccc;
    padding: 4px 8px;
    vertical-align: top;
    text-align: left;
}

tr:nth-child(even) {
    background: #f9f9f9;
}

details {
    margin-bottom: 10px;
}

.policy {
    margin: 0 0 8px 0;
    padding: 0;
    border: none;
    background: transparent;
}

.policy h5 {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 0;
}

.policy-state {
    font-weight: normal;
    color: #555;
    white-space: nowrap;
}

.success {
    color: #2e7d32;
}

.failure {
    color: #c62828;
}

.successfailure {
    color: #1565c0;
}

summary {
    cursor: pointer;
    font-weight: bold;
}

section.gpo {
    margin-bottom: 30px;
    padding-bottom: 20px;
    border-bottom: 2px solid #d0d0d0;
}

</style>

</head>
<body>
<a id="top"></a>

<h1>GPO Compliance Report</h1>

<p><strong>OU:</strong> $OU</p>

<p><strong>Generated:</strong> $(Get-Date)</p>

<hr/>

"@


$toc = @"
<h2>Contents</h2>
<ul>
"@

foreach ($LinkedGPO in $LinkedGPOs)
>>>>>>> Stashed changes
{
    throw "XML file contains no data: $XmlPath"
}

try
{
    [xml]$xml = $raw
}
catch
{
    throw "Failed to parse XML: $($_.Exception.Message)"
}

$General = Get-GPOGeneral $xml
$Links = Get-GPOLinks $xml
$SecurityFiltering = Get-GPOSecurityFiltering $xml
$Delegation = Get-GPODelegation $xml
$Policies = Get-AdministrativeTemplates $xml


Write-Host "-------"

$General | Format-List

Write-Host ""
Write-Host "-----"

$Links | Format-Table

Write-Host ""
Write-Host "========"


foreach($Policy in $Policies)
{
    Write-Host ""
    Write-Host "----------------------------------"

    Write-Host "Category:    $($Policy.Category)"

    Write-Host "SubCategory: $($Policy.SubCategory)"

    Write-Host "Policy:      $($Policy.Name)"

    Write-Host "State:       $($Policy.State)"

    if($Policy.Settings.Count)
    {
        Write-Host ""
        Write-Host "Settings:"

        foreach($Setting in $Policy.Settings)
        {
            Write-Host "    $($Setting.Name) = $($Setting.Value)"
        }
    }
}

$OutputFile =
    Join-Path `
        $PSScriptRoot `
        "Report.html"

Write-GPOHtmlReport `
    -General $General `
    -Links $Links `
    -SecurityFiltering $SecurityFiltering `
    -Delegation $Delegation `
    -Policies $Policies

$html |
    Set-Content `
    -Path $OutputFile `
    -Encoding UTF8

Write-Host ""
Write-Host "HTML report written to:"
Write-Host $OutputFile