# frozen_string_literal: true, encoding: ASCII-8BIT

class BACnet
    class Request < BinData::Record
        def service
            self.class::ServiceIds[service_id] || :unknown
        end

        def service=(name)
            service_id = self.class::ServiceIds[name.to_sym] || 0
        end

        def objects(data)
            objs = []
            srv  = service
            while data.length > 1 && data[0] != "\x0"
                obj = Obj.read(data)
                obj.context = srv
                objs << obj
                data = data[obj.do_num_bytes..-1]
            end
            objs
        rescue => e
            puts "#{e.message}\n#{e.backtrace.join("\n")}"
            objs
        end
    end

    class UnconfirmedRequest < Request
        endian :big

        ServiceIds = {
            i_am:   0,
            i_have: 1,
            unconfirmed_cov_notification:   2,
            unconfirmed_event_notification: 3,
            unconfirmed_private_transfer:   4,
            unconfirmed_text_message:       5,
            time_synchronization:           6,
            who_has: 7,
            who_is:  8,
            utc_time_synchronization:       9,
            write_group: 10,
            unconfirmed_cov_notification_multiple: 11
        }
        ServiceIds.merge!(ServiceIds.invert)

        bit4   :message_type
        bit4   :flags
        uint8  :service_id
    end

    class ConfirmedCommon < Request
        ServiceIds = {
            acknowledge_alarm: 0,
            confirmed_cov_notification: 1,
            confirmed_event_notification: 2,
            get_alarm_summary: 3,
            get_enrollment_summary: 4,
            subscribe_cov: 5,
            atomic_read_file: 6,
            atomic_write_file: 7,
            add_list_element: 8,
            remove_list_element: 9,
            create_object: 10,
            delete_object: 11,
            read_property: 12,
            # 13 doesn't seem to exist
            read_property_multiple: 14,
            write_property: 15,
            write_property_multiple: 16,
            device_communication_control: 17,
            confirmed_private_transfer: 18,
            confirmed_text_message: 19,
            reinitialize_device: 20,
            vt_open: 21,
            vt_close: 22,
            vt_data: 23,
            read_range: 26,
            life_safety_operation: 27,
            subscribe_cov_property: 28,
            get_event_information: 29,
            subscribe_cov_property_multiple: 30,
            confirmed_cov_notification_multiple: 31
        }
        ServiceIds.merge!(ServiceIds.invert)
    end

    class ConfirmedRequest < ConfirmedCommon
        endian :big

        bit4   :message_type

        # Flags
        bit1   :segmented_message
        bit1   :more_follows
        bit1   :segmented_response_accepted
        bit1   :ignore1

        bit1   :ignore2
        bit3   :max_response_segments
        bit4   :max_size

        uint8  :invoke_id

        struct :segment, onlyif: -> { segmented_message.nonzero? } do
            uint8  :sequence_number
            uint8  :window_size
        end

        uint8  :service_id
    end

    class SimpleACK < ConfirmedCommon
        endian :big

        bit4   :message_type
        bit4   :flags
        uint8  :invoke_id
        uint8  :service_id
    end

    class ComplexACK < ConfirmedCommon
        endian :big

        bit4   :message_type

        # Flags
        bit1   :segmented_message
        bit1   :more_follows
        bit1   :ignore1
        bit1   :ignore2

        uint8  :invoke_id

        struct :segment, onlyif: -> { segmented_message.nonzero? } do
            uint8  :sequence_number
            uint8  :window_size
        end

        uint8  :service_id

=begin
        TODO:: These are the complex ACK responses
            get_alarm_summary: 3,
            get_enrollment_summary: 4,
            atomic_read_file: 6,
            atomic_write_file: 7,
            create_object: 10,
            read_property: 12,
            read_property_multiple: 14,
            confirmed_private_transfer: 18,
            vt_open: 21,
            vt_data: 23,
            read_range: 26,
            get_event_information: 29
=end
    end

    class SegmentACK < ConfirmedCommon
        endian :big

        bit4   :message_type

        # Flags
        bit2   :flags
        bit1   :negative_ack
        bit1   :from_server

        uint8  :invoke_id
        struct :segment, onlyif: -> { segmented_message.nonzero? } do
            uint8  :sequence_number
            uint8  :window_size
        end
    end

    class Error < Request
        endian :big

        ServiceIds = {
            read_property: 12,
            device_comms_control: 17,
            reinitialize_device: 20
        }
        ServiceIds.merge!(ServiceIds.invert)

        ErrorClass = {
            device: 0,
            object: 1,
            property: 2,
            resources: 3,
            security: 4,
            services: 5,
            vt: 6,
            communication: 7
        }
        ErrorClass.merge!(ErrorClass.invert)

        ErrorCode = {
            other: 0,
            configuration_in_progress: 2,
            device_busy: 3,
            dynamic_creation_not_supported: 4,
            file_access_denied: 5,
            inconsistent_parameters: 7,
            inconsistent_selection_criterion: 8,
            invalid_data_type: 9,
            invalid_file_access_method: 10,
            invalid_file_start_position: 11,
            invalid_parameter_data_type: 13,
            invalid_time_stamp: 14,
            missing_required_parameter: 16,
            no_objects_of_specified_type: 17,
            no_space_for_object: 18,
            no_space_to_add_list_element: 19,
            no_space_to_write_property: 20,
            no_vt_sessions_available: 21,
            property_is_not_alist: 22,
            object_deletion_not_permitted: 23,
            object_identifier_already_exists: 24,
            operational_problem: 25,
            password_failure: 26,
            read_access_denied: 27,
            service_request_denied: 29,
            timeout: 30,
            unknown_object: 31,
            unknown_property: 32,
            unknown_vt_class: 34,
            unknown_vt_session: 35,
            unsupported_object_type: 36,
            value_out_of_range: 37,
            vt_session_already_closed: 38,
            vt_session_termination_failure: 39,
            write_access_denied: 40,
            character_set_not_supported: 41,
            invalid_array_index: 42,
            cov_subscription_failed: 43,
            not_cov_property: 44,
            optional_functionality_not_supported: 45,
            invalid_configuration_data: 46,
            datatype_not_supported: 47,
            duplicate_name: 48,
            duplicate_object_id: 49,
            property_is_not_an_array: 50,
            abort_buffer_overflow: 51,
            abort_invalid_apdu_in_this_state: 52,
            abort_preempted_by_higher_priority_task: 53,
            abort_segmentation_not_supported: 54,
            abort_proprietary: 55,
            abort_other: 56,
            invalid_tag: 57,
            network_down: 58,
            reject_buffer_overflow: 59,
            reject_inconsistent_parameters: 60,
            reject_invalid_parameter_data_type: 61,
            reject_invalid_tag: 62,
            reject_missing_required_parameter: 63,
            reject_parameter_out_of_range: 64,
            reject_too_many_arguments: 65,
            reject_undefined_enumeration: 66,
            reject_unrecognized_service: 67,
            reject_proprietary: 68,
            reject_other: 69,
            unknown_device: 70,
            unknown_route: 71,
            value_not_initialized: 72,
            invalid_event_state: 73,
            no_alarm_configured: 74,
            log_buffer_full: 75,
            logged_value_purged: 76,
            no_property_specified: 77,
            not_configured_for_triggered_logging: 78,
            unknown_subscription: 79,
            parameter_out_of_range: 80,
            list_element_not_found: 81,
            busy: 82,
            communication_disabled: 83,
            success: 84,
            access_denied: 85,
            bad_destination_address: 86,
            bad_destination_device_id: 87,
            bad_signature: 88,
            bad_source_address: 89,
            bad_timestamp: 90,
            cannot_use_key: 91,
            cannot_verify_message_id: 92,
            correct_key_revision: 93,
            destination_device_id_required: 94,
            duplicate_message: 95,
            encryption_not_configured: 96,
            encryption_required: 97,
            incorrect_key: 98,
            invalid_key_data: 99,
            key_update_in_progress: 100,
            malformed_message: 101,
            not_key_server: 102,
            security_not_configured: 103,
            source_security_required: 104,
            too_many_keys: 105,
            unknown_authentication_type: 106,
            unknown_key: 107,
            unknown_key_revision: 108,
            unknown_source_message: 109,
            not_router_to_dnet: 110,
            router_busy: 111,
            unknown_network_message: 112,
            message_too_long: 113,
            security_error: 114,
            addressing_error: 115,
            write_bdt_failed: 116,
            read_bdt_failed: 117,
            register_foreign_device_failed: 118,
            read_fdt_failed: 119,
            delete_fdt_entry_failed: 120,
            distribute_broadcast_failed: 121,
            unknown_file_size: 122,
            abort_apdu_too_long: 123,
            abort_application_exceeded_reply_time: 124,
            abort_out_of_resources: 125,
            abort_tsm_timeout: 126,
            abort_window_size_out_of_range: 127,
            file_full: 128,
            inconsistent_configuration: 129,
            inconsistent_object_type: 130,
            internal_error: 131,
            not_configured: 132,
            out_of_memory: 133,
            value_too_long: 134,
            abort_insufficient_security: 135,
            abort_security_error: 136,
            duplicate_entry: 137,
            invalid_value_in_this_state: 138
        }
        ErrorCode.merge!(ErrorCode.invert)

        bit4   :message_type
        bit4   :flags

        uint8  :invoke_id
        uint8  :service_id

        string :error_class_data, read_length: 2
        string :error_code_data,  read_length: 2

        def error_class
            @error_class ||= ::BACnet::Obj.read(error_class_data)
        end

        def error_code
            @error_code ||= ::BACnet::Obj.read(error_code_data)
        end

        def reason
            err_class = ErrorClass[error_class.get_value] || :unknown
            err_code = (ErrorCode[error_code.get_value] || :unknown).to_s.gsub('_', ' ')
            "#{err_code} (#{err_class} error #{error_class.get_value}:#{error_code.get_value})"
        end
    end

    class Reject < Request
        endian :big

        ServiceIds = {
            other: 0,
            buffer_overflow: 1,
            inconsistent_parameters: 2,
            invalid_parameter_data_type: 3,
            invalid_tag: 4,
            missing_required_parameter: 5,
            parameter_out_of_range: 6,
            too_many_arguments: 7,
            undefined_enumeration: 8,
            unrecognized_service: 9
        }
        ServiceIds.merge!(ServiceIds.invert)

        bit4   :message_type
        bit4   :flags

        uint8  :invoke_id
        uint8  :service_id # reject code

        alias_method :reason, :service
    end

    class Abort < Request
        endian :big

        ServiceIds = {
            other: 0,
            buffer_overflow: 1,
            invalid_apdu_in_this_state: 2,
            preempted_by_higher_priority_task: 3,
            segmentation_not_supported: 4,
            security_error: 5,
            insufficient_security: 6,
            window_size_out_of_range: 7,
            application_exceeded_reply_time: 8,
            out_of_resources: 9,
            tsm_timeout: 10,
            apdu_too_long: 11
        }
        ServiceIds.merge!(ServiceIds.invert)

        bit4   :message_type
        bit3   :flags
        bit1   :from_server

        uint8  :invoke_id
        uint8  :service_id # abort code

        alias_method :reason, :service
    end
end
