% Signal Quality Analysis
subjects = {'BCI02', 'BCI03', 'CRS02', 'CRS07', 'CRS08'};
subject_alt = {'C1', 'C2', 'P2' 'P3', 'P4'};
num_participants = length(subjects);
num_arrays = 4;

%% Load SQ, VM, and Cleaning Data
% Get list of SQ data
flist = dir(fullfile(DataPath, 'SignalQuality', '*.mat'));
SQData = cell(num_participants, 1);

% Load voltage data
load(fullfile(DataPath, "VMData_All.mat"));
VMData = data;
conversion_factor = 1e6;
total_charge = zeros(length(subjects), 64);

% Load cleaning data
load(fullfile(DataPath, 'CleaningData'));
% Remove data from before 14-Aug-2017 (different monitoring system)
min_date = datetime(736920, 'ConvertFrom', 'datenum');
for p = 1:num_participants
    idx = [cleaning_data{p}.date] > min_date;
    cleaning_data{p} = cleaning_data{p}(idx); %#ok<SAGROW>
end

% Load SQData and process VM data
implant_dates = NaT(num_participants, 1);
for pi = 1:num_participants
    % Load SQ Data
    SQData{pi} = load(fullfile(DataPath, 'SignalQuality', flist(pi).name));
    SQData{pi}.participant = flist(pi).name(1:5);
    implant_dates(pi) = datetime(SQData{pi}.implant_metadata.implant_date, 'Format', 'dd-MMM-uuuu');

    % Filter VM data by participant
    s_idx = strcmp(data.Subject, subjects(pi));
    total_current = cat(2, data.CurrentCount{s_idx});
    all_charge = total_current .*  0.2 ./ conversion_factor; % Convert to charge in mC
    total_charge(pi, :) = sum(all_charge, 2, 'omitnan');
end
SQData = cat(1, SQData{:});


clearvars data all_charge total_current s_idx pi

%% Analyze SNR/VPP/Cleaning
[SNR_r, SNR_rp, SNR_slope, Vpp_r, Vpp_rp, Vpp_slope] = deal(NaN(256, num_participants));
[Cln_r, Cln_rp, Cln_slope] = deal(NaN(64, num_participants));
[median_SNR, median_Vpp, median_vinter] = deal(cell(num_participants, 1));

correlation_type = 'spearman';
for pi = 1:num_participants
    % Get sensory and motor masks
    sens_idx = contains(SQData(pi).implant_metadata.array_names, 'sensory', 'IgnoreCase', true);
    sensory_mask = SQData(pi).implant_metadata.chan_indices(sens_idx);
    sensory_mask = cat(2, sensory_mask{:});
    motor_idx = contains(SQData(pi).implant_metadata.array_names, 'motor', 'IgnoreCase', true);
    motor_mask = SQData(pi).implant_metadata.chan_indices(motor_idx);
    motor_mask = cat(2, motor_mask{:});


    %%% SNR
    x = datetime(num2str(SQData(pi).session_dates'), 'Format', 'yyyyMMdd');
    x = years(x - x(1));
    y = cat(1, SQData(pi).signal_quality_analysis.ch_snr);
    y = 10.^(y./20); % Undo log scaling

    % Apply good session mask
    y_mask = NaN(size(y));
    for a = 1:num_arrays
        % Skip anterior/lateral motor arrays in BCI02 and BCI03
        if startsWith(subjects{pi}, 'BCI') && strcmp(SQData(p).implant_metadata.array_names{a}, 'Anterior Motor')
            continue
        end
        mask = SQData(pi).good_session_mask{a}; % Good days
        idx = SQData(pi).implant_metadata.chan_indices{a}; % Good chs
        y_mask(mask, idx) = y(mask, idx);
    end

    [SNR_r(:,pi), SNR_rp(:,pi)] = corr(x, y_mask, 'Rows', 'pairwise', 'type', correlation_type);
    for c = 1:256
        SNR_slope(c, pi) = nan_regression(x, y_mask(:,c));
    end
    
    % Smooth & subsample
    y_mask = movmedian(y_mask, 3, 1, 'omitnan');
    median_SNR{pi}.sensory = median(y_mask(:, sensory_mask), 2, 'omitnan');
    median_SNR{pi}.motor = median(y_mask(:, motor_mask), 2, 'omitnan');


    %%% Vpp
    y = cat(1, SQData(pi).signal_quality_analysis.ch_vpp); % Same x as SNR

    % Apply good session mask
    y_mask = NaN(size(y));
    for a = 1:num_arrays
        mask = SQData(pi).good_session_mask{a}; % Good days
        idx = SQData(pi).implant_metadata.chan_indices{a}; % Good chs
        y_mask(mask, idx) = y(mask, idx);
    end

    [Vpp_r(:,pi), Vpp_rp(:,pi)] = corr(x, y_mask, 'Rows', 'pairwise', 'type', correlation_type);
    for c = 1:256
        Vpp_slope(c, pi) = nan_regression(x, y_mask(:,c));
    end
    
    % Smooth & subsample
    y_mask = movmedian(y_mask, 3, 1, 'omitnan');
    median_Vpp{pi}.sensory = median(y_mask(:, sensory_mask), 2, 'omitnan');
    median_Vpp{pi}.motor = median(y_mask(:, motor_mask), 2, 'omitnan');
    

    %%% Cleaning
    idx = cellfun(@(c) ~isempty(c), {cleaning_data{pi}.vmin});
    x = datetime(datenum([cleaning_data{pi}(idx).date]), 'ConvertFrom', 'datenum');
    x = years(x - x(1));
    y = cat(2, [cleaning_data{pi}(idx).vinter]);
    [Cln_r(:,pi), Cln_rp(:,pi)] = corr(x', y', 'Rows', 'pairwise', 'type', correlation_type);
    for c = 1:64
        Cln_slope(c, pi) = nan_regression(x, y(c,:));
    end
    median_vinter{pi} = median(y, 1, 'omitmissing');
end

% Holm Bonferroni correction
SNR_rp = HolmBonferroni(SNR_rp);
Vpp_rp = HolmBonferroni(Vpp_rp);
Cln_rp = HolmBonferroni(Cln_rp);

%% Correlate SNR/VPP/Cleaning with VMData on sensory arrays




%% Supplementary Figure 3
[ax_size_y, ax_y_val] = GetAxisCoords(num_participants + 1, 0.04, 0.05);
ax_y_val = ax_y_val + 0.025; ax_y_val = flipud(ax_y_val);
ax_y_val(end) = ax_y_val(end) - 0.025;
[ax_size_x, ax_x_val] = GetAxisCoords(3, 0.1, 0.075);
marker_size = 5;

motor_color = rgb(244, 67, 54); % Red
sensory_color = rgb(0, 137, 123); % Teal

clf;
set(gcf, 'Units', 'Inches', 'Position', [27, 1, 6.45, 8.5]);
SetFont('Arial', 9)

% Line plots
for p = 1:num_participants
    % Get dates for SQData
    x = datetime(num2str(SQData(p).session_dates'), 'Format', 'yyyyMMdd');
    x = years(x - implant_dates(p));
    xl = [0, ceil(x(end))];
    xt = [xl(1):xl(end)];
    xl = [xl(1) - range(xl) * 0.05, xl(end) + range(xl) * 0.05];
    xtl = cell(size(xt));
    for i = 1:length(xtl)
        if i == 1
            xtl{i} = '0';
        elseif i == length(xtl)
            xtl{i} = num2str(i-1);
        else
            xtl{i} = '';
        end
    end

    % SNR
    axes('Position', [ax_x_val(1), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        % Sensory
        y = median_SNR{p}.sensory;
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .05)
        r = polyfit(datenum(x(~isnan(y))), y(~isnan(y)), 1);
        plot(xl, polyval(r, datenum(xl)), 'Color', sensory_color);
        % Motor
        y = median_SNR{p}.motor;
        scatter(x, y, marker_size, motor_color, 'MarkerEdgeAlpha', .05)
        r = polyfit(datenum(x(~isnan(y))), y(~isnan(y)), 1);
        plot(xl, polyval(r, datenum(xl)), 'Color', motor_color);
        
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabel', xtl, ...
                 'YLim', [0.75, 2], ...
                 'XTickLabelRotation', 0)
        
        % Formatting
        if p == 1
            [tx, ty] = GetAxisPosition(gca, 5, 5);
            text(tx, ty, ColorText({'Motor', 'Sensory'}, [motor_color; sensory_color]), ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom')
        elseif p == round(num_participants / 2)
            ylabel('SNR', 'FontWeight', 'bold')
        end
        title(ColorText(subject_alt{p}, SubjectColors(subject_alt{p})), 'VerticalAlignment', 'top')

    % Vpp
    axes('Position', [ax_x_val(2), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        % Sensory
        y = median_Vpp{p}.sensory;
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .05)
        r = polyfit(datenum(x(~isnan(y))), y(~isnan(y)), 1);
        plot(xl, polyval(r, datenum(xl)), 'Color', sensory_color);
        % Motor
        y = median_Vpp{p}.motor;
        scatter(x, y, marker_size, motor_color, 'MarkerEdgeAlpha', .05)
        r = polyfit(datenum(x(~isnan(y))), y(~isnan(y)), 1);
        plot(xl, polyval(r, datenum(xl)), 'Color', motor_color);
        
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabels', xtl, ...
                 'YLim', [0, 200], ...
                 'XTickLabelRotation', 0)
    
        if p == round(num_participants / 2)
            ylabel(sprintf('Vpp (%sV)', GetUnicodeChar('mu')), 'FontWeight', 'bold')
        elseif p == num_participants
            xlabel('Years Implanted', 'FontWeight', 'bold')
        end

    % Cleaning
    axes('Position', [ax_x_val(3), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        idx = cellfun(@(c) ~isempty(c), {cleaning_data{p}.vmin});
        x = [cleaning_data{p}(idx).date];
        x = years(x - implant_dates(p));
        y = median_vinter{p};
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .05)
    
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabels', xtl, ...
                 'YLim', [-3, 0], ...
                 'XTickLabelRotation', 0)
    
        if p == round(num_participants / 2)
            ylabel(sprintf('V_{inter} (%sV)', GetUnicodeChar('mu')), 'FontWeight', 'bold')
        end
end

% Summary slopes
xl = [1-.75 num_participants+.75];
ax1 = axes('Position', [ax_x_val(1), ax_y_val(6), ax_size_x, ax_size_y]); hold on
    plot(xl, [0, 0], 'Color', [.6 .6 .6], 'LineStyle', '--')
ax2 = axes('Position', [ax_x_val(2), ax_y_val(6), ax_size_x, ax_size_y]); hold on
    plot(xl, [0, 0], 'Color', [.6 .6 .6], 'LineStyle', '--')

    offset = 0.05;
    for pi = 1:num_participants
        % Get indices to split arrays
        sens_idx = contains(SQData(pi).implant_metadata.array_names, 'sensory', 'IgnoreCase', true);
        sensory_mask = SQData(pi).implant_metadata.chan_indices(sens_idx);
        sensory_mask = cat(2, sensory_mask{:});
        motor_idx = contains(SQData(pi).implant_metadata.array_names, 'motor', 'IgnoreCase', true);
        motor_mask = SQData(pi).implant_metadata.chan_indices(motor_idx);
        motor_mask = cat(2, motor_mask{:});

        % Plot SNR
        Swarm(pi-offset, SNR_slope(sensory_mask, pi), sensory_color, 'Parent', ax1, ...
            'Sides', 'left', 'DS', 'violin', 'SPL', 0, 'DW', .35)
        Swarm(pi+offset, SNR_slope(motor_mask, pi), motor_color, 'Parent', ax1, ...
            'Sides', 'right', 'DS', 'violin', 'SPL', 0, 'DW', .35)

        % Plot Vpp
        Swarm(pi-offset, Vpp_slope(sensory_mask, pi), sensory_color, 'Parent', ax2, ...
            'Sides', 'left', 'DS', 'violin', 'SPL', 0, 'DW', .35)
        Swarm(pi+offset, Vpp_slope(motor_mask, pi), motor_color, 'Parent', ax2, ...
            'Sides', 'right', 'DS', 'violin', 'SPL', 0, 'DW', .35)
    end
    set(ax1, 'YLim', [-1.5 1.5], ...
             'XLim', xl, ...
             'XTick', [1:num_participants], ...
             'XTickLabels', ColorText(subject_alt, SubjectColors(subject_alt)))
    ylabel(ax1, sprintf('%sSNR/year', GetUnicodeChar('Delta')), 'FontWeight', 'bold')

    set(ax2, 'YLim', [-150 100], ...
             'XLim', xl, ...
             'XTick', [1:num_participants], ...
             'XTickLabels', ColorText(subject_alt, SubjectColors(subject_alt)))
    ylabel(ax2, sprintf('%sVpp (%sV/year)', GetUnicodeChar('Delta'), GetUnicodeChar('mu')), 'FontWeight', 'bold')

axes('Position', [ax_x_val(3), ax_y_val(6), ax_size_x, ax_size_y]); hold on
    plot(xl, [0, 0], 'Color', [.6 .6 .6], 'LineStyle', '--')
    for pi = 1:num_participants
        Swarm(pi-offset, Cln_slope(:, pi), sensory_color, ...
            'Sides', 'both', 'DS', 'violin', 'SPL', 0, 'DW', .35)
    end

    set(gca, 'YLim', [-1.5 1.5], ...
             'XLim', xl, ...
             'XTick', [1:num_participants], ...
             'XTickLabels', ColorText(subject_alt, SubjectColors(subject_alt)))
    ylabel(sprintf('%sV_{inter} (%sV/year)', GetUnicodeChar('Delta'), GetUnicodeChar('mu')), 'FontWeight', 'bold')

shg


function slope = nan_regression(x, y)
    slope = NaN;
    nan_idx = isnan(y);
    if sum(~nan_idx) < 10
        return
    end
    if ~all(size(y) == size(x))
        y = y';
    end
    pf = polyfit(x(~nan_idx)', y(~nan_idx)', 1);
    slope = pf(1);
end