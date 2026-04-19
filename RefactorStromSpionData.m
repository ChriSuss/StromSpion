# ##
# RefactorStromSpionData.m
# Refactors the loaded data by adding a _timeofday column based on the _time value.
# The _timeofday is in seconds since midnight, adjusted for CET/CEST.
# ##

function data = RefactorStromSpionData(data)
    disp('Refactoring data: Calculating _timeofday...');

    # Define a constant for the time column index
    # Since csvread returns a matrix, use the column index instead of a name.
    # Adjust this to match the column where the time data is located.
    TIME_COL_IDX = 1; 
    
    try
        # Extract time column
        t = data(:, TIME_COL_IDX);
    catch
        disp(['Warning: Time column index ', num2str(TIME_COL_IDX), ' exceeds matrix dimensions. Refactoring skipped.']);
        return;
    end

    # Octave does not natively support datetime, so we parse manually
    time_of_day_sec = zeros(length(t), 1);
    success_count = 0;

    for i = 1:length(t)
        if iscell(t)
            val = t{i};
        else
            val = t(i);
        end
        
        utc_sec = -1;
        year = 0; month = 0; day = 0; h = 0; m = 0; s = 0;
        
        if ischar(val) || isstring(val)
            # Extract date and time from ISO8601 string, e.g. 2023-10-12T00:05:00Z
            val_str = char(val);
            matches = regexp(val_str, '^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})', 'tokens');
            if ~isempty(matches)
                year = str2double(matches{1}{1});
                month = str2double(matches{1}{2});
                day = str2double(matches{1}{3});
                h = str2double(matches{1}{4});
                m = str2double(matches{1}{5});
                s = str2double(matches{1}{6});
                utc_sec = h * 3600 + m * 60 + s;
            end
        elseif isnumeric(val)
            # If numeric, assume Unix timestamp (seconds since epoch in UTC)
            try
                # Octave's gmtime converts epoch to time struct
                tm = gmtime(val);
                year = tm.year + 1900;
                month = tm.mon + 1;
                day = tm.mday;
                h = tm.hour;
                m = tm.min;
                s = tm.sec;
                utc_sec = h * 3600 + m * 60 + s;
            catch
                # Ignored if gmtime not available
            end
        end
        
        if utc_sec >= 0
            # Convert to CET/CEST (Central European Time)
            # DST starts last Sunday in March at 01:00 UTC
            # Ends last Sunday in October at 01:00 UTC
            is_dst = false;
            if month > 3 && month < 10
                is_dst = true;
            elseif month == 3
                # Last Sunday in March
                dn_march31 = datenum(year, 3, 31);
                [~, dw] = weekday(dn_march31);
                last_sunday = 31 - (dw - 1);
                if day > last_sunday || (day == last_sunday && h >= 1)
                    is_dst = true;
                end
            elseif month == 10
                # Last Sunday in October
                dn_oct31 = datenum(year, 10, 31);
                [~, dw] = weekday(dn_oct31);
                last_sunday = 31 - (dw - 1);
                if day < last_sunday || (day == last_sunday && h < 1)
                    is_dst = true;
                end
            end
            
            offset_hours = 1; # CET is UTC+1
            if is_dst
                offset_hours = 2; # CEST is UTC+2
            end
            
            local_sec = utc_sec + offset_hours * 3600;
            local_sec = mod(local_sec, 86400); # Wrap around midnight
            
            time_of_day_sec(i) = local_sec;
            success_count = success_count + 1;
        end
    end
    
    if success_count > 0
        # Append the new time_of_day_sec array as a new column to the matrix
        data = [data, time_of_day_sec];
        disp(['Successfully added _timeofday as a new column for ', num2str(success_count), ' entries.']);
    else
        disp('Warning: Time column could not be converted. Refactoring skipped.');
    end
end
