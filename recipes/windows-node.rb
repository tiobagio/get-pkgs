require 'json'

script = <<-SCR
$updateSession = new-object -com "Microsoft.Update.Session"
$searcher=$updateSession.CreateupdateSearcher().Search(("IsInstalled=0 and Type='Software'"))
$updates = $searcher.Updates | ForEach-Object {
    $update = $_
    $value = New-Object psobject -Property @{
      "UpdateID" =  $update.Identity.UpdateID;
      "RevisionNumber" =  $update.Identity.RevisionNumber;
      "CategoryIDs" = $update.Categories | % { $_.CategoryID }
      "Title" = $update.Title
      "SecurityBulletinIDs" = $update.SecurityBulletinIDs
      "RebootRequired" = $update.RebootRequired
      "KBArticleIDs" = $update.KBArticleIDs
      "CveIDs" = $update.CveIDs
      "MsrcSeverity" = $update.MsrcSeverity
    }
    $value
}
$updates | ConvertTo-Json
SCR

cmd = powershell_out(script)
#json_out = JSON.parse(cmd.stdout)
File.write("scr.out", cmd.stdout)
node.override['software-updates'] = cmd.stdout

script = <<-SCR
Get-WmiObject -Class Win32_Product |Select Name, version |ConvertTo-Json
SCR

cmd = powershell_out(script)
node.override['software-installed'] = cmd.stdout
File.write("installed.out", cmd.stdout)
