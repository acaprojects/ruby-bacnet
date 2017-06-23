# frozen_string_literal: true, encoding: ASCII-8BIT

require 'bacnet/objects/primatives'
require 'bacnet/objects/identifiers'
require 'bacnet/objects/time'

class BACnet
    class Obj < BinData::Record
        endian :big

        bit4   :tag
        bit1   :context_specific
        bit3   :uint3_length, value: -> { data.bytesize > 0 ? (data.bytesize > 4 ? 5 : data.bytesize) : (@obj.parent.named_tag_value ? @obj.parent.named_tag_value : 0 ) }
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
            elsif uint3_length.value < 5
                uint3_length
            else
                # NOTE:: a bit of a hack here to store the named tag value
                @obj.parent.named_tag_value = uint3_length.value
                0 # named tag (wtf is up with this protocol!)
            end
        }

        MessageTypes = {
            0  => Null,
            1  => Boolean,
            2  => UnsignedInt,
            3  => SignedInt,
            4  => Real,
            5  => Double,
            6  => OctetString, # OctetString
            7  => CharString,
            8  => BitString,
            9  => UnsignedInt, # Enum response
            10 => Date,
            11 => Time,
            12 => ObjectIdentifier
        }
        MessageTypes.merge!(MessageTypes.invert)

        attr_accessor :context

        def get_value(prev = nil)
            begin
                tag_actual = ext_tag == 0 ? tag : ext_tag

                @value ||= if context_specific > 0
                    return value if @named_tag_value

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
                return @value.value(prev) if @value.method(:value).arity != 0
                @value.value
            rescue => e
                puts "failure parsing object tag #{tag_actual} in context #{context} - context specific? #{context_specific > 0}"
                self
            end
        end

        def raw_value
            get_value
            @value
        end

        def value
            if context && @named_tag_value
                return :opening_tag if @named_tag_value == 6
                return :closing_tag #  @named_tag_value == 7
            else
                data
            end
        end

        def is_named_tag?
            !!@named_tag_value
        end

        attr_reader :named_tag_value

        def named_tag_value=(value)
            val = value.to_i
            raise 'invalid named tag' unless [6, 7].include?(val)
            @named_tag_value = val
        end

        # These are the service IDs
        Contexts = {
            get_alarm_summary: {
                0 => ObjectIdentifier,
                1 => UnsignedInt, # Enum: 0=normal,1=fault,2=offnormal,3=highlimit,4=lowlimit,5=lifesafetyalarm
                2 => BitString    # 0=toOffnormal,1=toFault,2=toNormal
            },
            get_enrollment_summary: {
                0 => ObjectIdentifier,
                # EventType Enum: 0=changeOfBitstring,1=changeOfState,2=changeOfValue,3=commandFailure,4=floatingLimit,
                #  5=outOfRange,8=changeOfLifeSafety,9=extended,10=bufferReady,11=unsignedRange,13=accessEvent,
                #  14=doubleOutOfRange,15=signedOutOfRange,16=unsignedOutOfRange,17=changeOfCharacterstring,
                #  18=changeOfStatusFlags,19=changeOfReliability,20=none,21=changeOfDiscreteValue,22=changeOfTimer
                1 => UnsignedInt,
                # EventState Enum: 0=normal,1=fault,2=offnormal,3=highlimit,4=lowlimit,5=lifesafetyalarm
                2 => UnsignedInt,
                3 => UnsignedInt, # priority
                4 => UnsignedInt  # notification class
            },
            atomic_read_file: {
                0 => SignedInt, # fileStartPosition
                1 => SignedInt, # fileStartRecord
                2 => UnsignedInt # returnedRecordCount ?? NOTE:: unconfirmed
            },
            atomic_write_file: {
                0 => SignedInt, # fileStartPosition
                1 => SignedInt  # fileStartRecord
            },
            create_object: {
                0 => ObjectIdentifier
            },
            read_property: {
                0 => ObjectIdentifier,
                1 => PropertyIdentifier,
                2 => UnsignedInt # propertyArrayIndex
            },
            read_property_multiple: {
                0 => ObjectIdentifier,
                2 => PropertyIdentifier,
                3 => UnsignedInt
            },
            confirmed_private_transfer: {
                0 => UnsignedInt, # vendorId
                1 => UnsignedInt, # serviceNumber
                2 => OctetString      # resultBlock
            },
            vt_open: {
                0 => UnsignedInt # remoteVTSessionIdentifier
            },
            vt_data: {
                0 => ContextSpecificBoolean, # allNewDataAccepted
                1 => UnsignedInt # acceptedOctetCount
            },
            read_range: {
                0 => ObjectIdentifier,
                1 => PropertyIdentifier,
                2 => UnsignedInt, # propertyArrayIndex
                3 => BitString, # 0=firstItem, 1=lastItem, 2=moreItems
                4 => UnsignedInt, # itemCount
                5 => OctetString, # TODO:: based on Object and Property runtime values
                6 => UnsignedInt, # firstSequenceNumber
            },
            get_event_information: {
                0 => ObjectIdentifier,
                # EventState Enum: 0=normal,1=fault,2=offnormal,3=highlimit,4=lowlimit,5=lifesafetyalarm
                1 => UnsignedInt,
                2 => BitString,    # 0=toOffnormal,1=toFault,2=toNormal
                3 => Time,
                4 => UnsignedInt,  # notifyType Enum: 0=alarm, 1=event, 2=ackNotification 
                5 => BitString,    # 0=toOffnormal,1=toFault,2=toNormal
                6 => UnsignedInt,  # eventPriorities
            },
            restart_device: {
                0 => UnsignedInt,  # Type of reboot (0 == cold start)
                1 => CharString    # Password
            },
            device_communication_control: {
                1 => UnsignedInt,  # Enabled / Disabled
                2 => CharString    # Password
            },
            who_has: {
                2 => ObjectIdentifier,
                3 => CharString
            }
        }
    end
end
