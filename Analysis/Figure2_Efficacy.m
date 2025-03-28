load(fullfile(DataPath, 'DetectionData.mat'))
load(fullfile(DataPath, '..', 'BCI_HistoricalSurvey', 'ProcessedData', 'SurveyDataAll'))

subjects = {'BCI02', 'BCI03', 'CRS02b', 'CRS07', 'CRS08'};
subjects_alt = {'C1', 'C2', 'P2', 'P3', 'P4'};
num_subjects = length(subjects_alt);
num_channels = 64;

%% Summary statistics
for s = 1:num_subjects
    % Count total detection threshold measurements
    ndt = cellfun(@length, {DetectionData{s}.Threshold});
    fprintf('\n%s:\n', subjects_alt{s})
    fprintf('Total DTs: %d\n', sum(ndt));
    fprintf('Per electrode median (range): %1.0f (%1.0f-%1.0f)\n', prctile(ndt, [50, 25, 75]));
end

%% ANOVA on ddt/day slopes
[slopes_all, g1, g2] = deal(cell(length(DetectionData), 1));
for s = 1:length(DetectionData)
    y = [DetectionData{s}.ThresholdDateLinReg];
    slopes_all{s} = y(1:2:end)';
    g1{s} = repelem(s, length(slopes_all{s}), 1);
end

anova_tab = anovan(cat(1, slopes_all{:}), cat(1, g1{:}));

%% Analyze
dw = 250; % Bin width in days
subj_max_days = zeros(size(DetectionData));
for i = 1:length(DetectionData)
    subj_max_days(i) = max(cellfun(@max, {DetectionData{i}.DateFromImplant}));
end
max_days = ceil(max(subj_max_days)/ dw) * dw; % Max days
de = 0 : dw : max_days; % Day edges
dx = de(1:end-1) + (dw/2); % Day center
t_max = 60; % Threshold over which to assume disabled
term_idx = zeros(length(subjects), 1);

[discretized_thresholds, disabled_electrodes] = deal(cell(length(subjects_alt), 1));
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
        
        % Find threshold for each bin
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
    
    % Fill missing values if a threshold was missed
    enabled_channels = fillmissing(enabled_channels, "linear", 2, "MaxGap", 3);
    enabled_channels(isnan(enabled_channels)) = 0;
    disabled_electrodes{s} = enabled_channels;
    % Remove trailing 0s
    term_idx(s) = find(~all(enabled_channels == 0, 1), 1, 'last');

    % Vectorize
    d = cat(2, d{:});
    t = round(cat(2, t{:}));

    % Sort and find time to first sensation
    [~, sort_idx] = sort(d);
    d = d(sort_idx);
    t = t(sort_idx);
    ttfs_idx = find(~isnan(t) & ~isinf(t) & t < t_max, 1, 'first');
    fprintf('%s Time to first sensation: %d\n', subjects_alt{s}, d(ttfs_idx))
    
    % Discretize
    dv = cell(size(dx)); % Thresholds in each bin
    for i = 1:length(dx)
        dv{i} = t(d > de(i) & d <= de(i+1));
        dv{i}(isinf(dv{i})) = NaN;
    end
    discretized_thresholds{s} = dv;
end

%% Figure 2
SetFont('Arial', 9)

clf; 
set(gcf, 'Units', 'Inches', 'Position', [30 1 6.4 4])
[ax_w, ax_xs] = GetAxisCoords(3, .125, .05); ax_xs = ax_xs + .025;
[ax_h, ax_ys] = GetAxisCoords(2, .1, .1); ax_ys(2) = ax_ys(2) + .05;

h = 2; w = 3;

[corr_coeffs, corr_coeffs_p] = deal(NaN(num_subjects, 2));

% Detection thresholds
axes('Position', [ax_xs(1), ax_ys(2), ax_w, ax_h]); hold on
% axes('Position', [.1 .2 .35 .7]); hold on    
    for s = 1:num_subjects
        AlphaLine(dx, discretized_thresholds{s}, SubjectColors(subjects_alt{s}), ...
            'LineWidth', 2, 'IgnoreNan', 1)
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
    
    text(4000, 100, ColorText(subjects_alt, SubjectColors(subjects_alt)), ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top')
    
    ylabel(sprintf('Detection Threshold (%sA)', GetUnicodeChar('mu')))
    xlabel('Days From Implant')


% Threshold time relationship
axes('Position', [ax_xs(2), ax_ys(2), ax_w, ax_h]); hold on
    plot([.5 5.5], [0 0], 'Color', [.6 .6 .6], 'LineStyle', '--')
    for s = 1:num_subjects
        y = [DetectionData{s}.ThresholdDateLinReg];
        y = y(1:2:end);
        Swarm(s, y, SubjectColors(subjects_alt{s}), 'DistributionWidth', .35, 'DS', 'Box', 'SPL', 0)
    end
    set(gca, 'Ylim', [-.1 .1], ...
             'XTick', [1:5], ...
             'XTickLabel', ColorText(subjects_alt, SubjectColors(subjects_alt)), ...
             'XLim', [.5 5.5], ...
             'YTick', [-.1:.1:.2])
    ylabel(sprintf('%sDT (%sA/day)', GetUnicodeChar('Delta'), GetUnicodeChar('mu')))


% Functional electrodes
axes('Position', [ax_xs(3), ax_ys(2), ax_w, ax_h]); hold on
    for s = 1:num_subjects
        plot(dx(1:term_idx(s)), mean(disabled_electrodes{s}(:,1:term_idx(s)), 1, 'omitmissing'), ...
            'Color', SubjectColors(subjects_alt{s}), 'LineWidth', 2)
    end
    ylabel('p(Functional Electrodes)')
    xlabel('Days From Implant')


% Coverage line plots
axes('Position', [ax_xs(1), ax_ys(1), ax_w, ax_h]); hold on
    for s = 1:num_subjects
        prop_hand = zeros(term_idx(s), 1);
        for t = 1:term_idx(s)
            enabled_idx = logical(disabled_electrodes{s}(:,t));
            idx_all = cat(1, SurveyData{s}(1, enabled_idx).PFM_TIdx);
            nidx = unique(idx_all);
            prop_hand(t) = length(nidx) / total_palm_pixels;
        end
        plot(dx(1:term_idx(s)), prop_hand, 'Color', SubjectColors(subjects_alt{s}), ...
        'LineWidth', 2);
    end

    ylabel('Coverage')
    xlabel('Days From Implant')

% Coverage hand maps
axes('Position', [ax_xs(2), ax_ys(1), ax_w*1.5, ax_h]); hold on

AddFigureLabels(gcf, [.05 -.015])

% export_figure3x(FigurePath, 'Fig2_Efficacy')
shg
return

%% Enabled/disabled survey
% All pixels included in the palmar mask used, just don't want to add the dependencies to calculate this
total_palm_pixels = 410624;

clf; hold on
for s = 1:5
    % Disabled electrodes
    y = disabled_electrodes{s};
    % Fill missing values if a threshold was missed
    y = fillmissing(y, "linear", 2, "MaxGap", 3);
    y(isnan(y)) = 0;
    % Remove trailing 0s
    term_idx = find(~all(y == 0, 1), 1, 'last');
    
    prop_hand = zeros(term_idx, 1);
    for t = 1:term_idx
        enabled_idx = logical(y(:,t));
        idx_all = cat(1, SurveyData{s}(1, enabled_idx).PFM_TIdx);
        nidx = unique(idx_all);
        prop_hand(t) = length(nidx) / total_palm_pixels;
    end
    
    plot(dx(1:term_idx), mean(y(:,1:term_idx), 1, 'omitmissing'), 'Color', SubjectColors(subjects_alt{s}), ...
        'LineWidth', 2)

    ylabel('Functional Electrodes')
    
    yyaxis("right")
    plot(dx(1:term_idx), prop_hand, 'Color', SubjectColors(subjects_alt{s}), ...
        'LineWidth', 2, 'LineStyle', '--');
end

h = gca();
h.YAxis(2).Color = [.6 .6 .6];
ylabel('Coverage')


%% Plot all
s = 2;
clf;
map = zeros(1200, 1050);
for e = 1:64
    map(SurveyData{s}(e).PFM_TIdx) = map(SurveyData{s}(e).PFM_TIdx) + 1;
end

imagesc(map)