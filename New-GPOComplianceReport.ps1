param(
    [Parameter(Mandatory)]
    [string]$XmlPath
)

function Get-GPOGeneral {

    param([xml]$Xml)

    [PSCustomObject]@{
        Name     = $Xml.GPO.Name
        Owner    = $Xml.GPO.SecurityDescriptor.Owner.Name
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

[xml]$xml = Get-Content $XmlPath

$General = Get-GPOGeneral $xml
$Links = Get-GPOLinks $xml

Write-Host ""
Write-Host "GENERAL"
Write-Host "-------"

$General | Format-List

Write-Host ""
Write-Host "LINKS"
Write-Host "-----"

$Links | Format-Table
