load(fullfile(DataPath, 'DetectionData.mat'))
load(fullfile(DataPath, 'VMData_All.mat')); 
VMData = data;
clearvars data

u_part = unique(VMData.Subject);
subjects = {'C1', 'C2', 'P2', 'P3', 'P4'};
num_subjects = length(subjects);
num_channels = 64;

%% VM analysis
conversion_factor = 1e6;
total_charge = zeros(length(u_part), num_channels);
for pi = 1:length(u_part)
    % Filter participant
    s_idx = strcmp(VMData.Subject, u_part(pi));
    total_current = cat(2, VMData.CurrentCount{s_idx});
    total_current(total_current == 0) = NaN;
    all_charge = total_current .*  0.2 ./ conversion_factor; % Convert to charge in mC

    % Charge across time
    total_charge(pi, :) = sum(all_charge, 2, 'omitnan');
end

%% Supplementary Figure 2
cmap = ColorGradient([1 1 1], rgb(21, 101, 192));
SetFont('Arial', 9)

clf; 
set(gcf, 'Units', 'Inches', 'Position', [27, 1, 6.5, 8.5])

% Detection rasters
[ax_size, ax_val] = GetAxisCoords(num_subjects, 0.05, 0.04);
ax_val = flipud(ax_val); ax_val = ax_val + 0.01;
xs = 0.1; xw = 0.3; yh = ax_size;
for s = 1:num_subjects
    % Heatmap
    axes('Position', [xs ax_val(s) xw yh]); hold on

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
    set(gca, 'YTick', [1,32, 64], ...
             'YLim', [0 64.5], ...
             'XLim', [0 ceil(max(d, [], 'omitnan')/100)*100])
    title(subjects{s}, 'Color', SubjectColors(subjects{s}))
    if s == 5
        xlabel('Days post Implant', 'VerticalAlignment', 'top')
    elseif s == 3
        ylabel('Electrode')
    end
end

% Colorbar
c = ColorbarLegend(gcf, [.045 ax_val(1) 0.0125 yh*0.75], cmap, 'Vert', [0 1e4]);
set(c, 'YTickLabel', {'0', '100'}) 
y = ylabel(sprintf('DT_{50} (%sA)', GetUnicodeChar('mu')), 'VerticalAlignment', 'top');
y.Position(1) = y.Position(1) + 1;


% DT X Charge
[corr_coeffs, corr_coeffs_p] = deal(NaN(num_subjects, 1));
xs = 0.475; xw = 0.18;
xq = linspace(0, 75);
for s = 1:num_subjects
    axes('Position', [xs ax_val(s) xw yh]); hold on
    x = NaN(num_channels, 1);
    y = total_charge(s, :)';
    for c = 1:num_channels % Make sure we are comparing correctly
        dt_idx = [DetectionData{s}.Channel] == c;
        if all(dt_idx == 0)
            continue
        end
        x(c) = median(DetectionData{s}(dt_idx).Threshold, 'omitnan');
    end
    if all(isnan(x))
        continue
    end
    idx = ~isnan(x) & ~isinf(x);
    x_trim = x(idx); y_trim = y(idx);
    y_trim = y_trim ./ mean(y_trim); % normalize
    % Exponential curve fit
    f = fit(x_trim, y_trim, 'exp1');

    % Plot
    scatter(x_trim, y_trim, 30, SubjectColors(u_part{s}), 'filled', 'MarkerFaceAlpha', .2)
    plot(xq, feval(f, xq), 'Color', SubjectColors(u_part{s}), 'LineStyle', '-','LineWidth', 2)
    [corr_coeffs(s,1), corr_coeffs_p(s,1)] = corr(x,y, 'Rows', 'complete', 'Type', 'Kendall');

    if s == 5
        xlabel(sprintf('Median DT_{50} (%sA)', GetUnicodeChar('mu')))
    elseif s == 3
        ylabel('Charge Delivered (mC)')
    end
    
    set(gca, 'XLim', [0 75], ...
             'YLim', [0, prctile(y_trim, 95)], ...
             'XTick', [0:25:75])
    
end

corr_coeffs_p = HolmBonferroni(corr_coeffs_p);
all_ax = flipud(get(gcf(), 'Children')); all_ax = all_ax(7:end);
for s = 1:num_subjects
    [x,y] = GetAxisPosition(all_ax(s), 100, 95);
    text(x,y, sprintf('%s', pStr(corr_coeffs_p(s))), 'Parent', all_ax(s), ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', 'Color', [.2 .2 .2])
end


% Charge X dDT
[corr_coeffs, corr_coeffs_p] = deal(NaN(num_subjects, 1));
xs = 0.765;
for s = 1:num_subjects-1
    axes('Position', [xs ax_val(s) xw yh]); hold on
    plot([0 75], [0 0], 'Color', [.6 .6 .6], 'LineStyle', '--')
    y = NaN(num_channels, 1);
    x = total_charge(s, :)';
    for c = 1:num_channels % Make sure we are comparing correctly
        dt_idx = [DetectionData{s}.Channel] == c;
        if all(dt_idx == 0)
            continue
        end
        y(c) = DetectionData{s}(dt_idx).ThresholdDateLinReg(1);
    end
    % Remove nans/infs
    idx = ~isnan(y) & ~isinf(y);
    x_trim = x(idx); y_trim = y(idx);
    scatter(x_trim, y_trim, 30, SubjectColors(u_part{s}), 'filled', 'MarkerFaceAlpha', .2)

    % Format
    if s == 4
        xlabel('Charge Delivered (mC)')
    elseif s == 3
        ylabel(sprintf('Slope (%sA/day)', GetUnicodeChar('mu')))
    end
    
    set(gca, 'XLim', [0, ceil(prctile(x_trim, 95))], ...
             'XTick', [0, ceil(prctile(x_trim, 95))], ...
             'YLim', [-.1 .2])

    if all(isnan(y)) || sum(~isnan(y)) < 5
        continue
    end
    
    xq = linspace(0, ceil(prctile(x_trim, 95)));
    % Exponential curve fit
    f = fit(x_trim, y_trim, 'exp1');
    plot(xq, feval(f, xq), 'Color', SubjectColors(u_part{s}), 'LineStyle', '-','LineWidth', 2)
    [corr_coeffs(s,1), corr_coeffs_p(s,1)] = corr(x, y, 'Rows', 'complete', 'Type', 'Spearman');
    
    
end

corr_coeffs_p = HolmBonferroni(corr_coeffs_p);
all_ax = flipud(get(gcf(), 'Children')); all_ax = all_ax(12:end);
for s = 1:num_subjects-1
    [x,y] = GetAxisPosition(all_ax(s), 95, 95);
    text(x,y, sprintf('%s', pStr(corr_coeffs_p(s))), 'Parent', all_ax(s), ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', 'Color', [.2 .2 .2])
end

all_ax = flipud(get(gcf(), 'Children'));
% Axis labels
AddFigureLabels(all_ax(1), [0.05, 0.02], 64)
AddFigureLabels(all_ax(7), [0.05, 0.02], 65)
AddFigureLabels(all_ax(12), [0.075, 0.02], 66)
% export_figure3x(FigurePath, 'SuppFig2_Detection')
shg
