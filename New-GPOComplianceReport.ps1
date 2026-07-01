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

            $policies += [PSCustomObject]@{

                Category = $category[0]

                SubCategory =
                    if($category.Count -gt 1)
                    {
                        $category[1]
                    

                Name = $Policy.Name

                State = $Policy.State

                Explain = $Policy.Explain

                Settings = $settings
            }
        }
    }

    return $policies
}}

$Policies = Get-AdministrativeTemplates $xml

Write-Host ""
Write-Host "POLICIES"
Write-Host "========"

$Policies | Format-List * | Out-String | Write-Host

[xml]$xml = Get-Content $XmlPath

Write-Host "XmlPath: [$XmlPath]"

Write-Host "File exists: $(Test-Path $XmlPath)"

$file = Get-Item $XmlPath -ErrorAction SilentlyContinue

if ($file.Length -eq 0)
{
    throw "XML file is empty: $XmlPath"
}

if ($file) {
    Write-Host "File size: $($file.Length)"
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

$raw = Get-Content $XmlPath -Raw

Write-Host "Raw length: $($raw.Length)"

Write-Host "First 100 chars:"
Write-Host ($raw.Substring(0,[Math]::Min(100,$raw.Length)))

[xml]$xml = $raw

Write-Host "XML object is null: $($null -eq $xml)"

if ($xml) {
    Write-Host "Root element: $($xml.DocumentElement.Name)"
}

$General = Get-GPOGeneral $xml
$Links = Get-GPOLinks $xml

Write-Host ""
Write-Host "GENERAL OBJECT"
Write-Host "=============="

$General | Format-List * | Out-String | Write-Host

Write-Host ""
Write-Host "LINK OBJECTS"
Write-Host "============"

$Links | Format-List * | Out-String | Write-Host

Write-Host ""
Write-Host "GENERAL"
Write-Host "-------"

$General | Format-List

Write-Host ""
Write-Host "LINKS"
Write-Host "-----"

$Links | Format-Table
