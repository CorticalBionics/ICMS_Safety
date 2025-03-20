% Pulse count analysis
load(fullfile(DataPath, 'VMData_All.mat'))
u_part = unique(data.Subject);
u_part_alt = {'C1', 'C2', 'P2', 'P3', 'P4'};
num_part = length(u_part);

conversion_factor = 1e6; % Nano to millicoulomb

%% Summary statistics
[total_pulse_count, total_charge] = deal(zeros(size(u_part)));
[pulse_count_per_session, charge_per_session] = deal(cell(size(u_part)));
[total_pulse_per_electrode, total_charge_per_electrode] = deal(zeros(num_part, 64));
[pulse_percentiles, charge_percentiles] = deal(zeros(num_part, 3));

for pi = 1:num_part
    % Filter participant
    s_idx = strcmp(data.Subject, u_part(pi));
    % Combine across session
    total_pulses = cat(2, data.PulseCount{s_idx});
    total_pulses(total_pulses == 0) = NaN;
    total_current = cat(2, data.CurrentCount{s_idx});
    total_current(total_current == 0) = NaN;
    all_charge = total_current .*  0.2 ./ conversion_factor; % Convert to charge

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
    
    % Print summary stats
    fprintf('\n%s:\n', u_part(pi))
    fprintf('Total pulses delivered: %d\n', total_pulse_count(pi))
    fprintf('Pulses per session: %0.1f (%0.1f - %0.1f)\n', prctile(pulse_count_per_session{pi}, [50, 25, 75]) ./ 1000)
    fprintf('Pulses per electrode: %0.1f (%0.1f - %0.1f)\n', pulse_percentiles(pi, [2,1,3]) ./ 1000)
    fprintf('Total Charge delivered: %0.1f\n', total_charge(pi))
    fprintf('Charge per session: %0.1f (%0.1f - %0.1f)\n', prctile(charge_per_session{pi}, [50, 25, 75]))
    fprintf('Charge per electrode: %0.2f (%0.2f - %0.2f)\n', charge_percentiles(pi, [2,1,3]))
    cpp = (total_charge_per_electrode(pi,:) ./ total_pulse_per_electrode(pi,:));
    fprintf('Charge per phase: %0.2f (%0.2f - %0.2f)\n', prctile(cpp, [50, 25, 75]) .* conversion_factor)
end

fprintf('\nTotal pulses across participants: %d\n', sum(total_pulse_count))

%% Supplementary Figure 1
max_pulses = 1e4;
cmap = ColorGradient([1 1 1], rgb(21, 101, 192));
SetFont('Arial', 9)

clf; 
set(gcf, 'Units', 'Inches', 'Position', [27, 1, 6.5, 8.5])

% Heatmaps
[ax_size, ax_val] = GetAxisCoords(num_part, 0.04, 0.04);
ax_val = flipud(ax_val); ax_val = ax_val + 0.01;
xs = 0.1; xw = 0.3; yh = ax_size;
for pi = 1:num_part
    % Get pulses for heatmap
    s_idx = strcmp(data.Subject, u_part(pi));
    total_pulses = cat(2, data.PulseCount{s_idx});
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
    title(u_part_alt{pi}, 'Color', SubjectColors(u_part{pi}))
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
for pi = 1:num_part
    axes('Position', [xs ax_val(pi) xw yh], 'DataAspectRatio', [1 1 1]); hold on
    % Get pulses for per subject
    s_idx = strcmp(data.Subject, u_part(pi));
    total_pulses = cat(2, data.PulseCount{s_idx});
    total_pulses(total_pulses == 0) = NaN;
    sum_pulses = sum(total_pulses, 2, 'omitnan');
    % Get channel map
    cm = LoadSubjectChannelMap(u_part(pi));
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
                patch(x, y, cmap(cidx, :), 'EdgeColor', [.6 .6 .6])
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
for pi = 1:num_part
    Swarm(pi, total_pulse_count(pi), SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(1))
    Swarm(pi, pulse_count_per_session{pi}, SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(2))
    Swarm(pi, total_pulse_per_electrode(pi,:), SubjectColors(u_part{pi}), 'DS', 'Box', 'SPL', 0, 'Parent', ax(3))
    Swarm(pi, total_charge(pi), SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(4))
    Swarm(pi, charge_per_session{pi}, SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(5))
    Swarm(pi, total_charge_per_electrode(pi,:), SubjectColors(u_part{pi}), 'DS', 'Box', 'SPL', 0, 'Parent', ax(6))
    Swarm(pi, (total_charge_per_electrode(pi,:) ./ total_pulse_per_electrode(pi,:)) .* conversion_factor, ...
        SubjectColors(u_part{pi}), 'DS', 'Box', 'SPL', 0, 'Parent', ax(7)) % Convert back to nanocoulombs
end
% Format
set(ax(end), 'XTickLabel', ColorText(u_part_alt, SubjectColors(u_part)))

all_ax = get(gcf(), 'Children');

% Axis labels
AddFigureLabels(all_ax(19), [0.075, 0.025], 64)
AddFigureLabels(all_ax(13), [-0.025, 0.025], 65)
AddFigureLabels(all_ax([7:-1:1]), [0.05, 0.025], 66)

shg

% export_figure3x(FigurePath, 'PulseCounts')