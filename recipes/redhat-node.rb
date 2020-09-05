  def parse_json(script)
    cmd =  shell_out(script)
    begin
      JSON.parse(cmd.stdout)
    rescue JSON::ParserError => _e
      return []
    end
  end


  def packages
    rhel_packages = <<-PRINT_JSON
sleep 2 && echo " "
echo -n '{"installed":['
rpm -qa --queryformat '"name":"%{NAME}","version":"%{VERSION}-%{RELEASE}","arch":"%{ARCH}"\\n' |\\
  awk '{ printf "{"$1"}," }' | rev | cut -c 2- | rev | tr -d '\\n'
echo -n ']}'
PRINT_JSON
    parse_json(rhel_packages)
  end

  def updates
    rhel_updates = <<-PRINT_JSON
#!/bin/sh
python -c 'import sys; sys.path.insert(0, "/usr/share/yum-cli"); import cli; list = cli.YumBaseCli().returnPkgLists(["updates"]);res = ["{\\"name\\":\\""+x.name+"\\", \\"version\\":\\""+x.version+"-"+x.release+"\\",\\"arch\\":\\""+x.arch+"\\",\\"repository\\":\\""+x.repo.id+"\\"}" for x in list.updates]; print "{\\"available\\":["+",".join(res)+"]}"'
PRINT_JSON
    cmd = shell_out(rhel_updates)
    unless cmd.exitstatus == 0
      # essentially we want https://github.com/chef/inspec/issues/1205
      STDERR.puts 'Could not determine patch status.'
      return nil
    end

    first = cmd.stdout.index('{')
    res = cmd.stdout.slice(first, cmd.stdout.size - first)
    begin
      JSON.parse(res)
    rescue JSON::ParserError => _e
      return []
    end
  end

  def sec_updates
## the assumption is package name always start with lowercase;
## so anything else is extraneous e.g. error, informational messages not related to packages
##
    rhel_updates = <<-PRINT_JSON
echo -n '{"sec_updates":['
yum --security check-update |grep ^[a-z0-9]| awk '{ printf "{\\"name\\":\\""$1"\\", \\"version\\":\\""$2"\\"}," }' |rev | cut -c 2- | rev |tr -d '\\n'
echo -n ']}'
PRINT_JSON

    parse_json(rhel_updates)
  end

def compare (arr, installed)
  myhash = {}
  arr.each { |pkg|
    match_selection = installed.detect { |x| x["name"] == pkg["name"] }
    if match_selection then
       myhash[pkg["name"]] = {current: match_selection["version"], available: pkg["version"]}
    end
  }
  return myhash
end

p = packages
node.override['packages-installed'] = p['installed']
u = updates
node.override['packages-updates'] = compare(u['available'], p['installed'])
u = sec_updates
node.override['packages-sec_updates'] = compare(u['sec_updates'], p['installed'])

#puts "=-=-=-= packages =-=-=-=-="
#puts node.override['packages-installed']
#puts "=-=-=-=- updates =-=-=-=-="
#puts node.override['packages-updates']
#puts "-===-=-=- security updates =-=-=-=-=-="
#puts node.override['packages-sec_updates']

history = []
cmd = shell_out("yum history list | grep [1-9]")
cmd.stdout.each_line do |line|
	history << line
end
#puts history
node.override['yum-history'] = history

