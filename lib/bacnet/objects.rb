# frozen_string_literal: true, encoding: ASCII-8BIT

class BACnet
    class ObjCharString < BinData::Record
        endian :big

        bit4   :app_tag
        bit1   :context_specific
        bit3   :len,             value: 0b101

        uint8  :object_length, value: -> { text.bytesize + 1 }

        uint8  :format
        string :text, read_length: -> { object_length - 1 }
    end

    class ObjIdentifier < BinData::Record
        endian :big

        bit4   :app_tag
        bit1   :context_specific
        bit3   :len,              value: 4

        bit10  :device_type
        bit22  :instance_number
    end

    class ObjUnsignedInt < BinData::Record
        endian :big

        bit4   :app_tag,          value: 2
        bit1   :context_specific, value: 0
        bit3   :len,              value: 2

        uint16 :data
    end

    class ObjEnum < BinData::Record
        endian :big

        bit4   :app_tag
        bit1   :context_specific
        bit3   :len,              value: 1

        uint8  :data
    end

    class ObjDate < BinData::Record
        endian :big

        bit4   :app_tag,          value: 10
        bit1   :context_specific, value: 0
        bit3   :len,              value: 4

        uint8  :year
        uint8  :month
        uint8  :day
        uint8  :day_of_week
    end

    class ObjTime < BinData::Record
        endian :big

        bit4   :app_tag,          value: 11
        bit1   :context_specific, value: 0
        bit3   :len,              value: 4

        uint8  :hour
        uint8  :minute
        uint8  :second
        uint8  :msecond
    end
    

    class Obj < BinData::Record
        endian :big

        bit4   :app_tag
        bit1   :context_specific
        bit3   :len

        uint8  :object_length, onlyif: -> { len == 5 }
        string :data, read_length: -> { object_length > 0 ? object_length : len }

        MessageTypes = {
            2  => ObjUnsignedInt,
            9  => ObjEnum,
            10 => ObjDate,
            11 => ObjTime,
            12 => ObjIdentifier
        }
        def details(context = nil)
            if len == 5
                ObjCharString.read self.to_binary_s
            elsif context_specific && context
                ctx = Contexts[context]
                if ctx
                    klass = ctx[app_tag]
                    if klass
                        klass.read self.to_binary_s
                    else
                        puts "Unknown object type #{app_tag} in context #{context}"
                        self
                    end
                else
                    puts "Unknown object type #{app_tag} in unknown context #{context}"
                    self
                end
            else
                klass = MessageTypes[app_tag]
                if klass
                    klass.read self.to_binary_s
                else
                    puts "Unknown object type #{app_tag}"
                    self
                end
            end
        end

        # These are the service IDs
        Contexts = {
            restart_device: {
                0 => ObjEnum,         # Type of reboot (0 == cold start)
                1 => ObjCharString    # Password
            },
            device_comms_control: {
                1 => ObjEnum,         # Enabled / Disabled
                2 => ObjCharString    # Password
            },
            who_has: {
                2 => ObjIdentifier,
                3 => ObjCharString
            }
        }
    end
end
