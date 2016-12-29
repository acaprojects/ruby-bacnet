# frozen_string_literal: true, encoding: ASCII-8BIT

require 'bindata'

require 'bacnet/objects'
require 'bacnet/services'
require 'bacnet/npdu'

class BACnet
    Datagram = Struct.new(:header, :request, :objects) do
        def to_binary_s
            data = String.new(header.to_binary_s)
            data << request.to_binary_s

            if objects.empty?
                data << "\x00="
            else
                objects.each { |obj| data << obj.to_binary_s }
            end

            data
        end
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
                request = handler.read(message[npdu.do_num_bytes..-1])
                objects = request.objects(message[(npdu.do_num_bytes + request.do_num_bytes)..-1])
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

    BACnet - iso 16484-5 | ANSI / ASHRAE 135-2010
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
