
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

