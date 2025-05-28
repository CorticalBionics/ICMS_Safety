load(fullfile(DataPath, 'DetectionData.mat'))
load(fullfile(DataPath, 'QualityData.mat'))
load(fullfile(DataPath, '..', 'BCI_HistoricalSurvey', 'ProcessedData', 'SurveyDataAll'))
PainData.P3 = load(fullfile(DataPath, 'QualityData', 'P3_pain.mat'));
PainData.P4 = load(fullfile(DataPath, 'QualityData', 'P4_pain.mat'));

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
for s = 1:length(DetectionData)
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
    term_idx(s) = find(mean(enabled_channels, 1) > 0.1, 1, 'last'); % Haven't tested enough electrodes to know...

    % Vectorize
    d = cat(2, d{:});
    t = round(cat(2, t{:}));

    % Sort and find time to first sensation
    [~, sort_idx] = sort(d);
    d = d(sort_idx);
    t = t(sort_idx);
    ttfs_idx = find(~isnan(t) & ~isinf(t) & t < t_max, 1, 'first');
    fprintf('%s\n', subjects_alt{s})
    fprintf('\tTime to first sensation: %d\n', d(ttfs_idx))
    
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

    % Print medial starting threshold for each participant
    fprintf('\tMedian starting DT: %0.1f\n', median(discretized_thresholds{s}{1}, 'omitnan'))
end

%% Analyze quality data
% Count the number of unique surveys
unique_surveys = zeros(num_subjects, 1);
for i = 1:num_subjects
    nu = zeros(num_channels, 1);
    for c = 1:num_channels
        nu(c) = sum(QualityData(i).Responses.channel == c);
    end
    unique_surveys(i) = mode(nu);
end

num_perms = 1e1;
% Discretize and compute naturalness and quality frequency per year
for i = 1:num_subjects
    % Discretize to years
    % Get implant date
    if startsWith(subjects{i}, 'BCI')
        subj_config = cc.load_config.participant(subjects{i}, 'chicago');
    else
        subj_config = cc.load_config.participant(subjects{i}, 'pitt');
    end
    implant_date = datetime(subj_config.implant_date, "InputFormat", "uuuu-MM-dd");

    y = years(QualityData(i).Responses.Date - implant_date);
    y_max = ceil(max(y));
    % Filter for any responses
    any_resp = any(QualityData(i).Responses{:,3:end} > 0, 2);
    
    % Compute naturalness for each year across channels
    nat_mat = NaN(y_max+1, num_channels);
    for c = 1:num_channels
        c_idx = QualityData(i).Responses.channel == c;
        for j = 1:y_max
            y_idx = (j-1 < y) & (y < j);
            nat_mat(j,c) = mean(QualityData(i).Responses.Naturalness(y_idx & c_idx & any_resp), 'omitnan');
        end
    end
    QualityData(i).Naturalness = nat_mat; %#ok<*SAGROW>

    % Compute quality frequency in each year
    resp_mat = QualityData(i).Responses{:, [6:end]};
    qual_mat = NaN(y_max, size(resp_mat, 2), num_channels); % year by 'distinct' quality by electrode
    for c = 1:num_channels
        c_idx = QualityData(i).Responses.channel == c;
        for j = 1:y_max
            y_idx = (j-1 < y) & (y < j);
            qual_mat(j, :, c) = mean(resp_mat(y_idx & c_idx & any_resp, :) > 0, 1) > 0.3;
        end
    end
    qual_mat = mean(qual_mat, 3, 'omitnan'); % Proportion of electrodes for each quality
    QualityData(i).Frequency = qual_mat ./ sum(qual_mat, 2); % Normalize within year

    % Permutations for quality stability
    qual_corr_mat = NaN(num_channels, y_max);
    qual_corr_mat_null = NaN(num_channels, y_max, num_perms);
    for c = 1:num_channels
        c_idx = QualityData(i).Responses.channel == c;
        x = QualityData(i).Responses.Date(c_idx & any_resp);
        y = QualityData(i).Responses{c_idx & any_resp, [6:end]}';
        % Filter out never observed qualities
        filt_idx = ~any(y > 0, 2);
        y = y(~filt_idx, :);

        if isempty(y)
            continue
        end
        
        % Pairwise distance & correlation
        mask = tril(true(length(x)), -1);
        dxp = squareform(pdist(datenum(x))); %#ok<DATNM>
        r = corr(y, 'Rows', 'pairwise');

        % Shuffle and correlate
        temp_perm_r = cell(num_perms, 1);
        for p = 1:num_perms
            y_perm = y;
            for j = 1:size(y, 2)
                y_perm(:,j) = y_perm(randperm(size(y, 1)), j);
            end
            pr = corr(y_perm, 'Rows', 'pairwise');
            temp_perm_r{p} = pr(mask);
        end
        
        % Combine within channel/year
        dy = dxp(mask) ./ 365;
        r = r(mask);
        for j = 1:y_max
            idx = dy < j & dy > j - 1;
            if sum(idx) < 10 % Only take average of high N
                continue
            end
            qual_corr_mat(c,j) = mean(r(idx), 'omitnan');
            for p = 1:num_perms
                qual_corr_mat_null(c,j,p) = mean(temp_perm_r{p}(idx), 'omitnan');
            end
        end
    end

    QualityData(i).StabilityCorrelation.corr = qual_corr_mat;
    QualityData(i).StabilityCorrelation.null = qual_corr_mat_null;
end

return
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
    
    ct = ColorText(subjects_alt, SubjectColors(subjects_alt));
    text(10, 100, join(ct, '  '), ...
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


% Quality frequency bar charts
% Color for each quality
cols = [...
        % Orange/teal
        rgb(255, 193, 7); ... % Hot
        rgb(0, 150, 136); ... % Cold
        % Reds
        rgb(198, 40, 40); ... % Paresthesia-Tingle
        rgb(229, 57, 53); ... % Paresthesia-Itch
        rgb(239, 83, 80); ... % Paresthesia-Tickle
        rgb(239, 154, 154); ... % Paresthesia-Electrical
        % Purples
        rgb(206, 147, 216); ... % Movement-Flutter
        rgb(171, 71, 188); ... % Movement-Sparkle
        rgb(171, 71, 188); ... % Movement-Buzzing
        rgb(106, 27, 154); ... % Movement-Vibration
        % Blues
        rgb(33, 150, 243); ... % Mechanical-Sharp
        rgb(159, 168, 218); ... % Mechanical-Poke
        rgb(63, 81, 181); ... % Mechanical-Tapping
        rgb(21, 101, 192); ... % Mechanical-Pressure
        rgb(40, 53, 147); ... % Mechanical-Touch
        ];
x = 1;
xt = [];
xtl = {};
% P2
axes('Position', [0.49, .11, 0.41, ax_h-.025]); hold on
[x, xt, xtl] = quality_freq_bar(QualityData(3).Frequency, cols, x, xt, xtl);
[x, xt, xtl] = quality_freq_bar(QualityData(1).Frequency, cols, x + 1, xt, xtl);


set(gca, 'XLim', [.5, x+.2], ...
         'YTick', [0, 1], ...
         'YLim', [0 1], ...
         'XColor', 'none', ...
         'Clipping', 'off')
xlabel('Years from Implant', 'VerticalAlignment', 'top', 'Color', 'k')
ylabel('Quality Frequency', 'VerticalAlignment', 'middle')

% Fake x-axis
y = -0.05;
plot([1, 10.8], [y y], 'Color', 'k', 'LineWidth', 1)
plot([12, 16.8], [y y], 'Color', 'k', 'LineWidth', 1)
for i = [1:10, 12:16] + 0.4
    plot([i,i], [y, y+abs(y/3)], 'Color', 'k')
end
text(1.4, y*1.5, '1', 'VerticalAlignment', 'top', 'HorizontalAlignment', 'center')
text(10.4, y*1.5, '10', 'VerticalAlignment', 'top', 'HorizontalAlignment', 'center')
text(12.4, y*1.5, '1', 'VerticalAlignment', 'top', 'HorizontalAlignment', 'center')
text(16.4, y*1.5, '5', 'VerticalAlignment', 'top', 'HorizontalAlignment', 'center')

[x,y] = GetAxisPosition(gca, 120, 100);
leg_text = {'Touch', 'Pressure', 'Tapping', 'Poke', 'Sharp', ...
            'Vibration', 'Buzzing', 'Sparkle', 'Flutter', ...
            'Tingle', 'Itch', 'Tickle', 'Electrical', ...
            'Other'};
tex_cols = [cols([15:-1:11],:); ...
            cols([10:-1:7],:); ...
            cols([3:1:6],:); .6 .6 .6];
idx = [1,2,5,6,7,10,14];
text(x,y, ColorText(leg_text(idx), tex_cols(idx,:)), 'HorizontalAlignment', 'Right', 'VerticalAlignment', 'top')
text(5, 1.1, ColorText('P2', SubjectColors('P2')))
text(14, 1.1, ColorText('C1', SubjectColors('C1')))


% Labels 
AddFigureLabels(ax, [0.05 -0.015])
char_offset = 67;
annotation("textbox", [0.025 .45 .05 .05], 'String', char(char_offset+1), ...
'VerticalAlignment','top', 'HorizontalAlignment','left', 'EdgeColor', 'none', 'FontWeight','bold')

annotation("textbox", [0.45 .45 .05 .05], 'String', char(char_offset+2), ...
'VerticalAlignment','top', 'HorizontalAlignment','left', 'EdgeColor', 'none', 'FontWeight','bold')

% export_figure3x(FigurePath, 'Fig2_Efficacy')

shg
return


%% Supplementary Figure 3
[ax_w, ax_xs] = GetAxisCoords(3, .1, .075);
[ax_h, ax_ys] = GetAxisCoords(2, .1, .1); ax_ys(2) = ax_ys(2) + .05;

xticks = [0:10];
xticklabels = cell(size(xticks));
for x = 1:length(xticks)
    if x == 1
        xticklabels{x} = num2str(xticks(x));
    elseif x == length(xticks)
        xticklabels{x} = num2str(xticks(x));
    else
        xticklabels{x} = '';
    end
end

clf; 
set(gcf, 'Units', 'Inches', 'Position', [30 1 6.4 4])
% Relative coverage
axes('Position', [ax_xs(1), ax_ys(2), ax_w, ax_h]); hold on
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
    set(gca, 'XTick', xticks, ...
             'XTickLabel', xticklabels, ...
             'XTickLabelRotation', 0, ...
             'YLim', [0.5 1])

% Number of surveys
axes('Position', [ax_xs(2), ax_ys(2), ax_w, ax_h]); hold on
    for s = 1:num_subjects
        Swarm(s, unique_surveys(s), 'DS', 'Bar', 'SPL', 0, 'Color', SubjectColors(subjects_alt{s}))
    end

    set(gca, 'XLim', [.5 5.5], ...
             'XTick', [1:5], ...
             'XTickLabel', ColorText(subjects_alt, SubjectColors(subjects_alt)), ...
             'YLim', [0 70])
    ylabel('# Surveys')

% Naturalness
axes('Position', [ax_xs(3), ax_ys(2), ax_w, ax_h]); hold on
    for s = 1:num_subjects
        x = [1:size(QualityData(s).Naturalness, 1)] - .5;
        y = QualityData(s).Naturalness;
        AlphaLine(x, y, ...
            SubjectColors(subjects_alt{s}), 'LineWidth', 2)
    end

    set(gca, 'XLim', [0 10], ...
             'XTick', [0:10], ...
             'YLim', [0 10])
    ylabel('Naturalness')
    xlabel('Years from Implant')
    set(gca, 'XTick', xticks, ...
             'XTickLabel', xticklabels, ...
             'XTickLabelRotation', 0)

% Pain frequency
axes('Position', [ax_xs(1), ax_ys(1), ax_w, ax_h]); hold on
    for s = 1:num_subjects
        % Number of pain reports
        pain_resp = sum(QualityData(s).Responses.Pain > 0);
        % Divided by number times any report was given
        any_resp = sum(sum(QualityData(s).Responses{:,3:end} > 0, 2) > 0);
        Swarm(s, pain_resp / any_resp * 100 ,...
            'DS', 'Bar', 'SPL', 0, 'Color', SubjectColors(subjects_alt{s}))
    end

    set(gca, 'XLim', [.5 5.5], ...
             'XTick', [1:5], ...
             'XTickLabel', ColorText(subjects_alt, SubjectColors(subjects_alt)), ...
             'YLim', [0 100])
    ylabel('Pain Reported (%)')

% Pain rating
axes('Position', [ax_xs(2), ax_ys(1), ax_w, ax_h]); hold on
    % Stim related
    % P3
    idx = QualityData(4).Responses.Pain > 0;
    Swarm(1, QualityData(4).Responses.Pain (idx),...
        'DS', 'Bar', 'Color', SubjectColors('P3'), 'SPL', 0)
    Swarm(4, PainData.P3.uPain,...
        'DS', 'Bar', 'Color', SubjectColors('P3'), 'SPL', 0, 'HS', '\', 'HA', 84)
    % P4
    idx = QualityData(5).Responses.Pain > 0;
    Swarm(2, QualityData(5).Responses.Pain (idx),...
        'DS', 'Bar', 'Color', SubjectColors('P4'), 'SPL', 0)
    Swarm(5, PainData.P4.uPain,...
        'DS', 'Bar', 'Color', SubjectColors('P4'), 'SPL', 0, 'HS', '\', 'HA', 84)

    set(gca, 'XLim', [.5 5.5], ...
             'XTick', [1.5, 4.5], ...
             'XTickLabel', {'Stim', 'Baseline'})
    ylabel('Pain Rating')

% Quality stability
xticks = [0:8];
xticklabels = cell(size(xticks));
for x = 1:length(xticks)
    if x == 1
        xticklabels{x} = num2str(xticks(x));
    elseif x == length(xticks)
        xticklabels{x} = num2str(xticks(x));
    else
        xticklabels{x} = '';
    end
end

axes('Position', [ax_xs(3), ax_ys(1), ax_w, ax_h]); hold on
for p = [1,3,4] % Other participants don't have enough sessions to plot
    xl = 1:size(QualityData(p).StabilityCorrelation.corr,2);
    AlphaLine(xl - .5, QualityData(p).StabilityCorrelation.corr, SubjectColors(subjects_alt{p}), ...
        'ErrorType', 'Percentiles')
    AlphaLine(xl - .5, mean(QualityData(p).StabilityCorrelation.null, 3, 'omitnan'), SubjectColors(subjects_alt{p}), ...
        'ErrorType', 'STD', 'LineStyle', '--')
end

text(8.25, 0, {'- -'; 'Shuffle'}, 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left')

ylabel("Correlation (r)")
xlabel('Time between Surveys (years)')
set(gca, 'XLim', [0, max(xticks)], ...
         'XTick', xticks, ...
         'XTickLabel', xticklabels, ...
         'XTickLabelRotation', 0)

AddFigureLabels(gcf, [0.05 -0.015])
% export_figure3x(FigurePath, 'SuppFig3_QualityStability')

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

function [x, xt, xtl] = quality_freq_bar(cf, cols, x, xt, xtl)
    freq_t = 0.1; % Threshold below which to remove
    cf = fliplr(cf); % Flip the order so parasthesias get plotted first
    % cols = flipud(cols);
    
    for y = 1:size(cf, 1)
        cfy = cf(y,:);
        % Plot all values below threshold as gray
        idx = cfy < freq_t;
        other = sum(cfy(idx));
        patch([x, x, x+.8 x+.8], [0, other, other, 0], [.6 .6 .6], ...
                'LineStyle', 'none', 'FaceAlpha', .9);

        % Plot values above threshold
        cfy = cfy(~idx);
        cols_filt = cols(~idx,:);
        cfy = cumsum(cfy, 2) + other;
        cfy = [other, cfy];
        for q = 1:size(cfy, 2)-1
            patch([x, x, x+.8 x+.8], [cfy(q), cfy(q+1), cfy(q+1), cfy(q)], cols_filt(q, :), ...
                'LineStyle', 'none', 'FaceAlpha', .9);
        end
        xt = [xt, x]; %#ok<*AGROW>
        xtl = [xtl, num2str(y)];
        x = x + 1;
    end
end