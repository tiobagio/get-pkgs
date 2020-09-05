  def parse_json(script)
    cmd =  shell_out(script)
    begin
      JSON.parse(cmd.stdout)
    rescue JSON::ParserError => _e
      return []
    end
  end

  def packages
    ubuntu_packages = ubuntu_base + <<-PRINT_JSON
echo -n '{"installed":['
dpkg-query -W -f='${Status}\\t${Package}\\t${Version}\\t${Architecture}\\n' |\\
  grep '^install ok installed\\s' |\\
  awk '{ printf "{\\"name\\":\\""$4"\\",\\"version\\":\\""$5"\\",\\"arch\\":\\""$6"\\"}," }' | rev | cut -c 2- | rev | tr -d '\\n'
echo -n ']}'
PRINT_JSON
    parse_json(ubuntu_packages)
  end

  def updates
    ubuntu_updates = ubuntu_base + <<-PRINT_JSON
echo -n '{"available":['
DEBIAN_FRONTEND=noninteractive apt-get upgrade --dry-run | grep Inst | tr -d '[]()' |\\
  awk '{ printf "{\\"name\\":\\""$2"\\",\\"version\\":\\""$4"\\",\\"repo\\":\\""$5"\\",\\"arch\\":\\""$6"\\"}," }' | rev | cut -c 2- | rev | tr -d '\\n'
echo -n ']}'
PRINT_JSON
    parse_json(ubuntu_updates)
  end

  def sec_updates
    ubuntu_updates = ubuntu_base + <<-PRINT_JSON
echo -n '{"sec_updates":['
DEBIAN_FRONTEND=noninteractive apt-get upgrade --dry-run | grep Inst | grep -i security | tr -d '[]()' |\\
  awk '{ printf "{\\"name\\":\\""$2"\\",\\"version\\":\\""$4"\\",\\"repo\\":\\""$5"\\",\\"arch\\":\\""$6"\\"}," }' | rev | cut -c 2- | rev | tr -d '\\n'
echo -n ']}'
PRINT_JSON
    parse_json(ubuntu_updates)
  end

  def ubuntu_base
    base = <<-PRINT_JSON
#!/bin/sh
DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1
readlock() { cat /proc/locks | awk '{print $5}' | grep -v ^0 | xargs -I {1} find /proc/{1}/fd -maxdepth 1 -exec readlink {} \\; | grep '^/var/lib/dpkg/lock$'; }
while test -n "$(readlock)"; do sleep 1; done
echo " "
PRINT_JSON
    base
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
