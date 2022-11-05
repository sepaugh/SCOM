## Original - https://techibee.com/powershell/powershell-get-scom-groups-of-a-computer-account/1129#:~:text=Link-,hubo%20bomo,-June%2012%2C%202014%2C%203%3A23

## Get Windows Computer class
$computerClass = Get-SCOMClass -Name “Microsoft.Windows.Computer”

## FQDN
$computerFQDN = “fc16a.contoso.com”

## Get SCOM object # MonitoringObject (Microsoft.EnterpriseManagement.Monitoring.PartialMonitoringObject)
$computer = Get-SCOMClassInstance -Class $computerClass | Where-Object {($_.FullName -eq $computerFQDN) -or ($_.Name -eq $computerFQDN)}

## Relationship classes
# Microsoft.SystemCenter.ComputerGroupContainsComputer – Group contains Computers – Groups that contain only computers
$relation1 = Get-SCOMRelationship -Name “Microsoft.SystemCenter.ComputerGroupContainsComputer”

# Microsoft.SystemCenter.InstanceGroupContainsEntities – Contains Entities – Relationship between an instance group and the entities that it contains
$relation2 = Get-SCOMRelationship -Name “Microsoft.SystemCenter.InstanceGroupContainsEntities”

## Get SCOM Groups
Get-SCOMRelationshipInstance -TargetInstance $computer | Where-Object {!$_.isDeleted -and
( ($_.RelationshipId -eq $relation1.Id) -or ($_.RelationshipId -eq $relation2.Id) )} `
| Sort-Object SourceObject | Out-GridView
