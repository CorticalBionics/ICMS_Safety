load(fullfile(DataPath, 'DetectionData.mat'))
[subject_list, num_subjects] = GetSubjectList();
[subject_list_alt, num_subjects] = GetSubjectList(true);

% Detection threshold summary statistics
for s = 1:num_subjects
    % Count total detection threshold measurements
    ndt = cellfun(@length, {DetectionData{s}.Threshold});
    fprintf('\n%s:\n', subject_list_alt{s})
    fprintf('Total DTs: %d\n', sum(ndt));
    fprintf('Per electrode median (range): %1.0f (%1.0f-%1.0f)\n', prctile(ndt, [50, 25, 75]));
end


%% ANOVA on ddt/day slopes
[slopes_all, g1, g2] = deal(cell(length(DetectionData), 1));
for s = 1:length(DetectionData)
    y = [DetectionData{s}.ThresholdDateLinReg];
    slopes_all{s} = y(1:2:end)'; % Alternates between slope and offest
    g1{s} = repelem(s, length(slopes_all{s}), 1);
    fprintf('%s mean DT slope = %0.2f\n', subject_list_alt{s}, median(slopes_all{s}, 'omitnan') .* 365)
end

% Format the slopes
dt_slopes = NaN(64, num_subjects);
for s = 1:num_subjects
    for i = 1:64
        ch_idx = find([DetectionData{s}.Channel] == i);
        if isempty(ch_idx) % Skip untested channels
            continue
        end
        dt_slopes(i,s) = slopes_all{s}(ch_idx);
    end
end

anova(dt_slopes)


%% Analyze detection thresholds
num_channels = 64;
t_max = 100;
dw = 250; % Bin width in days
subj_max_days = zeros(size(DetectionData));
for i = 1:length(DetectionData)
    subj_max_days(i) = max(cellfun(@max, {DetectionData{i}.DateFromImplant}));
end
max_days = ceil(max(subj_max_days)/ dw) * dw; % Max days
de = 0 : dw : max_days; % Day edges
dx = de(1:end-1) + (dw/2); % Day center
term_idx = zeros(num_subjects, 1);

[discretized_thresholds, disabled_electrodes] = deal(cell(length(subject_list_alt), 1));
for s = 1:num_subjects
    % Format data
    % num_channels = size(DetectionData{s}, 2);
    % Date, threshold, channel
    [d, t, c] = deal(cell(num_channels, 1));
    enabled_channels = NaN(num_channels, length(dx));
    for i = 1:num_channels
        ch_idx = find([DetectionData{s}.Channel] == i);
        if isempty(ch_idx) % Skip untested channels
            continue
        end
        d{i} = DetectionData{s}(ch_idx).DateFromImplant;
        t{i} = DetectionData{s}(ch_idx).Threshold;
        c{i} = repelem(i, length(t{i}));
        
        % Find threshold for each bin
        for j = 1:length(dx)
            if dx(j) > subj_max_days(s)
                break
            end
            idx = d{i} > de(j) & d{i} <= de(j+1);
            % If no thresholds, assume disabled
            if sum(idx) == 0
                enabled_channels(i,j) = NaN;
            elseif median(t{i}(idx)) > t_max
                enabled_channels(i,j) = 0;
            else
                enabled_channels(i,j) = 1;
            end
        end
    end
    
    % Fill missing values if a threshold was missed
    enabled_channels = fillmissing(enabled_channels, "linear", 2, "MaxGap", 3);
    enabled_channels(isnan(enabled_channels)) = 0;
    enabled_channels = enabled_channels == 1;
    disabled_electrodes{s} = enabled_channels;
    % Remove trailing 0s
    term_idx(s) = find(mean(enabled_channels, 1) > 0.1, 1, 'last'); % Haven't tested enough electrodes to know...

    % Vectorize
    d = cat(2, d{:});
    t = round(cat(2, t{:}));
    c = cat(2, c{:});

    % Sort and find time to first sensation
    [~, sort_idx] = sort(d);
    d = d(sort_idx);
    t = t(sort_idx);
    c = c(sort_idx);
    ttfs_idx = find(~isnan(t) & ~isinf(t) & t < t_max, 1, 'first');
    fprintf('%s\n', subject_list_alt{s})
    fprintf('\tTime to first sensation: %d\n', d(ttfs_idx))
    
    % Discretize
    dv = NaN(num_channels, length(dx)); % Thresholds in each bin
    for i = 1:term_idx(s)
        for ch = 1:num_channels
            d_idx = d > de(i) & d <= de(i+1); % Matching date range
            ch_idx = c == ch; % Matching channel
            idx = d_idx & ch_idx; % Both
            if ~any(idx)
                continue
            end
            dv(ch,i) = median(t(idx));
        end
    end
    % Remove infs
    dv(isinf(dv)) = NaN;
    discretized_thresholds{s} = dv;
end

%% Make struct and export
DetectionAnalysis = struct();
DetectionAnalysis.discretized_thresholds = discretized_thresholds;
DetectionAnalysis.x = dx;
DetectionAnalysis.term_idx = term_idx;
DetectionAnalysis.disabled_electrodes = disabled_electrodes;
DetectionAnalysis.dt_slopes = dt_slopes;

% Export the data
save(fullfile(DataPath, 'DT_Analysis'), "DetectionAnalysis")