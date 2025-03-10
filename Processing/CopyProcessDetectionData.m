%%% Script to copy all raw detection data to a separate folder
source_folder = 'T:\SessionData';
target_folder = 'U:\UserFolders\CharlesGreenspon\BCI_DetectionThresholds\Data';

location = 'Chicago';
subject_session = {'BCI02', 900; ...
                   'BCI03', 201; ...
                   'CRS02b', 0; ...
                   'CRS07', 0; ...
                   'CRS08', 0}; 

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

        % Process each set
        for set_idx = 1:size(OLSData,1)
            if isa(OLSData(set_idx).SDO, 'cell')
                continue
            end
            OLSData(set_idx).Channel = OLSData(set_idx).SDO(1).channel;
            OLSData(set_idx).Date = OLSData(set_idx).SDO(1).sessionInfo.date; 
            % Old
            if strcmp(OLSData(set_idx).DataType, 'DetectionData')
                OLSData(set_idx).ResponseTable = response_table;
                OLSData(set_idx).Threshold = OLSData(set_idx).SDO(end).threshold;
                OLSData(set_idx).Method = 'OldTransformedStaircase';

            % New
            elseif strcmp(OLSData(set_idx).DataType, 'DetectionV2Data')
                if ~isfield(OLSData(set_idx).SDO(1), 'DetectionParadigm') || isempty(OLSData(set_idx).SDO(1).DetectionParadigm)
                    continue
                end
                OLSData(set_idx).ResponseTable = response_table;
                OLSData(set_idx).Threshold = OLSData(set_idx).SDO(end).DetectionThreshold;
                OLSData(set_idx).Method = OLSData(set_idx).SDO(1).DetectionParadigm;
            else
                error('Invalid DataType')
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
data_added = true(size(subject_session,1),1);
if any(data_added)
    for s = 1:size(subject_session,1)
        if ~data_added(s)
            continue % Only update subjects that have new data
        end
        % Make structs
        RawDetectionData = struct('Subject', [], ...
                                  'Session', [], ...
                                  'Set', [], ...
                                  'Channel', [], ...
                                  'Date', [],...
                                  'ResponseTable', [], ...
                                  'Threshold', [], ...
                                  'Method', []);

        ProcessedDetectionData = struct('Subject', [], ...
                                        'Channel', [], ...
                                        'Dates', [], ...
                                        'Thresholds', [], ...
                                        'MeanThreshold', [],...
                                        'StdThreshold', [], ...
                                        'LastThreshold', [], ...
                                        'TestedLast90Days', []);

        subject_session_data = dir(fullfile(target_folder, subject_session{s,1}));
        subj_ols_string = sprintf('OLSData_%s', subject_session{s,1});
        % Concatenate all the data
        for i = 1:size(subject_session_data,1)
            % Ensure is OLSData_*subjectID*
            if ~contains(subject_session_data(i).name, subj_ols_string)
                continue
            end
            % Load OLS Data
            load(fullfile(target_folder, subject_session{s,1}, subject_session_data(i).name))
            % Remove extra fields
            if any(strcmp(fieldnames(OLSData), 'Paradigm'))
                OLSData = rmfield(OLSData, {'Paradigm', 'TestLogComments', 'VMData'});
            end
            % Orient structure
            if size(OLSData,2) > size(OLSData,1)
                OLSData = OLSData'; 
            end
            % Only add ones with the 'method' tag as these were formatted properly
            if any(strcmp(fieldnames(OLSData), 'Method'))
                RawDetectionData(size(RawDetectionData,1):size(RawDetectionData,1)+size(OLSData,1)-1,1) = OLSData;
            else
                warning(fullfile(target_folder, subject_session{s,1}, subject_session_data(i).name))
            end
        end
        % Remove empties
        RawDetectionData = RawDetectionData(~cellfun(@isempty, {RawDetectionData.Date}) &...
                                                    ~cellfun(@isempty, {RawDetectionData.Threshold}) &...
                                                    ~strcmp({RawDetectionData.Threshold}, 'undetermined'));
        
        % Fix floor and ceiling issues
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
                RawDetectionData(zero_idx(j)).Threshold = Inf; % Above == Inf
            end
        end
        
        % Save the raw data
        save(fullfile(target_folder, subject_session{s,1}, sprintf('DetectionDataRaw_%s.mat', subject_session{s,1})), 'RawDetectionData')
    end
end