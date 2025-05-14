load(fullfile(DataPath, 'CleaningData'));
load(fullfile(DataPath, 'VMData_All.mat')); 
VMData = data; clearvars data
u_part = {'BCI02', 'BCI03', 'CRS02', 'CRS07', 'CRS08'};
subjects = {'C1', 'C2', 'P2', 'P3', 'P4'};
num_part = length(u_part);
num_channels = 64;

% Remove data from before 14-Aug-2017 (different monitoring system)
% min_date = datetime(736920, 'ConvertFrom', 'datenum');
% for p = 1:num_part
%     idx = [cleaning_data{p}.date] > min_date;
%     cleaning_data{p} = cleaning_data{p}(idx); %#ok<SAGROW>
% end

%% ANOVA on interphase voltages
% N-way ANOVA: participant X time (since implant) X electrode
[y, g1, g2, g3] = deal(cell(num_part, 1));
for p = 1:num_part
    % Get interphase voltage
    idx = cellfun(@(c) ~isempty(c), {cleaning_data{p}.vmin});
    x = [cleaning_data{p}(idx).date];
    ty = cat(2, [cleaning_data{p}(idx).vinter]);
    y{p} = ty(:);
    % Construct group values
    % participant == p for each value
    tg1 = repelem(p, size(ty,1), size(ty,2));
    g1{p} = tg1(:);
    % time = x - xmin
    tg2 = repmat(x, size(ty,1), 1);
    if contains(u_part{p}, 'BCI')
        site = 'chicago';
    elseif contains(u_part{p}, 'CRS')
        site = 'pitt';
    end
    if strcmp(u_part{p}, 'CRS02')
        id = datetime(cc.load_config.participant('CRS02b', site).implant_date, 'InputFormat','uuuu-MM-dd');
    else
        id = datetime(cc.load_config.participant(u_part{p}, site).implant_date, 'InputFormat','uuuu-MM-dd');
    end
    tg2 = days(tg2 - id);
    g2{p} = tg2(:);
    % electrode = 1:64 repmat
    tg3 = repmat([1:64]', 1, size(ty, 2));
    g3{p} = tg3(:);
end

% Concatenate all
y_c = cat(1, y{:});
g1_c = cat(1, g1{:});
g2_c = cat(1, g2{:});
g3_c = cat(1, g3{:});

int_anova = anovan(y_c, {g1_c, g2_c, g3_c}, 'varnames', {'Participant', 'Time', 'Electrode'});

%% Correlations
fnames = {'vmax', 'vinter', 'vmin'};
[r, rp, lin_coeffs] = deal(NaN(64, num_part, 3));
for p = 1:num_part
    idx = cellfun(@(c) ~isempty(c), {cleaning_data{p}.vmin});
    x = datenum([cleaning_data{p}(idx).date]); %#ok<DATNM>
    for f = 1:3
        ty = cat(2, [cleaning_data{p}(idx).(fnames{f})]);
        % Correlations of time vs voltage
        [r(:,p,f), rp(:,p,f)] = corr(x', ty', 'Rows', 'pairwise', 'type', 'spearman');
        % Linear regression
        for c = 1:64
            nan_idx = isnan(ty(c,:));
            if sum(~nan_idx) < 10
                continue
            end
            pf = polyfit(x(~nan_idx)', ty(c, ~nan_idx)', 1);
            lin_coeffs(c,p,f) = pf(1);
        end
    end
end
rp = HolmBonferroni(rp);

%% VM correlations
total_charge = zeros(length(u_part), num_channels);
for pi = 1:length(u_part)
    % Filter participant
    s_idx = strcmp(VMData.Subject, u_part(pi));
    total_current = cat(2, VMData.CurrentCount{s_idx});
    total_current(total_current == 0) = NaN;
    all_charge = total_current .*  0.2; % Convert to charge, don't need to convert to millicoulombs
end

%% Supplementary Figure 3
clf;
h = 3; w = 5;
yl = [0, .8 ; -1.2, -.2; -2, -1];

ii = 1;
for s = 1:3
    % Values over time
    subplot(h,w,[ii:ii+2]); hold on
    title(fnames{s})
    
    if s == 2
        ylabel('"Voltage"')
    end

    for p = 1:num_part
        idx = cellfun(@(c) ~isempty(c), {cleaning_data{p}.vmin});
        x = [cleaning_data{p}(idx).date];
        for f = 1:3
            y = cat(2, [cleaning_data{p}(idx).(fnames{s})]);
        end
        y = movmedian(y, 10, 2, 'omitmissing');
        AlphaLine(x, y, SubjectColors(u_part{p}), 'ErrorType', 'Percentile', 'Percentiles', [25, 75])
    end
    set(gca, 'YLim', yl(s,:), ...
             'XLim', [datetime('2015', 'Format', 'uuuu'), datetime('2025', 'Format', 'uuuu')])
    if s < 3
        set(gca, 'XTickLabel', {})
    end
    
    % Correlations
    subplot(h,w, ii + 3); hold on
    for p = 1:num_part
        col = repmat(SubjectColors(u_part{p}), 64, 1);
        % Color code correlatinos by significance
        idx = rp(:,p,s) > 0.05;
        if ~any(idx)
            continue
        end
        col(idx,:) = .8;
        Swarm(p, r(:,p,s), SubjectColors(u_part{p}), 'SwarmColor', col, 'DistributionWidth', .35)
    end

    % ylabel('Time X Interphase Correlation')
    set(gca, 'Ylim', [-1 1], ...
             'XTick', [1:5], ...
             'XTickLabel', ColorText(subjects, SubjectColors(u_part)), ...
             'XLim', [.5 5.5])
    if s < 3
        set(gca, 'XTickLabel', {})
    end
    if s == 2
        ylabel('Correlation')
    end


    % Slopes
    subplot(h,w, ii + 4); hold on
    plot([.5 5.5], [0 0], 'Color', [.6 .6 .6], 'LineStyle', '--')
    for p = 1:num_part
        Swarm(p, lin_coeffs(:,p,s), SubjectColors(u_part{p}), 'SPL', 0, 'DS', 'Box')
    end
    set(gca, 'Ylim', prctile(lin_coeffs(:,:,s), [5, 95], "all"), ...
             'XTick', [1:5], ...
             'XTickLabel', ColorText(subjects, SubjectColors(u_part)), ...
             'XLim', [.5 5.5])

    if s < 3
        set(gca, 'XTickLabel', {})
    end
    if s == 2
        ylabel('Slope (V/day)')
    end

    ii = ii + w;
end

shg

% export_figure3x(FigurePath, 'SuppFig3_Cleaning')
%%


%% Compare waveforms on two sessions
p = 1;
i1 = 50;
i2 = 300;

clf;
subplot(1,3,1); hold on
    plot([34 34], [-2 2], 'Color', [.6 .6 .6], 'LineStyle', '--')
    plot(cleaning_data{p}(i1).wf'); ylim([-2 2])
    title(string(cleaning_data{p}(i1).date))
    xlabel('Sample #')
    ylabel('"Voltage"')

subplot(1,3,2); hold on
    plot([34 34], [-2 2], 'Color', [.6 .6 .6], 'LineStyle', '--')
    plot(cleaning_data{p}(i2).wf'); ylim([-2 2])
    title(string(cleaning_data{p}(i2).date))
    xlabel('Sample #')

subplot(1,3,3); hold on
    x1 = median(cat(2, cleaning_data{p}(i1-5:i1+5).vmin), 2, 'omitnan');
    x2 = median(cat(2, cleaning_data{p}(i2-5:i2+5).vmin), 2, 'omitnan');
    scatter(x1, x2, 80, "filled")
    lims = prctile([x1; x2], [1, 99]);

    corr(x1, x2, 'Rows', 'complete', 'type', 'spearman');
    plot(lims, lims, 'k', 'LineStyle', '--')
    xlim(lims); ylim(lims)
    xlabel(string(cleaning_data{p}(i1).date))
    ylabel(string(cleaning_data{p}(i2).date))