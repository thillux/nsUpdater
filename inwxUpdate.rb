require_relative "inwx/Domrobot"
require "json"
require 'socket'

def parse_JSON_file(filename)
  File.open( filename, "r" ) do |f|
      return JSON.load(f)
  end
end

def get_domain_hosts(domrobot, domain)
  object = "nameserver"
  method = "info"

  params = { :domain => domain }

  result = domrobot.call(object, method, params)

  return result["resData"]["record"]
end

def create_record_for_host(domrobot, domain, ip)
  object = "nameserver"
  method = "createRecord"

  params = { :domain => domain, :type => 'A', :content => ip, :name => Socket.gethostname }

  result = domrobot.call(object, method, params)
end

def update_record_for_host(domrobot, domain, id, ip)
  object = "nameserver"
  method = "updateRecord"

  params = { :id => id, :content => ip }

  result = domrobot.call(object, method, params)
end

# http://coderrr.wordpress.com/2008/05/28/get-your-local-ip-address/
def local_ip
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily
 
  UDPSocket.open do |s|
    s.connect '64.233.187.99', 1
    s.addr.last
  end
  
  ensure
    Socket.do_not_reverse_lookup = orig
end

if __FILE__ == $PROGRAM_NAME
  addr = 'api.domrobot.com'

  puts 'INWX Updater'

  hostname = Socket.gethostname
  puts "Hostname: #{hostname}"

  ip = local_ip
  puts "IP: #{ip}"

  config = parse_JSON_file 'config.json'
  domain = config["domain"]
  username = config["username"]
  password = config["password"]

  domrobot = INWX::Domrobot.new(addr)

  result = domrobot.login(username, password)

  hosts = get_domain_hosts(domrobot, domain)

  entry =  hosts.select { |entry| entry["name"].include? hostname and entry["type"] == 'A' }

  if entry.nil?
    puts "Create new record for #{hostname} with #{ip}"
    create_record_for_host(domrobot, domain, ip)
  else
    old_ip = entry[0]["content"]
    new_ip = ip
    if old_ip != new_ip
      puts "Update record for #{hostname} from #{old_ip} to #{new_ip}"
      update_record_for_host(domrobot, domain, entry[0]["id"], ip)
    else
      puts "Nothing to update, #{hostname} still has #{old_ip}."
    end 
  end
end
