require 'socket'
require 'json'
require 'timeout'
require 'resolv'
def readvarint(data)
  i = 0
  j = 0
  loop do
    k = data.slice!(0)
    i |= (k & 0x7f) << j * 7
    j += 1
    if j > 5
      raise 'VarInt too big'
    end
    break if (k & 0x80) != 0x80
  end
  return i
end

def srvlookup(address)
  Timeout.timeout(10) do
    resolver = Resolv::DNS.new
    resp = resolver.getresources("_minecraft._tcp.#{address}", Resolv::DNS::Resource::IN::SRV).collect
    resp.each do |r|
      return r.target.to_s, r.port
    end
    return address, 25565
  end
end

def serverping(address, port = nil)
  unless port
    address, port = srvlookup(address) rescue [address, 25565]
  end
  Timeout.timeout(5) do
    s = TCPSocket.new address, port
    data = [0, 4, address.length, address, port, 1].pack('cccA*nc')
    data = [data.length, data].pack('ca*')
    s.send(data, 0)
    s.send([1, 0].pack('cc'), 0)

    resp = s.recv(1024).bytes
    len = readvarint(resp) - 1
    raise 'Bad packet' unless resp.slice!(0) == 0
    until resp.length >= len
      resp += s.recv(len - resp.length).bytes
    end
    s.close

    readvarint(resp)
    resp = resp.pack('c*')
    return JSON.parse(resp)
  end
end
