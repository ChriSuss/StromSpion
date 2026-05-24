# ##
# RefactorStromSpionData.m
# Refactors the loaded data by adding a _timeofday column based on the _time value.
# The _timeofday is in seconds since midnight, adjusted for CET/CEST.
# ##

function data = RefactorStromSpionData(data)
    disp('Refactoring data: Calculating _timeofday...');

    # Define the expected time column name
    TIME_COL_NAME = '_time';
    
    if ~iscell(data) || size(data, 1) < 1
        disp('Warning: Input data is empty or not a cell array. Refactoring skipped.');
        return;
    end
    
    # Auto-detect whether the first row contains headers
    is_header = false;
    first_row = data(1, :);
    for col = 1:length(first_row)
        val = first_row{col};
        if ischar(val) || isstring(val)
            # If the cell is a non-numeric string, assume it's a header
            if isempty(regexp(char(val), '^\s*\d+\s*$', 'once'))
                is_header = true;
                break;
            end
        end
    end
    
    # Determine the starting row for data processing
    if is_header
        start_row = 2;
    else
        start_row = 1;
    end
    
    # Try to find the time column by name in the header row
    timeColIdx = -1;
    if is_header
        for col = 1:length(first_row)
            val = first_row{col};
            if ischar(val) || isstring(val)
                cleaned_val = strtrim(strrep(char(val), '"', ''));
                if strcmp(cleaned_val, TIME_COL_NAME)
                    timeColIdx = col;
                    break;
                end
            end
        end
    end
    
    # If the column wasn't found by name (or there is no header),
    # search the first few rows of each column for an ISO8601 date string
    if timeColIdx == -1
        for col = 1:size(data, 2)
            for r = start_row:min(size(data, 1), start_row + 5)
                val = data{r, col};
                if ischar(val) || isstring(val)
                    if ~isempty(regexp(char(val), '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}', 'once'))
                        timeColIdx = col;
                        break;
                    end
                end
            end
            if timeColIdx ~= -1
                break;
            end
        end
    end
    
    # Default fallback to column 4 if still not found
    if timeColIdx == -1
        timeColIdx = 4;
        disp(['Warning: Time column could not be auto-detected. Falling back to column ', num2str(timeColIdx)]);
    else
        disp(['Found time column at index: ', num2str(timeColIdx)]);
    end
    
    try
        # Extract time column (excluding header if present)
        t = data(start_row:end, timeColIdx);
    catch
        disp(['Warning: Time column index ', num2str(timeColIdx), ' exceeds data dimensions. Refactoring skipped.']);
        return;
    end

    # Initialize output array and success count
    time_of_day_sec = NaN(length(t), 1);
    success_count = 0;

    # Check if elements are characters/strings (typical InfluxDB CSV output)
    is_str_col = false;
    if ~isempty(t)
        first_val = t{1};
        if ischar(first_val) || isstring(first_val)
            is_str_col = true;
        end
    end

    if is_str_col
        % Vectorized ISO8601 string parsing (extremely fast for large datasets)
        t_char = char(t);
        
        % Ensure the char matrix has sufficient width for slicing
        if size(t_char, 2) >= 19
            years = str2double(t_char(:, 1:4));
            months = str2double(t_char(:, 6:7));
            days = str2double(t_char(:, 9:10));
            hours = str2double(t_char(:, 12:13));
            minutes = str2double(t_char(:, 15:16));
            seconds = str2double(t_char(:, 18:19));
            
            % Identify rows that were successfully parsed
            valid_rows = ~isnan(years) & ~isnan(months) & ~isnan(days) & ...
                         ~isnan(hours) & ~isnan(minutes) & ~isnan(seconds);
            
            if any(valid_rows)
                utc_sec = hours * 3600 + minutes * 60 + seconds;
                
                % Vectorized DST calculation
                is_dst = false(length(t), 1);
                
                % April to September (always DST)
                is_dst(months > 3 & months < 10) = true;
                
                % March
                idx_march = (months == 3) & valid_rows;
                if any(idx_march)
                    dn_march31 = datenum(years(idx_march), 3, 31);
                    dw_march = weekday(dn_march31);
                    last_sunday_march = 31 - (dw_march - 1);
                    is_dst(idx_march) = (days(idx_march) > last_sunday_march) | ...
                                         ((days(idx_march) == last_sunday_march) & (hours(idx_march) >= 1));
                end
                
                % October
                idx_oct = (months == 10) & valid_rows;
                if any(idx_oct)
                    dn_oct31 = datenum(years(idx_oct), 10, 31);
                    dw_oct = weekday(dn_oct31);
                    last_sunday_oct = 31 - (dw_oct - 1);
                    is_dst(idx_oct) = (days(idx_oct) < last_sunday_oct) | ...
                                       ((days(idx_oct) == last_sunday_oct) & (hours(idx_oct) < 1));
                end
                
                % Compute offset hours
                offset_hours = ones(length(t), 1);
                offset_hours(is_dst) = 2;
                
                % Calculate local seconds since midnight
                local_sec = utc_sec + offset_hours * 3600;
                time_of_day_sec(valid_rows) = mod(local_sec(valid_rows), 86400);
                success_count = sum(valid_rows);
            end
        end
    end

    if ~is_str_col || success_count == 0
        % Fallback loop for numeric Unix timestamps or irregular rows
        for i = 1:length(t)
            val = t{i};
            utc_sec = -1;
            year = 0; month = 0; day = 0; h = 0; m = 0; s = 0;
            
            if isnumeric(val) && ~isnan(val) && ~isempty(val)
                try
                    tm = gmtime(val);
                    year = tm.year + 1900;
                    month = tm.mon + 1;
                    day = tm.mday;
                    h = tm.hour;
                    m = tm.min;
                    s = tm.sec;
                    utc_sec = h * 3600 + m * 60 + s;
                catch
                end
            end
            
            if utc_sec >= 0
                is_dst = false;
                if month > 3 && month < 10
                    is_dst = true;
                elseif month == 3
                    dn_march31 = datenum(year, 3, 31);
                    dw = weekday(dn_march31);
                    last_sunday = 31 - (dw - 1);
                    if day > last_sunday || (day == last_sunday && h >= 1)
                        is_dst = true;
                    end
                elseif month == 10
                    dn_oct31 = datenum(year, 10, 31);
                    dw = weekday(dn_oct31);
                    last_sunday = 31 - (dw - 1);
                    if day < last_sunday || (day == last_sunday && h < 1)
                        is_dst = true;
                    end
                end
                
                offset_hours = 1;
                if is_dst
                    offset_hours = 2;
                end
                
                local_sec = utc_sec + offset_hours * 3600;
                time_of_day_sec(i) = mod(local_sec, 86400);
                success_count = success_count + 1;
            end
        end
    end
    
    if success_count > 0
        # Append the new time_of_day_sec array as a new column to the cell array
        new_col = cell(size(data, 1), 1);
        if is_header
            new_col{1} = '_timeofday';
            for i = 1:length(time_of_day_sec)
                new_col{i+1} = time_of_day_sec(i);
            end
        else
            for i = 1:length(time_of_day_sec)
                new_col{i} = time_of_day_sec(i);
            end
        end
        data = [data, new_col];
        disp(['Successfully added _timeofday as a new column for ', num2str(success_count), ' entries.']);
    else
        disp('Warning: Time column could not be converted. Refactoring skipped.');
    end
end
