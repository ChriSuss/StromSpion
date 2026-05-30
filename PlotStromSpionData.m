# ##
# PlotStromSpionData.m
# Plots the StromSpion power consumption data in a 2D density heatmap style.
# The x-axis represents the time of day (seconds since midnight converted to hours),
# and the y-axis represents the power consumption values.
# ##

function PlotStromSpionData(data)
    disp('Plotting data: Generating power consumption heatmap...');

    # Define the expected column names
    VAL_COL_NAME = '_value';
    TOD_COL_NAME = '_timeofday';

    if ~iscell(data) || size(data, 1) < 1
        disp('Warning: Input data is empty or not a cell array. Plotting aborted.');
        return;
    end

    # Auto-detect headers row (row 1)
    is_header = false;
    first_row = data(1, :);
    for col = 1:length(first_row)
        val = first_row{col};
        if ischar(val) || isstring(val)
            if isempty(regexp(char(val), '^\s*\d+\s*$', 'once'))
                is_header = true;
                break;
            end
        end
    end

    # Determine starting row for extracting data
    if is_header
        start_row = 2;
    else
        start_row = 1;
    end

    # Find the column indices of _value and _timeofday
    valColIdx = -1;
    todColIdx = -1;

    if is_header
        for col = 1:length(first_row)
            val = first_row{col};
            if ischar(val) || isstring(val)
                cleaned_val = strtrim(strrep(char(val), '"', ''));
                if strcmp(cleaned_val, VAL_COL_NAME)
                    valColIdx = col;
                elseif strcmp(cleaned_val, TOD_COL_NAME)
                    todColIdx = col;
                end
            end
        end
    end

    # Fallbacks if columns were not found by name
    if valColIdx == -1
        valColIdx = 5; % Default column index for _value
    end
    if todColIdx == -1
        todColIdx = size(data, 2); % Default to the last column for _timeofday
    end

    # Extract cell columns
    try
        val_cell = data(start_row:end, valColIdx);
        tod_cell = data(start_row:end, todColIdx);
    catch
        disp('Warning: Column indices exceed data dimensions. Plotting aborted.');
        return;
    end

    # Safely and efficiently extract numeric values using vectorized checks
    is_num_val = cellfun('isclass', val_cell, 'double');
    is_num_tod = cellfun('isclass', tod_cell, 'double');
    valid = is_num_val & is_num_tod;

    if ~any(valid)
        disp('Warning: No numeric time of day or power consumption values found. Plotting aborted.');
        return;
    end

    # Convert cell arrays of double to double arrays
    Y = cell2mat(val_cell(valid));
    X_sec = cell2mat(tod_cell(valid));

    # Convert seconds since midnight to hours
    X = X_sec / 3600;

    # Filter out any NaN values that might remain
    valid_data = ~isnan(X) & ~isnan(Y);
    X = X(valid_data);
    Y = Y(valid_data);

    if isempty(X)
        disp('Warning: No valid data points to plot after filtering NaNs. Plotting aborted.');
        return;
    end

    disp(['Processing ', num2str(length(X)), ' data points for plotting...']);

    # Define the number of bins for the 2D histogram
    # 96 bins for x-axis represents 15-minute intervals (24 hours * 4)
    num_x_bins = 96;
    num_y_bins = 100;

    # Compute bin edges
    x_edges = linspace(0, 24, num_x_bins + 1);
    y_edges = linspace(min(Y), max(Y), num_y_bins + 1);

    # Find the bin index for each data point
    [~, x_bin] = histc(X, x_edges);
    [~, y_bin] = histc(Y, y_edges);

    # Clamp indices to [1, num_bins]
    x_bin(x_bin > num_x_bins) = num_x_bins;
    y_bin(y_bin > num_y_bins) = num_y_bins;

    # Keep only valid bins (indices > 0)
    valid_bins = (x_bin > 0) & (y_bin > 0);
    x_bin = x_bin(valid_bins);
    y_bin = y_bin(valid_bins);

    if isempty(x_bin)
        disp('Warning: No data points fell into valid bins. Plotting aborted.');
        return;
    end

    # Accumulate counts into a 2D grid matrix
    H = accumarray([y_bin, x_bin], 1, [num_y_bins, num_x_bins]);

    # Compute bin centers for axes labeling
    x_centers = x_edges(1:end-1) + diff(x_edges)/2;
    y_centers = y_edges(1:end-1) + diff(y_edges)/2;

    # Create figure
    hFig = figure('Visible', 'off'); % Create headless figure to avoid showing GUI window during runs

    # Use imagesc to plot the 2D density grid
    # A logarithmic scale log10(H + 1) is used to compress high-density peaks 
    # and reveal the structure in lower-density regions.
    imagesc(x_centers, y_centers, log10(H + 1));

    # Styling and aesthetics
    colormap('jet');
    hCb = colorbar;
    ylabel(hCb, 'Log10(Data point count + 1)');
    set(gca, 'YDir', 'normal'); % Normal Y direction (increasing upwards)

    xlabel('Time of Day (Hours since Midnight)');
    ylabel('Power Consumption (W)');
    title('Heatmap of Power Consumption over Time of Day');

    # Grid and tick layout
    grid on;
    set(gca, 'XTick', 0:2:24);
    xlim([0, 24]);

    # Save to a high-resolution PNG file
    output_png = 'stromspion_heatmap.png';
    try
        print(hFig, output_png, '-dpng', '-r150');
        disp(['Success! Heatmap plot saved to "', output_png, '".']);
    catch e
        disp(['Error occurred while saving plot: ', e.message]);
    end

    # Clean up figure memory
    close(hFig);
end
