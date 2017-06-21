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
            uint8  :mac_address_length
            string :mac_address, onlyif: -> { destination.mac_address_length.nonzero? }, read_length: -> { destination.mac_address_length }
        end

        struct :source, onlyif: -> { source_specifier.nonzero? } do
            uint16 :address
            uint8  :mac_address_length
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
    end
end
