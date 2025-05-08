% Signal Quality Analysis

%Data Folder
dataPath = 'P:\users\tgh28\Experiments\Longitudinal_ICMS\signal_quality_data';

%Set Colors for Sensory and Motor arrays
motor_color = rgb(48, 63, 159); %Blue
sensory_color = rgb(245, 124, 0); %Orange

subjects = {'C1', 'C2', 'P2' 'P3', 'P4'; ...
    'BCI02', 'BCI03', 'CRS02', 'CRS07', 'CRS08'};

%Get data folder
flist = dir(dataPath);
num_participants = length(flist);

%% Get total charge per ch
% Load voltage data
load("P:\users\tgh28\Experiments\Longitudinal_ICMS\VMData_All.mat");
VMData = data;
clearvars data

u_part = unique(VMData.Subject);
num_subjects = length(subjects);

% Get total charge
conversion_factor = 1e6;
total_charge = zeros(length(u_part), 64);

for pi = 1:length(u_part)

    % Filter by participant
    s_idx = strcmp(VMData.Subject, u_part(pi));

    total_current = cat(2, VMData.CurrentCount{s_idx});
    total_current(total_current == 0) = NaN;

    all_charge = total_current .*  0.2 ./ conversion_factor; % Convert to charge in mC

    % Charge across time
    total_charge(pi, :) = sum(all_charge, 2, 'omitnan');
end

%% Intialize Graph
figure;
set(gcf, 'Units', 'Inches', 'Position', [27, 1, 9, 8.5]);
SetFont('Arial', 9)

[ax_size, ax_val] = GetAxisCoords(num_subjects, 0.05, 0.04);
ax_val = flipud(ax_val) + 0.01;
xw = 0.26; yh = ax_size; xs = [0.05, 0.38, 0.69];

%% Graph per participant
for m = 3:num_participants

    %Load data
    load(fullfile(dataPath, flist(m).name));
    num_arrays = length(implant_metadata.array_names);

    %Get Participant name for Graph
    fileSplit = strsplit(flist(m).name, '_');
    ID = fileSplit{1};
    name_idx = find(strcmp(subjects(2, :), ID));
    participant = subjects{1, name_idx};

    %Get SNR and data data
    y = cat(1, signal_quality_analysis.ch_snr);
    y = 10.^(y./20); % Undo log scaling
    x = datetime(num2str(session_dates'), 'Format', 'yyyyMMdd');
    y_mask = NaN(size(y));

    %For each array get the data from the good days
    for a = 1:num_arrays
        mask = good_session_mask{a}; %wanted days
        idx = implant_metadata.chan_indices{a}; %wanted chs
        y_mask(mask, idx) = y(mask, idx);
    end

    y_mask = movmedian(y_mask, 3, 1, 'omitnan');

    sensory_mask = implant_metadata.chan_indices(contains(implant_metadata.array_names, 'sensory', 'IgnoreCase', true));
    sensory_mask = cat(2, sensory_mask{:});
    y_sensory = median(y_mask(:, sensory_mask), 2, 'omitnan');

    motor_mask = implant_metadata.chan_indices(contains(implant_metadata.array_names, 'motor', 'IgnoreCase', true));
    motor_mask = cat(2, motor_mask{:});
    y_motor = median(y_mask(:, motor_mask), 2, 'omitnan');

    %y_sensory = median(y(:, contains(implant_metadata.array_names, 'sensory', 'IgnoreCase', true)), 2);
    %y_motor = median(y(:, contains(implant_metadata.array_names, 'motor', 'IgnoreCase', true)), 2);


    %% Get the slopes of SNR
    num_sensory = length(sensory_mask);
    sensory_SNR_slopes = NaN(num_sensory, 1);
    x_num = datenum(x); %#ok<*DATNM>

    for c = 1:num_sensory
        ch = sensory_mask(c);
        y_ch = y_mask(:, ch);

        %Get index of Nans
        nan_idx = ~isnan(y_ch);

        %Calculate slope
        m = polyfit(x_num(nan_idx), y_ch(nan_idx), 1); %#ok<*FXSET>
        sensory_SNR_slopes(c) = m(1);
    end

    %% Get slopes of Vpp
    v = cat(1, signal_quality_analysis.ch_vpp);
    v_mask = NaN(size(v));
    sensory_Vpp_slopes = NaN(length(sensory_mask), 1);

    %Get data from only the good days
    for a = 1:num_arrays
        mask = good_session_mask{a}; %wanted days
        idx = implant_metadata.chan_indices{a}; %wanted chs
        v_mask(mask, idx) = v(mask, idx);
    end

    %Calculate the Vpp slope per ch
    for c = 1:num_sensory
        ch = sensory_mask(c);
        v_ch = v_mask(:, ch);

        nan_idx = ~isnan(v_ch);
        m = polyfit(x_num(nan_idx), v_ch(nan_idx), 1);
        sensory_Vpp_slopes(c) = m(1);
    end

    %% Plot data

    %Plot median SNR over time
    axes('Position', [xs(1), ax_val(name_idx), xw, yh]); hold on

    plot(x, y_sensory, 'Color', sensory_color, 'LineWidth', 1.5); hold on
    plot(x, y_motor, 'Color', motor_color, 'LineWidth', 1.5);
    box off;
    ylim([0 3]);
    title(participant, 'Color', SubjectColors(participant));
    ylabel('Median SNR');
    if name_idx == num_subjects
        xlabel('Days post implant');
    end

    %Plot Total charge
    charge = total_charge(name_idx, :);
    charge = charge';
    axes('Position', [xs(2), ax_val(name_idx), xw, yh]); hold on
    scatter(charge, sensory_SNR_slopes, 30, SubjectColors(participant), 'filled', 'MarkerFaceAlpha', 0.3);

    %Plot best fit line for SNR vs Charge
    idx = ~isnan(charge) & ~isnan(sensory_SNR_slopes);
    if sum(idx) >= 3
        % Exponential curve fit
        f = polyfit(charge(idx), sensory_SNR_slopes(idx), 1);
        xq = linspace(0, max(charge(idx)));
        yq = polyval(f, xq);
        plot(xq, yq, 'Color', SubjectColors(ID), 'LineWidth', 2);

        %Stats
        [r, p] = corr(charge, sensory_SNR_slopes, 'Type', 'Spearman', 'Rows', 'complete');
        text(max(charge)*0.95, max(sensory_SNR_slopes)*0.95, pStr(p), ...
            'HorizontalAlignment', 'right', 'Color', [.2 .2 .2]);
    end
    ylabel('SNR Slope')
    if name_idx == num_subjects
        xlabel('Charge Delivered (mC)')
    end
    box off

    %Plot Vpp slope vs. charge
    axes('Position', [xs(3), ax_val(name_idx), xw, yh]); hold on
    scatter(charge, sensory_Vpp_slopes, 30, SubjectColors(participant), 'filled', 'MarkerFaceAlpha', 0.3);

    % Plot best fit line
    idx = ~isnan(charge) & ~isnan(sensory_Vpp_slopes);
    if sum(idx) >= 3
        p = polyfit(charge(idx), sensory_Vpp_slopes(idx), 1);
        xq = linspace(0, max(charge(idx)));
        yq = polyval(p, xq);
        plot(xq, yq, 'Color', SubjectColors(participant), 'LineWidth', 2);

        % Stats
        [r, pval] = corr(charge, sensory_Vpp_slopes, 'Type', 'Spearman', 'Rows', 'complete');
        text(max(charge)*0.95, max(sensory_Vpp_slopes)*0.95, pStr(pval), ...
            'HorizontalAlignment', 'right', 'Color', [.2 .2 .2]);
    end
    ylabel('Vpp Slope');
    if name_idx == num_subjects
        xlabel('Charge Delivered (mC)');
    end
    box off;
end

%Add Axis Labels 
%axes('Position', [xs(1), ax_val(1) + 0.065, xw, 0.01]); title('Median SNR over Time');
%axes('Position', [xs(2), ax_val(1) + 0.065, xw, 0.01]); title('SNR Slope vs. Charge');
%axes('Position', [xs(3), ax_val(1) + 0.065, xw, 0.01]); title('Vpp Slope vs. Charge');




