%% Export cleaning data
subject_ids = {'BCI02', 'BCI03'};
output_path = fullfile(DataPath, "CleaningData");
data_path = "T:\SessionData";


%Stim Presets
num_electrodes = 64;
pulse_hw = 50;
pulse_dur = 700; % 200 cathodic, 100 inter, 400 anodic
idx_ratio = 300 / pulse_dur;

% Extraction loop
msg = '';
for s = 1:length(subject_ids)
    sub_data_path = fullfile(data_path, subject_ids{s}, 'VoltageMonitor');
    % Get list of VM folders
    flist = dir(fullfile(sub_data_path, 'VM_*'));
    for f = 1:length(flist)
    
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
            warning('No .mat file found in %s:%s\n', subject_ids{s}, flist(f).name)
            continue
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

        % Go through each trial
        for i = 1:length(VMData)
            
            % Check if Set was cleaning protocol (same channels length)
            chan_correct = length(VMData(i).Channels) == 12 || ...
                           length(VMData(i).Channels) == 11 || ...
                           sum(ismember(VMData(i).Channels, [3 32 35 64])) > 2;
            len_correct = length(VMData(i).Amplitudes{1, 1}) == 50;
    
            if ~chan_correct || ~len_correct %Check for cleaning data
                continue
            end
    
            [avg_vmax, avg_vinter, avg_vmin] = deal(NaN(num_electrodes, 1));
            waveform = cell(num_electrodes, 1);
            avg_waveform = NaN(num_electrodes,100);
    
            % Go through each ch and get waveforms and average
            for ch = 1:length(VMData(i).Channels)
                ch_idx = VMData(i).Channels(ch); %set channel
                if ch_idx == 0
                    continue
                end
                %Get all waveforms for cleaning protocol for that ch
                waveforms = VMData(i).Waveforms{ch};
                
                % Check that waveforms are all the right length
                if all(cellfun(@(x) length(x) == 100, waveforms))
          
                    % Convert into matrix (100 x 50 waveforms)
                    waveforms_mat = cell2mat(waveforms');
                    [v_min, v_max, v_inter] = deal(zeros(size(waveforms_mat, 2), 1));
                    % CALCULATE PER PULSE, THEN TAKE MEDIAN (each col is wave)
                    for w = 1:size(waveforms_mat, 2)
                        wave_temp = waveforms_mat(:,w);
        
                        % Calculate intermedite voltage
                        change_in_wave = abs(diff(wave_temp));
        
                        % Get index of v_inter
                        idx_start = find(change_in_wave(1:pulse_hw/2) < (0.01 * max(abs(wave_temp))), 1, 'last') + 1;
                        idx_stop = find(change_in_wave(end-pulse_hw:end) > (0.01 * max(abs(wave_temp))), 1, 'last') -1 + pulse_hw;
                        inter_idx = idx_start + round((idx_stop - idx_start) * idx_ratio);
        
                        if ~isempty(inter_idx) % Skip weird waveforms
                            % Save data for each waveform
                            v_min(w) = min(wave_temp);
                            v_max(w) = max(wave_temp);
                            v_inter(w) = wave_temp(inter_idx);
                        end
                    end
                
        
                    % Get averages with median
                    avg_vmin(ch_idx) = median(v_min);
                    avg_vmax(ch_idx) = median(v_max);
                    avg_vinter(ch_idx) = median(v_inter);
                    waveform{ch_idx} = waveforms_mat;
                    avg_waveform(ch_idx,:) = median(waveforms_mat, 2);
                else
                   warning('Waveform length is not 100 for file %s, trial %d, channel %d', expected_fname, i, ch);
                end
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
                if sum(VMData(i).Amplitudes{1, 1} == 10) == 50
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
    
        % Export single file for one day of data
        save(fullfile(output_path, expected_fname), "data")
    end
end


%% Combine all sessions
flist = dir(fullfile(output_path, '*.mat'));
data = cell(length(flist), 1);
num_electrodes = 64;

for f = 1:length(flist)
    temp = load(fullfile(output_path, flist(f).name));
    if isfield(temp, 'data')
        data{f} = temp.data;
    elseif isfield(temp, 'combined_data') % Process the old format dataset
        temp.data = struct('Subject', [], ...
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
        % Remove empties
        all_part = {temp.combined_data.Subject};
        empty_idx = cellfun(@isempty, all_part);
        temp.combined_data = temp.combined_data(~empty_idx);
        % Handle weird char struct
        all_part = {temp.combined_data.Subject};
        all_part = cellfun(@string, all_part, 'UniformOutput', false);
        all_part = cat(2, all_part{:});
        u_parts = unique(all_part);
        % Get dates
        all_dates = [temp.combined_data.Date];
        amp_idx = [temp.combined_data.Amp] == 10;
        for p = 1:length(u_parts)
            p_idx = strcmp(all_part, u_parts{p});
            u_dates = unique(all_dates(p_idx));
            for d = 1:length(u_dates)
                % Add to new structure
                temp.data(ii).Subject = u_parts{p};
                temp.data(ii).Date = u_dates(d);
                temp.data(ii).Amp = 10; % We're only comparing these 
                % Don't care about session/set/channels here so can leave empty

                % Format VM data
                idx = find(all_dates == u_dates(d) & p_idx & amp_idx);
                if isempty(idx)
                    continue
                end
                [temp.data(ii).vmin, temp.data(ii).vmax, temp.data(ii).vinter] = deal(NaN(num_electrodes, 1));
                temp.data(ii).waveform = cell(num_electrodes, 1);
                temp.data(ii).avg_waveform = NaN(num_electrodes, size(temp.combined_data(idx(1)).avg_waveform, 2));
                for i = 1:length(idx)
                    % Assign to above structures based on channel idx
                    ch_idx = temp.combined_data(idx(i)).channels;
                    temp.data(ii).vmin(ch_idx) = temp.combined_data(idx(i)).vmin;
                    temp.data(ii).vmax(ch_idx) = temp.combined_data(idx(i)).vmax;
                    temp.data(ii).vinter(ch_idx) = temp.combined_data(idx(i)).vinter;
                    for c = 1:length(ch_idx)
                        temp.data(ii).waveform{ch_idx(c), 1} = temp.combined_data(idx(i)).waveform{c};
                    end
                    temp.data(ii).avg_waveform(ch_idx, :) = temp.combined_data(idx(i)).avg_waveform;
                end
                ii = ii + 1;
            end
        end
        data{f} = temp.data;
    else
        error('Unsupported data')
    end
end
data = cat(2, data{:});
data = data(~cellfun(@isempty, {data.Amp})); % Remove empties
clearvars -except data
save(fullfile(DataPath, 'CleaningData_Full.mat'), 'data', '-v7.3')

return
%% Convert to participant:date format and save
u_part = unique({data.Subject});
u_part = unique(cellfun(@(c) c(1:5), u_part, 'UniformOutput', false));
subj_list = {data.Subject};
date_list = [data.Date];
amps = [data.Amp];

cleaning_data = cell(size(u_part));

for p = 1:length(u_part)
    p_idx = contains(subj_list, u_part(p));
    u_dates = unique([data(p_idx).Date]);
    for d = 1:length(u_dates)
        % Struct entry for each day
        cleaning_data{p}(d).date = u_dates(d);
        % Get matching data & only take Amp == 10 data because UC only has that for most days
        idx = p_idx & date_list == u_dates(d) & amps == 10;
        temp = data(idx);
        % Everything is already in 64x1, so just concatenate on 2nd dim and nanmean
        cleaning_data{p}(d).vmin = median(cat(2, temp.vmin), 2, 'omitnan');
        cleaning_data{p}(d).vinter = median(cat(2, temp.vinter), 2, 'omitnan');
        cleaning_data{p}(d).vmax = median(cat(2, temp.vmax), 2, 'omitnan');
        % 3rd dim for waveform
        cleaning_data{p}(d).wf = median(cat(3, temp.avg_waveform), 3, 'omitnan');
    end
end

save(fullfile(DataPath, 'CleaningData.mat'), 'cleaning_data', '-v7.3')

