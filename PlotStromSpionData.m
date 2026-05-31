# ##
# PlotStromSpionData.m
# Plots the StromSpion power consumption data in 2D density heatmap style
# for E_actual, E_actual_L1, E_actual_L2, and E_actual_L3.
# The x-axis represents the time of day (seconds since midnight converted to hours),
# and the y-axis represents the power consumption values.
# Uses a logarithmic y-axis scale for natural resolution scaling (high detail for low power).
# ##

function PlotStromSpionData(data)
    disp('Plotting data: Generating power consumption heatmaps...');

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

    # Find the column indices of _timeofday, E_actual, E_actual_L1, E_actual_L2, and E_actual_L3
    todColIdx = -1;
    totColIdx = -1;
    L1_ColIdx = -1;
    L2_ColIdx = -1;
    L3_ColIdx = -1;

    if is_header
        for col = 1:length(first_row)
            val = first_row{col};
            if ischar(val) || isstring(val)
                cleaned_val = strtrim(strrep(char(val), '"', ''));
                if strcmp(cleaned_val, '_timeofday')
                    todColIdx = col;
                elseif strcmp(cleaned_val, 'E_actual')
                    totColIdx = col;
                elseif strcmp(cleaned_val, 'E_actual_L1')
                    L1_ColIdx = col;
                elseif strcmp(cleaned_val, 'E_actual_L2')
                    L2_ColIdx = col;
                elseif strcmp(cleaned_val, 'E_actual_L3')
                    L3_ColIdx = col;
                end
            end
        end
    end

    # Fallbacks if columns were not found by name
    if todColIdx == -1
        todColIdx = size(data, 2); % Default to the last column
    end
    if totColIdx == -1
        totColIdx = 5;
    end
    if L1_ColIdx == -1
        L1_ColIdx = 6;
    end
    if L2_ColIdx == -1
        L2_ColIdx = 7;
    end
    if L3_ColIdx == -1
        L3_ColIdx = 8;
    end

    # Define phases/vectors to plot
    phases = {};
    if totColIdx ~= -1 && totColIdx <= size(data, 2)
        phases{end+1} = struct('name', 'E_actual', 'idx', totColIdx);
    end
    if L1_ColIdx ~= -1 && L1_ColIdx <= size(data, 2)
        phases{end+1} = struct('name', 'E_actual_L1', 'idx', L1_ColIdx);
    end
    if L2_ColIdx ~= -1 && L2_ColIdx <= size(data, 2)
        phases{end+1} = struct('name', 'E_actual_L2', 'idx', L2_ColIdx);
    end
    if L3_ColIdx ~= -1 && L3_ColIdx <= size(data, 2)
        phases{end+1} = struct('name', 'E_actual_L3', 'idx', L3_ColIdx);
    end

    # Try to extract the time column
    try
        tod_cell = data(start_row:end, todColIdx);
    catch
        disp('Warning: Timeofday column index exceeds data dimensions. Plotting aborted.');
        return;
    end

    for p = 1:length(phases)
        phase = phases{p};
        target_name = phase.name;
        col_idx = phase.idx;

        # Extract phase column
        try
            val_cell = data(start_row:end, col_idx);
        catch
            disp(['Warning: Column index for ', target_name, ' exceeds data dimensions. Skipping plot.']);
            continue;
        end

        # Safely and efficiently check numeric types using cellfun
        is_num_val = cellfun('isclass', val_cell, 'double');
        is_num_tod = cellfun('isclass', tod_cell, 'double');
        valid = is_num_val & is_num_tod;

        if ~any(valid)
            disp(['Warning: No valid numeric data found for ', target_name, '. Skipping plot.']);
            continue;
        end

        # Convert cell arrays to double arrays
        Y = cell2mat(val_cell(valid));
        X_sec = cell2mat(tod_cell(valid));

        # Convert seconds since midnight to hours
        X = X_sec / 3600;

        # Clean NaNs
        valid_data = ~isnan(X) & ~isnan(Y);
        X = X(valid_data);
        Y = Y(valid_data);

        if isempty(X)
            disp(['Warning: No valid data points for ', target_name, ' after filtering NaNs. Skipping plot.']);
            continue;
        end

        disp(['Processing ', num2str(length(X)), ' data points for ', target_name, '...']);

        # Define 2D histogram bins (time of day uses 5-minute intervals)
        num_x_bins = 3 * 96; 
        x_edges = linspace(0, 24, num_x_bins + 1);

        # Logarithmic y-axis bin edges to natively scale the resolution
        # We use log10(val + 1) to handle zero consumption values gracefully
        y_min = max(0, min(Y));
        y_max = max(Y);
        
        num_y_bins = 300;
        y_edges_log = linspace(log10(y_min + 1), log10(y_max + 1), num_y_bins + 1);

        # Transform target values to log10 space for binning
        Y_log = log10(Y + 1);

        # Find bin index for each data point
        [~, x_bin] = histc(X, x_edges);
        [~, y_bin] = histc(Y_log, y_edges_log);

        # Clamp indices to [1, num_bins]
        x_bin(x_bin > num_x_bins) = num_x_bins;
        y_bin(y_bin > num_y_bins) = num_y_bins;

        # Keep only valid bins
        valid_bins = (x_bin > 0) & (y_bin > 0);
        x_bin = x_bin(valid_bins);
        y_bin = y_bin(valid_bins);

        if isempty(x_bin)
            disp(['Warning: No data points fell into valid bins for ', target_name, '. Skipping plot.']);
            continue;
        end

        # Accumulate counts
        H = accumarray([y_bin, x_bin], 1, [num_y_bins, num_x_bins]);

        # Compute bin centers in log space for plotting coordinates
        x_centers = x_edges(1:end-1) + diff(x_edges)/2;
        y_centers_log = y_edges_log(1:end-1) + diff(y_edges_log)/2;

        # Create headless figure
        hFig = figure('Visible', 'off');

        # Plot 2D density grid with logarithmic density scale
        imagesc(x_centers, y_centers_log, log10(H + 1));

        # Styling
        colormap('jet');
        hCb = colorbar;
        ylabel(hCb, 'Log10(Data point count + 1)');
        set(gca, 'YDir', 'normal');

        # Set human-readable tick marks in Watts on the logarithmic y-axis
        cand_ticks = [0, 10, 20, 50, 100, 200, 350, 500, 750, 1000, 1500, 2000, 3000, 4000, 5000, 7500, 10000];
        active_ticks = cand_ticks(cand_ticks >= y_min & cand_ticks <= y_max);
        
        # Fallback if range is very narrow
        if length(active_ticks) < 2
            active_ticks = linspace(y_min, y_max, 5);
        end
        
        # Format labels
        tick_labels = cell(1, length(active_ticks));
        for i = 1:length(active_ticks)
            val = round(active_ticks(i));
            if val >= 1000
                tick_labels{i} = [num2str(val/1000), 'k'];
            else
                tick_labels{i} = num2str(val);
            end
        end

        # Set tick locations and labels in log10 space
        set(gca, 'YTick', log10(active_ticks + 1));
        set(gca, 'YTickLabel', tick_labels);

        xlim([0, 24]);
        ylim([log10(y_min + 1), log10(y_max + 1)]);

        xlabel('Time of Day (Hours since Midnight)');
        ylabel('Power Consumption (W, Log Scale)');
        title(['Heatmap of Power Consumption (', target_name, ') over Time of Day']);

        # Grid and tick layout
        grid on;
        set(gca, 'XTick', 0:2:24);

        # Save to high-resolution PNG file
        output_png = sprintf('stromspion_heatmap_%s.png', target_name);
        try
            print(hFig, output_png, '-dpng', '-r150');
            disp(['Success! Heatmap plot for ', target_name, ' saved to "', output_png, '".']);
        catch e
            disp(['Error occurred while saving plot for ', target_name, ': ', e.message]);
        end

        # Clean up
        close(hFig);
    end
end
