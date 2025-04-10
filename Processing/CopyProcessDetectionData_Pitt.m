%%% Script to copy all raw detection data to a separate folder
source_folder = 'P:\data_raw\human\crs_array';
target_folder = 'P:\users\tgh28\DetectionThresholdData';
location = 'Pitt';
subject_session = {'CRS02b', 0;...
                   'CRS07', 0; ...
                   'CRS08', 0}; 

%subject_session = {'CRS08', 0}; 

response_table_format = [["Trial", "double"]; ...
                         ["Amplitude", "double"]; ...
                         ["Frequency", "double"]; ...
                         ["Duration", "double"]; ...
                         ["SelectedInt", "double"]; ...
                         ["Correct", "logical"]];
data_added = false(size(subject_session,1),1);

for s = 1:size(subject_session,1)
    subject_id = subject_session{s,1};
    fprintf('%s\n', subject_id)
    ols_folder = fullfile(source_folder, subject_id, 'OpenLoopStim');
    % Filter by session num
    ols_session_list = dir(ols_folder);
    session_folders = {ols_session_list.name};
    session_folders = session_folders(contains(session_folders, subject_id));
    ses_idx = false(size(session_folders));
    for i = 1:length(session_folders)
        fsplit = strsplit(session_folders{i}, '.');
        ses_num = str2double(fsplit{end});
        if ses_num >= subject_session{s,2}
            ses_idx(i) = true;
        end
    end
    ses_idx = find(ses_idx);
    for ses = 1:length(ses_idx)
        fprintf(' - %d of %d: %s\n', ses, length(ses_idx), session_folders{ses_idx(ses)})
        % Check that the folder is a data folder
        if strcmpi(location, 'Pitt')
            if ~contains(session_folders{ses_idx(ses)}, sprintf('%sHome.data', subject_id)) && ...
                 ~contains(session_folders{ses_idx(ses)}, sprintf('%sLab.data', subject_id))   
                continue
            end
        elseif strcmpi(location, 'Chicago')
            if ~contains(session_folders{ses_idx(ses)}, sprintf('%s.data', subject_id))
                continue
            end
        end
        
        % Workout what the filename should be
        fname_split = strsplit(session_folders{ses_idx(ses)}, '.');
        fname = sprintf('OLSData_%s_%s', fname_split{1}, fname_split{3});
        % Check if it's already copied
        if exist(fullfile(target_folder, subject_id, [fname, '.mat']), 'file') == 2
            continue
        end

        % Load the data
        OLSData = LoadOLSData(fullfile(ols_folder, session_folders{ses_idx(ses)}), 'UseJSON', true); % JSONs tend to be smaller
        if isempty(OLSData)
            continue % Skip empty session folders
        end
        dt_idx = contains({OLSData.DataType}, 'Detection'); % detectionData & DetectionV2Data
        if ~any(dt_idx)
            continue % Skip sessions with no detection data
        end
        OLSData = OLSData(dt_idx);

        % Make trial table
        for set = 1:size(OLSData,1)
            if isa(OLSData(set).SDO, 'cell')
                continue
            end
            if ~all(contains({OLSData(set).SDO.trialType}, 'Detection'))
                continue
            end
            OLSData(set).Channel = OLSData(set).SDO(1).channel;
            if isfield(OLSData(set).SDO(1).sessionInfo, 'date') % Because Pitt hates me
                OLSData(set).Date = OLSData(set).SDO(1).sessionInfo.date;
            else
                OLSData(set).Date = 'Null';
            end
            response_table = table('Size',[size(OLSData(set).SDO,1), size(response_table_format,1)],... 
                                   'VariableNames', response_table_format(:,1),...
                                   'VariableTypes', response_table_format(:,2));
            % Table when using old detection tab
            if strcmp(OLSData(set).DataType, 'DetectionData')
                for t = 1:size(OLSData(set).SDO,1)
                    response_table{t, "Trial"} = t;
                    response_table{t, "Amplitude"} = OLSData(set).SDO(t).amplitude;
                    response_table{t, "Frequency"} = OLSData(set).SDO(t).frequency;
                    response_table{t, "Duration"} = OLSData(set).SDO(t).duration;
                    if isempty(OLSData(set).SDO(t).reportedData.stimulusInterval)
                        response_table{t, "SelectedInt"} = NaN;
                    else
                        response_table{t, "SelectedInt"} = OLSData(set).SDO(t).reportedData.stimulusInterval;
                        response_table{t, "Correct"} = OLSData(set).SDO(t).success;
                    end
                end
                OLSData(set).ResponseTable = response_table;
                OLSData(set).Threshold = OLSData(set).SDO(end).threshold;
                OLSData(set).Method = 'OldTransformedStaircase';

            % Table when using new detection tab
            elseif strcmp(OLSData(set).DataType, 'DetectionV2Data')
                if isempty(OLSData(set).SDO(1).DetectionParadigm)
                    continue
                end
                for t = 1:size(OLSData(set).SDO,1)
                    response_table{t, "Trial"} = t;
                    response_table{t, "Amplitude"} = OLSData(set).SDO(t).amplitude;
                    response_table{t, "Frequency"} = OLSData(set).SDO(t).frequency;
                    response_table{t, "Duration"} = OLSData(set).SDO(t).duration;
                    if ~isfield(OLSData(set).SDO(t).reportedData, 'value')
                        response_table{t, "SelectedInt"} = NaN;
                    else
                        response_table{t, "SelectedInt"} = OLSData(set).SDO(t).reportedData.value;
                        response_table{t, "Correct"} = OLSData(set).SDO(t).DetectionLogit;
                    end
                end
                OLSData(set).ResponseTable = response_table;
                OLSData(set).Threshold = OLSData(set).SDO(end).DetectionThreshold;
                OLSData(set).Method = OLSData(set).SDO(1).DetectionParadigm;
            end
        end
        OLSData = rmfield(OLSData, {'SDO', 'DataType'});
      
        % Copy the OLSData file with only the detection data
        fprintf(' * Copying %s\n', fname)
        save(fullfile(target_folder, subject_id, [fname, '.mat']), 'OLSData') %.mat

        data_added(s) = true;
    end
end
%%
if any(data_added)
    todays_date = datenum(datetime('today'));
    for s = 1:size(subject_session,1)
        if ~data_added(s)
            continue % Only update subjects that have new data
        end
        % Make structs
        RawDetectionData = struct('Subject', [], 'Session', [], 'Set', [], 'Channel', [], 'Date', [],...
                                      'ResponseTable', [], 'Threshold', [], 'Method', []);
        ProcessedDetectionData = struct('Subject', [], 'Channel', [], 'Dates', [], 'Thresholds', [], 'MeanThreshold', [],...
                               'StdThreshold', [], 'LastThreshold', [], 'TestedLast90Days', []);
        subject_session_data = dir(fullfile(target_folder, subject_session{s,1}));
        subj_ols_string = sprintf('OLSData_%s', subject_session{s,1});
        % Concatenate all the data
        for i = 1:size(subject_session_data,1)
            % Ensure is OLSData_*subjectID*
            if ~contains(subject_session_data(i).name, subj_ols_string)
                continue
            end
            % Will load OLS Data
            load(fullfile(target_folder, subject_session{s,1}, subject_session_data(i).name))
            if ~isfield(OLSData, 'Method') % Empty sessions that were copied
                continue
            end
            RawDetectionData(size(RawDetectionData,1):size(RawDetectionData,1)+length(OLSData)-1,1) = OLSData;
        end
        % Remove empties
        RawDetectionData = RawDetectionData(~cellfun(@isempty, {RawDetectionData.Date}) &...
                                                    ~cellfun(@isempty, {RawDetectionData.Threshold}) &...
                                                    ~strcmp({RawDetectionData.Threshold}, 'undetermined'));
        % Fix floor and ceiling errors
        char_idx = cellfun(@ischar, {RawDetectionData.Threshold});
        lesser_idx = contains({RawDetectionData(char_idx).Threshold}, '<');
        if any(lesser_idx)
            zero_idx = find(char_idx);
            zero_idx = zero_idx(lesser_idx);
            for j = 1:length(zero_idx)
                RawDetectionData(zero_idx(j)).Threshold = 0;
            end
        end
        char_idx = cellfun(@ischar, {RawDetectionData.Threshold});
        greater_idx = contains({RawDetectionData(char_idx).Threshold}, '>');
        if any(greater_idx)
            zero_idx = find(char_idx);
            zero_idx = zero_idx(greater_idx);
            for j = 1:length(zero_idx)
                RawDetectionData(zero_idx(j)).Threshold = 100;
            end
        end
        
        % Save the raw data
        save(fullfile(target_folder, subject_session{s,1}, sprintf('DetectionDataRaw_%s.mat', subject_session{s,1})), 'RawDetectionData')

        % Process it by channel
        u_channels = unique([RawDetectionData.Channel]);
        for c = 1:length(u_channels)
            channel_idx = find([RawDetectionData.Channel] == u_channels(c) & ...
                               ~cellfun(@isempty, {RawDetectionData.Date}) & ...
                               ~cellfun(@(c) strcmp(c, 'Null'), {RawDetectionData.Date}));
            % This should already be sorted but just in case
            [dates, sort_idx] = sort(cellfun(@datenum, {RawDetectionData(channel_idx).Date}, 'UniformOutput', true)); 
            channel_idx_sorted = channel_idx(sort_idx);
            % Assign to struct
            ProcessedDetectionData(c).Subject = subject_session{s,1};
            ProcessedDetectionData(c).Channel = u_channels(c);
            ProcessedDetectionData(c).Dates = {RawDetectionData(channel_idx_sorted).Date};
            ProcessedDetectionData(c).Thresholds = [RawDetectionData(channel_idx_sorted).Threshold];
            ProcessedDetectionData(c).MeanThreshold = mean(ProcessedDetectionData(c).Thresholds);
            ProcessedDetectionData(c).StdThreshold = std(ProcessedDetectionData(c).Thresholds);
            ProcessedDetectionData(c).LastThreshold = ProcessedDetectionData(c).Thresholds(end);
            if todays_date - dates(end) < 90
                ProcessedDetectionData(c).TestedLast90Days = true;
            else
                ProcessedDetectionData(c).TestedLast90Days = false;
            end
        end

        % Save the processed data
        save(fullfile(target_folder, subject_session{s,1}, sprintf('DetectionDataProcessed_%s.mat', subject_session{s,1})), 'ProcessedDetectionData')
    end
end



