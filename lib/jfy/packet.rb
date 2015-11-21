module Jfy
  class Packet
    attr_reader :data

    def initialize(code, data = [], options = {})
      @header = [0xA5, 0xA5]
      @src = options[:src] || 0x01
      @dst = options[:dst] || 0x01
      @ctrl, @func = code
      @data = data || []
      @ender = [0x0A, 0x0D]
    end

    def command
      [@ctrl, @func]
    end

    def ack?
      @data == [0x06]
    end

    def sub_packet
      @sub_packet ||= @header + [@src, @dst, @ctrl, @func, @data.size] + @data
    end

    def packet
      @packet ||= sub_packet + checksum + @ender
    end

    def checksum
      @checksum ||= begin
        sum = sub_packet.inject(:+)
        sum ^= 0xffff
        sum += 1

        left = (sum & 0xffff) >> 8
        right = sum & 0x00ff

        [left, right]
      end
    end

    def decode
      @data.pack('c*')
    end

    def to_s
      packet.pack('c*')
    end

    def inspect
      hex = @data.map { |d| "0x#{d.to_s(16)}" }.join(' ')
      csum = checksum.map { |d| "0x#{d.to_s(16)}" }.join(' ')
      data = decode.encode('ASCII', :invalid => :replace, :undef => :replace)
      format('<Jfy::Packet:0x%02x @ctrl=0x%02X @func=0x%02X @data=[%s] @hex=[%s] @csum=[%s]>',
             object_id, @ctrl, @func, data, hex, csum)
    end
  end
end
