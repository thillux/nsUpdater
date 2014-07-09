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

def create_record_for_host4(domrobot, domain, ip)
  object = "nameserver"
  method = "createRecord"

  params = { :domain => domain, :type => 'A', :content => ip, :name => Socket.gethostname }

  result = domrobot.call(object, method, params)
end

def create_record_for_host6(domrobot, domain, ip)
  object = "nameserver"
  method = "createRecord"

  params = { :domain => domain, :type => 'AAAA', :content => ip, :name => Socket.gethostname }

  result = domrobot.call(object, method, params)
end

def update_record_for_host(domrobot, id, ip)
  object = "nameserver"
  method = "updateRecord"

  params = { :id => id, :content => ip }

  result = domrobot.call(object, method, params)
end

def delete_record_for_host(domrobot, id)
  object = "nameserver"
  method = "deleteRecord"

  params = { :id => id}

  result = domrobot.call(object, method, params)
end

# http://coderrr.wordpress.com/2008/05/28/get-your-local-ip-address/
def local_ip4
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily
 
  UDPSocket.open do |s|
    begin
      s.connect '173.194.113.119', 1
      s.addr.last
    rescue
      nil
    end
  end
  
  ensure
    Socket.do_not_reverse_lookup = orig
end

def local_ip6
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily
 
  UDPSocket.open(Socket::AF_INET6) do |s|
    begin
      s.connect '2a00:1450:4001:80b::1018', 1
      s.addr.last
    rescue
      nil  
    end
  end
  
  ensure
    Socket.do_not_reverse_lookup = orig
end

if __FILE__ == $PROGRAM_NAME
  addr = 'api.domrobot.com'

  puts 'INWX Updater'
  puts

  hostname = Socket.gethostname
  puts "Hostname: #{hostname}"

  ip4 = local_ip4
  puts "IPv4: #{ip4}"

  ip6 = local_ip6
  puts "IPv6: #{ip6}"
  puts

  config = parse_JSON_file 'config.json'
  domain = config["domain"]
  username = config["username"]
  password = config["password"]

  domrobot = INWX::Domrobot.new(addr)

  result = domrobot.login(username, password)

  hosts = get_domain_hosts(domrobot, domain)

  puts "Handle IPv4 addresses:"
  # IPv4
  if not ip4.nil?
    entry4 = hosts.select { |entry| entry["name"].include? hostname and entry["type"] == 'A' }
    if entry4.empty?
      puts "Create new IPv4 record for #{hostname} with #{ip}"
      create_record_for_host4(domrobot, domain, ip4)
    else
      old_ip4 = entry4[0]["content"]
      new_ip4 = ip4

      if old_ip4 != new_ip4
        puts "Update IPv4 record for #{hostname} from #{old_ip} to #{new_ip}"
        update_record_for_host(domrobot, entry4[0]["id"], ip4)
      else
        puts "Nothing to update for IPv4, #{hostname} still has #{old_ip4}."
      end
    end
  end

  if ip4.nil?
    if not entry4.empty?
      puts "Host has no IPv4 address, delete the old entry."
      delete_record_for_host(domrobot, entry4[0]["id"])
    else
      puts "Host has no IPv4 address. Nothing to do."
    end
  end
  puts

  # IPv6  
  puts "Handle IPv6 addresses:"
  entry6 = hosts.select { |entry| entry["name"].include? hostname and entry["type"] == 'AAAA' }
  if not ip6.nil?
    if entry6.empty?
      puts "Create new IPv6 record for #{hostname} with #{ip6}"
      create_record_for_host6(domrobot, domain, ip6)
    else
      old_ip6 = entry6[0]["content"]
      new_ip6 = ip6

      if old_ip6 != new_ip6
        puts "Update IPv6 record for #{hostname} from #{old_ip6} to #{new_ip6}"
        update_record_for_host(domrobot, entry6[0]["id"], ip6)
      else
        puts "Nothing to update for IPv6, #{hostname} still has #{old_ip6}."
      end
    end
  end

  if ip6.nil?
    if not entry6.empty?
      puts "Host has no IPv6 address, delete the old entry."
      delete_record_for_host(domrobot, entry6[0]["id"])
    else
      puts "Host has no IPv6 address. Nothing to do."
    end
  end
end
