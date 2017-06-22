# frozen_string_literal: true, encoding: ASCII-8BIT

require 'bindata'

require 'bacnet/objects'
require 'bacnet/services'
require 'bacnet/npdu'

class BACnet
    Datagram = Struct.new(:header, :request, :objects) do
        def to_binary_s
            data = String.new(request.to_binary_s)

            if objects.empty?
                data << "\x00="
            else
                objects.each { |obj| data << obj.to_binary_s }
            end

            length = data.bytesize + header.do_num_bytes - 1
            header.request_length = length.to_i

            # ignore the overlapping byte
            "#{header.to_binary_s[0..-2]}#{data}"
        end
    end


    def self.new_datagram(message, *objects)
        data = Datagram.new

        npdu = NPDU.new
        npdu.protocol = 0x81
        npdu.request_type = 0x0A
        npdu.version = 0x01

        data.header = npdu
        data.request = message
        data.objects = objects
        data
    end


    def initialize(callback = nil, **options, &blk)
        @buffer = String.new
        @callback = callback || blk
    end

    def read(data, **options)
        @buffer << data
        npdu = begin
            NPDU.read(@buffer)
        rescue IOError
            return
        end
        error = nil

        while @buffer.length >= npdu.request_length
            message = @buffer[0..npdu.request_length]
            @buffer = @buffer[npdu.request_length..-1]

            handler = npdu.payload_handler
            objects = []
            request = nil

            if handler
                # We overlapped the NPDU and APDU by 1 byte
                # as message type and flags are in the same byte
                start_byte = npdu.do_num_bytes - 1
                request = handler.read(message[start_byte..-1])

                start_byte = npdu.do_num_bytes + request.do_num_bytes - 1
                objects = request.objects(message[start_byte..-1])
            else
                puts "unknown request type #{npdu.message_type}"
            end

            dgram = Datagram.new(npdu, request, objects)
            begin
                @callback.call(dgram)
            rescue => e
                error = e
            end

            # rescue when there is not enough data to process the packet
            if @buffer.length > 0
                begin
                    npdu = NPDU.read(@buffer)
                rescue IOError
                    break
                end
            else
                break
            end
        end

        raise error if error
        nil
    end
end

=begin

    BACnet - iso 16484-5 | ANSI / ASHRAE 135-2016
    - objects (values, inputs and outputs)
      - properties (parts of an object with actual values)
    - services (request + response Protocol Data Units or PDU)
      - alarm / events (change thresholds or alarms with trigger levels, calendar + schedule events)
      - file access
      - object access
      - device management
      - virtual terminals

    UDP 47808 (0xBAC0)
    + instance number, unique on a network
    + vendor id lookup
    + device object is always present (object type 8)
    + read property service is always present

    Discover devices:
    - broadcast who-is (service)
    - devices broadcast respond i-am (service)


    NPDU == network layer
    APDU == application layer. Encapsulated in the NPDU

=end
