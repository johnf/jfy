require 'jfy/packet'
require 'jfy/codes'
require 'jfy/errors'

require 'serialport'

module Jfy
  class Client
    def initialize(options = {})
      serial_port = options[:serial_port] || '/dev/ttyUSB0'
      baud = options[:baud] || 9600
      @debug = options[:debug] || false

      @serial = SerialPort.new(serial_port, :baud => baud)

      @serial.flush_output
      @serial.flush_input
      @serial.read_timeout = 1_000

      @last_write = Time.now
    end

    def re_register
      packet = Packet.new(Jfy::Codes::RE_REGISTER, [], :dst => 0x0)
      write(packet, :read => false)
    end

    def offline_query
      packet = Packet.new(Jfy::Codes::OFFLINE_QUERY, [], :dst => 0x0)
      packet = write(packet)

      fail(BadPacket, 'invalid offline response') unless packet.command == Jfy::Codes::REGISTER_REQUEST

      packet.decode
    end

    def register(serial_num, address)
      data = serial_num.unpack('c*') << address
      packet = Jfy::Packet.new(Jfy::Codes::SEND_ADDRESS, data, :dst => 0x0)
      packet = write(packet)

      fail(BadPacket, 'invalid send address response') unless packet.command == Jfy::Codes::ADDRESS_CONFIRM
      fail(BadPacket, 'No Ack') unless packet.ack?
    end

    def description(serial_num)
      packet = Jfy::Packet.new(Jfy::Codes::READ_DESCRIPTION, [], :dst => serial_num)
      packet = write(packet)

      fail(BadPacket, 'invalid description response') unless packet.command == Jfy::Codes::READ_DESCRIPTION_RESP

      packet.decode
    end

    def rw_description(serial_num)
      packet = Jfy::Packet.new(Jfy::Codes::READ_RW_DESCRIPTION, [], :dst => serial_num)
      packet = write(packet)

      fail(BadPacket, 'invalid rw description response') unless packet.command == Jfy::Codes::READ_RW_DESCRIPTION_RESP

      packet.decode
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def query_normal_info(serial_num)
      packet = Jfy::Packet.new(Jfy::Codes::QUERY_NORMAL_INFO, [], :dst => serial_num)
      packet = write(packet)

      fail(BadPacket, 'invalid query normal info response') unless packet.command == Jfy::Codes::QUERY_NORMAL_INFO_RESP

      data = packet.data

      modes = {
        [0x0, 0x0] => :wait,
        [0x0, 0x1] => :normal,
        [0x0, 0x2] => :warning,
        [0x0, 0x3] => :error,
      }
      mode = modes[data[24, 2]] || fail("Unkown mode #{data[24]} #{data[25]}")

      metrics = {
        :temperature => short(data, 0) / 10.0,
        :mode        => mode,
        :voltage     => [
          short(data, 2) / 10.0,
          short(data, 4) / 10.0,
          short(data, 6) / 10.0,
          # FIXME: Need to test on larger inverter
          # short(data, 28) / 10.0,
          # short(data, 30) / 10.0,
          # short(data, 32) / 10.0,
          # short(data, 40) / 10.0,
          # short(data, 42) / 10.0,
          # short(data, 44) / 10.0,
        ],
        :current     => [
          short(data, 8) / 10.0,
          short(data, 10) / 10.0,
          short(data, 12) / 10.0,
          # FIXME: Need to test on larger inverter
          # short(data, 34) / 10.0,
          # short(data, 36) / 10.0,
          # short(data, 38) / 10.0,
          # short(data, 46) / 10.0,
          # short(data, 48) / 10.0,
          # short(data, 50) / 10.0,
        ],
        :hours       => long(data, 18),
        :power       => {
          :total => long(data, 14) / 10.0 * 1_000,
          :today => short(data, 26) / 100.0 * 1_000,
          :now   => short(data, 22),
        },
      }

      if data.size > 68
        metrics.merge!(
          :fault => {
            :temperature => short(data, 114) / 10.0,
            :voltage     => [
              short(data, 116) / 10.0,
              short(data, 118) / 10.0,
              short(data, 120) / 10.0,
            ],
          },
        )
      end

      metrics
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def query_inverter_info(serial_num)
      packet = Jfy::Packet.new(Jfy::Codes::QUERY_INVERTER_INFO, [], :dst => serial_num)
      packet = write(packet)

      fail(BadPacket, 'invalid inverter info response') unless packet.command == Jfy::Codes::QUERY_INVERTER_INFO_RESP

      data = packet.data

      phase_types = {
        0x31 => 1,
        0x33 => 3,
      }
      phases = phase_types[data[0]] || fail("Unknown phase mode #{data[0]}")

      rating          = data[1, 6].pack('c*').to_i
      version         = data[7, 5].pack('c*')
      model           = data[12, 16].pack('c*').strip
      manufacturer    = data[28, 16].pack('c*').strip
      serial          = data[44, 16].pack('c*').strip
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
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def query_set_info(serial_num)
      packet = Jfy::Packet.new(Jfy::Codes::QUERY_SET_INFO, [], :dst => serial_num)
      packet = write(packet)

      fail(BadPacket, 'invalid set info response') unless packet.command == Jfy::Codes::QUERY_SET_INFO_RESP

      data = packet.data

      metrics = {
        :pv_voltage   => {
          :startup   => short(data, 0) / 10.0,
          :high_stop => short(data, 4) / 10.0,
          :low_stop  => short(data, 6) / 10.0,
        },
        :grid         => {
          :voltage   => {
            :min => short(data, 8) / 10.0,
            :max => short(data, 10) / 10.0,
          },
          :frequency => {
            :min => short(data, 12) / 100.0,
            :max => short(data, 14) / 100.0,
          },
          :impedance => {
            :max   => short(data, 16) / 1_000.0,
            :delta => short(data, 18),
          },
        },
        :power_max    => short(data, 20),
        :power_factor => short(data, 22) / 100.0,
        :connect_time => short(data, 2),
      }

      metrics
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private

    def short(data, offset)
      a, b = data[offset, 2]

      ((a & 0x00ff) << 8) | (b & 0xff)
    end

    def long(data, offset)
      a, b, c, d = data[offset, 4]

      ((a & 0x00ff) << 24) |
        ((b & 0x00ff) << 16) |
        ((c & 0x00ff) << 8) |
        (d & 0xff)
    end

    def write(packet, options = {})
      p packet if @debug

      wait
      @serial.syswrite(packet.to_s)
      @last_write = Time.now

      read unless options[:read] == false
    end

    def wait
      diff = Time.now - @last_write

      return unless diff < 0.5

      sleep(0.5 - diff)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def read
      buffer = []

      loop do
        char = @serial.getbyte
        fail(ReadTimeout) if char.nil?

        buffer << char

        fail(BadPacket, 'invalid header') if buffer.size == 2 && buffer != [0xA5, 0xA5]

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

      # TODO: My unit seems to return the wrong size here (Maybe we should have an option if not all units do this)
      size -= 2 if [ctrl, func] == Jfy::Codes::QUERY_SET_INFO_RESP

      data = buffer.take(size)
      buffer = buffer.drop(size)

      checksum = [buffer.shift, buffer.shift]
      ender = [buffer.shift, buffer.shift]

      packet = Packet.new([ctrl, func], data, :src => src, :dst => dst)
      p packet if @debug

      fail(BadPacket, 'invalid checksum') if checksum != packet.checksum &&
                                             [ctrl, func] != Jfy::Codes::QUERY_SET_INFO_RESP

      fail(BadPacket, 'invalid ender') unless ender == [0x0A, 0x0D]

      packet
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  end
end
