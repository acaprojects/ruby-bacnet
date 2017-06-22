# frozen_string_literal: true, encoding: ASCII-8BIT

class BACnet
    class SimplePrimative
        def initialize(value)
            @value = value
        end
        attr_reader :value
    end

    class Null < SimplePrimative
        def self.read(_)
            self.new(nil)
        end
    end

    class Boolean < SimplePrimative
        def self.read(data)
            self.new(data.bytesize == 1)
        end
    end

    class BitString < SimplePrimative
        def self.read(data)
            bytes = data.bytes
            remainder = bytes.shift

            return self.new([]) if bytes.length == 0
            numbits = bytes.length * 8 - remainder
            bools = []
            numbits.times do |i|
                bools << ((bytes[i / 8] >> (7 - (i % 8))) & 0x1) == 1
            end
            self.new(bools)
        end
    end

    # represents a variable bit length integer
    class UnsignedInt < SimplePrimative
        # Can be an arbitrarily long integer
        def self.read(data)
            val = 0
            len = data.bytesize - 1
            data.bytes.each_with_index do |byte, index|
                val |= ((byte & 0xff) << ((len - index) * 8))
            end

            self.new(val)
        end
    end

    class SignedInt < SimplePrimative
        # Can be an arbitrarily long integer
        def self.read(data)
            bytes = data.bytes
            negative = (bytes[0] & 0b10000000) > 0

            if negative
                val = 0
                len = data.bytesize - 1
                bytes.each_with_index do |byte, index|
                    # Invert each byte
                    val |= ((~byte & 0xff) << ((len - index) * 8))
                end

                # Complete the 2's compliment conversion
                return self.new(-(val + 1))
            end

            UnsignedInt.read(data)
        end
    end

    class Real < SimplePrimative
        def self.read(data)
            # single-precision, network (big-endian) byte order
            self.new(data.unpack('g')[0])
        end
    end

    class Double < SimplePrimative
        def self.read(data)
            # double-precision, network (big-endian) byte order
            self.new(data.unpack('G')[0])
        end
    end

    class OctetString < SimplePrimative
        def self.read(data)
            self.new(data.force_encoding(::Encoding::BINARY))
        end
    end

    class CharString < SimplePrimative
        Encodings = {
            0 => ::Encoding::UTF_8,        # ANSI_X3_4
            1 => ::Encoding::UTF_16,       # IBM_MS_DBCS
            2 => ::Encoding::EUC_JISX0213, # JIS_C_6226
            3 => ::Encoding::UCS_4BE,      # ISO_10646_UCS_4
            4 => ::Encoding::UCS_2BE,      # ISO_10646_UCS_2
            5 => ::Encoding::ISO8859_1
        }

        # Can be an arbitrarily long integer
        def self.read(data)
            format = data.bytes[0]

            enc = Encodings[format]
            return self.new(data[1..-1].force_encoding(enc)) if enc
            self.new(data[1..-1])
        end
    end

    class Identifier < BinData::Record
        endian :big

        bit10  :object_type
        bit22  :instance_number

        ObjectType = {
            analog_input: 0,
            analog_output: 1,
            analog_value: 2,
            binary_input: 3,
            binary_output: 4,
            binary_value: 5,
            calendar: 6,
            command: 7,
            device: 8,
            event_enrollment: 9,
            file: 10,
            group: 11,
            loop: 12,
            multi_state_input: 13,
            multi_state_output: 14,
            notification_class: 15,
            program: 16,
            schedule: 17,
            averaging: 18,
            multi_state_value: 19,
            trend_log: 20,
            life_safety_point: 21,
            life_safety_zone: 22,
            accumulator: 23,
            pulse_converter: 24,
            event_log: 25,
            global_group: 26,
            trend_log_multiple: 27,
            load_control: 28,
            structured_view: 29,
            access_door: 30,
            timer: 31,
            access_credential: 32,
            access_point: 33,
            access_rights: 34,
            access_user: 35,
            access_zone: 36,
            credential_data_input: 37,
            network_security: 38,
            bitstring_value: 39,
            characterstring_value: 40,
            date_pattern_value: 41,
            date_value: 42,
            datetime_pattern_value: 43,
            datetime_value: 44,
            integer_value: 45,
            large_analog_value: 46,
            octetstring_value: 47,
            positive_integer_value: 48,
            time_pattern_value: 49,
            time_value: 50,
            notification_forwarder: 51,
            alert_enrollment: 52,
            channel: 53,
            lighting_output: 54,
            binary_lighting_output: 55,
            network_port: 56,
            elevator_group: 57,
            escalator: 58,
            lift: 59
        }
        ObjectType.merge!(ObjectType.invert)

        def type
            ObjectType[object_type] || :unknown
        end

        def value; self; end
    end

    class Date < BinData::Record
        endian :big

        uint8  :year_raw
        uint8  :month
        uint8  :day
        uint8  :day_of_week # Monday == 1, Sunday == 7

        UnspecifiedYear = 255
        UnspecifiedDay = 255
        LastDayOfMonth = 32

        def year
            year_raw + 1900
        end
    end

    class Time < BinData::Record
        endian :big

        Unspecified = 255

        uint8  :hour
        uint8  :minute
        uint8  :second
        uint8  :hundredth

        def value; self; end
    end


    class Obj < BinData::Record
        endian :big

        bit4   :tag
        bit1   :context_specific
        bit3   :uint3_length, value: -> { data.bytesize > 4 ? 5 : data.bytesize }
        uint8  :ext_tag,     onlyif: -> { tag == 0x0F }

        uint8  :uint8_length,  onlyif: -> { uint3_length == 5   }, value: -> { data.bytesize > 253 ? (data.bytesize > 65535 ? 255 : 254) : data.bytesize }
        uint16 :uint16_length, onlyif: -> { uint8_length == 254 }, value: -> { data.bytesize }
        uint32 :uint32_length, onlyif: -> { uint8_length == 255 }, value: -> { data.bytesize }

        string :data, read_length: -> {
            if uint32_length.value && uint32_length.value > 0
                uint32_length
            elsif uint16_length.value && uint16_length.value > 0
                uint16_length
            elsif uint8_length.value && uint8_length.value > 0
                uint8_length
            else
                uint3_length
            end
        }

        MessageTypes = {
            0 => Null,
            1 => Boolean,
            2 => UnsignedInt,
            3 => SignedInt,
            4 => Real,
            5 => Double,
            6 => OctetString, # OctetString
            7  => CharString,
            8  => BitString,
            9  => UnsignedInt, # Enum response
            10 => Date,
            11 => Time,
            12 => Identifier
        }

        attr_accessor :context

        def get_value
            tag_actual = ext_tag == 0 ? tag : ext_tag

            @value ||= if context_specific > 0
                ctx = Contexts[context]
                if ctx
                    klass = ctx[tag_actual]
                    if klass
                        klass.read data
                    else
                        puts "Unknown object type #{tag_actual} in context #{context}"
                        self
                    end
                else
                    puts "Unknown object type #{tag_actual} in unknown context #{context}"
                    self
                end
            else
                klass = MessageTypes[tag_actual]
                if klass
                    klass.read data
                else
                    puts "Unknown object type #{tag_actual}"
                    self
                end
            end
            @value.value
        end

        def value
            data
        end

        # These are the service IDs
        Contexts = {
            restart_device: {
                0 => UnsignedInt,  # Type of reboot (0 == cold start)
                1 => CharString    # Password
            },
            device_communication_control: {
                1 => UnsignedInt,  # Enabled / Disabled
                2 => CharString    # Password
            },
            who_has: {
                2 => Identifier,
                3 => CharString
            }
        }
    end
end
