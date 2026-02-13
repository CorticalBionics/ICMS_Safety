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

    % Check ES cables
    if contains(subjects{s}, 'CRS')
        for i = 1:size(RawDetectionData, 1)
            dn = datetime(RawDetectionData(i).Date, 'InputFormat', 'dd-MMM-uuuu');
            if dn > datetime('01-01-2024', 'InputFormat', 'dd-MM-uuuu') && dn < datetime('02-01-2026', 'InputFormat', 'dd-MM-uuuu')
                RawDetectionData(i).Channel = es_channel_flip(RawDetectionData(i).Channel);
            end
        end
    end

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
        % Correlation
        x = formatted_struct(c).DateFromImplant';
        y = formatted_struct(c).Threshold';
        n_idx = ~isnan(y) & ~isinf(y);
        if all(~n_idx) || length(y) < 5
            [formatted_struct(c).ThresholdDateCorrR, formatted_struct(c).ThresholdDateCorrP] = deal(NaN);
            formatted_struct(c).ThresholdDateLinReg = [NaN, NaN];
        else
            [formatted_struct(c).ThresholdDateCorrR, formatted_struct(c).ThresholdDateCorrP] = corr(x(n_idx), y(n_idx),...
                'Rows', 'complete', 'Type', 'Spearman');
            formatted_struct(c).ThresholdDateLinReg = polyfit(x(n_idx), y(n_idx), 1);
        end
    end
    subject_structs{s} = formatted_struct;
end
DetectionData = subject_structs;
save(fullfile(DataPath, 'DetectionData'), 'DetectionData');

%%
function chan = es_channel_flip(chan)
    % "flip" the es cable stim connector and output the equivalent channel number
    % cerestim omnetics cable pinout
    pinout = [
        01 02;
        03 04;
        05 06;
        07 08;
        09 10;
        11 12;
        13 14;
        15 16;
        17 18;
        19 20;
        21 22;
        23 24;
        25 26;
        27 28;
        29 30;
        31 32
        ];
    
    flippedpinout = rot90(pinout, 2);
    
    % find chan index and flip. Account for banks.
    bank_num = floor((chan-1)/32);
    mchan = mod(chan-1, 32) + 1;
    
    mchan = flippedpinout(find(pinout == mchan, 1));
    chan = mchan + bank_num*32;
end