case node['platform']
when 'ubuntu'
	include_recipe 'get-pkgs::ubuntu-node'
when 'windows'
	include_recipe 'get-pkgs::windows-node'
when 'redhat'
	include_recipe 'get-pkgs::redhat-node'
end
