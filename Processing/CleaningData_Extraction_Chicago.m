%% Export cleaning data
subject_ids = {'BCI02', 'BCI03', 'CRS02b', 'CRS07', 'CRS08'};
output_path = fullfile(DataPath, "CleaningData");
data_path = "T:\SessionData";

%Stim Presets
num_electrodes = 64;
pulse_dur = 700; % 200 cathodic, 100 inter, 400 anodic
idx_ratio = 300 / pulse_dur;

% Extraction loop
for s = 1:length(subject_ids)
    msg = subject_ids{s};
    disp(msg)
    sub_data_path = fullfile(data_path, subject_ids{s}, 'VoltageMonitor');
    
    % Get list of VM folders/files
    if startsWith(subject_ids{s}, 'BCI')
        flist = dir(fullfile(sub_data_path, 'VM_*'));
    elseif startsWith(subject_ids{s}, 'CRS')
        flist = dir(sub_data_path);
    end
    
    % Loop through the files
    for f = 1:length(flist)
        if startsWith(subject_ids{s}, 'BCI')
            % Try to find mat file and get date
            expected_fname = sprintf('%s_%s.mat', subject_ids{s}, flist(f).name);
        
            if isfile(fullfile(output_path, expected_fname)) % Skip if it already has been done
                continue
            elseif isfile(fullfile(sub_data_path, flist(f).name, expected_fname))
                dn = datetime(flist(f).name(4:end), 'InputFormat', 'uuuu_MM_dd');
                %Print loading file
                msg = InlineProgressBar('Loading %d/%d', [f,length(flist)], msg);
                load(fullfile(sub_data_path, flist(f).name, expected_fname));
            else
                msg = sprintf('No .mat file found in %s:%s', subject_ids{s}, flist(f).name);
                disp(msg)
                continue
            end

        elseif startsWith(subject_ids{s}, 'CRS')
            if flist(f).isdir
                continue
            end
            if contains(flist(f).name, 'motor')
                continue % These don't contain any cleaning
            else
                dn = datetime(flist(f).name(end-13:end-4), 'InputFormat', 'MM_dd_uuuu');
                expected_fname = sprintf('%s_VM_%s.mat', subject_ids{s}, datetime(dn, 'format', 'uuuu_MM_dd'));
            end
            % Skip if exists
            if isfile(fullfile(output_path, expected_fname)) % Skip if it already has been done
                continue
            end
            % Load the already formatted .mat file
            load(fullfile(sub_data_path, flist(f).name));
        end

        % Create data structure for day
        data = struct('Subject', [], ...
                      'Date', [], ...
                      'Session', [], ...
                      'Set', [], ...
                      'channels', [], ...
                      'vmin', [], ...
                      'vmax', [], ...
                      'vinter', [], ...
                      'waveform', [], ...
                      'Amp', [], ...
                      'avg_waveform', []);
        ii = 1;

        % Go through each row of VMData
        for i = 1:length(VMData)
            if ~contains(VMData(i).SessionType, 'OpenLoop')
                continue
            end

            % len_correct = length(VMData(i).Amplitudes{1, 1}) == 50;
            amp_correct = all(cat(1, VMData(i).Amplitudes{:}) == 10);
    
            if ~amp_correct %Check for cleaning data
                continue
            end
    
            [avg_vmax, avg_vinter, avg_vmin] = deal(NaN(num_electrodes, 1));
            [waveform, avg_waveform] = deal(cell(num_electrodes, 1));
    
            % Go through each ch and get waveforms and average
            for ch = 1:length(VMData(i).Channels)
                ch_idx = VMData(i).Channels(ch); %set channel
                if ch_idx == 0
                    continue
                end
                %Get all waveforms for cleaning protocol for that ch
                waveforms = VMData(i).Waveforms{ch};
                
                % Check that waveforms are all the right length
                if isnumeric(waveforms) && size(waveforms, 1) == 160
                    pulse_hw = 80; % Old format
                elseif iscell(waveforms) && all(cellfun(@(x) length(x) == 100, waveforms))
                    waveforms = cell2mat(waveforms');
                    pulse_hw = 50; % New format
                elseif iscell(waveforms) && all(cellfun(@(x) length(x) == 150, waveforms))
                    waveforms = cell2mat(waveforms');
                    pulse_hw = 35; % One off?
                else
                   warning('Error parsing file %s, row %d, channel %d', expected_fname, i, ch);
                   continue
                end
          
                    
                [v_min, v_max, v_inter] = deal(zeros(size(waveforms, 2), 1));
                % CALCULATE PER PULSE, THEN TAKE MEDIAN (each col is wave)
                for w = 1:size(waveforms, 2)
                    wave_temp = waveforms(:,w);
    
                    % Calculate intermedite voltage
                    change_in_wave = abs(diff(wave_temp));
    
                    % Get index of v_inter
                    idx_start = find(change_in_wave(1:floor(pulse_hw/2)) < (0.01 * max(abs(wave_temp))), 1, 'last') + 1;
                    idx_stop = find(change_in_wave(end-pulse_hw:end) > (0.01 * max(abs(wave_temp))), 1, 'last') -1 + pulse_hw;
                    if isempty(idx_stop) % Backup method
                        idx_stop = find(change_in_wave(idx_start + pulse_hw:end) > ...
                            (0.01 * max(abs(wave_temp))), 1, 'last') -1;
                        idx_stop = idx_stop + idx_start + pulse_hw;
                    end
                    inter_idx = idx_start + floor((idx_stop - idx_start) * idx_ratio) - 1;
    
                    if ~isempty(inter_idx) % Skip weird waveforms
                        % Save data for each waveform
                        v_min(w) = min(wave_temp);
                        v_max(w) = max(wave_temp);
                        v_inter(w) = wave_temp(inter_idx);
                    end
                end

                if all(isnan(v_inter))
                    warning('No voltages detected %s, trial %d, channel %d', expected_fname, i, ch);
                    continue
                end

    
                % Get averages with median
                avg_vmin(ch_idx) = median(v_min);
                avg_vmax(ch_idx) = median(v_max);
                avg_vinter(ch_idx) = median(v_inter);
                waveform{ch_idx} = waveforms;
                avg_waveform{ch_idx} = median(waveforms, 2);
            end
    
            % Format data
            temp = struct();
            temp.Subject = VMData(i).SubjectID;
            temp.Date = dn;
            temp.Session = VMData(i).SessionNum;
            temp.Set = VMData(i).Set;
            temp.channels = VMData(i).Channels;
            temp.vmin = avg_vmin;
            temp.vmax = avg_vmax;
            temp.vinter = avg_vinter;
            temp.waveform = waveform;
            temp.avg_waveform = avg_waveform;
            if all(VMData(i).Amplitudes{1, 1} == 0) %Remove sets with 0 amplitudes
                warning('Amplitude was all zeros for %s, session %d, set %d', VMData(i).SubjectID, VMData(i).SessionNum, VMData(i).Set);
                continue
            else
                if all(VMData(i).Amplitudes{1, 1} == 10)
                    temp.Amp = 10;
                elseif all(VMData(i).Amplitudes{1, 1} == 20)
                    temp.Amp = 20;
                else
                    continue
                end
    
                % Add to data struct
                data(ii) = temp;
                ii = ii + 1;
            end
        end
    
        % Skip empty data
        if isempty(data(1).Subject)
            continue
        end
        % Export single file for one day of data
        save(fullfile(output_path, expected_fname), "data")
    end
end


%% Convert to participant:date format and save
clearvars -except output_path subject_ids num_electrodes
disp('Consolidating')

u_part = unique(cellfun(@(c) c(1:5), subject_ids, 'UniformOutput', false));
cleaning_data = cell(size(u_part));
flist = dir(fullfile(output_path, '*.mat'));
flist = {flist.name};

for p = 1:length(u_part)
    disp(u_part(p))
    % Filter files by participant
    p_idx = find(contains(flist, u_part{p}));
    % Load data for each subject
    temp_data = cell(size(p_idx));
    for d = 1:length(p_idx)
        temp = load(fullfile(output_path, flist{p_idx(d)}));
        if isfield(temp, 'data')
            if isempty(temp.data(1).Subject)
                continue
            end
            temp_data{d} = temp.data;
        else
            error('Unsupported data')
        end
    end
    temp_data = cat(2, temp_data{:});

    % Check for ES cable flip
    if contains(u_part{p}, 'CRS')
        for i = 1:size(temp_data, 2)
            dn = datetime(temp_data(i).Date, 'InputFormat', 'dd-MMM-uuuu');
            if dn > datetime('01-01-2024', 'InputFormat', 'dd-MM-uuuu') && dn < datetime('02-01-2026', 'InputFormat', 'dd-MM-uuuu')
                new_channels = zeros(size(temp_data(i).channels));
                for c = 1:length(temp_data(i).channels)
                    new_channels(c) = es_channel_flip(temp_data(i).channels(c));
                end
                % Update channels and indices for each one
                old_idx = temp_data(i).channels;
                [new_vmin, new_vmax, new_vinter] = deal(NaN(num_electrodes, 1));
                new_vmin(new_channels) = temp_data(i).vmin(old_idx);
                new_vmax(new_channels) = temp_data(i).vmax(old_idx);
                new_vinter(new_channels) = temp_data(i).vinter(old_idx);
                new_wvf = cell(num_electrodes,1);
                new_wvf(new_channels) = temp_data(i).waveform(old_idx);

                % Overwrite
                temp_data(i).channels = new_channels;
                temp_data(i).vmin = new_vmin;
                temp_data(i).vmax = new_vmax;
                temp_data(i).vinter = new_vinter;
                temp_data(i).waveform = new_wvf;
            end
        end
    end

    % Combine values within day
    date_list = [temp_data.Date];
    amp_list = [temp_data.Amp];
    u_dates = unique(date_list);
    for d = 1:length(u_dates)
        % Struct entry for each day
        cleaning_data{p}(d).date = u_dates(d);
        % Get matching data & only take Amp == 10 data because UC only has that for most days
        idx = date_list == u_dates(d) & amp_list == 10;
        temp = temp_data(idx);
        % Remove sham stimuli
        idx = true(size(temp));
        for i = 1:size(temp, 2)
            if any(temp(i).channels > 64)
                idx(i) = false;
            end
        end
        temp = temp(idx);

        % Everything is already in 64x1, so just concatenate on 2nd dim and nanmean
        cleaning_data{p}(d).vmin = median(cat(2, temp.vmin), 2, 'omitnan');
        cleaning_data{p}(d).vinter = median(cat(2, temp.vinter), 2, 'omitnan');
        cleaning_data{p}(d).vmax = median(cat(2, temp.vmax), 2, 'omitnan');
        % 3rd dim for waveform
        try
            cleaning_data{p}(d).wf = median(cat(3, temp.avg_waveform), 3, 'omitnan');
        catch
            wf = cat(2, temp.avg_waveform);
            jdx = find(cellfun(@(c) ~isempty(c), wf(:)), 1);
            s = size(wf{jdx});
            wf2 = cell(64,1);
            for i = 1:64
                wf2{i} = cat(2, wf{i,:});
                if isempty(wf2{i})
                    wf2{i} = NaN(s);
                end
            end
            cleaning_data{p}(d).wf = cat(2, wf2{:});
        end
    end
end

save(fullfile(DataPath, 'CleaningData.mat'), 'cleaning_data', '-v7.3')
