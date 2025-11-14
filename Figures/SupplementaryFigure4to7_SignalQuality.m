% Signal Quality Analysis
load(fullfile(DataPath, "SQ_Analysis"))
load(fullfile(DataPath, "SignalQuality"))
load(fullfile(DataPath, 'DT_Analysis'));
load(fullfile(DataPath, "VMData_All.mat"), 'total_charge')
[subject_list, num_subjects] = GetSubjectList(true);

% Load cleaning data
load(fullfile(DataPath, 'CleaningData'));
% Remove data from before 832 days after implant for P2 (different monitoring system)
idx = [cleaning_data{3}.date] > 832; % Relative number of days after implant
cleaning_data{3} = cleaning_data{3}(idx);

% Load impedance data
load(fullfile(DataPath, 'ImpedanceData'));
% Remove bad arrays from C1 and C2
% Anterior motor from C1
filt = SQData(1).implant_metadata.chan_indices{1};
ImpedanceData(1).impedances(:,filt) = NaN(length(ImpedanceData(1).dates), length(filt));
% Posterior sensory from C2
filt = SQData(2).implant_metadata.chan_indices{4};
ImpedanceData(2).impedances(:,filt) = NaN(length(ImpedanceData(2).dates), length(filt));

%% Supplementary Figure 4
[ax_size_y, ax_y_val] = GetAxisCoords(num_subjects, 0.04, 0.05);
ax_y_val = ax_y_val + 0.025; ax_y_val = flipud(ax_y_val);
[ax_size_x, ax_x_val] = GetAxisCoords(4, 0.1, 0.05);
ax_x_val = ax_x_val + 0.0125;
marker_size = 5;

sensory_color = rgb(52, 152, 219); % Peterriver
motor_color = rgb(46, 63, 79); % Wetasphalt

clf;
set(gcf, 'Units', 'Inches', 'Position', [31, 1, 6.45, 7.5]);
SetFont('Arial', 9)

% Line plots
for p = 1:num_subjects
    % Get dates for SQData
    x = SQAnalysis.sq_dates{p};
    xl = [0, ceil(x(end))];
    xt = [xl(1):xl(end)];
    xl = [xl(1) - range(xl) * 0.05, xl(end) + range(xl) * 0.05];
    xq = linspace(xl(1), xl(2));
    xtl = sparse_xticklabels(xt);

    % SNR
    axes('Position', [ax_x_val(1), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        % Sensory
        y = SQAnalysis.median_SNR{p}.sensory;
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .25)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xq, polyval(r, xq), 'Color', sensory_color, 'LineWidth', 2);
        % Motor
        y = SQAnalysis.median_SNR{p}.motor;
        scatter(x, y, marker_size, motor_color, 'MarkerEdgeAlpha', .25)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xq, polyval(r, xq), 'Color', motor_color, 'LineWidth', 2);
        
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabel', xtl, ...
                 'YLim', [0.75, 2], ...
                 'XTickLabelRotation', 0)
        
        % Formatting
        if p == 1
            text(5, 5, ColorText({'Motor', 'Sensory'}, [motor_color; sensory_color]), ...
                'sc', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom')
        elseif p == round(num_subjects / 2)
            ylabel('SNR', 'FontWeight', 'bold', 'VerticalAlignment','middle')
        end
        title(ColorText(subject_list{p}, SubjectColors(subject_list{p})), 'VerticalAlignment', 'top')

    % Vpp
    axes('Position', [ax_x_val(2), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        % Sensory
        y = SQAnalysis.median_Vpp{p}.sensory;
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .25)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xq, polyval(r, xq), 'Color', sensory_color, 'LineWidth', 2);
        % Motor
        y = SQAnalysis.median_Vpp{p}.motor;
        scatter(x, y, marker_size, motor_color, 'MarkerEdgeAlpha', .25)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xq, polyval(r, xq), 'Color', motor_color, 'LineWidth', 2);
        
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabels', xtl, ...
                 'YLim', [0, 200], ...
                 'XTickLabelRotation', 0)
    
        if p == round(num_subjects / 2)
            ylabel(sprintf('Vpp (%sV)', GetUnicodeChar('mu')), 'FontWeight', 'bold', 'VerticalAlignment','middle')           
        end

    % Impedances
    axes('Position', [ax_x_val(3), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        % Sensory
        x = SQAnalysis.imp_dates{p};
        y = SQAnalysis.median_Imp{p}.sensory;
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .25)
        % r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        % plot(xq, polyval(r, xq), 'Color', sensory_color, 'LineWidth', 2);
        % Motor
        y = SQAnalysis.median_Imp{p}.motor;
        scatter(x, y, marker_size, motor_color, 'MarkerEdgeAlpha', .25)
        % r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        % plot(xq, polyval(r, xq), 'Color', motor_color, 'LineWidth', 2);
        
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabels', xtl, ...
                 'XTickLabelRotation', 0)
    
        if p == round(num_subjects / 2)
            ylabel(sprintf('Impedance (k%s)', GetUnicodeChar('Omega')), 'FontWeight', 'bold', 'VerticalAlignment','middle')
        end

    % Cleaning
    axes('Position', [ax_x_val(4), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        x = SQAnalysis.cln_dates{p};
        y = SQAnalysis.median_vinter{p};
        y(y < -1.5) = NaN; % Disconnected channels
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .5)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xq, polyval(r, xq), 'Color', sensory_color, 'LineWidth', 2);
        % [r,p] = corr(x,y, 'Rows', 'complete');
    
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabels', xtl, ...
                 'YLim', [-1.3, -0.75], ...
                 'XTickLabelRotation', 0)
    
        if p == round(num_subjects / 2)
            ylabel(sprintf('V_{inter} (V)'), 'FontWeight', 'bold', 'VerticalAlignment','middle')
        end
end

annotation("textbox", [0.4 0.025 0.2 0.025], 'String',  'Years Post Implant', 'FontWeight', 'bold', 'EdgeColor', 'none')

h = gcf();
AddFigureLabels(h.Children([end, end-1, end-2, end-3]), [.075, .0275])
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
mc = multcompare(stat, 'Dimension', 2);


%% Correlations between all factors
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

corr_ps = HolmBonferroni(corr_ps);
% Reflect the ps values after HBPHC
corr_ps = mean(cat(4, corr_ps, permute(corr_ps, [2,1,3])), 4, 'omitnan');


%% Supplementary Figure 5
dt_xbin = 250;
[ax_size_y, ax_y_val] = GetAxisCoords(2, 0.15, 0.1);

clf;
set(gcf, 'Units', 'Inches', 'Position', [1, 1, 6.45, 4.5]);
SetFont('Arial', 9)
colors = SubjectColors(subject_list);


[ax_size_x, ax_x_val] = GetAxisCoords(5, 0.05, 0.075);
% Charge correlation dot plots
% Concatenate for easy indexing
r = cat(1, SQAnalysis.SNR_charge_r, SQAnalysis.Vpp_charge_r, SQAnalysis.Imp_charge_r, SQAnalysis.vinter_charge_r);
p = cat(1, SQAnalysis.SNR_charge_rp, SQAnalysis.Vpp_charge_rp, SQAnalysis.Imp_charge_rp, SQAnalysis.vinter_charge_rp);

axes('Position', [ax_x_val(1), ax_y_val(2), ax_size_x, ax_size_y]); hold on; title('Charge')
    plot([.5 4.5], [0 0], 'Color', [.6 .6 .6], 'LineStyle', ':')
    for i = 1:size(r,1)
        for j = 1:num_subjects
            if p(i,j) < 0.05
                fc = colors(j,:);
            else
                fc = [1,1,1];
            end
            scatter(i, r(i,j), 30, 'MarkerEdgeColor', colors(j,:), ...
                    'MarkerFaceColor', fc, 'LineWidth', 1.5)
        end
    end

    set(gca, 'XTick', [1:4], ...
             'XLim', [.5 4.5], ...
             'XTickLabels', {'SNR', 'V_{pp}', 'Imp', 'V_{inter}'}, ...
             'YLim', [-1 1])
    ylabel('Correlation (r)')


% Signal Quality correlation dot plots
titles = {sprintf('%sSNR', GetUnicodeChar('Delta')), ...
          sprintf('%sV_{pp}', GetUnicodeChar('Delta')), ...
          sprintf('%sV_{inter}', GetUnicodeChar('Delta')), ...
          sprintf('%sDT', GetUnicodeChar('Delta'))};
yv = [1:4];
for ax = 1:4
    axes('Position', [ax_x_val(ax+1), ax_y_val(2), ax_size_x, ax_size_y]); hold on
    yv_ax = yv(yv ~= ax);
    sig_cor_plot(corr_rs(ax, yv_ax,:), corr_ps(ax, yv_ax,:), colors)
    
    % Format
    title(titles{ax})
    set(gca, 'XTickLabels', titles(yv_ax), 'YTickLabels', {})
end

% Metric detection plots
[ax_size_x, ax_x_val] = GetAxisCoords(4, 0.095, 0.075);
clearvars ax
% Create axes
for j = 1:4
    ax(j) = axes('Position', [ax_x_val(j), ax_y_val(1), ax_size_x, ax_size_y]); hold on %#ok<SAGROW>
    set(ax(j), 'XTick', [1.5:3:14.5], ...
               'XTickLabel', ColorText(subject_list, SubjectColors(subject_list)))
end

% Plot and assign data to cell for ANOVA
[snr, vpp, cln, dt] = deal(cell(num_subjects, 1));
i = 1;
for pi = 1:num_subjects
    % Get last time point
    xmax = DetectionAnalysis.term_idx(pi);
    
    % Get functional indices for first and last time point
    dt_idx_end = DetectionAnalysis.disabled_electrodes{pi}(:,xmax);
    dt{pi} = dt_idx_end;
    
    % Get median SQ metrics for first and last time point
    sm = SQAnalysis.sensory_masks{pi};
    x = SQData(pi).session_dates;
    sqx_idx_end = x-max(x) >= -dt_xbin; % Last time bin
    
    % SNR
    y_snr = cat(1, SQData(pi).signal_quality_analysis.ch_snr);
    y_snr = 10.^(y_snr./20); % Undo log scaling
    y_snr_end = median(y_snr(sqx_idx_end, sm), 1, 'omitnan');
    snr{pi} = y_snr_end;

    % Vpp
    y_vpp = cat(1, SQData(pi).signal_quality_analysis.ch_vpp); % Same x as SNR
    y_vpp_end = median(y_vpp(sqx_idx_end, sm), 1, 'omitnan');
    vpp{pi} = y_vpp_end;

    % V_inter
    idx = cellfun(@(c) ~isempty(c), {cleaning_data{pi}.vmin});
    x = [cleaning_data{pi}(idx).date];
    clnx_idx_end = x-max(x) >= -dt_xbin; % Last time bin

    y_cln = cat(2, [cleaning_data{pi}(idx).vinter]);
    y_cln(y_cln < -1.5) = NaN; % Disconnected channels
    y_cln_end = median(y_cln(:, clnx_idx_end), 2, 'omitnan');
    cln{pi} = y_cln_end;

    % Impedance (uses different dates because not stim only)
    sensory_mask = SQAnalysis.sensory_masks{pi};
    imp_idx = (max(ImpedanceData(pi).dates) - ImpedanceData(pi).dates) < 250;
    imp_vals = ImpedanceData(pi).impedances(imp_idx, sensory_mask);
    imp_vals = median(imp_vals, 1, 'omitnan');

    % Add data
    % SNR
    Swarm(i, y_snr_end(dt_idx_end), 'Color', colors(pi,:), ...
        'Parent', ax(1), 'distribution_style', 'Box', 'swarm_point_limit', 0)
    Swarm(i+1, y_snr_end(~dt_idx_end), 'Color',colors(pi,:), ...
        'Parent', ax(1), 'distribution_style', 'Box', 'swarm_point_limit', 0, 'distribution_face_alpha', 0)
    % Vpp
    Swarm(i, y_vpp_end(dt_idx_end), 'Color', colors(pi,:), ...
        'Parent', ax(2), 'distribution_style', 'Box', 'swarm_point_limit', 0)
    Swarm(i+1, y_vpp_end(~dt_idx_end), 'Color', colors(pi,:), ...
        'Parent', ax(2), 'distribution_style', 'Box', 'swarm_point_limit', 0, 'distribution_face_alpha', 0)
    % Cln
    Swarm(i, y_cln_end(dt_idx_end), 'Color', colors(pi,:), ...
        'Parent', ax(3), 'distribution_style', 'Box', 'swarm_point_limit', 0)
    Swarm(i+1, y_cln_end(~dt_idx_end), 'Color', colors(pi,:), ...
        'Parent', ax(3), 'distribution_style', 'Box', 'swarm_point_limit', 0, 'distribution_face_alpha', 0)
    % Imp
    Swarm(i, imp_vals(dt_idx_end), 'Color', colors(pi,:), ...
        'Parent', ax(4), 'distribution_style', 'Box', 'swarm_point_limit', 0)
    Swarm(i+1, imp_vals(~dt_idx_end), 'Color', colors(pi,:), ...
        'Parent', ax(4), 'distribution_style', 'Box', 'swarm_point_limit', 0, 'distribution_face_alpha', 0)
    
    % Increment x
    i = i + 3;
end

% Formatting
ylabel(ax(1), 'SNR')
ylabel(ax(2), sprintf('Vpp (%sv)', GetUnicodeChar('mu')))
ylabel(ax(3), sprintf('V_{inter} (%sv)', GetUnicodeChar('mu')))
ylabel(ax(4), 'Impedance (kOhms)')
set(ax(4), 'YScale', 'log')

text(1, 1.5, 'Detectable', 'Rotation', 90, 'HorizontalAlignment','left', 'VerticalAlignment', 'middle', 'Parent', ax(1))
text(2.5, 1.5, 'Undetectable', 'Rotation', 90, 'HorizontalAlignment','left', 'VerticalAlignment', 'middle', 'Parent', ax(1))

AddFigureLabels(gcf(), [.05, 0])
% export_figure3x(FigurePath, 'SuppFig5_SQ_DT')

shg

%% ANOVA on data
snr = cat(1, snr{:})';
vpp = cat(1, vpp{:})';
cln = cat(2, cln{:});
dt = cat(2, dt{:});
prt = repmat([1:5], 64, 1);

snr_anova = anovan(snr(:), {dt(:), prt(:)}, 'varnames', {'Detectable', 'Participant'});
vpp_anova = anovan(vpp(:), {dt(:), prt(:)}, 'varnames', {'Detectable', 'Participant'});
cln_anova = anovan(cln(:), {dt(:), prt(:)}, 'varnames', {'Detectable', 'Participant'});


%% Supplementary Figure 6 right column
clf; 
set(gcf, 'Units', 'Inches', 'Position', [1, 1, 3, 10]);
SetFont('Arial', 9)

[ax_size_y, ax_y_val] = GetAxisCoords(num_subjects, 0.05, 0.05);
[ax_size_x, ax_x_val] = GetAxisCoords(1, 0.05, 0.1);
ax_y_val = flipud(ax_y_val);

for pi = 1:num_subjects
    axes('Position', [ax_x_val, ax_y_val(pi), ax_size_x, ax_size_y]); hold on

    % Get functional indices for first and last time point
    dt_idx_1 = DetectionAnalysis.disabled_electrodes{pi}(:,1);
    dt_idx_end = DetectionAnalysis.disabled_electrodes{pi}(:,DetectionAnalysis.term_idx(pi));

    % Counts
    Swarm(1, sum(dt_idx_1 & dt_idx_end), SubjectColors(subject_list{pi}), ...
        'DS', 'Bar', 'swarm_point_limit', 0)
    Swarm(2, sum(dt_idx_1 & ~dt_idx_end), SubjectColors(subject_list{pi}), ...
        'DS', 'Bar', 'swarm_point_limit', 0)
    Swarm(3, sum(dt_idx_end & ~dt_idx_1), SubjectColors(subject_list{pi}), ...
        'DS', 'Bar', 'swarm_point_limit', 0)

    % Format
    set(gca, 'XLim', [.5 3.5], ...
             'YLim', [0 64], ...
             'XTick', [1:3], ...
             'YTick', [0:16:64], ...
             'XTickLabels', {}, ...
             'TickDir', 'out')
end

set(gca, 'XTickLabels', {sprintf('1^{st} %s n^{th}', GetUnicodeChar('Union')), ... 
     '1^{st} ~ n^{th}', 'n^{th} ~ 1^{st}'})

shg
%export_figure3x(FigurePath, 'SuppFig7_Uggo')


%% Helper functions
function sig_cor_plot(r,p, color)
    % Collapse dimensions for easier indexing (v X participant)
    r = squeeze(r);
    p = squeeze(p);

    % Plot 0-line
    plot([.5 size(r,1) + .5], [0,0], 'Color', [.6 .6 .6], 'LineStyle', ':')

    for i = 1:size(r,1)
        for j = 1:size(r,2)
            if p(i,j) < 0.05
                fc = color(j,:);
            else
                fc = [1,1,1];
            end
            scatter(i, r(i,j), 30, 'MarkerEdgeColor', color(j,:), ...
                    'MarkerFaceColor', fc, 'LineWidth', 1.5)
        end
    end

    set(gca, 'XLim', [.5 size(r,1) + .5], ...
             'XTick', [1:size(r,1)], ...
             'YLim', [-1 1])

end