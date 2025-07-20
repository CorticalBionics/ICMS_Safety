% Pulse count analysis
load(fullfile(DataPath, 'VMData_All.mat'))
[subject_list, ~] = GetSubjectList();
subject_list = cellfun(@(c) c(1:5), subject_list, 'UniformOutput', false);
[subject_list_alt, num_subjects] = GetSubjectList(true);
conversion_factor = 1e6;

%% Summary statistics
[total_pulse_count, total_charge, total_duration] = deal(zeros(size(subject_list)));
[pulse_count_per_session, charge_per_session] = deal(cell(size(subject_list)));
[total_pulse_per_electrode, total_charge_per_electrode] = deal(zeros(num_subjects, 64));
[pulse_percentiles, charge_percentiles] = deal(zeros(num_subjects, 3));

vn = {'Stim sessions', 'Total Duration', 'Duration per session', 'Total pulses', 'Pulses per session', ...
      'Pulses per electrode', 'Total charge', 'Charge per session', 'Charge per electrode', 'Charge per phase', ...
      '# Trials', '# Single-electrode trials', '# Multi-electrode trials'};
vt = repmat("string", num_subjects, 1);
summary_table = table('Size', [length(vn), num_subjects], 'RowNames', vn, ...
    'VariableNames', subject_list_alt(1:num_subjects), 'VariableTypes', vt);

for pi = 1:num_subjects
    % Filter participant
    s_idx = strcmp(VMData.Subject, subject_list(pi));
    % Combine across session
    total_pulses = cat(2, VMData.PulseCount{s_idx});
    total_pulses(total_pulses == 0) = NaN;
    total_current = cat(2, VMData.CurrentCount{s_idx});
    total_current(total_current == 0) = NaN;
    all_charge = total_current .*  0.2 ./ conversion_factor; % Convert to charge
    all_duration = [VMData.Duration(s_idx)];

    % Pulse number analysis
    total_pulse_count(pi) = sum(total_pulses, 'all', 'omitnan');
    total_pulse_per_electrode(pi,:) = sum(total_pulses, 2, 'omitnan');
    pulse_count_per_session{pi} = sum(total_pulses, 1, 'omitnan');
    pulse_percentiles(pi, :) = prctile(total_pulse_per_electrode(pi,:), [25, 50, 75]);

    % Charge analysis
    total_charge(pi) = sum(all_charge, 'all', 'omitnan');
    total_charge_per_electrode(pi,:) = sum(all_charge, 2, 'omitnan');
    charge_per_session{pi} = sum(all_charge, 1, 'omitnan');
    charge_percentiles(pi, :) = prctile(total_charge_per_electrode(pi,:), [25, 50, 75]);
    
    % Summary stats
    summary_table{1, pi} = {sprintf('%d', sum(pulse_count_per_session{pi} > 0))};
    summary_table{2, pi} = {sprintf('%0.1f', sum(all_duration) / 60 / 60)}; % Convert seconds -> hours
    summary_table{3, pi} = {sprintf('%0.1f (%0.1f - %0.1f)', prctile(all_duration, [50, 25, 75]) ./ 60)};
    summary_table{4, pi} = {sprintf('%0.1f', total_pulse_count(pi) / 1e6)};
    summary_table{5, pi} = {sprintf('%0.1f (%0.1f - %0.1f)', prctile(pulse_count_per_session{pi}, [50, 25, 75]) ./ 1e3)};
    summary_table{6, pi} = {sprintf('%0.1f (%0.1f - %0.1f)', pulse_percentiles(pi, [2,1,3]) ./ 1e3)};
    summary_table{7, pi} = {sprintf('%0.1f', total_charge(pi))};
    summary_table{8, pi} = {sprintf('%0.1f (%0.1f - %0.1f)', prctile(charge_per_session{pi}, [50, 25, 75]))};
    summary_table{9, pi} = {sprintf('%0.2f (%0.1f - %0.1f)', charge_percentiles(pi, [2,1,3]))};
    cpp = (total_charge_per_electrode(pi,:) ./ total_pulse_per_electrode(pi,:));
    summary_table{10, pi} = {sprintf('%0.2f (%0.1f - %0.1f)', prctile(cpp, [50, 25, 75]) .* conversion_factor)};
    nst = sum([VMData.NumSingleElec(s_idx)]) / 1e3;
    nmt = sum([VMData.NumMultiElec(s_idx)]) / 1e3;
    tt = nst + nmt;
    summary_table{11, pi} = {sprintf('%0.1f', tt)};
    summary_table{12, pi} = {sprintf('%0.1f (%0.0f%%)', nst, nst / tt * 100)};
    summary_table{13, pi} = {sprintf('%0.1f (%0.0f%%)', nmt, nmt / tt * 100)};
end

fprintf('\nTotal pulses across participants: %d\n', sum(total_pulse_count))

%% Supplementary Figure 1
max_pulses = 1e4;
cmap = ColorGradient([1 1 1], rgb(21, 101, 192));
SetFont('Arial', 9)

clf; 
set(gcf, 'Units', 'Inches', 'Position', [1, 1, 6.5, 8.5])

% Heatmaps
[ax_size, ax_val] = GetAxisCoords(num_subjects, 0.04, 0.04);
ax_val = flipud(ax_val); ax_val = ax_val + 0.01;
xs = 0.1; xw = 0.3; yh = ax_size;
for pi = 1:num_subjects
    % Get pulses for heatmap
    s_idx = strcmp(VMData.Subject, subject_list(pi));
    total_pulses = cat(2, VMData.PulseCount{s_idx});
    total_pulses(total_pulses == 0) = NaN;

    % Round num sessions
    ns = ceil(sum(s_idx) / 10) * 10;

    % Heatmap
    axes('Position', [xs ax_val(pi) xw yh]); hold on
    imagesc(total_pulses)
    set(gca, 'YTick', [1,32, 64], ...
             'YLim', [0 64.5], ...
             'XLim', [0 ns], ...
             'XTick', [0 ns], ...
             'CLim', [0 1e4], ...
             'Colormap', cmap)
    title(subject_list_alt{pi}, 'Color', SubjectColors(subject_list{pi}))
    if pi == 5
        xlabel('Session Number', 'VerticalAlignment', 'bottom')
    elseif pi == 3
        ylabel('Electrode')
    end
end


% Colorbar
c = ColorbarLegend(gcf, [.04 ax_val(1) 0.0125 yh*0.75], cmap, 'Vert', [0 1e4]);
set(c, 'YTickLabel', {'0', '1e^4'}) 
y = ylabel('# Pulses', 'VerticalAlignment', 'top');
y.Position(1) = y.Position(1) + 1;

% Electrode maps
xs = 0.38; xw = 0.3;
for pi = 1:num_subjects
    axes('Position', [xs ax_val(pi) xw yh], 'DataAspectRatio', [1 1 1]); hold on
    % Get pulses for per subject
    s_idx = strcmp(VMData.Subject, subject_list(pi));
    total_pulses = cat(2, VMData.PulseCount{s_idx});
    total_pulses(total_pulses == 0) = NaN;
    sum_pulses = sum(total_pulses, 2, 'omitnan');
    % Get channel map
    cm = LoadSubjectChannelMap(subject_list{pi});
    array_maps = cm.ChannelNumbers(find(cm.IsSensory));
    y_offset = 0;
    for a = 1:length(array_maps)
        for i = 1:numel(array_maps{a})
            [gy,gx] = ind2sub(size(array_maps{a}), i); % Get grid position
            y = [gx, gx, gx+1, gx+1]+ y_offset;
            x = [gy, gy+1, gy+1, gy];
            if isnan(array_maps{a}(i)) % Show empty channels as gray
                patch(x, y, [.8 .8 .8], 'EdgeColor', [.6 .6 .6])
            else
                cidx = round((sum_pulses(array_maps{a}(i)) / max(sum_pulses)/0.5) * 255);
                if cidx > 255
                    cidx = 255;
                elseif cidx == 0
                    cidx = 1;
                end
                patch(x, y, cmap(cidx, :), 'EdgeColor', [.6 .6 .6], 'FaceAlpha', 1)
            end
        end
        y_offset = 7;
    end
    set(gca, 'XLim', [1 11], 'YLim', [1 14], 'XColor', 'none', 'YColor', 'none')
end


% Colorbar
c = ColorbarLegend(gcf, [xs+0.07 ax_val(end)-0.02 0.155 0.01], cmap, 'Horz', [0 1]);
x = xlabel('p(Pulses)', 'VerticalAlignment', 'bottom');

% Summary statistics
xs = 0.74; xw = 0.225;
[ax_size, ax_val] = GetAxisCoords(7, 0.05, 0.04);
ax_val = flipud(ax_val); ax_val = ax_val + 0.01;
clearvars ax
% Custom y-labels
l = {'Total # Pulses', 'Pulses/Session', 'Pulses/Electrode', 'Total Charge (mC)', ...
     sprintf('Charge per\nSession (mC)'), ...
     sprintf('Charge per\nElectrode (mC)'), ...
     sprintf('Charge/Phase\n/Electrode (nC)')};

% Create axes
for i = 1:7
    ax(i) = axes('Position', [xs, ax_val(i) xw ax_size]); hold on %#ok<SAGROW>
    annotation("textarrow", [xs-.05, xs-.05], [ax_val(i)+ax_size/2, ax_val(i)+ax_size/2], 'String', l{i}, ...
        'TextRotation', 90, 'HeadStyle', 'none', 'LineStyle', 'none', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom')
    set(ax(i), 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', {})
end
% Add plot elements
for pi = 1:num_subjects
    Swarm(pi, total_pulse_count(pi), SubjectColors(subject_list{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(1))
    Swarm(pi, pulse_count_per_session{pi}, SubjectColors(subject_list{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(2))
    Swarm(pi, total_pulse_per_electrode(pi,:), SubjectColors(subject_list{pi}), 'DS', 'Box', 'SPL', 0, 'Parent', ax(3))
    Swarm(pi, total_charge(pi), SubjectColors(subject_list{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(4))
    Swarm(pi, charge_per_session{pi}, SubjectColors(subject_list{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(5))
    Swarm(pi, total_charge_per_electrode(pi,:), SubjectColors(subject_list{pi}), 'DS', 'Box', 'SPL', 0, 'Parent', ax(6))
    Swarm(pi, (total_charge_per_electrode(pi,:) ./ total_pulse_per_electrode(pi,:)) .* conversion_factor, ...
        SubjectColors(subject_list{pi}), 'DS', 'Box', 'SPL', 0, 'Parent', ax(7)) % Convert back to nanocoulombs
end
% Format
set(ax(end), 'XTickLabel', ColorText(subject_list_alt, SubjectColors(subject_list)))

all_ax = get(gcf(), 'Children');

% Axis labels
AddFigureLabels(all_ax(19), [0.075, 0.025], 64)
AddFigureLabels(all_ax(13), [-0.025, 0.025], 65)
AddFigureLabels(all_ax([7:-1:1]), [0.05, 0.025], 66)

shg

%export_figure3x(FigurePath, 'SuppFig1_PulseCounts')