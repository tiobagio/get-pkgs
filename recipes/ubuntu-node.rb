require 'json'
require 'set'


debian_packages =  <<-PRINT_JSON
echo -n '{"installed":['
dpkg-query -W -f='${Status}\\t${Package}\\t${Version}\\t${Architecture}\\n' |\\
  grep '^install ok installed\\s' |\\
  awk '{ printf "{\\"name\\":\\""$4"\\",\\"version\\":\\""$5"\\",\\"arch\\":\\""$6"\\"}," }' | rev | cut -c 2- | rev | tr -d '\\n'
echo -n ']}'
PRINT_JSON
cmd = shell_out(debian_packages)
json_out = JSON.parse(cmd.stdout)
installed = json_out['installed']
File.write("/tmp/installed.out", installed)

debian_updates = <<-PRINT_JSON
echo -n '{"available":['
DEBIAN_FRONTEND=noninteractive apt upgrade --dry-run | grep Inst | tr -d '[]()' |\\
  awk '{ printf "{\\"name\\":\\""$2"\\",\\"version\\":\\""$4"\\",\\"repo\\":\\""$5"\\",\\"arch\\":\\""$6"\\"}," }' | rev | cut -c 2- | rev | tr -d '\\n'
echo -n ']}'
PRINT_JSON
cmd = shell_out(debian_updates)
json_out = JSON.parse(cmd.stdout)
updates = json_out['available']
File.write("/tmp/available.out", updates)

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

## yum history

