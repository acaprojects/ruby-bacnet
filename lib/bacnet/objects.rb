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

    class ObjectIdentifier < BinData::Record
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

    class PropertyIdentifier < BinData::Record
        endian :big

        uint8  :property_type

        PropertyType = {
            acked_transitions: 0,
            ack_required: 1,
            action: 2,
            action_text: 3,
            active_text: 4,
            active_vt_sessions: 5,
            alarm_value: 6,
            alarm_values: 7,
            all: 8,
            all_writes_successful: 9,
            apdu_segment_timeout: 10,
            apdu_timeout: 11,
            application_software_version: 12,
            archive: 13,
            bias: 14,
            change_of_state_count: 15,
            change_of_state_time: 16,
            notification_class: 17,
            controlled_variable_reference: 19,
            controlled_variable_units: 20,
            controlled_variable_value: 21,
            cov_increment: 22,
            date_list: 23,
            daylight_savings_status: 24,
            deadband: 25,
            derivative_constant: 26,
            derivative_constant_units: 27,
            description: 28,
            description_of_halt: 29,
            device_address_binding: 30,
            device_type: 31,
            effective_period: 32,
            elapsed_active_time: 33,
            error_limit: 34,
            event_enable: 35,
            event_state: 36,
            event_type: 37,
            exception_schedule: 38,
            fault_values: 39,
            feedback_value: 40,
            file_access_method: 41,
            file_size: 42,
            file_type: 43,
            firmware_revision: 44,
            high_limit: 45,
            inactive_text: 46,
            in_process: 47,
            instance_of: 48,
            integral_constant: 49,
            integral_constant_units: 50,
            limit_enable: 52,
            list_of_group_members: 53,
            list_of_object_property_references: 54,
            local_date: 56,
            local_time: 57,
            location: 58,
            low_limit: 59,
            manipulated_variable_reference: 60,
            maximum_output: 61,
            max_apdu_length_accepted: 62,
            max_info_frames: 63,
            max_master: 64,
            max_pres_value: 65,
            minimum_off_time: 66,
            minimum_on_time: 67,
            minimum_output: 68,
            min_pres_value: 69,
            model_name: 70,
            modification_date: 71,
            notify_type: 72,
            number_of_apdu_retries: 73,
            number_of_states: 74,
            object_identifier: 75,
            object_list: 76,
            object_name: 77,
            object_property_reference: 78,
            object_type: 79,
            optional: 80,
            out_of_service: 81,
            output_units: 82,
            event_parameters: 83,
            polarity: 84,
            present_value: 85,
            priority: 86,
            priority_array: 87,
            priority_for_writing: 88,
            process_identifier: 89,
            program_change: 90,
            program_location: 91,
            program_state: 92,
            proportional_constant: 93,
            proportional_constant_units: 94,
            protocol_object_types_supported: 96,
            protocol_services_supported: 97,
            protocol_version: 98,
            read_only: 99,
            reason_for_halt: 100,
            recipient_list: 102,
            reliability: 103,
            relinquish_default: 104,
            required: 105,
            resolution: 106,
            segmentation_supported: 107,
            setpoint: 108,
            setpoint_reference: 109,
            state_text: 110,
            status_flags: 111,
            system_status: 112,
            time_delay: 113,
            time_of_active_time_reset: 114,
            time_of_state_count_reset: 115,
            time_synchronization_recipients: 116,
            units: 117,
            update_interval: 118,
            utc_offset: 119,
            vendor_identifier: 120,
            vendor_name: 121,
            vt_classes_supported: 122,
            weekly_schedule: 123,
            attempted_samples: 124,
            average_value: 125,
            buffer_size: 126,
            client_cov_increment: 127,
            cov_resubscription_interval: 128,
            event_time_stamps: 130,
            log_buffer: 131,
            log_device_object_property: 132,
            enable: 133,
            log_interval: 134,
            maximum_value: 135,
            minimum_value: 136,
            notification_threshold: 137,
            protocol_revision: 139,
            records_since_notification: 140,
            record_count: 141,
            start_time: 142,
            stop_time: 143,
            stop_when_full: 144,
            total_record_count: 145,
            valid_samples: 146,
            window_interval: 147,
            window_samples: 148,
            maximum_value_timestamp: 149,
            minimum_value_timestamp: 150,
            variance_value: 151,
            active_cov_subscriptions: 152,
            backup_failure_timeout: 153,
            configuration_files: 154,
            database_revision: 155,
            direct_reading: 156,
            last_restore_time: 157,
            maintenance_required: 158,
            member_of: 159,
            mode: 160,
            operation_expected: 161,
            setting: 162,
            silenced: 163,
            tracking_value: 164,
            zone_members: 165,
            life_safety_alarm_values: 166,
            max_segments_accepted: 167,
            profile_name: 168,
            auto_slave_discovery: 169,
            manual_slave_address_binding: 170,
            slave_address_binding: 171,
            slave_proxy_enable: 172,
            last_notify_record: 173,
            schedule_default: 174,
            accepted_modes: 175,
            adjust_value: 176,
            count: 177,
            count_before_change: 178,
            count_change_time: 179,
            cov_period: 180,
            input_reference: 181,
            limit_monitoring_interval: 182,
            logging_object: 183,
            logging_record: 184,
            prescale: 185,
            pulse_rate: 186,
            scale: 187,
            scale_factor: 188,
            update_time: 189,
            value_before_change: 190,
            value_set: 191,
            value_change_time: 192,
            align_intervals: 193,
            interval_offset: 195,
            last_restart_reason: 196,
            logging_type: 197,
            restart_notification_recipients: 202,
            time_of_device_restart: 203,
            time_synchronization_interval: 204,
            trigger: 205,
            utc_time_synchronization_recipients: 206,
            node_subtype: 207,
            node_type: 208,
            structured_object_list: 209,
            subordinate_annotations: 210,
            subordinate_list: 211,
            actual_shed_level: 212,
            duty_window: 213,
            expected_shed_level: 214,
            full_duty_baseline: 215,
            requested_shed_level: 218,
            shed_duration: 219,
            shed_level_descriptions: 220,
            shed_levels: 221,
            state_description: 222,
            door_alarm_state: 226,
            door_extended_pulse_time: 227,
            door_members: 228,
            door_open_too_long_time: 229,
            door_pulse_time: 230,
            door_status: 231,
            door_unlock_delay_time: 232,
            lock_status: 233,
            masked_alarm_values: 234,
            secured_status: 235,
            absentee_limit: 244,
            access_alarm_events: 245,
            access_doors: 246,
            access_event: 247,
            access_event_authentication_factor: 248,
            access_event_credential: 249,
            access_event_time: 250,
            access_transaction_events: 251,
            accompaniment: 252,
            accompaniment_time: 253,
            activation_time: 254,
            active_authentication_policy: 255,
            assigned_access_rights: 256,
            authentication_factors: 257,
            authentication_policy_list: 258,
            authentication_policy_names: 259,
            authentication_status: 260,
            authorization_mode: 261,
            belongs_to: 262,
            credential_disable: 263,
            credential_status: 264,
            credentials: 265,
            credentials_in_zone: 266,
            days_remaining: 267,
            entry_points: 268,
            exit_points: 269,
            expiration_time: 270,
            extended_time_enable: 271,
            failed_attempt_events: 272,
            failed_attempts: 273,
            failed_attempts_time: 274,
            last_access_event: 275,
            last_access_point: 276,
            last_credential_added: 277,
            last_credential_added_time: 278,
            last_credential_removed: 279,
            last_credential_removed_time: 280,
            last_use_time: 281,
            lockout: 282,
            lockout_relinquish_time: 283,
            max_failed_attempts: 285,
            members: 286,
            muster_point: 287,
            negative_access_rules: 288,
            number_of_authentication_policies: 289,
            occupancy_count: 290,
            occupancy_count_adjust: 291,
            occupancy_count_enable: 292,
            occupancy_lower_limit: 294,
            occupancy_lower_limit_enforced: 295,
            occupancy_state: 296,
            occupancy_upper_limit: 297,
            occupancy_upper_limit_enforced: 298,
            passback_mode: 300,
            passback_timeout: 301,
            positive_access_rules: 302,
            reason_for_disable: 303,
            supported_formats: 304,
            supported_format_classes: 305,
            threat_authority: 306,
            threat_level: 307,
            trace_flag: 308,
            transaction_notification_class: 309,
            user_external_identifier: 310,
            user_information_reference: 311,
            user_name: 317,
            user_type: 318,
            uses_remaining: 319,
            zone_from: 320,
            zone_to: 321,
            access_event_tag: 322,
            global_identifier: 323,
            verification_time: 326,
            base_device_security_policy: 327,
            distribution_key_revision: 328,
            do_not_hide: 329,
            key_sets: 330,
            last_key_server: 331,
            network_access_security_policies: 332,
            packet_reorder_time: 333,
            security_pdu_timeout: 334,
            security_time_window: 335,
            supported_security_algorithms: 336,
            update_key_set_timeout: 337,
            backup_and_restore_state: 338,
            backup_preparation_time: 339,
            restore_completion_time: 340,
            restore_preparation_time: 341,
            bit_mask: 342,
            bit_text: 343,
            is_utc: 344,
            group_members: 345,
            group_member_names: 346,
            member_status_flags: 347,
            requested_update_interval: 348,
            covu_period: 349,
            covu_recipients: 350,
            event_message_texts: 351,
            event_message_texts_config: 352,
            event_detection_enable: 353,
            event_algorithm_inhibit: 354,
            event_algorithm_inhibit_ref: 355,
            time_delay_normal: 356,
            reliability_evaluation_inhibit: 357,
            fault_parameters: 358,
            fault_type: 359,
            local_forwarding_only: 360,
            process_identifier_filter: 361,
            subscribed_recipients: 362,
            port_filter: 363,
            authorization_exemptions: 364,
            allow_group_delay_inhibit: 365,
            channel_number: 366,
            control_groups: 367,
            execution_delay: 368,
            last_priority: 369,
            write_status: 370,
            property_list: 371,
            serial_number: 372,
            blink_warn_enable: 373,
            default_fade_time: 374,
            default_ramp_rate: 375,
            default_step_increment: 376,
            egress_time: 377,
            in_progress: 378,
            instantaneous_power: 379,
            lighting_command: 380,
            lighting_command_default_priority: 381,
            max_actual_value: 382,
            min_actual_value: 383,
            power: 384,
            transition: 385,
            egress_active: 386,
            interface_value: 387,
            fault_high_limit: 388,
            fault_low_limit: 389,
            low_diff_limit: 390,
            strike_count: 391,
            time_of_strike_count_reset: 392,
            default_timeout: 393,
            initial_timeout: 394,
            last_state_change: 395,
            state_change_values: 396,
            timer_running: 397,
            timer_state: 398,
            apdu_length: 399,
            ip_address: 400,
            ip_default_gateway: 401,
            ip_dhcp_enable: 402,
            ip_dhcp_lease_time: 403,
            ip_dhcp_lease_time_remaining: 404,
            ip_dhcp_server: 405,
            ip_dns_server: 406,
            bacnet_ip_global_address: 407,
            bacnet_ip_mode: 408,
            bacnet_ip_multicast_address: 409,
            bacnet_ip_nat_traversal: 410,
            ip_subnet_mask: 411,
            bacnet_ip_udp_port: 412,
            bbmd_accept_fd_registrations: 413,
            bbmd_broadcast_distribution_table: 414,
            bbmd_foreign_device_table: 415,
            changes_pending: 416,
            command: 417,
            fd_bbmd_address: 418,
            fd_subscription_lifetime: 419,
            link_speed: 420,
            link_speeds: 421,
            link_speed_autonegotiate: 422,
            mac_address: 423,
            network_interface_name: 424,
            network_number: 425,
            network_number_quality: 426,
            network_type: 427,
            routing_table: 428,
            virtual_mac_address_table: 429,
            command_time_array: 430,
            current_command_priority: 431,
            last_command_time: 432,
            value_source: 433,
            value_source_array: 434,
            bacnet_ipv6mode: 435,
            ipv6address: 436,
            ipv6prefix_length: 437,
            bacnet_ipv6udp_port: 438,
            ipv6default_gateway: 439,
            bacnet_ipv6multicast_address: 440,
            ipv6dns_server: 441,
            ipv6auto_addressing_enable: 442,
            ipv6dhcp_lease_time: 443,
            ipv6dhcp_lease_time_remaining: 444,
            ipv6dhcp_server: 445,
            ipv6zone_index: 446,
            assigned_landing_calls: 447,
            car_assigned_direction: 448,
            car_door_command: 449,
            car_door_status: 450,
            car_door_text: 451,
            car_door_zone: 452,
            car_drive_status: 453,
            car_load: 454,
            car_load_units: 455,
            car_mode: 456,
            car_moving_direction: 457,
            car_position: 458,
            elevator_group: 459,
            energy_meter: 460,
            energy_meter_ref: 461,
            escalator_mode: 462,
            fault_signals: 463,
            floor_text: 464,
            group_id: 465,
            group_mode: 467,
            higher_deck: 468,
            installation_id: 469,
            landing_calls: 470,
            landing_call_control: 471,
            landing_door_status: 472,
            lower_deck: 473,
            machine_room_id: 474,
            making_car_call: 475,
            next_stopping_floor: 476,
            operation_direction: 477,
            passenger_alarm: 478,
            power_mode: 479,
            registered_car_call: 480,
            active_cov_multiple_subscriptions: 481,
            protocol_level: 482,
            reference_port: 483,
            deployed_profile_location: 484,
            profile_location: 485,
            tags: 486,
            subordinate_node_types: 487,
            subordinate_tags: 488,
            subordinate_relationships: 489,
            default_subordinate_relationship: 490,
            represents: 491
        }
        PropertyType.merge!(PropertyType.invert)

        def type
            PropertyType[object_type] || :unknown
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
            12 => ObjectIdentifier
        }

        attr_accessor :context

        def get_value
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
            @value.value
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
