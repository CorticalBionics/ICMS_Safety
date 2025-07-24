% Signal Quality Analysis
load(fullfile(DataPath, "SQ_Analysis"))
load(fullfile(DataPath, 'DT_Analysis'));
load(fullfile(DataPath, "VMData_All.mat"), 'total_charge')
[subject_list, num_subjects] = GetSubjectList(true);

%% Supplementary Figure 4
[ax_size_y, ax_y_val] = GetAxisCoords(num_subjects, 0.04, 0.05);
ax_y_val = ax_y_val + 0.03; ax_y_val = flipud(ax_y_val);
[ax_size_x, ax_x_val] = GetAxisCoords(3, 0.1, 0.075);
marker_size = 5;

sensory_color = rgb(52, 152, 219); % Peterriver
motor_color = rgb(52, 73, 94); % Wetasphalt

clf;
set(gcf, 'Units', 'Inches', 'Position', [30, 1, 6.45, 7.5]);
SetFont('Arial', 9)

% Line plots
for p = 1:num_subjects
    % Get dates for SQData
    x = SQAnalysis.sq_dates{p};
    xl = [0, ceil(x(end))];
    xt = [xl(1):xl(end)];
    xl = [xl(1) - range(xl) * 0.05, xl(end) + range(xl) * 0.05];
    xtl = sparse_xticklabels(xt);

    % SNR
    axes('Position', [ax_x_val(1), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        % Sensory
        y = SQAnalysis.median_SNR{p}.sensory;
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .25)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xl, polyval(r, xl), 'Color', sensory_color, 'LineWidth', 2);
        % Motor
        y = SQAnalysis.median_SNR{p}.motor;
        scatter(x, y, marker_size, motor_color, 'MarkerEdgeAlpha', .25)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xl, polyval(r, xl), 'Color', motor_color, 'LineWidth', 2);
        
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabel', xtl, ...
                 'YLim', [0.75, 2], ...
                 'XTickLabelRotation', 0)
        
        % Formatting
        if p == 1
            [tx, ty] = GetAxisPosition(gca, 5, 5);
            text(tx, ty, ColorText({'Motor', 'Sensory'}, [motor_color; sensory_color]), ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom')
        elseif p == round(num_subjects / 2)
            ylabel('SNR', 'FontWeight', 'bold')
        end
        title(ColorText(subject_list{p}, SubjectColors(subject_list{p})), 'VerticalAlignment', 'top')

    % Vpp
    axes('Position', [ax_x_val(2), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        % Sensory
        y = SQAnalysis.median_Vpp{p}.sensory;
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .25)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xl, polyval(r, xl), 'Color', sensory_color, 'LineWidth', 2);
        % Motor
        y = SQAnalysis.median_Vpp{p}.motor;
        scatter(x, y, marker_size, motor_color, 'MarkerEdgeAlpha', .25)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xl, polyval(r, xl), 'Color', motor_color, 'LineWidth', 2);
        
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabels', xtl, ...
                 'YLim', [0, 200], ...
                 'XTickLabelRotation', 0)
    
        if p == round(num_subjects / 2)
            ylabel(sprintf('Vpp (%sV)', GetUnicodeChar('mu')), 'FontWeight', 'bold')
        elseif p == num_subjects
            xlabel('Years Implanted', 'FontWeight', 'bold')
        end

    % Cleaning
    axes('Position', [ax_x_val(3), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        x = SQAnalysis.cln_dates{p};
        y = SQAnalysis.median_vinter{p};
        y(y < -1.5) = NaN; % Disconnected channels
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .5)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xl, polyval(r, xl), 'Color', sensory_color, 'LineWidth', 2);
        % [r,p] = corr(x,y, 'Rows', 'complete');
    
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabels', xtl, ...
                 'YLim', [-1.3, -0.75], ...
                 'XTickLabelRotation', 0)
    
        if p == round(num_subjects / 2)
            ylabel(sprintf('V_{inter} (V)'), 'FontWeight', 'bold')
        end
end

h = gcf();
AddFigureLabels(h.Children([end, end-1, end-2]), [.075, .0275])
% export_figure3x(FigurePath, 'SuppFig4_SignalQuality')

shg

%% SQ ANOVAs
sensory_mask = SQAnalysis.sensory_masks{1};
g2 = ones(256,1);
g2(sensory_mask) = 2;

g1 = repmat([1:5], 256, 1);
g2 = repmat(g2, 1, 5);
[snr_anova_tab] = anovan(SQAnalysis.SNR_slope(:), {g1(:), g2(:)}, ...
    'varnames', {'Participant', 'ArrayType'});

[p, vpp_anova_tab, stat] = anovan(SQAnalysis.Vpp_slope(:), {g1(:), g2(:)}, ...
    'varnames', {'Participant', 'ArrayType'});
multcompare(stat, 'Dimension', 2)

%% Supplementary Figure 5
[ax_size_x, ax_x_val] = GetAxisCoords(3, 0.1, 0.1);
[ax_size_y, ax_y_val] = GetAxisCoords(num_subjects, 0.05, 0.05);
ax_y_val = ax_y_val + 0.01;

clf;
set(gcf, 'Units', 'Inches', 'Position', [27, 1, 6.45, 8]);
SetFont('Arial', 9)
marker_size = 10;

clearvars ax
% Create axes
i = 1;
for p = 1:num_subjects
    for j = 1:3
        ax(i) = axes('Position', [ax_x_val(j), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        set(ax(i), 'XScale', 'linear', 'YScale', 'linear')
        i = i + 1;
    end
end

prctile_mask = [5, 95];

o = length(h.Children) + 1;
for pi = 1:num_subjects
    x = total_charge(pi, :)';
    xl = [0 ceil(max(x, [], 'omitnan'))];
  
    % Get sensory mask
    sensory_mask = SQAnalysis.sensory_masks{pi};
    
    % SNR
    snr_y = SQAnalysis.SNR_slope(sensory_mask, pi);
    mask = snr_y < prctile(snr_y, prctile_mask(1)) | snr_y > prctile(snr_y, prctile_mask(2));
    snr_y(mask) = NaN;
    nan_idx = ~isnan(snr_y);
    scatter(x, snr_y, marker_size, SubjectColors(subject_list{pi}), 'MarkerEdgeAlpha', .5, 'Parent', ax(o-3))
    r = polyfit(x(nan_idx), snr_y(nan_idx), 1);
    plot(xl, polyval(r, xl), 'Color', SubjectColors(subject_list{pi}), 'Parent', ax(o-3), 'LineWidth', 2);

    % Vpp
    vpp_y = SQAnalysis.Vpp_slope(sensory_mask, pi);
    mask = vpp_y < prctile(vpp_y, prctile_mask(1)) | vpp_y > prctile(vpp_y, prctile_mask(2));
    vpp_y(mask) = NaN;
    nan_idx = ~isnan(vpp_y);
    scatter(x, vpp_y, marker_size, SubjectColors(subject_list{pi}), 'MarkerEdgeAlpha', .5, 'Parent', ax(o-2))
    r = polyfit(x(nan_idx), vpp_y(nan_idx), 1);
    plot(xl, polyval(r, xl), 'Color', SubjectColors(subject_list{pi}), 'Parent', ax(o-2), 'LineWidth', 2);

    %Vinter
    cln_y = SQAnalysis.Cln_slope(:, pi);
    mask = cln_y < prctile(cln_y, prctile_mask(1)) | cln_y > prctile(cln_y, prctile_mask(2));
    cln_y(mask) = NaN;
    nan_idx = ~isnan(cln_y);
    scatter(x, cln_y, marker_size, SubjectColors(subject_list{pi}), 'MarkerEdgeAlpha', .5, 'Parent', ax(o-1))
    r = polyfit(x(nan_idx), cln_y(nan_idx), 1);
    plot(xl, polyval(r, xl), 'Color', SubjectColors(subject_list{pi}), 'Parent', ax(o-1), 'LineWidth', 2);

    % Formatting
    if pi == 3
        ylabel(ax(o-3), sprintf('%sSNR/year', GetUnicodeChar('Delta')), 'FontWeight', 'bold')
        ylabel(ax(o-2), sprintf('%sVpp (%sV/year)', GetUnicodeChar('Delta'), GetUnicodeChar('mu')), 'FontWeight', 'bold')
        ylabel(ax(o-1), sprintf('%sV_{inter} (V/year)', GetUnicodeChar('Delta')), 'FontWeight', 'bold')

        xl(2) = 30;
    end
    
    for i = 1:3
        set(ax(o-i), 'XLim', xl)
    end

    o = o - 3;
end


xlabel(ax(2), 'Charge per Electrode (mC)', 'FontWeight', 'bold')

% Add text values after correction
h = gcf;
o = length(h.Children) + 1;
for i = 1:num_subjects
    title(ax(o-3), ColorText(subject_list(i), SubjectColors(subject_list(i))));

    t = sprintf('r = %0.3f\n%s', SQAnalysis.SNR_charge_r(i), pStr(SQAnalysis.SNR_charge_rp(i), 3));
    [x,y] = GetAxisPosition(ax(o-3), 100, 5);
    text(x,y,t, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [.2 .2 .2], ...
        'Parent', ax(o-3))

    t = sprintf('r = %0.3f\n%s', SQAnalysis.Vpp_charge_r(i), pStr(SQAnalysis.Vpp_charge_rp(i), 3));
    [x,y] = GetAxisPosition(ax(o-2), 100, 5);
    text(x,y,t, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [.2 .2 .2], ...
        'Parent', ax(o-2))

    t = sprintf('r = %0.3f\n%s', SQAnalysis.vinter_charge_r(i), pStr(SQAnalysis.vinter_charge_rp(i), 3));
    [x,y] = GetAxisPosition(ax(o-1), 100, 5);
    text(x,y,t, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [.2 .2 .2], ...
        'Parent', ax(o-1))

    o = o - 3;
end

AddFigureLabels(h.Children([3,2,1]), [.07, .0275])
% export_figure3x(FigurePath, 'SuppFig5_ChargeQuality')

%% Supplementary Figure 6 - Correlations between all factors
% For each participant:
% Correlate delta SNR, delta VPP, delta Vinter, delta detection threshold
[corr_rs, corr_ps] = deal(NaN(4, 4, num_subjects));
p_mask = logical(tril(ones(4)));
r_mask = ones(4); r_mask(1:5:end) = 0; r_mask = logical(r_mask);
for pi = 1:num_subjects
    % Get sensory mask
    sensory_mask = SQAnalysis.sensory_masks{pi};

    % Get value
    x = [SQAnalysis.SNR_slope(sensory_mask, pi), SQAnalysis.Vpp_slope(sensory_mask, pi), ...
         SQAnalysis.Cln_slope(:,pi), DetectionAnalysis.dt_slopes(:,pi)];
    % remove P4 from detection
    if pi == 5
        x(:,4) = NaN;
    end
    [r, p] = corr(x, 'Rows','pairwise','Type','Spearman');
    % NaN the p values for later HB correction
    p(p_mask) = NaN;
    corr_ps(:,:,pi) = p;
    
    % Remove self-correlation
    corr_rs(:,:,pi) = r;
end

xl = {'SNR', 'Vpp', 'Vinter', 'DT'};
corr_ps = HolmBonferroni(corr_ps);

%%
[ax_size_x, ax_x_val] = GetAxisCoords(4, 0.05, 0.1);
[ax_size_y, ax_y_val] = GetAxisCoords(1, 0.3, 0.15);
ax_y_val = ax_y_val + 0.05;

clf;
set(gcf, 'Units', 'Inches', 'Position', [27, 1, 12, 4]);
SetFont('Arial', 18)
marker_size = 60;

colors = SubjectColors(subject_list);

% SNR
axes('Position', [ax_x_val(1), ax_y_val, ax_size_x, ax_size_y]); hold on; title 'SNR'
    x = 1;
    yv = [2:4];
    for y = yv
        Swarm(x, squeeze(corr_rs(1, y, :)), 'SwarmColor', colors, ...
            'DistributionMethod', 'None', 'CenterLineWidth', 0, 'SwarmMarkerSize', marker_size)
        x = x + 1;
    end

    set(gca, 'XLim', [.5 3.5], ...
             'XTick', [1:3], ...
             'XTickLabels', xl(yv), ...
             'YLim', [-1 1])
    ylabel('Correlation (r)')

% Vpp
axes('Position', [ax_x_val(2), ax_y_val, ax_size_x, ax_size_y]); hold on; title 'V_{pp}'
    x = 1;
    yv = [1,3,4];
    for y = yv
        Swarm(x, squeeze(corr_rs(2, y, :)), 'SwarmColor', colors, ...
            'DistributionMethod', 'None', 'CenterLineWidth', 0, 'SwarmMarkerSize', marker_size)
        x = x + 1;
    end

    set(gca, 'XLim', [.5 3.5], ...
             'XTick', [1:3], ...
             'XTickLabels', xl(yv), ...
             'YLim', [-1 1], ...
             'YTickLabels', {})

% V_inter
axes('Position', [ax_x_val(3), ax_y_val, ax_size_x, ax_size_y]); hold on; title 'V_{inter}'
    x = 1;
    yv = [1,2,4];
    for y = yv
        Swarm(x, squeeze(corr_rs(3, y, :)), 'SwarmColor', colors, ...
            'DistributionMethod', 'None', 'CenterLineWidth', 0, 'SwarmMarkerSize', marker_size)
        x = x + 1;
    end

    set(gca, 'XLim', [.5 3.5], ...
             'XTick', [1:3], ...
             'XTickLabels', xl(yv), ...
             'YLim', [-1 1], ...
             'YTickLabels', {})

% DT
axes('Position', [ax_x_val(4), ax_y_val, ax_size_x, ax_size_y]); hold on; title 'dDT'
    x = 1;
    yv = [1:3];
    for y = yv
        Swarm(x, squeeze(corr_rs(4, y, :)), 'SwarmColor', colors, ...
            'DistributionMethod', 'None', 'CenterLineWidth', 0, 'SwarmMarkerSize', marker_size)
        x = x + 1;
    end

    set(gca, 'XLim', [.5 3.5], ...
             'XTick', [1:3], ...
             'XTickLabels', xl(yv), ...
             'YLim', [-1 1], ...
             'YTickLabels', {})
    


shg

%%

clf;
for pi = 1:num_subjects-1
    subplot(1,num_subjects-1,pi); hold on
    imagesc(corr_rs(:,:,pi), 'AlphaData', r_mask)
    set(gca, 'CLim', [-1 1], ...
             'XTick', [1:4], ...
             'YTick', [1:4], ...
             'XTickLabel', xl, ...
             'YTickLabel', xl, ...
             'XLim', [.5, 4.5], ...
             'YLim', [.5, 4.5], ...
             'Box', 'on', ...
             'Color', [.8 .8 .8])
    if pi > 1
        set(gca, 'YTickLabel', {})
    end

    for x = 1:4
        for y = 1:4
            if y <= x
                continue
            end
            text(y,x, sprintf("r = %0.2f\n%s", corr_rs(x,y,pi), pStr(corr_ps(x,y,pi))), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle')
        end
    end

end

ColorbarLegend(gcf(), [.95 .125 .025 .81], parula(), 'vert', [-1 1])

shg