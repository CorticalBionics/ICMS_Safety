% Pulse count analysis
load(fullfile(DataPath, 'VMData_All.mat'))
u_part = unique(data.Subject);
u_part_alt = {'C1', 'C2', 'P2', 'P3', 'P4'};

%% Summary statistics
[total_pulse_count, total_charge] =  deal(zeros(size(u_part)));
[pulse_count_per_session, charge_per_session] = deal(cell(size(u_part)));
[total_pulse_per_electrode, total_charge_per_electrode] = deal(zeros(length(u_part), 64));
[pulse_percentiles, charge_percentiles] = deal(zeros(length(u_part), 3));
for pi = 1:length(u_part)
    % Filter participant
    s_idx = strcmp(data.Subject, u_part(pi));
    % Combine across session
    total_pulses = cat(2, data.PulseCount{s_idx});
    total_pulses(total_pulses == 0) = NaN;
    total_current = cat(2, data.CurrentCount{s_idx});
    total_current(total_current == 0) = NaN;
    all_charge = total_current .*  0.2; % Convert to charge

    % Pulse number analysis
    total_pulse_count(pi) = sum(total_pulses, 'all', 'omitnan');
    total_pulse_per_electrode(pi,:) = sum(total_pulses, 2, 'omitnan');
    pulse_count_per_session{pi} = sum(total_pulses, 1, 'omitnan');
    pulse_percentiles(pi, :) = round(prctile(total_pulse_per_electrode(pi,:), [25, 50, 75]));

    % Charge analysis
    total_charge(pi) = sum(all_charge, 'all', 'omitnan');
    total_charge_per_electrode(pi,:) = sum(all_charge, 2, 'omitnan');
    charge_per_session{pi} = sum(all_charge, 1, 'omitnan');
    charge_percentiles(pi, :) = round(prctile(total_pulse_per_electrode(pi,:), [25, 50, 75]));
    mean_current = mean(all_charge, 2, 'omitnan');
    
    % Display
    fprintf('\n%s:\n', u_part(pi))
    fprintf('Total pulses delivered: %d\n', total_pulse_count(pi))
    fprintf('Mean pulses per session: %d\n', round(sum(total_pulses, 'all', 'omitnan') / sum(s_idx)))
    fprintf('Pulses per electrode (mean, 25, 75): %d (%d, %d)\n', pulse_percentiles(pi, [2,1,3]))
    fprintf('Total Charge delivered: %d\n', total_charge(pi))
    fprintf('Mean Charge per session: %d\n', round(sum(total_charge, 'all', 'omitnan') / sum(s_idx)))
    fprintf('Charge per electrode (mean, 25, 75): %d (%d, %d)\n', charge_percentiles(pi, [2,1,3]))
end


%% Plot (Vertical)
max_pulses = 1e4;
cmap = ColorGradient([1 1 1], rgb(21, 101, 192));
SetFont('Arial', 9)

clf; 
set(gcf, 'Units', 'Inches', 'Position', [28, 1, 6.5, 9])

% Heatmaps
[ax_size, ax_val] = GetAxisCoords(5, 0.05, 0.04);
ax_val = flipud(ax_val);
xs = 0.1; xw = 0.3; yh = ax_size;
for pi = 1:length(u_part)
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
xs = 0.37; xw = 0.3;
for pi = 1:length(u_part)
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
            if isnan(array_maps{a}(i)) % Show empty channels as white
                patch(x, y, [1 1 1], 'EdgeColor', [.6 .6 .6])
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
c = ColorbarLegend(gcf, [xs+0.07 ax_val(end)-0.015 0.16 0.01], cmap, 'Horz', [0 1]);
x = xlabel('p(Pulses)', 'VerticalAlignment', 'bottom');

% Summary statistics
xs = 0.725; xw = 0.225;
[ax_size, ax_val] = GetAxisCoords(7, 0.05, 0.04);
ax_val = flipud(ax_val);
clearvars ax
% Custom y-labels
l = {'Total # Pulses', 'Pulses per Session', 'Pulses per Electrode', 'Total Charge (mC)', ...
     sprintf('Charge per\nSession (%sC)', GetUnicodeChar('mu')), ...
     sprintf('Charge per\nElectrode (%sC)', GetUnicodeChar('mu')), ...
     sprintf('Charge/Pulse\nElectrode (nC)')};

% Create axes
for i = 1:7
    ax(i) = axes('Position', [xs, ax_val(i) xw ax_size]); hold on %#ok<SAGROW>
    annotation("textarrow", [xs-.05, xs-.05], [ax_val(i)+ax_size/2, ax_val(i)+ax_size/2], 'String', l{i}, ...
        'TextRotation', 90, 'HeadStyle', 'none', 'LineStyle', 'none', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom')
    set(ax(i), 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', {})
end
% Add plot elements
for pi = 1:length(u_part)
    Swarm(pi, total_pulse_count(pi), SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(1))
    Swarm(pi, pulse_count_per_session{pi}, SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(2))
    Swarm(pi, total_pulse_per_electrode(pi,:), SubjectColors(u_part{pi}), 'DS', 'Box', 'SPL', 0, 'Parent', ax(3))
    Swarm(pi, total_charge(pi) ./ 1e9, SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(4))
    Swarm(pi, charge_per_session{pi} ./ 1e6, SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0, 'Parent', ax(5))
    Swarm(pi, total_charge_per_electrode(pi,:) ./ 1e6, SubjectColors(u_part{pi}), 'DS', 'Box', 'SPL', 0, 'Parent', ax(6))
    Swarm(pi, total_charge_per_electrode(pi,:) ./ total_pulse_per_electrode(pi,:), SubjectColors(u_part{pi}),...
        'DS', 'Box', 'SPL', 0, 'Parent', ax(7))
end
% Format
% set(ax(7), 'XLim', [.5 5.5], 'XTick', [1:5], 'YLim', [0, 20], 'XTickLabel', {})
set(ax(end), 'XTickLabel', ColorText(u_part_alt, SubjectColors(u_part)))

shg

% export_figure4x(pwd, 'PulseCounts')