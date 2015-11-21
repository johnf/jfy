require 'spec_helper'

require 'jfy/codes'
require 'jfy/packet'

describe Jfy::Packet do
  describe 'creates a packet' do
    subject(:packet) { described_class.new(Jfy::Codes::QUERY_INVERTER_INFO) }

    it 'header' do
      expect(packet.instance_variable_get(:@header)).to eq([0xA5, 0xA5])
    end

    it 'src' do
      expect(packet.instance_variable_get(:@src)).to eq(0x01)
    end

    it 'dst' do
      expect(packet.instance_variable_get(:@dst)).to eq(0x01)
    end

    it 'command' do
      expect(packet.command).to eq(Jfy::Codes::QUERY_INVERTER_INFO)
    end

    it 'ctrl' do
      expect(packet.instance_variable_get(:@ctrl)).to eq(Jfy::Codes::QUERY_INVERTER_INFO.first)
    end

    it 'func' do
      expect(packet.instance_variable_get(:@func)).to eq(Jfy::Codes::QUERY_INVERTER_INFO.last)
    end

    it 'data' do
      expect(packet.instance_variable_get(:@data)).to be_empty
    end

    it 'ender' do
      expect(packet.instance_variable_get(:@ender)).to eq([0x0A, 0x0D])
    end

    it 'checkum' do
      expect(packet.checksum).to eq([0xFE, 0x40])
    end

    it 'ack' do
      expect(packet).to_not be_ack
    end
  end

  describe 'creates an ack packet' do
    subject(:packet) { described_class.new(Jfy::Codes::ADDRESS_CONFIRM, [0x06]) }

    it 'data' do
      expect(packet.instance_variable_get(:@data)).to eq([0x06])
    end

    it 'ack' do
      expect(packet).to be_ack
    end
  end

  describe 'decodes packet data' do
    subject(:packet) { described_class.new(Jfy::Codes::READ_DESCRIPTION_RESP, [0x6D, 0x6F, 0x6F]) }

    it 'decode' do
      expect(packet.decode).to eq('moo')
    end

    it 'to_s' do
      data = [0xA5, 0xA5, 0x01, 0x01, 0x31, 0xBF, 0x03, 0x6D, 0x6F, 0x6F, 0xFC, 0x76, 0x0A, 0x0D]
      expect(packet.to_s).to eq(data.pack('c*'))
    end

    it 'inspect' do
      data = /<Jfy::Packet:0x[a-f0-9]{12} @ctrl=0x31 @func=0xBF @data=\[moo\] @hex=\[0x6d 0x6f 0x6f\]>/
      expect(packet.inspect).to match(data)
    end
  end
end
