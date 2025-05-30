% Signal Quality Analysis
load(fullfile(DataPath, "SQ_Analysis"))
subject_alt = {'C1', 'C2', 'P2' 'P3', 'P4'};
num_participants = length(subject_alt);

%% Supplementary Figure 4
[ax_size_y, ax_y_val] = GetAxisCoords(num_participants, 0.04, 0.05);
ax_y_val = ax_y_val + 0.03; ax_y_val = flipud(ax_y_val);
[ax_size_x, ax_x_val] = GetAxisCoords(3, 0.1, 0.075);
marker_size = 5;

motor_color = rgb(0, 137, 123); % Teal
sensory_color = rgb(244, 67, 54); % Red

clf;
set(gcf, 'Units', 'Inches', 'Position', [27, 1, 6.45, 7.5]);
SetFont('Arial', 9)

% Line plots
for p = 1:num_participants
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
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .1)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xl, polyval(r, xl), 'Color', sensory_color, 'LineWidth', 2);
        % Motor
        y = SQAnalysis.median_SNR{p}.motor;
        scatter(x, y, marker_size, motor_color, 'MarkerEdgeAlpha', .1)
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
        elseif p == round(num_participants / 2)
            ylabel('SNR', 'FontWeight', 'bold')
        end
        title(ColorText(subject_alt{p}, SubjectColors(subject_alt{p})), 'VerticalAlignment', 'top')

    % Vpp
    axes('Position', [ax_x_val(2), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        % Sensory
        y = SQAnalysis.median_Vpp{p}.sensory;
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .1)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xl, polyval(r, xl), 'Color', sensory_color, 'LineWidth', 2);
        % Motor
        y = SQAnalysis.median_Vpp{p}.motor;
        scatter(x, y, marker_size, motor_color, 'MarkerEdgeAlpha', .1)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xl, polyval(r, xl), 'Color', motor_color, 'LineWidth', 2);
        
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabels', xtl, ...
                 'YLim', [0, 200], ...
                 'XTickLabelRotation', 0)
    
        if p == round(num_participants / 2)
            ylabel(sprintf('Vpp (%sV)', GetUnicodeChar('mu')), 'FontWeight', 'bold')
        elseif p == num_participants
            xlabel('Years Implanted', 'FontWeight', 'bold')
        end

    % Cleaning
    axes('Position', [ax_x_val(3), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        x = SQAnalysis.cln_dates{p};
        y = SQAnalysis.median_vinter{p};
        y(y < -1.5) = NaN; % Disconnected channels
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .25)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xl, polyval(r, xl), 'Color', sensory_color, 'LineWidth', 2);
        % [r,p] = corr(x,y, 'Rows', 'complete');
    
        set(gca, 'XLim', xl, ...
                 'XTick', xt, ...
                 'XTickLabels', xtl, ...
                 'YLim', [-1.3, -0.75], ...
                 'XTickLabelRotation', 0)
    
        if p == round(num_participants / 2)
            ylabel(sprintf('V_{inter} (V)'), 'FontWeight', 'bold')
        end
end


% Manually reduce range of P4 cleaning voltages
h = gcf();
for i = [4:6]
    set(h.Children(i), 'XLim', [-.1 2.1], ...
                       'XTick', [0:2], ...
                       'XTickLabels', {'0', '', '2'})
end

AddFigureLabels(h.Children([end, end-1, end-2]), [.075, .0275])
% export_figure3x(FigurePath, 'SuppFig4_SignalQuality')

shg

%% Supplementary Figure 5
[ax_size_x, ax_x_val] = GetAxisCoords(3, 0.1, 0.1);
[ax_size_y, ax_y_val] = GetAxisCoords(num_participants, 0.05, 0.05);
% ax_y_val = flipud(ax_y_val);
ax_y_val = ax_y_val + 0.01;

clf;
set(gcf, 'Units', 'Inches', 'Position', [27, 1, 6.45, 8]);
SetFont('Arial', 9)
marker_size = 10;

clearvars ax
% Create axes
i = 1;
for p = 1:num_participants
    for j = 1:3
        ax(i) = axes('Position', [ax_x_val(j), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        set(ax(i), 'XScale', 'linear', 'YScale', 'linear')
        i = i + 1;
    end
end

% Correlate SNR/VPP/Cleaning with VMData on sensory arrays

o = length(h.Children) + 1;
for pi = 1:num_participants
    x = total_charge(pi, :)';
    xl = [0 ceil(max(x, [], 'omitnan'))];
  
    % Get sensory mask
    sens_idx = contains(SQData(pi).implant_metadata.array_names, 'sensory', 'IgnoreCase', true);
    sensory_mask = SQData(pi).implant_metadata.chan_indices(sens_idx);
    sensory_mask = cat(2, sensory_mask{:});
    
    % SNR
    snr_y = SNR_slope(sensory_mask, pi);
    mask = snr_y < prctile(snr_y, prctile_mask(1)) | snr_y > prctile(snr_y, prctile_mask(2));
    snr_y(mask) = NaN;
    nan_idx = ~isnan(snr_y);
    scatter(x, snr_y, marker_size, SubjectColors(subjects{pi}), 'MarkerEdgeAlpha', .5, 'Parent', ax(o-3))
    r = polyfit(x(nan_idx), snr_y(nan_idx), 1);
    plot(xl, polyval(r, xl), 'Color', SubjectColors(subjects{pi}), 'Parent', ax(o-3), 'LineWidth', 2);
    [SNR_charge_r(pi), SNR_charge_rp(pi)] = corr(x, snr_y, 'Rows', 'pairwise', 'type', correlation_type);

    % Vpp
    vpp_y = Vpp_slope(sensory_mask, pi);
    mask = vpp_y < prctile(vpp_y, prctile_mask(1)) | vpp_y > prctile(vpp_y, prctile_mask(2));
    vpp_y(mask) = NaN;
    nan_idx = ~isnan(vpp_y);
    scatter(x, vpp_y, marker_size, SubjectColors(subjects{pi}), 'MarkerEdgeAlpha', .5, 'Parent', ax(o-2))
    r = polyfit(x(nan_idx), vpp_y(nan_idx), 1);
    plot(xl, polyval(r, xl), 'Color', SubjectColors(subjects{pi}), 'Parent', ax(o-2), 'LineWidth', 2);
    [Vpp_charge_r(pi), Vpp_charge_rp(pi)] = corr(x, vpp_y, 'Rows', 'pairwise', 'type', correlation_type);

    %Vinter
    cln_y = Cln_slope(:, pi);
    mask = cln_y < prctile(cln_y, prctile_mask(1)) | cln_y > prctile(cln_y, prctile_mask(2));
    cln_y(mask) = NaN;
    nan_idx = ~isnan(cln_y);
    scatter(x, cln_y, marker_size, SubjectColors(subjects{pi}), 'MarkerEdgeAlpha', .5, 'Parent', ax(o-1))
    r = polyfit(x(nan_idx), cln_y(nan_idx), 1);
    plot(xl, polyval(r, xl), 'Color', SubjectColors(subjects{pi}), 'Parent', ax(o-1), 'LineWidth', 2);
    [vinter_charge_r(pi), vinter_charge_rp(pi)] = corr(x, cln_y, 'Rows', 'pairwise', 'type', correlation_type);

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
for i = 1:num_participants
    title(ax(o-3), ColorText(subject_alt(i), SubjectColors(subject_alt(i))));

    t = sprintf('r = %0.3f\n%s', SNR_charge_r(i), pStr(SNR_charge_rp(i), 3));
    [x,y] = GetAxisPosition(ax(o-3), 100, 5);
    text(x,y,t, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [.2 .2 .2], ...
        'Parent', ax(o-3))

    t = sprintf('r = %0.3f\n%s', Vpp_charge_r(i), pStr(Vpp_charge_rp(i), 3));
    [x,y] = GetAxisPosition(ax(o-2), 100, 5);
    text(x,y,t, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [.2 .2 .2], ...
        'Parent', ax(o-2))

    t = sprintf('r = %0.3f\n%s', vinter_charge_r(i), pStr(vinter_charge_rp(i), 3));
    [x,y] = GetAxisPosition(ax(o-1), 100, 5);
    text(x,y,t, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [.2 .2 .2], ...
        'Parent', ax(o-1))

    o = o - 3;
end

AddFigureLabels(h.Children([3,2,1]), [.07, .0275])
% export_figure3x(FigurePath, 'SuppFig5_ChargeQuality')