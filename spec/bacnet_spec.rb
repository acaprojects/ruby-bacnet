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
        @bacnet.read("\x81\xa\x0\xb\x10\x7\x2c\x2\x0\x0\x3d")

        expect(@dgrams.length).to be(1)
        dgram = @dgrams[0]

        expect(dgram.request.nil?).to be(false)
        expect(dgram.request.service).to be(:acknowledge_alarm)

        expect(dgram.objects.length).to be(0)
    end

    it "should parse an error message" do
        @bacnet.read("\x81\x0a\x00\x12\x01\x20\x00\x0d\x01\x3d\xff\x50\x34\x14\x91\x05\x91\x1a")

        expect(@dgrams.length).to be(1)
        dgram = @dgrams[0]

        expect(dgram.request.nil?).to be(false)
        expect(dgram.request.service).to be(:reinitialize_device)
        expect(dgram.request.class).to be(::BACnet::Error)
        expect(dgram.request.reason).to eq('password failure (services error 5:26)')

        expect(dgram.objects.length).to be(0)
    end

    it "should parse a reject message" do
        @bacnet.read("\x81\x0a\x00\x0e\x01\x20\x00\x0d\x01\x3d\xff\x60\x3b\x09")

        expect(@dgrams.length).to be(1)
        dgram = @dgrams[0]

        expect(dgram.request.nil?).to be(false)
        expect(dgram.request.service).to be(:unrecognized_service)
        expect(dgram.request.class).to be(::BACnet::Reject)

        expect(dgram.objects.length).to be(0)
    end

    it "should parse an unconfirmed 'who has' message" do
        @bacnet.read("\x81\xa\x0\x16\x1\x20\xff\xff\x0\xff\x10\x7\x3d\x8\x00SYNERGY")

        expect(@dgrams.length).to be(1)
        dgram = @dgrams[0]

        expect(dgram.request.nil?).to be(false)
        expect(dgram.request.service).to be(:who_has)

        expect(dgram.objects.length).to be(1)
        expect(dgram.objects[0].get_value).to eq("SYNERGY")
    end

    it "should parse a confirmed message with multiple objects" do
        @bacnet.read("\x81\xa\x0\x1c\x1\x24\x0\xd\x1\x3d\xff\x0\x3\x1\x11\x19\x0\x2d\x9\x00filister")

        expect(@dgrams.length).to be(1)
        dgram = @dgrams[0]

        expect(dgram.header.destination.mac_address_length).to eq(1)
        expect(dgram.header.destination.mac_address.length).to be(1)
        expect(dgram.header.hop_count).to eq(255)

        expect(dgram.request.nil?).to be(false)
        expect(dgram.request.service).to be(:device_communication_control)

        expect(dgram.objects.length).to be(2)
        expect(dgram.objects[0].get_value).to eq(0)
        expect(dgram.objects[1].get_value).to eq("filister")
    end

    it "should parse a complex ack message" do
        @bacnet.read("\x81\x0a\x00\x26\x01\x08\x00\x0d\x01\x3d\x30\x01\x0c\x0c\x00\x40\x00\x65\x19\x57\x3e\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x3f")
        expect(@dgrams.length).to be(1)
        dgram = @dgrams[0]

        expect(dgram.objects[0].get_value.class).to be(::BACnet::ObjectIdentifier)
        expect(dgram.objects[1].get_value.class).to be(::BACnet::PropertyIdentifier)
        expect(dgram.objects[2].get_value).to be(:opening_tag)
        expect(dgram.objects[3].get_value).to be(nil)

        expect(dgram.objects.length).to be(20)
    end

    it "should output valid datagrams" do
        @bacnet.read("\x81\xa\x0\x16\x1\x20\xff\xff\x0\xff\x10\x7\x3d\x8\x00SYNERGY")
        expect(@dgrams[0].to_binary_s).to eq("\x81\xa\x0\x16\x1\x20\xff\xff\x0\xff\x10\x7\x3d\x8\x00SYNERGY")

        @bacnet.read("\x81\xa\x0\x1c\x1\x24\x0\xd\x1\x3d\xff\x0\x3\x1\x11\x19\x0\x2d\x9\x00filister")
        expect(@dgrams[1].to_binary_s).to eq("\x81\xa\x0\x1c\x1\x24\x0\xd\x1\x3d\xff\x0\x3\x1\x11\x19\x0\x2d\x9\x00filister")

        @bacnet.read("\x81\xa\x0\xb\x10\x7\x2c\x2\x0\x0\x3d")
        expect(@dgrams[2].to_binary_s).to eq("\x81\xa\x0\xb\x10\x7\x2c\x2\x0\x0\x3d")

        complex_ack = "\x81\x0a\x00\x26\x01\x08\x00\x0d\x01\x3d\x30\x01\x0c\x0c\x00\x40\x00\x65\x19\x57\x3e\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x3f"
        @bacnet.read(complex_ack)
        expect(@dgrams[3].to_binary_s).to eq(complex_ack)
    end
end
