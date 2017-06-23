# frozen_string_literal: true, encoding: ASCII-8BIT

class BACnet
    # Network Protocol Data Unit
    class NPDU < BinData::Record
        endian :big

        uint8  :protocol
        uint8  :request_type
        uint16 :request_length
        uint8  :version

        bit1   :is_group_address
        bit1   :reserved_1,  value: 0
        bit1   :destination_specifier  # Contains a destination address
        bit1   :reserved_2,  value: 0
        bit1   :source_specifier       # Contains a source address
        bit1   :expecting_reply
        bit2   :priority

        struct :destination, onlyif: -> { destination_specifier.nonzero? } do
            uint16 :address
            uint8  :mac_address_length, value: -> { destination.mac_address.bytesize }
            string :mac_address, onlyif: -> { destination.mac_address_length.nonzero? }, read_length: -> { destination.mac_address_length }
        end

        struct :source, onlyif: -> { source_specifier.nonzero? } do
            uint16 :address
            uint8  :mac_address_length, value: -> { source.mac_address.bytesize }
            string :mac_address, onlyif: -> { source.mac_address_length.nonzero? }, read_length: -> { source.mac_address_length }
        end

        uint8  :hop_count, onlyif: -> { destination_specifier.nonzero? }

        # Technically the start of the APDU
        MessageTypes = {
            0 => ConfirmedRequest,
            1 => UnconfirmedRequest,
            2 => SimpleACK,
            3 => ComplexACK,
            4 => SegmentACK,
            5 => Error,
            6 => Reject,
            7 => Abort
        }
        bit4   :message_type
        bit4   :flags

        def payload_handler
            MessageTypes[message_type]
        end

        def destination_mac
            return nil if destination_specifier == 0
            read_mac destination
        end

        def destination_mac=(address)
            assign_mac(destination, address)
            self.destination_specifier = 1 if destination.mac_address.length > 0
        end

        def source_mac
            return nil if source_specifier == 0
            read_mac source
        end

        def source_mac=(address)
            assign_mac(source, address)
            self.source_specifier = 1 if source.mac_address.length > 0
        end


        protected


        def read_mac(struct)
            if struct.mac_address_length == 1
                struct.mac_address.bytes[0]
            else # assume ethernet address
                struct.mac_address.unpack('H*')[0]
            end
        end

        def assign_mac(struct, address)
            if address.is_a?(Integer)
                struct.mac_address = address.chr
            elsif address.length == 6
                # already binary
                struct.mac_address = address
            else # assume hex string
                struct.mac_address = hex_to_byte(address)
            end
        end

        def hex_to_byte(data)
            # Removes invalid characters
            data = data.gsub(/(0x|[^0-9A-Fa-f])*/, "")

            # Ensure we have an even number of characters
            data.prepend('0') if data.length % 2 > 0

            # Convert to binary string
            [data].pack('H*')
        end
    end
end
