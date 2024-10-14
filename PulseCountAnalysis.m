% Pulse count analysis
tld = fullfile(DataPath(), 'VM_Info');
load(fullfile(tld, 'VMData_All.mat'))

%%
subject_id = 'BCI02';
s_idx = strcmp(data.Subject, subject_id);
total_pulses = cat(2, data.PulseCount{s_idx});
total_pulses(total_pulses == 0) = NaN;
sum_pulses = sum(total_pulses, 2, 'omitnan');
fprintf('Total pulses delivered: %d\n', sum(total_pulses, 'all', 'omitnan'))
fprintf('Mean pulses per session: %d\n', round(sum(total_pulses, 'all', 'omitnan') / sum(s_idx)))
fprintf('Pulses per electrode (mean, 25, 75): %d, (%d, %d)\n', round(prctile(sum_pulses, [50, 25, 75])))

clf; set(gcf, 'Units', 'Inches', 'Position', [3, 3, 5, 5])
xw = 0.6; yh = 0.5;
bdr = 0.13;
axes('Position', [bdr bdr xw yh]);
    imagesc(total_pulses)
    set(gca, 'YTick', [1,32, 64], 'CLim', [0 1e4])
    ylabel('Electrode')
    xlabel('Session Number')
    colormap bone

axes('Position', [bdr bdr+yh+0.025 xw .2]); hold on
    AlphaLine(1:size(total_pulses, 1), total_pulses, [0,0,0], ...
        'IgnoreNaN', 1, 'ErrorType', 'SEM')
    set(gca, 'YScale', 'log', 'XTick', [])
    ylabel('Num Pulses')

axes('Position', [bdr+xw+0.025 bdr .2 yh]); hold on
    stp = sum(total_pulses, 2, 'omitnan');
    for c = 1:size(total_pulses, 1)
        x = [.1, stp(c), stp(c), .1];
        y = [c-0.5, c-0.5, c+0.5, c+0.5];
        patch(x,y,[.6 .6 .6])
    end
    set(gca, 'YDir', 'reverse', 'YTick', [], 'YLim', [-.5 64.5])
    % xlabel('Total Pulses')
shg