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
  end
end
