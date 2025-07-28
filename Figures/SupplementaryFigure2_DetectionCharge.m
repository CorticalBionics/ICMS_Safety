load(fullfile(DataPath, 'DetectionData.mat'))
load(fullfile(DataPath, 'VMData_All.mat')); 

[subject_list, num_subjects] = GetSubjectList(true);
num_channels = 64;


%% Supplementary Figure 2
SetFont('Arial', 9)

c1 = rgb(0, 158, 115);
c2 = rgb(0, 114, 178);
c3 = rgb(152, 33, 135);

nc = 512;
cmap1 = [linspace(c1(1), c2(1), nc)',...
         linspace(c1(2), c2(2), nc)',...
         linspace(c1(3), c2(3), nc)'];
cmap2 = [linspace(c2(1), c3(1), nc)',...
         linspace(c2(2), c3(2), nc)',...
         linspace(c2(3), c3(3), nc)'];
cmap_big = [cmap1; cmap2];

clf; 
set(gcf, 'Units', 'Inches', 'Position', [1, 1, 6.5, 8.5])

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
    d = d ./ 365; % Convert to years
    t = round(cat(2, t{:}));
    
    % Sort by color
    [ut, ~, it] = unique(t);
    idx = round(linspace(1, length(cmap_big), length(ut)));
    cmap = cmap_big(idx, :);
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
    xm = ceil(max(d, [], 'omitnan'));

    xl = [0, xm];
    xt = [xl(1):xl(end)];
    xl = [xl(1) - range(xl) * 0.05, xl(end) + range(xl) * 0.05];
    xtl = cell(size(xt));
    for i = 1:length(xtl)
        if i == 1
            xtl{i} = '0';
        elseif i == length(xtl)
            xtl{i} = num2str(i-1);
        else
            xtl{i} = '';
        end
    end

    set(gca, 'YTick', [1,32, 64], ...
             'YLim', [0 64.5], ...
             'XLim', xl, ...
             'XTick', xt, ...
             'XTickLabel', xtl, ...
             'XTickLabelRotation', 0)
    title(subject_list{s}, 'Color', SubjectColors(subject_list{s}))
    if s == 5
        xlabel('Years Post Implant', 'VerticalAlignment', 'top')
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
    scatter(x_trim, y_trim, 30, SubjectColors(subject_list{s}), 'filled', 'MarkerFaceAlpha', .2)
    plot(xq, feval(f, xq), 'Color', SubjectColors(subject_list{s}), 'LineStyle', '-','LineWidth', 2)
    [corr_coeffs(s,1), corr_coeffs_p(s,1)] = corr(x,y, 'Rows', 'complete', 'Type', 'Spearman');

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
    scatter(x_trim, y_trim, 30, SubjectColors(subject_list{s}), 'filled', 'MarkerFaceAlpha', .2)

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
    plot(xq, feval(f, xq), 'Color', SubjectColors(subject_list{s}), 'LineStyle', '-','LineWidth', 2)
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
