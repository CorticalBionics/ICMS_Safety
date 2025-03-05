tld = 'U:\UserFolders\CharlesGreenspon\BCI_DetectionThresholds\Data';

% Get list of subjects
d = dir(tld);
subjects = {};
for i = 3:length(d)
    if d(i).isdir
        subjects{end+1} = d(i).name; %#ok<SAGROW>
    end
end

% Load raw structs and process
subject_structs = cell(length(subjects), 1);
subj_max_days = zeros(size(subject_structs));
max_days = 0;
for s = 1:length(subjects)
    fname = sprintf('DetectionDataRaw_%s.mat', subjects{s});
    load(fullfile(tld, subjects{s}, fname))

    % 100 Hz stim single electrode only
    idx = false(size(RawDetectionData));
    for i = 1:length(RawDetectionData)
        if RawDetectionData(i).ResponseTable{1, "Frequency"} == 100 && ...
           isscalar(RawDetectionData(i).Channel)
            idx(i) = true;
        end
    end
    RawDetectionData = RawDetectionData(idx);

    % Get implant date
    if startsWith(subjects{s}, 'BCI')
        subj_config = cc.load_config.participant(subjects{s}, 'chicago');
    else
        subj_config = cc.load_config.participant(subjects{s}, 'pitt');
    end
    implant_date = datetime(subj_config.implant_date, "InputFormat", "uuuu-MM-dd");

    % Format by channel
    [u_channel, ~, ic] = unique([RawDetectionData.Channel]);
    formatted_struct = struct();
    for c = 1:length(u_channel)
        formatted_struct(c).Subject = subjects{s};
        formatted_struct(c).Channel = u_channel(c);
        c_idx = ic == c;
        formatted_struct(c).Dates = cellfun(@(c) datetime(c, "InputFormat", "dd-MMM-uuuu"), {RawDetectionData(c_idx).Date});
        formatted_struct(c).Threshold = [RawDetectionData(c_idx).Threshold];
        formatted_struct(c).DateFromImplant = days(formatted_struct(c).Dates - implant_date);
    end
    subject_structs{s} = formatted_struct;

    % Check max days
    subj_max_days(s) = max(cellfun(@max, {formatted_struct.DateFromImplant}));

    % Count total detection threshold measurements
    ndt = cellfun(@length, {formatted_struct.Threshold});
    fprintf('%s: %d total DTs (%0.1f %s %0.1f)\n', ...
        subjects{s}, sum(ndt), mean(ndt), GetUnicodeChar("PlusMinus"), std(ndt))
end

clearvars -except subject_structs subj_max_days
subjects = {'C1', 'C2', 'P2', 'P3', 'P4'};
num_channels = 64;

%% Analyze
dw = 250; % Bin width in days
max_days = ceil(max(subj_max_days)/ dw) * dw; % Max days
de = 0 : dw : max_days; % Day edges
dx = de(1:end-1) + (dw/2); % Day center
t_max = 90;

[discretized_thresholds, disabled_electrodes] = deal(cell(length(subjects), 1));
for s = 1:length(subjects)
    % Format data
    % num_channels = size(subject_structs{s}, 2);
    % Date, threshold, channel
    [d, t] = deal(cell(num_channels, 1));
    enabled_channels = NaN(num_channels, length(dx));
    for i = 1:num_channels
        ch_idx = find([subject_structs{s}.Channel] == i);
        if isempty(ch_idx) % Skip untested channels
            continue
        end
        d{i} = subject_structs{s}(ch_idx).DateFromImplant;
        t{i} = subject_structs{s}(ch_idx).Threshold;
        
        % Find the last value with threshold below 'threshold'
        for j = 1:length(dx)
            if dx(j) > subj_max_days(s)
                break
            end
            idx = d{i} > de(j) & d{i} <= de(j+1);
            % If no thresholds, assume disabled
            if sum(idx) == 0
                enabled_channels(i,j) = 0;
            elseif median(t{i}(idx)) > t_max
                enabled_channels(i,j) = 0;
            else
                enabled_channels(i,j) = 1;
            end
        end
    end
    disabled_electrodes{s} = enabled_channels;

    % Vectorize
    d = cat(2, d{:});
    t = round(cat(2, t{:}));
    
    % Discretize
    dv = cell(size(dx)); % Thresholds in each bin
    for i = 1:length(dx)
        dv{i} = t(d > de(i) & d <= de(i+1));
        dv{i}(isinf(dv{i})) = NaN;
    end
    discretized_thresholds{s} = dv;
end

%% Plot
clf; 
set(gcf, 'Units', 'Inches', 'Position', [31 1 10 4])
% Detection thresholds
axes('Position', [.1 .2 .35 .7]); hold on    
    for s = 1:length(subjects)
        AlphaLine(dx, discretized_thresholds{s}, SubjectColors(subjects{s}), 'LineWidth', 2, 'IgnoreNan', 1)
    end
    
    
    % Format
    fmt = 'linear';
    if strcmpi(fmt, 'log')
        set(gca, 'XLim', [50 4000], ...
                 'YLim', [0 100], ...
                 'XScale', 'log')
    elseif strcmpi(fmt, 'linear')
        set(gca, 'XLim', [0 4000], ...
                 'YLim', [0 100], ...
                 'XScale', 'linear')
    end
    
    text(4000, 100, ColorText(subjects, SubjectColors(subjects)), ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top')
    
    ylabel(sprintf('Detection Threshold (%sA)', GetUnicodeChar('mu')))
        xlabel('Days From Implant')

% Disabled electrodes?
axes('Position', [.55 .2 .35 .7]); hold on


shg


return

%% Individual participant raster + line plots
s = 1;
h = 2; w = 2;

clf; 
set(gcf, 'Units', 'Inches', 'Position', [31 1 15 8])
annotation("textbox", [.05 .85 .1 .1], 'String', ...
    ColorText(subjects(s), SubjectColors(subjects(s))), ...
    'EdgeColor', 'none', 'FontSize', 24)

% Raster plot of threshold
subplot(h,w,1); hold on
    % Format data
    % Date, threshold, channel
    [d, t, c] = deal(cell(num_channels, 1));
    for i = 1:num_channels
        ch_idx = find([subject_structs{s}.Channel] == i);
        if isempty(ch_idx) % Skip untested channels
            continue
        end
        c{i} = repelem(subject_structs{s}(ch_idx).Channel, length(subject_structs{s}(ch_idx).Dates));
        d{i} = subject_structs{s}(ch_idx).DateFromImplant;
        t{i} = subject_structs{s}(ch_idx).Threshold;
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
    set(gca, 'YLim', [.5 num_channels+.5], 'XLim', [0 max_days])
    ylabel('Electrode')
    xlabel('Days From Implant')

% Colorbar legend 
    p = get(gca, 'Position');
    pw = 0.125;
    px = p(1) + p(3) - pw;
    py = p(2) + p(4) + 0.035;
    cb = ColorbarLegend(gcf, [px, py, pw 0.0125], cmap, 'Horz', [0 100]);


% Enabled/disabled
subplot(h,w,3);
    imagesc(dx, 1:num_channels, disabled_electrodes{s}, 'alphadata', ~isnan(disabled_electrodes{s}))
    set(gca, 'YDir', 'normal')

% Individual electrodes detection thresholds
subplot(h,w,2); hold on
    for i = 1:num_channels
        ch_idx = find([subject_structs{s}.Channel] == i);
        if isempty(ch_idx) % Skip untested channels
            continue
        end
        plot(subject_structs{s}(ch_idx).DateFromImplant, subject_structs{s}(ch_idx).Threshold, 'Color', [.6 .6 .6])
    end

    ylabel(sprintf('Detection Threshold (%sA)', GetUnicodeChar('mu')))
    xlabel('Days From Implant')


% Summary detection threshold
subplot(h,w,4); hold on
    AlphaLine(dx, discretized_thresholds{s}, SubjectColors(subjects{s}), 'LineWidth', 2, 'IgnoreNan', 1)

    ylabel(sprintf('Detection Threshold (%sA)', GetUnicodeChar('mu')))
    xlabel('Days From Implant')

shg