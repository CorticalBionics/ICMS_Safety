% Pulse count analysis
load(fullfile(DataPath, 'VMData_All.mat'))
u_part = unique(data.Subject);
u_part_alt = {'C1', 'C2', 'P2', 'P3', 'P4'};

%% Summary statistics
[pc, ps] = deal(zeros(size(u_part))); % pulse count, per session
pp = zeros(length(u_part), 3); % pulse percentiles (25, 50, 75)
for pi = 1:length(u_part)
    % Filter participant
    s_idx = strcmp(data.Subject, u_part(pi));
    % Combine across sessions
    total_pulses = cat(2, data.PulseCount{s_idx});
    total_pulses(total_pulses == 0) = NaN;
    sum_pulses = sum(total_pulses, 2, 'omitnan');
    pc(pi) = sum(total_pulses, 'all', 'omitnan');
    ps(pi) = pc(pi) / sum(s_idx);
    % Per electrode stats
    pp(pi, :) = round(prctile(sum_pulses, [25, 50, 75]));
    
    % Display
    fprintf('\n%s:\n', u_part(pi))
    fprintf('Total pulses delivered: %d\n', pc(pi))
    fprintf('Mean pulses per session: %d\n', round(sum(total_pulses, 'all', 'omitnan') / sum(s_idx)))
    fprintf('Pulses per electrode (mean, 25, 75): %d (%d, %d)\n', pp(pi, [2,1,3]))
end

%% Plot (Horizontal)
cmap = ColorGradient([1 1 1], rgb(21, 101, 192));
max_pulses = 1e4;
SetFont('Arial', 9)

clf; 
set(gcf, 'Units', 'Inches', 'Position', [31, 1, 6.45, 7])


% Heatmaps
[xw, xs] = GetAxisCoords(5, 0.04, 0.075);
ys = 0.75;  yh = 0.2;
for pi = 1:length(u_part)
    % Get pulses for heatmap
    s_idx = strcmp(data.Subject, u_part(pi));
    total_pulses = cat(2, data.PulseCount{s_idx});
    total_pulses(total_pulses == 0) = NaN;

    % Round num sessions
    ns = ceil(sum(s_idx) / 10) * 10;

    % Heatmap
    axes('Position', [xs(pi) ys xw yh]); hold on
    imagesc(total_pulses)
    set(gca, 'YTick', [1,32, 64], ...
             'YLim', [0 64.5], ...
             'XLim', [0 ns], ...
             'XTick', [0 ns], ...
             'CLim', [0 max_pulses], ...
             'Colormap', cmap)
    title(u_part_alt{pi}, 'Color', SubjectColors(u_part{pi}))
    if pi == 1
        ylabel('Electrode')
    elseif pi == 3
        xlabel('Session Number')
    end

    % Remove ylabels
    if pi > 1
        set(gca, 'YTickLabel', {})
    end
end


% Colorbar
c = ColorbarLegend(gcf, [.975 ys 0.0125 yh], cmap, 'Vert', [0 1e4]);
set(c, 'YTickLabel', {'0' '1e^4'}) 
ylabel('# Pulses', 'VerticalAlignment', 'top')


% Electrode maps
ys = 0.275;
yh = 0.4; 
for pi = 1:length(u_part)
    axes('Position', [xs(pi) ys xw yh], 'DataAspectRatio', [1 1 1]); hold on
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
            x = [gx, gx, gx+1, gx+1];
            y = [gy, gy+1, gy+1, gy]+ y_offset;
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
        y_offset = 11;
    end
    set(gca, 'XLim', [1 7], 'YLim', [1 22], 'XColor', 'none', 'YColor', 'none')
end


% Colorbar
c = ColorbarLegend(gcf, [.975 ys 0.0125 yh/2], cmap, 'Vert', [0 1e4]);
set(c, 'YTickLabel', [0  1]) 
ylabel('p(Total Pulses)', 'VerticalAlignment', 'middle')


% Summary statistics
[xw, xs] = GetAxisCoords(3, 0.1, 0.075);
ys = 0.05; yh = 0.15;
% Pulse counts
axes('Position', [xs(1) ys xw yh]); hold on
    for pi = 1:length(u_part)
        Swarm(pi, pc(pi), SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0)
    end
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', ColorText(u_part_alt, SubjectColors(u_part)))
    ylabel('Total # Pulses')


% Pulses per session
axes('Position', [xs(2) ys xw yh]); hold on
    for pi = 1:length(u_part)
        Swarm(pi, ps(pi), SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0)
    end
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', ColorText(u_part_alt, SubjectColors(u_part)))
    ylabel('Pulses/Session')


% Pulses per electrode
axes('Position', [xs(3) ys xw yh]); hold on
    for pi = 1:length(u_part)
        % Get pulses for per subject
        s_idx = strcmp(data.Subject, u_part(pi));
        total_pulses = cat(2, data.PulseCount{s_idx});
        total_pulses(total_pulses == 0) = NaN;
        sum_pulses = sum(total_pulses, 2, 'omitnan');
        % Plot
        Swarm(pi, sum_pulses, SubjectColors(u_part{pi}), 'DS', 'Box', 'SPL', 0)
    end
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', ColorText(u_part_alt, SubjectColors(u_part)))
    ylabel('Pulses/Electrode')

shg

%% Plot (Vertical)
cmap = ColorGradient([1 1 1], rgb(21, 101, 192));
SetFont('Arial', 9)

clf; 
set(gcf, 'Units', 'Inches', 'Position', [31, 1, 4.5, 9])

% Heatmaps
[ax_size, ax_val] = GetAxisCoords(5, 0.05, 0.04);
ax_val = flipud(ax_val);
xs = 0.1; xw = 0.45; yh = ax_size;
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

    % Increment y-start
    xss = xss + (xw * 1.25);
end

shg

xs = 0.7; xw = 0.25;
[ax_size, ax_val] = GetAxisCoords(4, 0.075, 0.04);
ax_val = flipud(ax_val);
% Pulse counts
axes('Position', [xs, ax_val(1) xw ax_size]); hold on
    for pi = 1:length(u_part)
        Swarm(pi, pc(pi), SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0)
    end
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', ColorText(u_part_alt, SubjectColors(u_part)))
    ylabel('Total # Pulses')


% Pulses per session
axes('Position', [xs, ax_val(2) xw ax_size]); hold on
    for pi = 1:length(u_part)
        Swarm(pi, ps(pi), SubjectColors(u_part{pi}), 'DS', 'Bar', 'SPL', 0)
    end
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', ColorText(u_part_alt, SubjectColors(u_part)))
    ylabel('Pulses/Session')


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
    set(gca, 'XLim', [.5 5.5], 'XTick', [1:5], 'XTickLabel', ColorText(u_part_alt, SubjectColors(u_part)))
    ylabel('Pulses/Electrode')

shg