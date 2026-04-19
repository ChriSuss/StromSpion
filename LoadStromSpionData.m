# ##
# LoadStromSpionData.m
# Loads data from InfluxDB using the provided secrets.
# ##

function data = LoadStromSpionData(secrets)
    disp('Loading StromSpion data...');

    # Example placeholder: using the secrets configuration
    # API_URL,API_KEY and API_CMD are available in the secrets struct
    if isfield(secrets, 'API_URL')
        disp(['Connecting to: ', secrets.API_URL]);
    end

    # Define the output file path in the current directory with date suffix
    today_date_str = datestr(now, 'yyyy_mm_dd');
    output_file = sprintf('data_influxdb_%s.csv', today_date_str);

    # Only call the system command when there's not yet an output_file available from today
    if ~exist(output_file, 'file')
        # Create the command to execute
        # Note: We add '-o "$output_file"' to redirect the output to a file.
        command = sprintf('%s -o %s', secrets.API_CMD, output_file);

        # Execute the query
        disp('Querying for data from database...');
        [status, msg] = system(command);

        if status == 0
            disp(['Success! Data was saved in "', output_file, '".']);
            # Short preview of the first lines in the console
            disp('Preview of the file:');
            system(['head -n 5 ' output_file]);
        else
            disp(['Error during cURL call. Status: ', num2str(status)]);
        end
    else
        disp('Data for today already exists. Skipping query.');
    end

    # Determine which file to read
    file_to_read = '';
    if exist(output_file, 'file')
        file_to_read = output_file;
    else
        # Read from the most recent available file
        files = dir('data_influxdb_*.csv');
        if ~isempty(files)
            [~, idx] = sort([files.datenum], 'descend');
            file_to_read = files(idx(1)).name;
            disp(['Today''s file is not available. Using most recent file: ', file_to_read]);
        end
    end

    if isempty(file_to_read)
        error('No data files available to read.');
    end

    disp(['Reading data from ', file_to_read, '...']);
    try
        data = readtable(file_to_read);
    catch
        # Fallback
        data = csvread(file_to_read, 1, 0);
    end

    disp('Data loaded successfully.');
end
