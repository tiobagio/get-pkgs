require 'json'
require 'set'

## find out installed packages
##
rhel_packages = <<-PRINT_JSON
sleep 2 && echo " "
echo -n '{"installed":['
rpm -qa --queryformat '"name":"%{NAME}","version":"%{VERSION}-%{RELEASE}","arch":"%{ARCH}"\\n' |\\
  awk '{ printf "{"$1"}," }' | rev | cut -c 2- | rev | tr -d '\\n'
echo -n ']}'
PRINT_JSON

cmd = shell_out(rhel_packages)
json_out = JSON.parse(cmd.stdout)
installed = json_out['installed']
node.override['software-installed'] = installed
#File.write("/tmp/installed.out", installed)

## get availables updates/patches
##
rhel_updates = <<-PRINT_JSON
#!/bin/sh
python -c 'import sys; sys.path.insert(0, "/usr/share/yum-cli"); import cli; ybc = cli.YumBaseCli(); ybc.setCacheDir("/tmp"); list = ybc.returnPkgLists(["updates"]);res = ["{\\"name\\":\\""+x.name+"\\", \\"version\\":\\""+x.version+"-"+x.release+"\\",\\"arch\\":\\""+x.arch+"\\"}" for x in list.updates]; print "{\\"available\\":["+",".join(res)+"]}"'
PRINT_JSON

cmd = shell_out(rhel_updates)
unless cmd.exitstatus == 0
# essentially we want https://github.com/chef/inspec/issues/1205
	STDERR.puts 'Could not determine patch status.'
	return nil
end

# skip extraneous message "Loaded plugins.." 
#
first = cmd.stdout.index('{') 
res = cmd.stdout.slice(first, cmd.stdout.size - first)
begin 
	json_out = JSON.parse(res)
	rescue JSON::ParserError => _e
end

updates = json_out['available']
#File.write("/tmp/available.out", updates)

## get installed software that has updates OR intersects installed and updates
#
compared_packages = []
package_updates = {}
installed.each do |pkg|
	match_selection = updates.detect { |x| x["name"] == pkg["name"] }
	if match_selection then	
		#puts match_selection
		compared_packages << {name: pkg["name"], current: pkg["version"], available: match_selection["version"]}
		package_updates[pkg["name"]] = {current: pkg["version"], available: match_selection["version"]}
	end
end
node.override['software-updates'] = package_updates
#puts package_updates

history = []
cmd = shell_out("yum history list | grep [1-9]")
cmd.stdout.each_line do |line|
	history << line
end
#puts history
node.override['yum-history'] = history
#File.write("/tmp/installed.out", installed)

