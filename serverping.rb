require 'socket'
require 'json'
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

def serverping(address, port)
    s = TCPSocket.new 'deltawhy.me', 25566
    data = [0, 4, 'deltawhy.me'.length, 'deltawhy.me', 25566, 1].pack('cccA*nc')
    data = [data.length, data].pack('ca*')
    p data
    s.send(data, 0)
    s.send([1, 0].pack('cc'), 0)

    resp = s.recv(1024).bytes
    len = readvarint(resp)
    raise 'Bad packet' unless resp.slice!(0) == 0
    resp += s.recv(len - resp.length).bytes
    s.close

    readvarint(resp)
    resp = resp.pack('c*')
    return JSON.parse(resp)
end
