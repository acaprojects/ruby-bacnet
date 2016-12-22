# frozen_string_literal: true, encoding: ASCII-8BIT

require 'bacnet'


describe "bacnet protocol helper" do
    before :each do
        @dgrams = []
        @bacnet = BACnet.new do |dgram|
            @dgrams << dgram
        end
    end

    it "should parse a simple ack message" do
        datagram = @bacnet.read("\x81\xa\x0\xb\x10\x7\x2c\x2\x0\x0\x3d")

        expect(@dgrams.length).to be(1)
        dgram = @dgrams[0]

        expect(dgram.request.nil?).to be(false)
        expect(dgram.request.service).to be(:acknowledge_alarm)

        expect(dgram.objects.length).to be(0)
    end

    it "should parse an unconfirmed 'who has' message" do
        datagram = @bacnet.read("\x81\xa\x0\x16\x1\x20\xff\xff\x0\xff\x10\x7\x3d\x8\x00SYNERGY")

        expect(@dgrams.length).to be(1)
        dgram = @dgrams[0]

        expect(dgram.request.nil?).to be(false)
        expect(dgram.request.service).to be(:who_has)

        expect(dgram.objects.length).to be(1)
        expect(dgram.objects[0].text).to eq("SYNERGY")
    end

    it "should parse a confirmed message with multiple objects" do
        datagram = @bacnet.read("\x81\xa\x0\x1c\x1\x24\x0\xd\x1\x3d\xff\x0\x3\x1\x11\x19\x0\x2d\x9\x00filister")

        expect(@dgrams.length).to be(1)
        dgram = @dgrams[0]

        expect(dgram.header.destination.mac_address_length).to eq(1)
        expect(dgram.header.destination.mac_address.length).to be(1)
        expect(dgram.header.hop_count).to eq(255)

        expect(dgram.request.nil?).to be(false)
        expect(dgram.request.service).to be(:device_comms_control)

        expect(dgram.objects.length).to be(2)
        expect(dgram.objects[0].data).to eq(0)
        expect(dgram.objects[1].text).to eq("filister")
    end
end
