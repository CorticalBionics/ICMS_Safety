load(fullfile(DataPath, 'DetectionData.mat'))
load(fullfile(DataPath, 'VMData_All.mat')); VMData = data; clearvars data

u_part = unique(VMData.Subject);
subjects = {'C1', 'C2', 'P2', 'P3', 'P4'};
num_subjects = length(subjects);
num_channels = 64;

%% Analyze
dw = 250; % Bin width in days
subj_max_days = zeros(size(DetectionData));
for i = 1:length(DetectionData)
    subj_max_days(i) = max(cellfun(@max, {DetectionData{i}.DateFromImplant}));
end
max_days = ceil(max(subj_max_days)/ dw) * dw; % Max days
de = 0 : dw : max_days; % Day edges
dx = de(1:end-1) + (dw/2); % Day center
t_max = 90; % Threshold over which to assume disabled

[discretized_thresholds, disabled_electrodes] = deal(cell(length(subjects), 1));
for s = 1:num_subjects
    % Format data
    % num_channels = size(DetectionData{s}, 2);
    % Date, threshold, channel
    [d, t] = deal(cell(num_channels, 1));
    enabled_channels = NaN(num_channels, length(dx));
    for i = 1:num_channels
        ch_idx = find([DetectionData{s}.Channel] == i);
        if isempty(ch_idx) % Skip untested channels
            continue
        end
        d{i} = DetectionData{s}(ch_idx).DateFromImplant;
        t{i} = DetectionData{s}(ch_idx).Threshold;
        
        % Find the last value with threshold below 'threshold'
        for j = 1:length(dx)
            if dx(j) > subj_max_days(s)
                break
            end
            idx = d{i} > de(j) & d{i} <= de(j+1);
            % If no thresholds, assume disabled
            if sum(idx) == 0
                enabled_channels(i,j) = NaN;
            elseif median(t{i}(idx)) > t_max
                enabled_channels(i,j) = 0;
            else
                enabled_channels(i,j) = 1;
            end
        end
    end
    disabled_electrodes{s} = enabled_channels;

    % Vectorize
    d = cat(2, d{:});
    t = round(cat(2, t{:}));
    
    % Discretize
    dv = cell(size(dx)); % Thresholds in each bin
    for i = 1:length(dx)
        dv{i} = t(d > de(i) & d <= de(i+1));
        dv{i}(isinf(dv{i})) = NaN;
    end
    discretized_thresholds{s} = dv;
end

%% VM analysis
total_charge = zeros(length(u_part), num_channels);
[cumulative_charge, cumulative_dates] = deal(cell(size(u_part)));
for pi = 1:length(u_part)
    % Filter participant
    s_idx = strcmp(VMData.Subject, u_part(pi));
    cumulative_dates{pi} = VMData.Date(s_idx);
    total_current = cat(2, VMData.CurrentCount{s_idx});
    total_current(total_current == 0) = NaN;
    all_charge = total_current .*  0.2; % Convert to charge, don't need to convert to millicoulombs

    % Charge across time
    total_charge(pi, :) = sum(all_charge, 2, 'omitnan');
    % Cumulative charge
    cumulative_charge{pi} = cumsum(all_charge, 2, 'omitnan');
end

%% Correlate VM data with detection data
clf; hold on
for s = 1:num_subjects
    x = total_charge(s, :)';
    y = NaN(num_channels, 1);
    for c = 1:num_channels % Make sure we are comparing correctly
        dt_idx = [DetectionData{s}.Channel] == c;
        if all(dt_idx == 0)
            continue
        end
        y(c) = DetectionData{s}(dt_idx).ThresholdDateCorrR;
    end
    if all(isnan(y))
        continue
    end
    % Plot
    scatter(x,y, 30, SubjectColors(u_part{s}), 'filled')
    % Linear regression
    idx = ~isnan(y);
    p = polyfit(x(idx),y(idx),1);
    xq = [min(x), max(x)];
    plot(xq, polyval(p, xq), 'Color', SubjectColors(u_part{s}), 'LineStyle', '--')
    corr(x,y, 'Rows', 'complete', 'Type', 'Kendall');
end

set(gca, 'XLim', [0, 3e7], 'YLim', [-1 1])
ylabel('Duration:Threhsold Correlation')
xlabel('Charge Delivered')

shg


%% Plot
SetFont('Arial', 9)
clf; 
set(gcf, 'Units', 'Inches', 'Position', [31 1 10 3])
% Detection thresholds
subplot(1,3,1); hold on
% axes('Position', [.1 .2 .35 .7]); hold on    
    for s = 1:num_subjects
        AlphaLine(dx, discretized_thresholds{s}, SubjectColors(subjects{s}), 'LineWidth', 2, 'IgnoreNan', 1)
    end
    
    
    % Format
    fmt = 'linear';
    if strcmpi(fmt, 'log')
        set(gca, 'XLim', [50 4000], ...
                 'YLim', [0 100], ...
                 'XScale', 'log')
    elseif strcmpi(fmt, 'linear')
        set(gca, 'XLim', [0 4000], ...
                 'YLim', [0 100], ...
                 'XScale', 'linear')
    end
    
    text(4000, 100, ColorText(subjects, SubjectColors(subjects)), ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top')
    
    ylabel(sprintf('Detection Threshold (%sA)', GetUnicodeChar('mu')))
    xlabel('Days From Implant')

% Threshold time correlation
subplot(1,3,2); hold on
    for s = 1:num_subjects
        col = repmat(SubjectColors(u_part{s}), length(DetectionData{s}), 1);
        % Color code correlatinos by significance
        idx = [DetectionData{s}.ThresholdDateCorrP] > 0.05;
        col(idx,:) = .8;
        Swarm(s, [DetectionData{s}.ThresholdDateCorrR], 'SwarmColor', col, 'DistributionWidth', .35)
    end
    set(gca, 'Ylim', [-1 1], 'XTick', [1:5], 'XTickLabel', ColorText(subjects, SubjectColors(u_part)), ...
        'XLim', [.5 5.5])
    ylabel(sprintf('Correlation (%s)', GetUnicodeChar('rho')))


% Disabled electrodes?
subplot(1,3,3); hold on
    for s = 1:num_subjects
        y = disabled_electrodes{s};
        % Fill missing values if a threshold was missed
        y = fillmissing(y, "linear", 2, "MaxGap", 3);
        y(isnan(y)) = 0;
        % Remove trailing 0s
        term_idx = find(~all(y == 0, 1), 1, 'last');

        plot(dx(1:term_idx), mean(y(:,1:term_idx), 1, 'omitmissing'), 'Color', SubjectColors(subjects{s}), ...
            'LineWidth', 2)
    end
    ylabel('p(Enabled Electrodes)')
    xlabel('Days From Implant')

shg


return

%% Individual participant raster + line plots
s = 1;
h = 2; w = 2;

clf; 
set(gcf, 'Units', 'Inches', 'Position', [31 1 15 8])
annotation("textbox", [.05 .85 .1 .1], 'String', ...
    ColorText(subjects(s), SubjectColors(subjects(s))), ...
    'EdgeColor', 'none', 'FontSize', 24)

% Raster plot of threshold
subplot(h,w,1); hold on
    % Format data
    % Date, threshold, channel
    [d, t, c] = deal(cell(num_channels, 1));
    for i = 1:num_channels
        ch_idx = find([DetectionData{s}.Channel] == i);
        if isempty(ch_idx) % Skip untested channels
            continue
        end
        c{i} = repelem(DetectionData{s}(ch_idx).Channel, length(DetectionData{s}(ch_idx).Dates));
        d{i} = DetectionData{s}(ch_idx).DateFromImplant;
        t{i} = DetectionData{s}(ch_idx).Threshold;
    end
    % Vectorize
    c = cat(2, c{:});
    d = cat(2, d{:});
    t = round(cat(2, t{:}));
    
    % Sort by color
    [ut, ~, it] = unique(t);
    cmap = winter(length(ut));
    for i = 1:length(ut)
        it_idx = it == i;
        x = d(it_idx);
        y = c(it_idx);
    
        % Set inf to black otherwise use cmap
        if isinf(ut(i)) || isnan(ut(i))
            col = [0,0,0];
        else
            col = cmap(i,:);
        end
    
        % Make raster format
        [x_vec, y_vec] = deal(NaN(1,1));
        for j = 1:length(x)
            x_vec = [x_vec, x(j), x(j), NaN]; %#ok<*AGROW> 
            y_vec = [y_vec, y(j)-0.5, y(j)+0.5, NaN];
        end
    
        % Plot
        plot(x_vec, y_vec, 'Color', col, 'LineWidth', 2)
    end
    set(gca, 'YLim', [.5 num_channels+.5], 'XLim', [0 max_days])
    ylabel('Electrode')
    xlabel('Days From Implant')

% Colorbar legend 
    p = get(gca, 'Position');
    pw = 0.125;
    px = p(1) + p(3) - pw;
    py = p(2) + p(4) + 0.035;
    cb = ColorbarLegend(gcf, [px, py, pw 0.0125], cmap, 'Horz', [0 100]);
    xlabel(cb, 'Detection Threshold (uA)', 'VerticalAlignment', 'bottom')


% Enabled/disabled
subplot(h,w,3);
    imagesc(dx, 1:num_channels, disabled_electrodes{s}, 'alphadata', ~isnan(disabled_electrodes{s}))
    set(gca, 'YDir', 'normal')

% Individual electrodes detection thresholds
subplot(h,w,2); hold on
        AlphaLine(dx, discretized_thresholds{s}, SubjectColors(subjects{s}), 'LineWidth', 2, 'IgnoreNan', 1)

    ylabel(sprintf('Detection Threshold (%sA)', GetUnicodeChar('mu')))
    xlabel('Days From Implant')
    set(gca, 'XLim', [0 max_days])


% Summary detection threshold
subplot(h,w,4); hold on
    col = repmat(SubjectColors(u_part{s}), length(DetectionData{s}), 1);
    % Color code correlatinos by significance
    idx = [DetectionData{s}.ThresholdDateCorrP] > 0.05;
    col(idx,:) = .8;
    Swarm(1, [DetectionData{s}.ThresholdDateCorrR], 'SwarmColor', col)
    set(gca, 'Ylim', [-1 1])

shg