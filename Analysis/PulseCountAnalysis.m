% Pulse count analysis
load(fullfile(DataPath, 'VMData_All.mat'))
u_part = unique(data.Subject);
u_part_alt = {'C1', 'C2', 'P2', 'P3', 'P4'};

%% Summary statistics
[pc, ps, cc, cs] = deal(zeros(size(u_part))); % pulse count/per session, current count/per session
[pp, cp] = deal(zeros(length(u_part), 3)); % pulse, current percentiles (25, 50, 75)
for pi = 1:length(u_part)
    % Filter participant
    s_idx = strcmp(data.Subject, u_part(pi));

    % Pulse number analysis
    % Combine across session
    total_pulses = cat(2, data.PulseCount{s_idx});
    total_pulses(total_pulses == 0) = NaN;
    sum_pulses = sum(total_pulses, 2, 'omitnan');
    % Total
    pc(pi) = sum(total_pulses, 'all', 'omitnan');
    % Per session
    ps(pi) = pc(pi) / sum(s_idx);
    % Per electrode stats
    pp(pi, :) = round(prctile(sum_pulses, [25, 50, 75]));

    % Pulse current analysis
    % Combine across session
    total_current = cat(2, data.CurrentCount{s_idx});
    total_current(total_current == 0) = NaN;
    sum_current = sum(total_current, 2, 'omitnan');
    % Total
    cc(pi) = sum(total_current, 'all', 'omitnan');
    % Per session
    cs(pi) = cc(pi) / sum(s_idx);
    % Per electrode stats
    cp(pi, :) = round(prctile(sum_current, [25, 50, 75]));
    
    % Display
    fprintf('\n%s:\n', u_part(pi))
    fprintf('Total pulses delivered: %d\n', pc(pi))
    fprintf('Mean pulses per session: %d\n', round(sum(total_pulses, 'all', 'omitnan') / sum(s_idx)))
    fprintf('Pulses per electrode (mean, 25, 75): %d (%d, %d)\n', pp(pi, [2,1,3]))
    fprintf('Total current delivered: %d\n', cc(pi))
    fprintf('Mean current per session: %d\n', round(sum(total_current, 'all', 'omitnan') / sum(s_idx)))
    fprintf('Current per electrode (mean, 25, 75): %d (%d, %d)\n', cp(pi, [2,1,3]))
end


%% Plot (Vertical)
max_pulses = 1e4;
cmap = ColorGradient([1 1 1], rgb(21, 101, 192));
SetFont('Arial', 9)

clf; 
set(gcf, 'Units', 'Inches', 'Position', [31, 1, 6.5, 9])

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

xs = 0.7; xw = 0.225;
[ax_size, ax_val] = GetAxisCoords(6, 0.05, 0.04);
ax_val = flipud(ax_val);
% Pulse counts
axes('Position', [xs, ax_val(1) xw ax_size]); hold on
    for pi = 1:length(u_part)
        Swarm(pi, pc(pi), SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0)
    end
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', {})


% Pulses per session
axes('Position', [xs, ax_val(2) xw ax_size]); hold on
    for pi = 1:length(u_part)
        Swarm(pi, ps(pi), SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0)
    end
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', {})


% Pulses per electrode
axes('Position', [xs, ax_val(3) xw ax_size]); hold on
    for pi = 1:length(u_part)
        % Get pulses for per subject
        s_idx = strcmp(data.Subject, u_part(pi));
        total_pulses = cat(2, data.PulseCount{s_idx});
        total_pulses(total_pulses == 0) = NaN;
        sum_pulses = sum(total_pulses, 2, 'omitnan');
        % Plot
        Swarm(pi, sum_pulses, SubjectColors(u_part{pi}), 'DS', 'Box', 'SPL', 0)
    end
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', {})


% Current counts
axes('Position', [xs, ax_val(4) xw ax_size]); hold on
    for pi = 1:length(u_part)
        Swarm(pi, cc(pi) ./ 1e9, SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0)
    end
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', {})


% Current per session
axes('Position', [xs, ax_val(5) xw ax_size]); hold on
    for pi = 1:length(u_part)
        Swarm(pi, cs(pi) ./ 1e6, SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0)
    end
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', {})


% Current per electrode
axes('Position', [xs, ax_val(6) xw ax_size]); hold on
    for pi = 1:length(u_part)
        % Get pulses for per subject
        s_idx = strcmp(data.Subject, u_part(pi));
        total_pulses = cat(2, data.CurrentCount{s_idx});
        total_pulses(total_pulses == 0) = NaN;
        sum_pulses = sum(total_pulses, 2, 'omitnan');
        % Plot
        Swarm(pi, sum_pulses ./ 1e6, SubjectColors(u_part{pi}), 'DS', 'Box', 'SPL', 0)
    end
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', ColorText(u_part_alt, SubjectColors(u_part)))

% Custom y-labels
l = {'Total # Pulses', 'Pulses/Session', 'Pulses/Electrode', 'Total Current (mC)', ...
     sprintf('Current/Session (%sC)', GetUnicodeChar('mu')), ...
     sprintf('Current/Electrode (%sC)', GetUnicodeChar('mu'))};

for i = 1:length(l)
    annotation("textarrow", [xs-.06, xs-.06], [ax_val(i)+ax_size/2, ax_val(i)+ax_size/2], 'String', l{i}, ...
        'TextRotation', 90, 'HeadStyle', 'none', 'LineStyle', 'none', 'HorizontalAlignment', 'center')
end
shg

% export_figure4x(pwd, 'PulseCounts')