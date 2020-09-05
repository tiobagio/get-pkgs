#class Windows2012UpdateFetcher < UpdateFetcher

  def installed
    script = 'Get-WmiObject -Class Win32_Product |Select name, version |ConvertTo-Json'
    cmd = powershell_out(script)
    begin
      cache_hotfix_installed = JSON.parse(cmd.stdout)
    rescue JSON::ParserError => _e
      return []
    end
  end  


  def hotfixes
    hotfix_cmd = 'Get-HotFix | Select-Object -Property Status, Description, HotFixId, Caption, InstallDate, InstalledBy | ConvertTo-Json'
    cmd = powershell_out(hotfix_cmd)
    begin
      cache_hotfix_installed = JSON.parse(cmd.stdout)
    rescue JSON::ParserError => _e
      return []
    end
  end

  def fetch_updates
    #return @cache_available if defined?(@cache_available)
    script = <<-EOH
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
    EOH
    cmd = powershell_out(script)

    begin
      cache_available = JSON.parse(cmd.stdout)
    rescue JSON::ParserError => _e
      # we return nil if an error occured to indicate, that we were not able to retrieve data
      cache_available = {}
    end
  end

  def important?(update)
    security_category?(update['CategoryIDs'])
  end

  def optional?(update)
    !important?(update)
  end

  # @see: https://msdn.microsoft.com/en-us/library/ff357803(v=vs.85).aspx
  # e6cf1350-c01b-414d-a61f-263d14d133b4 -> Critical Updates
  # 0fa1201d-4330-4fa8-8ae9-b877473b6441 -> Security Updates
  # 28bc880e-0592-4cbf-8f95-c79b17911d5f -> Update Rollups
  # does not include recommended updates yet
  def security_category?(uuids)
    return if uuids.nil?
    uuids.include?('0fa1201d-4330-4fa8-8ae9-b877473b6441') ||
      uuids.include?('28bc880e-0592-4cbf-8f95-c79b17911d5f') ||
      uuids.include?('e6cf1350-c01b-414d-a61f-263d14d133b4')
  end


  def all (all_updates)
    updates = all_updates
    updates.map { |update| update }
  end

  # returns all important updates
  def important (all_updates)
    updates = all_updates
    updates
      .select { |update| important?(update)
      }.map { |update| 
        update
      }
  end

  # returns all optional updates
  def optional (all_updates)
    updates = all_updates
    updates.select { |update|
      optional?(update)
    }.map { |update| # rubocop:disable Style/MultilineBlockChain
      update
    }
  end

  def to_hash (arr)
    myhash = {}
    arr.each { |pkg|
         myhash[pkg["name"]] = {current: match_selection["version"], available: pkg["version"]}
    }
    return myhash
  end

  all = fetch_updates
  puts all
  puts "=-=-=-==-=-=important=-=-=-=-"
  i = important(all)
  puts i
  puts "=-=-=-=-=-=-optional=-=-=-=-"
  o = optional(all)
  puts o

  pkgs = installed
  puts "=-=-=-=-=-=-installed software=-=-=-=-"
  puts pkgs

  puts "=-=-=-=-=-=-hotfixes=-=-=-=-"
  hf = hotfixes
  puts hf