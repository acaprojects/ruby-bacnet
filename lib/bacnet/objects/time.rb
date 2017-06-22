# frozen_string_literal: true, encoding: ASCII-8BIT

class BACnet
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
end
