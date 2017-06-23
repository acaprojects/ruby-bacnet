# frozen_string_literal: true, encoding: ASCII-8BIT

require 'time'

class BACnet
    class Date < BinData::Record
        endian :big

        uint8  :year_raw
        uint8  :month_raw
        uint8  :day_raw
        uint8  :day_of_week # Monday == 1, Sunday == 7

        Unspecified = 255
        LastDayOfMonth = 32

        def year
            year_raw == Unspecified ? Date.today.year : (year_raw + 1900)
        end

        def month
            month_raw == Unspecified ? Date.today.month : month_raw
        end

        def day
            if day_raw == Unspecified
                Date.today.day
            else
                day_raw == LastDayOfMonth ? -1 : day_raw
            end
        end

        def value
            ::Date.civil(year, month, day)
        end
    end

    class Time < BinData::Record
        endian :big

        Unspecified = 255

        uint8  :hour_raw
        uint8  :minute_raw
        uint8  :second_raw
        uint8  :hundredth_raw

        def hour
            hour_raw == Unspecified ? 0 : hour_raw
        end

        def minute
            minute_raw == Unspecified ? 0 : minute_raw
        end

        def second
            second_raw == Unspecified ? 0 : second_raw
        end

        def hundredth
            hundredth_raw == Unspecified ? 0 : hundredth_raw
        end

        def second_float
            h = hundredth
            if h > 0
                second.to_f + (h.to_f / 100)
            else
                second
            end
        end

        def value(date = ::Date.today)
            date = ::Date.today unless date.is_a?(::Date)
            ::Time.new(date.year, date.month, date.day, hour, minute, second_float)
        end
    end
end
