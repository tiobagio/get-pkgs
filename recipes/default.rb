case node['platform_family']
when 'debian'
	include_recipe 'get-pkgs::ubuntu-node'
when 'windows'
	include_recipe 'get-pkgs::windows-node'
when 'rhel', 'amazon'
	include_recipe 'get-pkgs::redhat-node'
end
