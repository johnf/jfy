require 'jfy/packet'
require 'jfy/codes'
require 'jfy/errors'

require 'serialport'

module Jfy
  class Client
    def initialize(options = {})
      serial_port = options[:serial_port] || '/dev/ttyUSB0'
      baud = options[:baud] || 9600
      @debug = options[:debug] || true # FIXME: make false

      @serial = SerialPort.new(serial_port, :baud => baud)

      @serial.flush_output
      @serial.flush_input
      @serial.read_timeout = 1_000
    end

    def re_register
      packet = Packet.new(Jfy::Codes::RE_REGISTER, [], :dst => 0x0)
      write(packet)

      # sleep(1) # TODO: Should the sleep be in the library?
    end

    def offline_query
      packet = Packet.new(Jfy::Codes::OFFLINE_QUERY, [], :dst => 0x0)
      write(packet)
      packet = read

      fail(BadPacket, 'invalid offline response') unless packet.command == Jfy::Codes::REGISTER_REQUEST

      packet.decode
    end

    def register(serial_num, address)
      data = serial_num.unpack('c*') << address
      packet = Jfy::Packet.new(Jfy::Codes::SEND_ADDRESS, data, :dst => 0x0)
      write(packet)
      packet = read

      fail(BadPacket, 'invalid send address response') unless packet.command == Jfy::Codes::ADDRESS_CONFIRM
      fail(BadPacket, 'No Ack') unless packet.ack?
    end

    def description(serial_num)
      packet = Jfy::Packet.new(Jfy::Codes::READ_DESCRIPTION, [], :dst => serial_num)
      write(packet)
      packet = read

      p packet.command
      fail(BadPacket, 'invalid description response') unless packet.command == Jfy::Codes::READ_DESCRIPTION_RESP

      packet.decode
    end

    def rw_description(serial_num)
      packet = Jfy::Packet.new(Jfy::Codes::READ_RW_DESCRIPTION, [], :dst => serial_num)
      write(packet)
      packet = read

      fail(BadPacket, 'invalid rw description response') unless packet.command == Jfy::Codes::READ_RW_DESCRIPTION_RESP

      packet.decode
    end

    def short(a, b)
      ((a & 0x00ff) << 8) | (b & 0xff)
    end

    def long(a, b, c, d)
      ((a & 0x00ff) << 24) |
        ((b & 0x00ff) << 16) |
        ((c & 0x00ff) << 8) |
        (d & 0xff)
    end

    def query_normal_info
      write(Jfy::Codes::QUERY_NORMAL_INFO)
      packet = read

      fail(BadPacket, 'invalid rw description response') unless packet.command == Jfy::Codes::QUERY_NORMAL_INFO_RESP

      data = packet.data

      case [data[24], data[25]]
      when [0x0, 0x0]
        mode = :wait
      when [0x0, 0x1]
        mode = :normal
      when [0x0, 0x2]
        mode = :warning
      when [0x0, 0x3]
        mode = :error
      else
        fail("Unkown mode #{data[24]} #{data[25]}")
      end

      metrics = {
        :temperature => short(data[0], data[1]) / 10.0,
        :mode        => mode,
        :voltage     => [
          short(data[2], data[3]) / 10.0,
          short(data[4], data[5]) / 10.0,
          short(data[6], data[7]) / 10.0,
          # FIXME: Need to test on larger inverter
          # short(data[28], data[29]) / 10.0,
          # short(data[30], data[31]) / 10.0,
          # short(data[32], data[33]) / 10.0,
          # short(data[40], data[41]) / 10.0,
          # short(data[42], data[43]) / 10.0,
          # short(data[44], data[45]) / 10.0,
        ],
        :current     => [
          short(data[8], data[9]) / 10.0,
          short(data[10], data[11]) / 10.0,
          short(data[12], data[13]) / 10.0,
          # FIXME: Need to test on larger inverter
          # short(data[34], data[35]) / 10.0,
          # short(data[36], data[37]) / 10.0,
          # short(data[38], data[39]) / 10.0,
          # short(data[46], data[47]) / 10.0,
          # short(data[48], data[49]) / 10.0,
          # short(data[50], data[51]) / 10.0,
        ],
        :hours       => long(data[18], data[19], data[20], data[21]),
        :power       => {
          :total => long(data[14], data[15], data[16], data[17]) / 10.0 * 1_000,
          :today => short(data[26], data[27]) / 100.0 * 1_000,
          :now   => short(data[22], data[23]),
        },
      }

      if data.size > 68
        metrics.merge!(
          :fault       => {
            :temperature => short(data[114], data[115]) / 10.0,
            :voltage     => [
              short(data[116], data[117]) / 10.0,
              short(data[118], data[119]) / 10.0,
              short(data[120], data[121]) / 10.0,
            ],
          },
        )
      end

      ap metrics

      metrics
    end

    def query_inverter_info
      write(Jfy::Codes::QUERY_INVERTER_INFO)
      packet = read

      fail(BadPacket, 'invalid inverter info response') unless packet.command == Jfy::Codes::QUERY_INVERTER_INFO_RESP

      data = packet.data

      case data[0]
      when 0x31
        phases = 1
      when 0x33
        phases = 3
      else
        fail("Unknown phase mode #{data[0]}")
      end

      rating = data[1, 6].pack('c*').to_i
      version = data[7, 5].pack('c*')
      model = data[12, 16].pack('c*').strip
      manufacturer = data[28, 16].pack('c*').strip
      serial = data[44, 16].pack('c*').strip
      nominal_voltage = data[60, 4].pack('c*').to_i / 10.0

      metrics = {
        :phases          => phases,
        :rating          => rating,
        :version         => version,
        :model           => model,
        :manufacturer    => manufacturer,
        :serial          => serial,
        :nominal_voltage => nominal_voltage,
      }

      metrics
    end

    # FIXME: Always returns a bad checksum
    # def query_set_info
    #   write(Jfy::Codes::QUERY_SET_INFO)
    #   packet = read

    #   fail(BadPacket, 'invalid set info response') unless packet.command == Jfy::Codes::QUERY_SET_INFO_RESP

    #   data = packet.data

    #   metrics = {
    #     :pv_voltage   => {
    #       :startup   => short(*data[0, 2]) / 10.0,
    #       :high_stop => short(*data[4, 2]) / 10.0,
    #       :low_stop  => short(*data[6, 2]) / 10.0,
    #     },
    #     :grid         => {
    #       :voltage   => {
    #         :min => short(*data[8, 2]) / 10.0,
    #         :max => short(*data[10, 2]) / 10.0,
    #       },
    #       :frequency => {
    #         :min => short(*data[12, 2]) / 100.0,
    #         :max => short(*data[14, 2]) / 100.0,
    #       },
    #       :impedance => {
    #         :max   => short(*data[16, 2]),
    #         :delta => short(*data[18, 2]),
    #       },
    #     },
    #     :power_max    => short(*data[20, 2]),
    #     :power_factor => short(*data[22, 2]) / 100.0,
    #     :connect_time => short(*data[2, 2]),
    #   }

    #   metrics
    # end

    # FIXME: Always returns an error
    # def query_time
    #   write(Jfy::Codes::QUERY_TIME)
    #   packet = read
    #   p packet.command

    #   fail(BadPacket, 'invalid time response') unless packet.command == Jfy::Codes::QUERY_TIME_RESP

    #   data = packet.data
    #   p data

    #   {}
    # end

    private

    def write(packet)
      p packet if @debug

      p packet.packet.pack('c*').unpack('H* ') # TODO: Remove me

      @serial.syswrite(packet.to_s)
    end

    def read
      buffer = []

      # FIXME: be smarter and read the header
      loop do
        char = @serial.getbyte
        fail(ReadTimeout) if char.nil?

        buffer << char

        break if buffer[-2, 2] == [0x0A, 0x0D]

        fail(BadPacket, 'packet too big') if buffer.size > 256
      end

      header = [buffer.shift, buffer.shift]
      fail(BadPacket, 'invalid header') unless header == [0xA5, 0xA5]

      src = buffer.shift
      dst = buffer.shift

      ctrl = buffer.shift
      func = buffer.shift

      size = buffer.shift
      data = buffer.take(size)
      buffer = buffer.drop(size)

      checksum = [buffer.shift, buffer.shift]
      ender = [buffer.shift, buffer.shift]

      packet = Packet.new([ctrl, func], data, :src => src, :dst => dst)
      p packet if @debug

      fail(BadPacket, 'invalid checksum') unless checksum == packet.checksum

      fail(BadPacket, 'invalid ender') unless ender == [0x0A, 0x0D]

      packet
    end
  end
end

