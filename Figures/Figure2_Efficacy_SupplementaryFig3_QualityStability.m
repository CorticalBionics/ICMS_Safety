% Code to plot Figure 2 and Supp Fig 3
load(fullfile(DataPath, 'DetectionData.mat'))
load(fullfile(DataPath, 'DT_Analysis.mat'))
load(fullfile(DataPath, 'SQ_Analysis.mat'))
load(fullfile(DataPath, 'QualityAnalysis.mat'))
load(fullfile(DataPath, '..', 'BCI_HistoricalSurvey', 'ProcessedData', 'SurveyDataAll'))

[subject_list, ~] = GetSubjectList();
% subject_list = cellfun(@(c) c(1:5), subject_list, 'UniformOutput', false);
[subject_list_alt, num_subjects] = GetSubjectList(true);
num_channels = 64;

% Thick palm
[~, palmar_template, ~, ~] = GetHandMasks();
palm_thick = mean(palmar_template,3);
palm_thick = bwmorph(~palm_thick, 'thicken', 3);
palm_thick = uint8(repmat(~palm_thick,[1,1,3])) .* 255;
% All pixels included in the palmar mask used, just don't want to add the dependencies to calculate this
total_palm_pixels = 410624;


%% Figure 2
SetFont('Arial', 9)
clf;
clearvars ax

sensory_color = rgb(52, 152, 219); % Peterriver
motor_color = rgb(46, 63, 79); % Wetasphalt

set(gcf, 'Units', 'Inches', 'Position', [1 1 6.4 6.5])
[ax_w, ax_xs] = GetAxisCoords(3, .1, .05); ax_xs = ax_xs + .025;
[ax_h, ax_ys] = GetAxisCoords(3, .125, .05); ax_ys(1) = ax_ys(1) + 0.025;

[corr_coeffs, corr_coeffs_p] = deal(NaN(num_subjects, 2));

% Detection thresholds
ax(1) = axes('Position', [ax_xs(1), ax_ys(3), ax_w, ax_h]); hold on
% axes('Position', [.1 .2 .35 .7]); hold on    
    for s = 1:num_subjects
        AlphaLine(DetectionAnalysis.x ./ 365, DetectionAnalysis.discretized_thresholds{s}, ...
             SubjectColors(subject_list_alt{s}), 'line_width', 2, 'ignore_nan', 1)
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
    
    ct = ColorText(subject_list_alt, SubjectColors(subject_list_alt));
    text(10, 100, join(ct, '  '), ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top')
    
    ylabel(sprintf('Detection Threshold (%sA)', GetUnicodeChar('mu')))
    xlabel('Years from Implant')


% Threshold time relationship
ax(2) = axes('Position', [ax_xs(2), ax_ys(3), ax_w, ax_h]); hold on
    plot([.5 5.5], [0 0], 'Color', [.6 .6 .6], 'LineStyle', '--')
    for s = 1:num_subjects-1
        y = [DetectionData{s}.ThresholdDateLinReg];
        y = y(1:2:end);
        Swarm(s, y .* 365, 'color', SubjectColors(subject_list_alt{s}), 'distribution_width', .35, 'distribution_style', 'Box', ...
            'swarm_point_limit', 0, 'distribution_line_width', 1.5)
    end
    set(gca, 'Ylim', [-30 45], ...
             'XTick', [1:5], ...
             'XTickLabel', ColorText(subject_list_alt, SubjectColors(subject_list_alt)), ...
             'XLim', [.5 4.5], ...
             'YTick', [-30:30:60])
    ylabel(sprintf('%sDT (%sA/year)', GetUnicodeChar('Delta'), GetUnicodeChar('mu')))


% Functional electrodes
[pct_remaining, pct_of_max] = deal(NaN(num_subjects, 1));
ax(3) = axes('Position', [ax_xs(3), ax_ys(3), ax_w, ax_h]); hold on
    for s = 1:num_subjects
        x = DetectionAnalysis.x(1:DetectionAnalysis.term_idx(s)) ./ 365;
        y = mean(DetectionAnalysis.disabled_electrodes{s}(:,1:DetectionAnalysis.term_idx(s)), 1, 'omitmissing');
        plot(x, y, 'Color', SubjectColors(subject_list_alt{s}), 'LineWidth', 2)
        scatter(x,y, 20, 'MarkerEdgeColor', SubjectColors(subject_list_alt{s}), 'MarkerFaceColor', 'w', ...
            'LineWidth', 2, 'MarkerFaceAlpha', 1)
        % Print the remaining percent for each
        pct_remaining(s) = y(end) * 100;
        pct_of_max(s) = y(end)/max(y)*100;
    end
    ylabel('p(Functional Electrodes)')
    xlabel('Years from Implant')
    set(gca, 'YLim', [0 1])
    
    fprintf("Percent remaining = %0.1f +/- %0.1f\n", mean(pct_remaining), std(pct_remaining))
    fprintf("Percent of max = %0.2f +/- %0.1f\n", mean(pct_of_max), std(pct_of_max))

% Coverage hand maps
% P2 Timepoint 1
    p = [0.025, ax_ys(2)+ax_h/2 0.15, ax_h / 2];
    s = 3; t = 1;
    mini_hand_map(palm_thick, SurveyData, DetectionAnalysis.disabled_electrodes, subject_list, p, s, t)
    title('Year 1')

% P2 Timepoint 2
    p = [0.165, ax_ys(2)+ax_h/2, 0.15, ax_h / 2];
    s = 3; t = floor(length(DetectionAnalysis.x) / 2);
    mini_hand_map(palm_thick, SurveyData, DetectionAnalysis.disabled_electrodes, subject_list, p, s, t)
    title('Year 5')

% P2 Timepoint 3
    p = [0.305, ax_ys(2)+ax_h/2, 0.15, ax_h / 2];
    s = 3; t = length(DetectionAnalysis.x);
    mini_hand_map(palm_thick, SurveyData, DetectionAnalysis.disabled_electrodes, subject_list, p, s, t)
    title('Year 10')

% C1 Timepoint 1
    p = [0.025, ax_ys(2)-ax_h/10, 0.15, ax_h / 2];
    s = 1; t = 1;
    mini_hand_map(palm_thick, SurveyData, DetectionAnalysis.disabled_electrodes, subject_list, p, s, t)

% C1 Timepoint 2
    p = [0.165, ax_ys(2)-ax_h/10, 0.15, ax_h / 2];
    s = 1; t = floor(length(DetectionAnalysis.x) / 2) - 1;
    mini_hand_map(palm_thick, SurveyData, DetectionAnalysis.disabled_electrodes, subject_list, p, s, t)


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
axes('Position', [0.5, ax_ys(2), 0.41, ax_h]); hold on
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

leg_text = {'Touch', 'Pressure', 'Tapping', 'Poke', 'Sharp', ...
            'Vibration', 'Buzzing', 'Sparkle', 'Flutter', ...
            'Tingle', 'Itch', 'Tickle', 'Electrical', ...
            'Other'};
tex_cols = [cols([15:-1:11],:); ...
            cols([10:-1:7],:); ...
            cols([3:1:6],:); .6 .6 .6];
idx = [1,2,5,6,7,10,14];
text(1.2,1, ColorText(leg_text(idx), tex_cols(idx,:)), 'sc', 'HorizontalAlignment', 'Right', 'VerticalAlignment', 'top')
text(5, 1.1, ColorText('P2', SubjectColors('P2')))
text(14, 1.1, ColorText('C1', SubjectColors('C1')))

%%% Summary slopes
% Summary slopes
xl = [1-.75 num_subjects+.75];
ax1 = axes('Position', [ax_xs(1), ax_ys(1), ax_w, ax_h]); hold on
    plot(xl, [0, 0], 'Color', [.6 .6 .6], 'LineStyle', '--')
ax2 = axes('Position', [ax_xs(2), ax_ys(1), ax_w, ax_h]); hold on
    plot(xl, [0, 0], 'Color', [.6 .6 .6], 'LineStyle', '--')

    offset = 0.05;
    for pi = 1:num_subjects
        % Get indices to split arrays
        sensory_mask = SQAnalysis.sensory_masks{pi};
        motor_mask = SQAnalysis.motor_masks{pi};

        % Plot SNR
        Swarm(pi-offset, SQAnalysis.SNR_slope(sensory_mask, pi), 'color', sensory_color, 'parent', ax1, ...
            'violin_sides', 'Left', 'distribution_style', 'Violin', 'swarm_point_limit', 0, 'distribution_width', .35)
        if SQAnalysis.SNR_slope_p(pi, 1) < 0.05
            text(pi-0.15, 1, '*', 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center', ...
                'Parent', ax1, 'FontSize', 15, 'Color', sensory_color)
        end
        Swarm(pi+offset, SQAnalysis.SNR_slope(motor_mask, pi), 'color', motor_color, 'Parent', ax1, ...
            'violin_sides', 'Right', 'distribution_style', 'Violin', 'swarm_point_limit', 0, 'distribution_width', .35)
        if SQAnalysis.SNR_slope_p(pi, 2) < 0.05
            text(pi+0.15, 1, '*', 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center', ...
                'Parent', ax1, 'FontSize', 15, 'Color', motor_color)
        end
        % Ranksum test
        [P,H] = ranksum(SQAnalysis.SNR_slope(sensory_mask, pi), SQAnalysis.SNR_slope(motor_mask, pi));
        P = P * 5 % Bonferroni correction
        if P < 0.05
            text(pi, -1.1, '#', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', ...
                'Parent', ax1, 'FontSize', 9)
            fprintf('Participant %s SNR slope %s\n', subject_list_alt{pi}, pStr(P, 3))
        end

        % Plot Vpp
        Swarm(pi-offset, SQAnalysis.Vpp_slope(sensory_mask, pi), 'color', sensory_color, 'Parent', ax2, ...
            'violin_sides', 'Left', 'distribution_style', 'Violin', 'swarm_point_limit', 0, 'distribution_width', .35)
        if SQAnalysis.Vpp_slope_p(pi, 1) < 0.05
            text(pi-0.15, 100, '*', 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center', ...
                'Parent', ax2, 'FontSize', 15, 'Color', sensory_color)
        end
        Swarm(pi+offset, SQAnalysis.Vpp_slope(motor_mask, pi), 'color', motor_color, 'Parent', ax2, ...
            'violin_sides', 'Right', 'distribution_style', 'Violin', 'swarm_point_limit', 0, 'distribution_width', .35)
        if SQAnalysis.Vpp_slope_p(pi, 2) < 0.05
            text(pi+0.15, 100, '*', 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center', ...
                'Parent', ax2, 'FontSize', 15, 'Color', motor_color)
        end
        % Ranksum test
        [P,H] = ranksum(SQAnalysis.Vpp_slope(sensory_mask, pi), SQAnalysis.Vpp_slope(motor_mask, pi));
        P = P * 5; % Bonferroni correction
        if P < 0.05
            text(pi, -160, '#', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', ...
                'Parent', ax2, 'FontSize', 9)
            fprintf('Participant %s VPP slope %s\n', subject_list_alt{pi}, pStr(P,3))
        end
    end
    set(ax1, 'YLim', [-1.1 1], ...
             'XLim', xl, ...
             'XTick', [1:num_subjects], ...
             'XTickLabels', ColorText(subject_list_alt, SubjectColors(subject_list_alt)))
    ylabel(ax1, sprintf('%sSNR/year', GetUnicodeChar('Delta')), 'FontWeight', 'bold')
    text(3, -1, ColorText({'Sensory', 'Motor'}, [sensory_color; motor_color]), ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'Parent', ax1)

    set(ax2, 'YLim', [-160 100], ...
             'XLim', xl, ...
             'XTick', [1:num_subjects], ...
             'XTickLabels', ColorText(subject_list_alt, SubjectColors(subject_list_alt)))
    ylabel(ax2, sprintf('%sVpp (%sV/year)', GetUnicodeChar('Delta'), GetUnicodeChar('mu')), 'FontWeight', 'bold')

axes('Position', [ax_xs(3), ax_ys(1), ax_w, ax_h]); hold on
    plot(xl, [0, 0], 'Color', [.6 .6 .6], 'LineStyle', '--')
    for pi = 1:num_subjects
        Swarm(pi, SQAnalysis.Cln_slope(:, pi), 'color', sensory_color, ...
            'violin_sides', 'Both', 'distribution_style', 'Violin', 'swarm_point_limit', 0, 'distribution_width', .35)
        if SQAnalysis.Cln_slope_p(pi) < 0.05
            text(pi, .25, '*', 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center', ...
                'FontSize', 15, 'Color', sensory_color)
        end
    end

    set(gca, 'YLim', [-.25 .25], ...
             'XLim', xl, ...
             'XTick', [1:num_subjects], ...
             'XTickLabels', ColorText(subject_list_alt, SubjectColors(subject_list_alt)))
    ylabel(sprintf('%sV_{inter} (V/year)', GetUnicodeChar('Delta')), 'FontWeight', 'bold')
    shg


% Labels 
AddFigureLabels(ax, [0.05 0.0125])
char_offset = 67;
annotation("textbox", [0.025 .6125 .05 .05], 'String', char(char_offset+1), ...
'VerticalAlignment','top', 'HorizontalAlignment','left', 'EdgeColor', 'none', 'FontWeight','bold')

annotation("textbox", [0.45 .6125 .05 .05], 'String', char(char_offset+2), ...
'VerticalAlignment','top', 'HorizontalAlignment','left', 'EdgeColor', 'none', 'FontWeight','bold')

annotation("textbox", [0.025 .2825 .05 .05], 'String', char(char_offset+3), ...
'VerticalAlignment','top', 'HorizontalAlignment','left', 'EdgeColor', 'none', 'FontWeight','bold')

annotation("textbox", [0.36 .2825 .05 .05], 'String', char(char_offset+4), ...
'VerticalAlignment','top', 'HorizontalAlignment','left', 'EdgeColor', 'none', 'FontWeight','bold')

annotation("textbox", [0.7 .2825 .05 .05], 'String', char(char_offset+5), ...
'VerticalAlignment','top', 'HorizontalAlignment','left', 'EdgeColor', 'none', 'FontWeight','bold')

% export_figure3x(FigurePath, 'Fig2_Efficacy')

shg
return


%% Supplementary Figure 3
[ax_w, ax_xs] = GetAxisCoords(3, .1, .075);
[ax_h, ax_ys] = GetAxisCoords(2, .125, .1); ax_ys(2) = ax_ys(2) + .025;

xt10 = [0:10];
xtl10 = sparse_xticklabels(xt10);

xt8 = [0:8];
xtl8 = sparse_xticklabels(xt8);

clf; 
set(gcf, 'Units', 'Inches', 'Position', [1 1 6.4 4])
% Number of surveys
axes('Position', [ax_xs(1), ax_ys(2), ax_w, ax_h]); hold on
    for s = 1:num_subjects
        Swarm(s, unique_surveys(s,:), 'distribution_style', 'Bar', 'Color', SubjectColors(subject_list_alt{s}))
    end

    set(gca, 'XLim', [.5 5.5], ...
             'XTick', [1:5], ...
             'XTickLabel', ColorText(subject_list_alt, SubjectColors(subject_list_alt)), ...
             'YLim', [0 70])
    ylabel('# Surveys')

% Relative coverage
axes('Position', [ax_xs(2), ax_ys(2), ax_w, ax_h]); hold on
    for s = 1:num_subjects
        prop_hand = zeros(DetectionAnalysis.term_idx(s), 1);
        for t = 1:DetectionAnalysis.term_idx(s)
            enabled_idx = DetectionAnalysis.disabled_electrodes{s}(:,t) == 1;
            idx_all = cat(1, SurveyData{s}(1, enabled_idx).PFM_TIdx);
            nidx = unique(idx_all);
            prop_hand(t) = length(nidx) / total_palm_pixels;
        end
        prop_hand = prop_hand ./ max(prop_hand);
        plot(DetectionAnalysis.x(1:DetectionAnalysis.term_idx(s)) ./ 365, prop_hand, ...
            'Color', SubjectColors(subject_list_alt{s}), 'LineWidth', 2);
    end
    
    ylabel('Relative Coverage')
    xlabel('Years from Implant')
    set(gca, 'XTick', xt10, ...
             'XTickLabel', xtl10, ...
             'XTickLabelRotation', 0, ...
             'YLim', [0.5 1])

% Quality stability
axes('Position', [ax_xs(3), ax_ys(2), ax_w, ax_h]); hold on
for p = [1,3,4] % Other participants don't have enough sessions to plot
    xl = 1:size(QualityData(p).StabilityCorrelation.corr,2);
    AlphaLine(xl - .5, QualityData(p).StabilityCorrelation.corr, SubjectColors(subject_list_alt{p}), ...
        'ErrorType', 'Percentiles', 'LineWidth', 2)
    AlphaLine(xl - .5, mean(QualityData(p).StabilityCorrelation.null, 3, 'omitnan'), SubjectColors(subject_list_alt{p}), ...
        'ErrorType', 'Percentiles', 'LineStyle', '--')
end

text(8.25, 0, {'- -'; 'Shuffle'}, 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left')

ylabel("Correlation (r)")
xlabel('Time between Surveys (years)')
set(gca, 'XLim', [0, max(xt8)], ...
         'XTick', xt8, ...
         'XTickLabel', xtl8, ...
         'XTickLabelRotation', 0)


% Naturalness
axes('Position', [ax_xs(1), ax_ys(1), ax_w, ax_h]); hold on
    for s = 1:num_subjects
        x = [1:size(QualityData(s).Naturalness, 1)] - .5;
        y = QualityData(s).Naturalness;
        AlphaLine(x, y, ...
            SubjectColors(subject_list_alt{s}), 'LineWidth', 2)
    end

    set(gca, 'XLim', [0 10], ...
             'XTick', [0:10], ...
             'YLim', [0 10])
    ylabel('Naturalness')
    xlabel('Years from Implant', 'VerticalAlignment', 'middle')
    set(gca, 'XTick', xt10, ...
             'XTickLabel', xtl10, ...
             'XTickLabelRotation', 0)

% Pain frequency
axes('Position', [ax_xs(2), ax_ys(1), ax_w, ax_h]); hold on
    for s = 1:num_subjects
        % Number of pain reports
        pain_resp = sum(QualityData(s).Responses.Pain > 0);
        % Divided by number times any report was given
        any_resp = sum(sum(QualityData(s).Responses{:,3:end} > 0, 2) > 0);
        Swarm(s, pain_resp / any_resp * 100 ,...
            'distribution_style', 'Bar', 'swarm_point_limit', 0, 'Color', SubjectColors(subject_list_alt{s}))
    end

    set(gca, 'XLim', [.5 5.5], ...
             'XTick', [1:5], ...
             'XTickLabel', ColorText(subject_list_alt, SubjectColors(subject_list_alt)), ...
             'YLim', [0 100])
    ylabel('Pain Reported (%)')

% Pain rating
axes('Position', [ax_xs(3), ax_ys(1), ax_w, ax_h]); hold on
    % Stim related
    % P3
    idx = QualityData(4).Responses.Pain > 0;
    Swarm(4, QualityData(4).Responses.Pain(idx),...
        'distribution_style', 'Bar', 'Color', SubjectColors('P3'), 'swarm_point_limit', 0)
    Swarm(1, PainData.P3.uPain,...
        'distribution_style', 'Bar', 'Color', SubjectColors('P3'), 'swarm_point_limit', 0, 'HS', '\', 'HA', 84)
    [p,h] = ranksum(QualityData(4).Responses.Pain(idx), PainData.P3.uPain)
    % P4
    idx = QualityData(5).Responses.Pain > 0;
    Swarm(5, QualityData(5).Responses.Pain (idx),...
        'distribution_style', 'Bar', 'Color', SubjectColors('P4'), 'swarm_point_limit', 0)
    Swarm(2, PainData.P4.uPain,...
        'distribution_style', 'Bar', 'Color', SubjectColors('P4'), 'swarm_point_limit', 0, 'HS', '\', 'HA', 84)
    [p,h] = ranksum(QualityData(5).Responses.Pain(idx), PainData.P4.uPain);

    set(gca, 'XLim', [.5 5.5], ...
             'XTick', [1.5, 4.5], ...
             'XTickLabel', {'Baseline', 'Stim'})
    ylabel('Pain Rating')

AddFigureLabels(gcf, [0.05 -0.015])
% export_figure3x(FigurePath, 'SuppFig3_QualityStability')
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
            overlay(SurveyData{s}(e).PFM_TIdx) = 1; %overlay(SurveyData{s}(e).PFM_TIdx) + 0.1;
        end
    end
    imagesc(overlay, 'AlphaData',  overlay .* 0.8)
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