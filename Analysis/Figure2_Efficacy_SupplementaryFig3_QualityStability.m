load(fullfile(DataPath, 'DetectionData.mat'))
load(fullfile(DataPath, 'QualityData.mat'))
load(fullfile(DataPath, '..', 'BCI_HistoricalSurvey', 'ProcessedData', 'SurveyDataAll'))

subjects = {'BCI02', 'BCI03', 'CRS02b', 'CRS07', 'CRS08'};
subjects_alt = {'C1', 'C2', 'P2', 'P3', 'P4'};
num_subjects = length(subjects_alt);
num_channels = 64;
t_max = 80; % Threshold over which to assume disabled

% Thick palm
[~, palmar_template, ~, ~] = GetHandMasks();
palm_thick = mean(palmar_template,3);
palm_thick = bwmorph(~palm_thick, 'thicken', 3);
palm_thick = uint8(repmat(~palm_thick,[1,1,3])) .* 255;
% All pixels included in the palmar mask used, just don't want to add the dependencies to calculate this
total_palm_pixels = 410624;

%% Detection threshold summary statistics
for s = 1:num_subjects
    % Count total detection threshold measurements
    ndt = cellfun(@length, {DetectionData{s}.Threshold});
    fprintf('\n%s:\n', subjects_alt{s})
    fprintf('Total DTs: %d\n', sum(ndt));
    fprintf('Per electrode median (range): %1.0f (%1.0f-%1.0f)\n', prctile(ndt, [50, 25, 75]));
end

%% ANOVA on ddt/day slopes
[slopes_all, g1, g2] = deal(cell(length(DetectionData), 1));
for s = 1:length(DetectionData)-1
    y = [DetectionData{s}.ThresholdDateLinReg];
    slopes_all{s} = y(1:2:end)'; % Alternates between slope and offest
    g1{s} = repelem(s, length(slopes_all{s}), 1);
    fprintf('%s mean DT slope = %0.2f\n', subjects_alt{s}, median(slopes_all{s}, 'omitnan') .* 365)
end
fprintf('Grand mean DT slope = %0.2f\n', mean(cat(1, slopes_all{:}), 'omitnan') * 365)
anova_tab = anovan(cat(1, slopes_all{:}), cat(1, g1{:}));

%% Analyze detection thresholds
dw = 250; % Bin width in days
subj_max_days = zeros(size(DetectionData));
for i = 1:length(DetectionData)
    subj_max_days(i) = max(cellfun(@max, {DetectionData{i}.DateFromImplant}));
end
max_days = ceil(max(subj_max_days)/ dw) * dw; % Max days
de = 0 : dw : max_days; % Day edges
dx = de(1:end-1) + (dw/2); % Day center
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
    enabled_channels = enabled_channels == 1;
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
        idx = d > de(i) & d <= de(i+1);
        if sum(idx) < 5 % Only add to bin if at least 5 observations
            continue
        end
        dv{i} = t(idx);
        dv{i}(isinf(dv{i})) = NaN;
    end
    discretized_thresholds{s} = dv;
end

%% Analyze quality data
unique_surveys = zeros(num_subjects, 1);
for i = 1:num_subjects
    nu = zeros(num_channels, 1);
    for c = 1:num_channels
        nu(c) = sum(QualityData(i).Responses.channel == c);
    end
    unique_surveys(i) = mode(nu);
end

%% Figure 2
SetFont('Arial', 9)

clf;
clearvars ax

set(gcf, 'Units', 'Inches', 'Position', [30 1 6.4 4])
[ax_w, ax_xs] = GetAxisCoords(3, .1, .05); ax_xs = ax_xs + .025;
[ax_h, ax_ys] = GetAxisCoords(2, .1, .1); ax_ys(2) = ax_ys(2) + .05;

h = 2; w = 3;

[corr_coeffs, corr_coeffs_p] = deal(NaN(num_subjects, 2));

% Detection thresholds
ax(1) = axes('Position', [ax_xs(1), ax_ys(2), ax_w, ax_h]); hold on
% axes('Position', [.1 .2 .35 .7]); hold on    
    for s = 1:num_subjects
        AlphaLine(dx ./ 365, discretized_thresholds{s}, SubjectColors(subjects_alt{s}), ...
            'LineWidth', 2, 'IgnoreNan', 1)
    end
    
    % Format
    fmt = 'linear';
    if strcmpi(fmt, 'log')
        set(gca, 'XLim', [0.5 10.5], ...
                 'YLim', [0 100], ...
                 'XScale', 'log')
    elseif strcmpi(fmt, 'linear')
        set(gca, 'XLim', [0 10.5], ...
                 'YLim', [0 100], ...
                 'XScale', 'linear')
    end
    
    text(4000, 100, ColorText(subjects_alt, SubjectColors(subjects_alt)), ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top')
    
    ylabel(sprintf('Detection Threshold (%sA)', GetUnicodeChar('mu')))
    xlabel('Years from Implant')


% Threshold time relationship
ax(2) = axes('Position', [ax_xs(2), ax_ys(2), ax_w, ax_h]); hold on
    plot([.5 5.5], [0 0], 'Color', [.6 .6 .6], 'LineStyle', '--')
    for s = 1:num_subjects-1
        y = [DetectionData{s}.ThresholdDateLinReg];
        y = y(1:2:end);
        Swarm(s, y .* 365, SubjectColors(subjects_alt{s}), 'DistributionWidth', .35, 'DS', 'Box', 'SPL', 0)
    end
    set(gca, 'Ylim', [-30 70], ...
             'XTick', [1:5], ...
             'XTickLabel', ColorText(subjects_alt, SubjectColors(subjects_alt)), ...
             'XLim', [.5 5.5], ...
             'YTick', [-30:30:60])
    ylabel(sprintf('%sDT (%sA/year)', GetUnicodeChar('Delta'), GetUnicodeChar('mu')))


% Functional electrodes
ax(3) = axes('Position', [ax_xs(3), ax_ys(2), ax_w, ax_h]); hold on
    for s = 1:num_subjects
        plot(dx(1:term_idx(s)) ./ 365, mean(disabled_electrodes{s}(:,1:term_idx(s)), 1, 'omitmissing'), ...
            'Color', SubjectColors(subjects_alt{s}), 'LineWidth', 2)
    end
    ylabel('p(Functional Electrodes)')
    xlabel('Years from Implant')

% Coverage hand maps
% P2 Timepoint 1
    p = [0.025, .25, 0.15, ax_h / 2];
    s = 3; t = 1;
    mini_hand_map(palm_thick, SurveyData, disabled_electrodes, subjects, p, s, t)
    title('Year 1')

% P2 Timepoint 2
    p = [0.165, .25, 0.15, ax_h / 2];
    s = 3; t = floor(length(dx) / 2);
    mini_hand_map(palm_thick, SurveyData, disabled_electrodes, subjects, p, s, t)
    title('Year 5')

% P2 Timepoint 3
    p = [0.305, .25, 0.15, ax_h / 2];
    s = 3; t = length(dx);
    mini_hand_map(palm_thick, SurveyData, disabled_electrodes, subjects, p, s, t)
    title('Year 10')

% C1 Timepoint 1
    p = [0.025, .05, 0.15, ax_h / 2];
    s = 1; t = 1;
    mini_hand_map(palm_thick, SurveyData, disabled_electrodes, subjects, p, s, t)

% C1 Timepoint 2
    p = [0.165, .05, 0.15, ax_h / 2];
    s = 1; t = floor(length(dx) / 2) - 1;
    mini_hand_map(palm_thick, SurveyData, disabled_electrodes, subjects, p, s, t)

% Labels 
AddFigureLabels(ax, [0.05 -0.01])
char_offset = 67;
annotation("textbox", [0.025 .45 .05 .05], 'String', char(char_offset+1), ...
'VerticalAlignment','top', 'HorizontalAlignment','left', 'EdgeColor', 'none', 'FontWeight','bold')

annotation("textbox", [0.475 .45 .05 .05], 'String', char(char_offset+2), ...
'VerticalAlignment','top', 'HorizontalAlignment','left', 'EdgeColor', 'none', 'FontWeight','bold')

% export_figure3x(FigurePath, 'Fig2_Efficacy')

shg
return


%% Supplementary Figure 3
clf; 
% Relative coverage
subplot(3,3,1); hold on
    for s = 1:num_subjects
        prop_hand = zeros(term_idx(s), 1);
        for t = 1:term_idx(s)
            enabled_idx = disabled_electrodes{s}(:,t) == 1;
            idx_all = cat(1, SurveyData{s}(1, enabled_idx).PFM_TIdx);
            nidx = unique(idx_all);
            prop_hand(t) = length(nidx) / total_palm_pixels;
        end
        prop_hand = prop_hand ./ max(prop_hand);
        plot(dx(1:term_idx(s)) ./ 365, prop_hand, 'Color', SubjectColors(subjects_alt{s}), ...
        'LineWidth', 2);
    end
    
    ylabel('Relative Coverage')
    xlabel('Years from Implant')

% Number of surveys
subplot(3,3,2); hold on
    for s = 1:num_subjects
        Swarm(s, unique_surveys(s), 'DS', 'Bar', 'SPL', 0, 'Color', SubjectColors(subjects_alt{s}))
    end

    set(gca, 'XLim', [.5 5.5], ...
             'XTick', [1:5], ...
             'XTickLabel', ColorText(subjects_alt, SubjectColors(subjects_alt)))
    ylabel('# Surveys')

% Pain frequency
subplot(3,3,3); hold on
    for s = 1:num_subjects
        Swarm(s, mean(QualityData(s).Responses.Pain > 0) * 100 ,...
            'DS', 'Bar', 'SPL', 0, 'Color', SubjectColors(subjects_alt{s}))
    end

    set(gca, 'XLim', [.5 5.5], ...
             'XTick', [1:5], ...
             'XTickLabel', ColorText(subjects_alt, SubjectColors(subjects_alt)), ...
             'YLim', [0 100])
    ylabel('Pain Reported (%)')

% Pain rating
subplot(3,3,4); hold on

    % Stim related
    % P3
    idx = QualityData(4).Responses.Pain > 0;
    Swarm(3, mean(QualityData(4).Responses.Pain (idx)),...
        'DS', 'Bar', 'SPL', 0, 'Color', SubjectColors('P3'))
    % P4
    idx = QualityData(5).Responses.Pain > 0;
    Swarm(4, mean(QualityData(5).Responses.Pain (idx)),...
        'DS', 'Bar', 'SPL', 0, 'Color', SubjectColors('P4'))
    % 
    % set(gca, 'XLim', [.5 5.5], ...
    %          'XTick', [1:5], ...
    %          'XTickLabel', ColorText(subjects_alt, SubjectColors(subjects_alt)))
    ylabel('Pain Rating')



shg

%% Functions
function mini_hand_map(palm_thick, SurveyData, disabled_electrodes, subjects, p, s, t)
    palm_ax = axes('Position', p); hold on
    imshow(palm_thick)

    overlay_ax = axes('Position', gca().Position);
    overlay = zeros(size(palm_thick, [1, 2]));
    for e = 1:64
        if disabled_electrodes{s}(e,t) == 1
            % overlay(SurveyData{s}(e).PFM_TIdx) = 0.5;
            overlay(SurveyData{s}(e).PFM_TIdx) = overlay(SurveyData{s}(e).PFM_TIdx) + 0.1;
        end
    end
    imagesc(overlay, 'AlphaData',  overlay)
    colormap(overlay_ax, ColorGradient(SubjectColors(subjects{s}), SubjectColors(subjects{s})))

    xl = [0 1050]; yl = [0 750];

    set(overlay_ax, 'DataAspectRatio', [1 1 1], 'Color', 'none', 'XColor', 'none', 'YColor', 'none', 'XLim', xl, 'YLim', yl)
    set(palm_ax, 'DataAspectRatio', [1 1 1], 'XColor', 'k', 'YColor', 'k', 'YDir', 'reverse', 'XLim', xl, 'YLim', yl)
end