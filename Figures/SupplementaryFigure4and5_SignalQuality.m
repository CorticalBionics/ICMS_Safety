% Signal Quality Analysis
subjects = {'BCI02', 'BCI03', 'CRS02', 'CRS07', 'CRS08'};
subject_alt = {'C1', 'C2', 'P2' 'P3', 'P4'};
num_participants = length(subjects);
num_arrays = 4;

%% Load SQ, VM, and Cleaning Data
% Get list of SQ data
flist = dir(fullfile(DataPath, 'SignalQuality', '*.mat'));
SQData = cell(num_participants, 1);

% Load voltage data
load(fullfile(DataPath, "VMData_All.mat"));
VMData = data;
conversion_factor = 1e6;
total_charge = zeros(length(subjects), 64);

% Load cleaning data
load(fullfile(DataPath, 'CleaningData'));
% Remove data from before 14-Aug-2017 (different monitoring system)
min_date = datetime(736920, 'ConvertFrom', 'datenum');
for p = 1:num_participants
    idx = [cleaning_data{p}.date] > min_date;
    cleaning_data{p} = cleaning_data{p}(idx); %#ok<SAGROW>
end

% Load SQData and process VM data
implant_dates = NaT(num_participants, 1);
for pi = 1:num_participants
    % Load SQ Data
    SQData{pi} = load(fullfile(DataPath, 'SignalQuality', flist(pi).name));
    SQData{pi}.participant = flist(pi).name(1:5);
    implant_dates(pi) = datetime(SQData{pi}.implant_metadata.implant_date, 'Format', 'dd-MMM-uuuu');

    % Filter VM data by participant
    s_idx = strcmp(data.Subject, subjects(pi));
    total_current = cat(2, data.CurrentCount{s_idx});
    all_charge = total_current .*  0.2 ./ conversion_factor; % Convert to charge in mC
    total_charge(pi, :) = sum(all_charge, 2, 'omitnan');
end
SQData = cat(1, SQData{:});

clearvars data all_charge total_current s_idx pi

%% Analyze SNR/VPP/Cleaning
[SNR_r, SNR_rp, SNR_slope, Vpp_r, Vpp_rp, Vpp_slope] = deal(NaN(256, num_participants));
[Cln_r, Cln_rp, Cln_slope] = deal(NaN(64, num_participants));
[median_SNR, median_Vpp, median_vinter] = deal(cell(num_participants, 1));
[med_SNR_r, med_SNR_p, med_Vpp_r, med_Vpp_p, med_Cln_r, med_Cln_p] = deal(NaN(num_participants, 1));

correlation_type = 'spearman';
for pi = 1:num_participants
    % Get sensory and motor masks
    sens_idx = contains(SQData(pi).implant_metadata.array_names, 'sensory', 'IgnoreCase', true);
    sensory_mask = SQData(pi).implant_metadata.chan_indices(sens_idx);
    sensory_mask = cat(2, sensory_mask{:});
    motor_idx = contains(SQData(pi).implant_metadata.array_names, 'motor', 'IgnoreCase', true);
    motor_mask = SQData(pi).implant_metadata.chan_indices(motor_idx);
    motor_mask = cat(2, motor_mask{:});


    %%% SNR
    x = datetime(num2str(SQData(pi).session_dates'), 'Format', 'yyyyMMdd');
    x = years(x - x(1));
    y = cat(1, SQData(pi).signal_quality_analysis.ch_snr);
    y = 10.^(y./20); % Undo log scaling

    % Apply good session mask
    y_mask = NaN(size(y));
    for a = 1:num_arrays
        % Skip anterior/lateral motor arrays in BCI02 and BCI03
        if startsWith(subjects{pi}, 'BCI') && strcmp(SQData(p).implant_metadata.array_names{a}, 'Anterior Motor')
            continue
        end
        mask = SQData(pi).good_session_mask{a}; % Good days
        idx = SQData(pi).implant_metadata.chan_indices{a}; % Good chs
        y_mask(mask, idx) = y(mask, idx);
    end

    [SNR_r(:,pi), SNR_rp(:,pi)] = corr(x, y_mask, 'Rows', 'pairwise', 'type', correlation_type);
    for c = 1:256
        SNR_slope(c, pi) = nan_regression(x, y_mask(:,c));
    end
    
    % Smooth & subsample
    y_mask = movmedian(y_mask, 3, 1, 'omitnan');
    median_SNR{pi}.sensory = median(y_mask(:, sensory_mask), 2, 'omitnan');
    median_SNR{pi}.motor = median(y_mask(:, motor_mask), 2, 'omitnan');


    %%% Vpp
    y = cat(1, SQData(pi).signal_quality_analysis.ch_vpp); % Same x as SNR

    % Apply good session mask
    y_mask = NaN(size(y));
    for a = 1:num_arrays
        mask = SQData(pi).good_session_mask{a}; % Good days
        idx = SQData(pi).implant_metadata.chan_indices{a}; % Good chs
        y_mask(mask, idx) = y(mask, idx);
    end

    [Vpp_r(:,pi), Vpp_rp(:,pi)] = corr(x, y_mask, 'Rows', 'pairwise', 'type', correlation_type);
    for c = 1:256
        Vpp_slope(c, pi) = nan_regression(x, y_mask(:,c));
    end
    
    % Smooth & subsample
    y_mask = movmedian(y_mask, 3, 1, 'omitnan');
    median_Vpp{pi}.sensory = median(y_mask(:, sensory_mask), 2, 'omitnan');
    median_Vpp{pi}.motor = median(y_mask(:, motor_mask), 2, 'omitnan');
    

    %%% Cleaning
    idx = cellfun(@(c) ~isempty(c), {cleaning_data{pi}.vmin});
    x = [cleaning_data{pi}(idx).date];
    x = years(x - x(1));
    y = cat(2, [cleaning_data{pi}(idx).vinter]);
    y(y < -1.5) = NaN; % Disconnected channels
    [Cln_r(:,pi), Cln_rp(:,pi)] = corr(x', y', 'Rows', 'pairwise', 'type', correlation_type);
    for c = 1:64
        Cln_slope(c, pi) = nan_regression(x, y(c,:));
    end
    median_vinter{pi} = median(y, 1, 'omitmissing');
    [med_Cln_r(pi), med_Cln_p(pi)] = corr(x', median_vinter{pi}', 'Rows', 'complete');
end

% Holm Bonferroni correction
SNR_rp = HolmBonferroni(SNR_rp);
Vpp_rp = HolmBonferroni(Vpp_rp);
Cln_rp = HolmBonferroni(Cln_rp);
med_Cln_p = med_Cln_p * num_participants;


%% Supplementary Figure 4
[ax_size_y, ax_y_val] = GetAxisCoords(num_participants + 1, 0.04, 0.05);
ax_y_val = ax_y_val + 0.03; ax_y_val = flipud(ax_y_val);
ax_y_val(end) = ax_y_val(end) - 0.05;
[ax_size_x, ax_x_val] = GetAxisCoords(3, 0.1, 0.075);
marker_size = 5;

motor_color = rgb(244, 67, 54); % Red
sensory_color = rgb(0, 137, 123); % Teal

clf;
set(gcf, 'Units', 'Inches', 'Position', [27, 1, 6.45, 8.5]);
SetFont('Arial', 9)

% Line plots
for p = 1:num_participants
    % Get dates for SQData
    x = datetime(num2str(SQData(p).session_dates'), 'Format', 'yyyyMMdd');
    x = years(x - implant_dates(p));
    xl = [0, ceil(x(end))];
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

    % SNR
    axes('Position', [ax_x_val(1), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        % Sensory
        y = median_SNR{p}.sensory;
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .1)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xl, polyval(r, xl), 'Color', sensory_color, 'LineWidth', 2);
        % Motor
        y = median_SNR{p}.motor;
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
        y = median_Vpp{p}.sensory;
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .1)
        r = polyfit(x(~isnan(y)), y(~isnan(y)), 1);
        plot(xl, polyval(r, xl), 'Color', sensory_color, 'LineWidth', 2);
        % Motor
        y = median_Vpp{p}.motor;
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
        idx = cellfun(@(c) ~isempty(c), {cleaning_data{p}.vmin});
        x = [cleaning_data{p}(idx).date];
        x = years(x - implant_dates(p));
        y = median_vinter{p};
        y(y < -1.5) = NaN; % Disconnected channels
        scatter(x, y, marker_size, sensory_color, 'MarkerEdgeAlpha', .15)
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

% Summary slopes
xl = [1-.75 num_participants+.75];
ax1 = axes('Position', [ax_x_val(1), ax_y_val(6), ax_size_x, ax_size_y+0.025]); hold on
    plot(xl, [0, 0], 'Color', [.6 .6 .6], 'LineStyle', '--')
ax2 = axes('Position', [ax_x_val(2), ax_y_val(6), ax_size_x, ax_size_y+0.025]); hold on
    plot(xl, [0, 0], 'Color', [.6 .6 .6], 'LineStyle', '--')

    offset = 0.05;
    for pi = 1:num_participants
        % Get indices to split arrays
        sens_idx = contains(SQData(pi).implant_metadata.array_names, 'sensory', 'IgnoreCase', true);
        sensory_mask = SQData(pi).implant_metadata.chan_indices(sens_idx);
        sensory_mask = cat(2, sensory_mask{:});
        motor_idx = contains(SQData(pi).implant_metadata.array_names, 'motor', 'IgnoreCase', true);
        motor_mask = SQData(pi).implant_metadata.chan_indices(motor_idx);
        motor_mask = cat(2, motor_mask{:});

        % Plot SNR
        Swarm(pi-offset, SNR_slope(sensory_mask, pi), sensory_color, 'Parent', ax1, ...
            'Sides', 'left', 'DS', 'violin', 'SPL', 0, 'DW', .35)
        Swarm(pi+offset, SNR_slope(motor_mask, pi), motor_color, 'Parent', ax1, ...
            'Sides', 'right', 'DS', 'violin', 'SPL', 0, 'DW', .35)
        % Ranksum test
        [P,H] = ranksum(SNR_slope(sensory_mask, pi), SNR_slope(motor_mask, pi));
        P = P * 5; % Bonferroni correction
        if P < 0.05
            text(pi, 1, '*', 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center', ...
                'Parent', ax1, 'FontSize', 15)
            fprintf('Participant %s SNR slope %s\n', subject_alt{pi}, pStr(P, 3))
        end

        % Plot Vpp
        Swarm(pi-offset, Vpp_slope(sensory_mask, pi), sensory_color, 'Parent', ax2, ...
            'Sides', 'left', 'DS', 'violin', 'SPL', 0, 'DW', .35)
        Swarm(pi+offset, Vpp_slope(motor_mask, pi), motor_color, 'Parent', ax2, ...
            'Sides', 'right', 'DS', 'violin', 'SPL', 0, 'DW', .35)
        % Ranksum test
        [P,H] = ranksum(Vpp_slope(sensory_mask, pi), Vpp_slope(motor_mask, pi));
        P = P * 5; % Bonferroni correction
        if P < 0.05
            text(pi, 100, '*', 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center', ...
                'Parent', ax2, 'FontSize', 15)
            fprintf('Participant %s VPP slope %s\n', subject_alt{pi}, pStr(P,3))
        end
    end
    set(ax1, 'YLim', [-1 1], ...
             'XLim', xl, ...
             'XTick', [1:num_participants], ...
             'XTickLabels', ColorText(subject_alt, SubjectColors(subject_alt)))
    ylabel(ax1, sprintf('%sSNR/year', GetUnicodeChar('Delta')), 'FontWeight', 'bold')

    set(ax2, 'YLim', [-150 100], ...
             'XLim', xl, ...
             'XTick', [1:num_participants], ...
             'XTickLabels', ColorText(subject_alt, SubjectColors(subject_alt)))
    ylabel(ax2, sprintf('%sVpp (%sV/year)', GetUnicodeChar('Delta'), GetUnicodeChar('mu')), 'FontWeight', 'bold')

axes('Position', [ax_x_val(3), ax_y_val(6), ax_size_x, ax_size_y+0.025]); hold on
    plot(xl, [0, 0], 'Color', [.6 .6 .6], 'LineStyle', '--')
    for pi = 1:num_participants
        Swarm(pi-offset, Cln_slope(:, pi), sensory_color, ...
            'Sides', 'both', 'DS', 'violin', 'SPL', 0, 'DW', .35)
    end

    set(gca, 'YLim', [-.25 .25], ...
             'XLim', xl, ...
             'XTick', [1:num_participants], ...
             'XTickLabels', ColorText(subject_alt, SubjectColors(subject_alt)))
    ylabel(sprintf('%sV_{inter} (V/year)', GetUnicodeChar('Delta')), 'FontWeight', 'bold')


% Manually reduce range of P4 cleaning voltages
h = gcf();
for i = [4:6]
    set(h.Children(i), 'XLim', [-.1 2.1], ...
                       'XTick', [0:2], ...
                       'XTickLabels', {'0', '', '2'})
end
h.Children(4).Children(2).MarkerEdgeAlpha = .4; % Make markers a little more obvious

AddFigureLabels(h.Children([end, 3, end-1, 2, end-2, 1]), [.07, .0275])
% export_figure3x(FigurePath, 'SuppFig4_SignalQuality')

shg

%% Supplementary Figure 5
[ax_size_x, ax_x_val] = GetAxisCoords(3, 0.1, 0.1);
[ax_size_y, ax_y_val] = GetAxisCoords(num_participants, 0.05, 0.05);
% ax_y_val = flipud(ax_y_val);
ax_y_val = ax_y_val + 0.03;
xl = [0 1];
prctile_mask = [5, 95];

clf;
set(gcf, 'Units', 'Inches', 'Position', [27, 1, 6.45, 9]);
SetFont('Arial', 9)
marker_size = 10;

clearvars ax
% Create axes
i = 1;
for p = 1:num_participants
    for j = 1:3
        ax(i) = axes('Position', [ax_x_val(j), ax_y_val(p), ax_size_x, ax_size_y]); hold on
        set(ax(i), 'XScale', 'linear', 'YScale', 'linear', 'XTick', [0 1])
        i = i + 1;
    end
end

% Correlate SNR/VPP/Cleaning with VMData on sensory arrays
[SNR_charge_r, SNR_charge_rp, Vpp_charge_r, Vpp_charge_rp, vinter_charge_r, vinter_charge_rp] = ...
    deal(NaN(1, num_participants));
o = length(h.Children) + 1;
for pi = 1:num_participants
    x = rescale(total_charge(pi, :)');

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
    end

    o = o - 3;
end

% Holm Bonferroni correction
p_all = [SNR_charge_rp; Vpp_charge_rp; vinter_charge_rp];
p_all = HolmBonferroni(p_all);
SNR_charge_rp = p_all(1,:);
Vpp_charge_rp = p_all(2,:);
vinter_charge_rp = p_all(3,:);

% Add text values after correction
h = gcf;
o = length(h.Children) + 1;
for i = 1:num_participants
    t = sprintf('r = %0.3f\n%s', SNR_charge_r(i), pStr(SNR_charge_rp(i), 3));
    [x,y] = GetAxisPosition(ax(o-3), 100, 5);
    text(x,y,t, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [.2 .2 .2], ...
        'Parent', ax(o-3))
    title(ax(o-3), ColorText(subject_alt(i), SubjectColors(subject_alt(i))));

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

xlabel(ax(2), 'Normalized Charge per Electrode', 'FontWeight', 'bold')
AddFigureLabels(h.Children([3,2,1]), [.07, .0275])
export_figure3x(FigurePath, 'SuppFig5_ChargeQuality')

%% Functions
function slope = nan_regression(x, y)
    slope = NaN;
    nan_idx = isnan(y);
    if sum(~nan_idx) < 10
        return
    end
    if ~all(size(y) == size(x))
        y = y';
    end
    pf = polyfit(x(~nan_idx)', y(~nan_idx)', 1);
    slope = pf(1);
end