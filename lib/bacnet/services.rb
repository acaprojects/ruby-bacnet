# frozen_string_literal: true, encoding: ASCII-8BIT

class BACnet
    class Request < BinData::Record
        ServiceIds = {
            acknowledge_alarm:    0,
            i_have:               1,
            who_has:              7,
            device_comms_control: 17,
            restart_device:       20
        }
        ServiceIds.merge!(ServiceIds.invert)

        def service
            ServiceIds[service_id] || :unknown
        end

        def service=(name)
            service_id = ServiceIds[name.to_sym] || 0
        end

        def objects(data)
            objs = []
            while data.length > 1 && data[0] != "\x0"
                obj = Obj.read(data).details(service)
                objs << obj
                data = data[obj.do_num_bytes..-1]
            end
            objs
        rescue => e
            puts "#{e.message}"
            objs
        end
    end

    class SimpleACK < Request
        endian :big

        uint8  :invoke_id
        uint8  :service_id
    end

    class UnconfirmedReq < Request
        endian :big

        uint8  :service_id
    end

    class ConfirmedReq < Request
        endian :big

        bit1   :ignore
        bit3   :max_response_segments
        bit4   :max_size

        uint8  :invoke_id
        uint8  :service_id
    end
end
