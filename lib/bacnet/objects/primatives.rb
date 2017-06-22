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

    class ContextSpecificBoolean < SimplePrimative
        def self.read(data)
            self.new(data.bytes[0] == 1)
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
end
