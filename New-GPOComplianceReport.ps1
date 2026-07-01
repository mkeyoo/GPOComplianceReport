param(
    [Parameter(Mandatory)]
    [string]$XmlPath
)

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

function Write-GPOHtmlReport {

    param(
        $General,
        $Links,
        $Policies,
        $OutputPath
    )

    $html = @"

<!DOCTYPE html>

<html>

<head>

<meta charset="utf-8">

<title>$($General.Name)</title>

<style>

body {
    font-family: Segoe UI, Arial;
    margin: 20px;
}

h1 {
    border-bottom: 2px solid black;
}

h2 {
    margin-top: 30px;
    border-bottom: 1px solid gray;
}

h3 {
    margin-left: 20px;
}

h4 {
    margin-left: 40px;
}

.policy {
    margin-left: 60px;
    margin-bottom: 15px;
    padding: 10px;
    border-left: 3px solid #888;
}

.setting {
    margin-left: 20px;
}

.enabled {
    color: green;
    font-weight: bold;
}

.disabled {
    color: red;
    font-weight: bold;
}

table {
    border-collapse: collapse;
}

th, td {
    border: 1px solid #ccc;
    padding: 5px;
}

</style>

</head>

<body>

"@

    $html += "<h1>$($General.Name)</h1>"

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
                    "Enabled" {"enabled"}
                    "Disabled" {"disabled"}
                    default {""}
                }

                $html += @"

<div class='policy'>

<b>$($Policy.Name)</b>

<br>

<span class='$stateClass'>
$($Policy.State)
</span>

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
                }

                $html += "</div>"
            }
        }
    }

    $html += @"

</body>

</html>

"@

    $html |
        Set-Content `
        -Path $OutputPath `
        -Encoding UTF8
}

$Policies | Format-List * | Out-String | Write-Host

[xml]$xml = Get-Content $XmlPath

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

if ([string]::IsNullOrWhiteSpace($raw))
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
$Policies = Get-AdministrativeTemplates $xml

Write-Host ""
Write-Host "GENERAL"
Write-Host "-------"

$General | Format-List

Write-Host ""
Write-Host "LINKS"
Write-Host "-----"

$Links | Format-Table

Write-Host ""
Write-Host "POLICIES"
Write-Host "========"

$Policies | Format-List * | Out-String | Write-Host

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
    -Policies $Policies `
    -OutputPath $OutputFile

Write-Host ""
Write-Host "HTML report written to:"
Write-Host $OutputFile