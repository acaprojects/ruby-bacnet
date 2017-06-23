# frozen_string_literal: true, encoding: ASCII-8BIT

require 'bindata'

require 'bacnet/objects'
require 'bacnet/services'
require 'bacnet/npdu'

class BACnet
    Datagram = Struct.new(:header, :request, :objects, :junk) do
        def to_binary_s
            data = String.new(request.to_binary_s)
            objects.each { |obj| data << obj.to_binary_s }

            # This is data we were unable to parse
            # might be required?
            data << junk if junk

            # We don't want to force these at all times
            header.destination_specifier = 1 if header.destination.address > 0
            header.source_specifier = 1      if header.source.address > 0

            # Force length
            length = data.bytesize + header.do_num_bytes - 1
            header.request_length = length.to_i

            # Ensure other fields are set
            header.protocol = 0x81 if header.protocol == 0
            header.version = 0x01 if header.version == 0

            # ignore the overlapping byte
            "#{header.to_binary_s[0..-2]}#{data}"
        end

        def add(obj, tag: nil)
            self.objects ||= []
            wrapper = Obj.new
            wrapper.data = obj.to_binary_s

            if tag
                wrapper.context_specific = 1

                if tag >= 0x0F
                    wrapper.tag = 0x0F
                    wrapper.ext_tag = tag
                else
                    wrapper.tag = tag
                end
            else
                wrapper.tag = Obj::MessageTypes[obj.class]
            end
            self.objects << wrapper
            self.objects.length
        end
    end


    def self.new_datagram(message, destination: 0, destination_mac: '', source: 0,
                            source_mac: '', is_group_address: 0, priority: 0,
                            hop_count: 0xFF, objects: [], request_type: :original_unicast_npdu)
        data = Datagram.new
        npdu = NPDU.new
        npdu.request_type = request_type
        npdu.priority = priority
        npdu.hop_count = hop_count
        npdu.is_group_address = is_group_address
        npdu.destination.address = destination
        npdu.destination_mac = destination_mac
        npdu.source.address = source
        npdu.source_mac = source_mac

        data.header = npdu
        data.request = message
        data.objects = Array(objects)
        data
    end

    def self.confirmed_req( destination:, service:, destination_mac: '', source: 0,
                            source_mac: '', is_group_address: 0, priority: 0,
                            hop_count: 0xFF, invoke_id: 1, objects: [],
                            request_type: :original_unicast_npdu)
        
        cr = ConfirmedRequest.new
        cr.segmented_message = 0
        cr.more_follows = 0
        cr.segmented_response_accepted = 1
        cr.max_response_segments = 0
        cr.max_size = 5 # max response size: 1476 bytes
        cr.invoke_id = invoke_id
        cr.service_id = ConfirmedRequest::ServiceIds[service.to_sym]

        data = new_datagram(cr,
                destination: destination, destination_mac: destination_mac, source: source,
                source_mac: source_mac, is_group_address: is_group_address, priority: priority,
                hop_count: hop_count, objects: objects, request_type: request_type)

        data.header.expecting_reply = 1
        data
    end

    def self.unconfirmed_req(destination:, service:, destination_mac: '', source: 0,
                            source_mac: '', is_group_address: 0, priority: 0,
                            hop_count: 0xFF, objects: [], request_type: :original_unicast_npdu)

        # TODO:: simplify creating broadcast requests

        ucr = UnconfirmedRequest.new
        ucr.service_id = UnconfirmedRequest::ServiceIds[service.to_sym]

        new_datagram(ucr,
                destination: destination, destination_mac: destination_mac, source: source,
                source_mac: source_mac, is_group_address: is_group_address, priority: priority,
                hop_count: hop_count, objects: objects, request_type: request_type)
    end

    def self.build_array(*objects)
        current = []
        arrays = [current]
        prev = nil
        objects.each do |obj|
            val = obj.get_value(prev)
            if val == :opening_tag
                arr = []
                current << arr
                current = arr
                arrays << current
            elsif val == :closing_tag
                current = arrays.pop unless arrays.length < 2
            else
                current << val
            end
            prev = val
        end

        arrays[0]
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
                objects, data = request.objects(message[start_byte..-1])
            else
                puts "unknown request type #{npdu.message_type}"
            end

            dgram = Datagram.new(npdu, request, objects, data)
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
