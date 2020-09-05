class Windows2012UpdateFetcher < UpdateFetcher

  def hotfixes
    return @cache_hotfix_installed if defined?(@cache_hotfix_installed)

    hotfix_cmd = 'Get-HotFix | Select-Object -Property Status, Description, HotFixId, Caption, InstallDate, InstalledBy | ConvertTo-Json'
    cmd = @inspec.command(hotfix_cmd)
    begin
      @cache_hotfix_installed = JSON.parse(cmd.stdout)
    rescue JSON::ParserError => _e
      return []
    end
  end

  def fetch_updates
    return @cache_available if defined?(@cache_available)
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
    cmd = @inspec.powershell(script)

    begin
      @cache_available = JSON.parse(cmd.stdout)
    rescue JSON::ParserError => _e
      # we return nil if an error occured to indicate, that we were not able to retrieve data
      @cache_available = {}
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
end


  # returns all important updates
  def important
    updates = fetch_updates
    updates
      .select { |update|
        @update_mgmt.important?(update)
      }.map { |update| # rubocop:disable Style/MultilineBlockChain
        WindowsUpdate.new(update)
      }
  end

  # returns all optional updates
  def optional
    updates = fetch_updates
    updates.select { |update|
      @update_mgmt.optional?(update)
    }.map { |update| # rubocop:disable Style/MultilineBlockChain
      WindowsUpdate.new(update)
    }
  end

  def reboot_required?
    return @chache_reboot if defined?(@chache_reboot)
    @chache_reboot = inspec.registry_key('HKLM\Software\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update').has_property?('RebootRequired')
  end
