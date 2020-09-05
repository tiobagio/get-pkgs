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


node.override['packages-installed']=packages
puts node.override['packages-installed']
