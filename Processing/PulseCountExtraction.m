% Count the number of pulses
num_electrodes = 64;
data_path = cc.load_config.system('backup_path');
output_path = fullfile(DataPath, "VM_Info");
subject_ids = {'BCI02', 'BCI03'};
temp = table('Size', [1, 8], ...
    'VariableNames', {'Subject', 'Date', 'PulseCount', 'CurrentCount', 'Duration', 'NumSingleElec', 'NumMultiElec', 'Waveforms'}, ...
    'VariableTypes', ["string", "datetime", "cell", "cell", "double", "double", "double", "cell"]);
override = false;

for s = 1:length(subject_ids)
    elec_map = cc.analysis.load_participant_electrode_map(subject_ids{s});

    % Get contents of voltage monitor directory
    vm_path = fullfile(data_path, subject_ids{s}, 'VoltageMonitor');
    flist = dir(fullfile(vm_path, 'VM*'));
    
    msg = '';
    for f = 1:length(flist)
        msg = InlineProgressBar('Loading %d/%d', [f,length(flist)], msg);

        % Skip anything that isn't a subfolder
        if ~flist(f).isdir
            continue
        end

        % Try to find mat file and get date
        expected_fname = sprintf('%s_%s.mat', subject_ids{s}, flist(f).name);
        expected_ffname = fullfile(vm_path, flist(f).name, expected_fname);
        if isfile(fullfile(output_path, expected_fname)) & ~override
            continue
        elseif isfile(expected_ffname)
            fsplit = strsplit(flist(f).name, '_');
            dn = datetime([str2double(fsplit{2}), str2double(fsplit{3}), str2double(fsplit{4})]);
            load(expected_ffname);
        else
            warning('No .mat file found in %s\n', flist(f).name)
            msg = '';
            continue
        end


        % create vector for number of pulses and total amplitude
        [num_pulses, total_current] = deal(zeros(num_electrodes, 1));
        total_duration = zeros(length(VMData), 1);
        ch_waveforms = cell(num_electrodes, 1);
        
        % Running count
        for i = 1:length(VMData)

            for c = 1:length(VMData(i).Channels)
                % Sometimes motor exec sends fake pulses
                if (strcmpi(VMData(i).SessionType, 'MotorExperiments') && VMData(i).Channels(c) > num_electrodes) || ...
                        VMData(i).Channels(c) == 0 
                    continue
                end
                
                c_idx = VMData(i).Channels(c);
                % Check channel counting
                if c_idx > 64 % We changed from reporting cerestim output to absolute electrode number
                    c_idx = br2vm(c_idx, elec_map);
                end
                
                num_pulses(c_idx) = num_pulses(c_idx) + sum(VMData(i).Amplitudes{c} > 0);
                total_current(c_idx) = total_current(c_idx) + sum(VMData(i).Amplitudes{c});
            end
            
            timestamps = sort(cat(1, VMData(i).Timestamps{:}));
            if any(diff(timestamps > 0.2)) % Anything below 5 Hz stimulation
                dt_idx = find(diff(timestamps) > 0.2);
                dt_idx = [0; dt_idx; length(timestamps)]; % Pad with first and last index
                td = 0;
                for j = 1:length(dt_idx) - 1
                    td = td + (timestamps(dt_idx(j+1)) - timestamps(dt_idx(j)+1)); % +1 so we don't count the gap itself
                end
                total_duration(i) = td;
            else
                total_duration(i) = timestamps(end) - timestamps(1);
            end
            
        end

        % Store data in table
        data = temp;
        data{1, "Subject"} = subject_ids(s);
        data{1, "Date"} = dn;
        data{1, "PulseCount"} = {num_pulses};
        data{1, "CurrentCount"} = {total_current};
        data{1, "Duration"} = sum(total_duration);
        data{1, "NumSingleElec"} = sum(cellfun(@length, {VMData.Channels}) == 1);
        data{1, "NumMultiElec"} = sum(cellfun(@length, {VMData.Channels}) > 1);
        data{1, "Waveforms"} = {ch_waveforms};
        
        % Export
        save(fullfile(output_path, expected_fname), "data")
    end
end

%% Combine data
flist = dir(fullfile(output_path, '*.mat'));
data = cell(length(flist), 1);

for f = 1:length(flist)
    temp = load(fullfile(output_path, flist(f).name));
    % Fix dates if not logged properly
    if isnat(temp.data.Date)
        fsplit = strsplit(flist(f).name, '_');
        if contains(fsplit{end}, 'motor')
            temp.data.Date = datetime([fsplit{5}, fsplit{3}, fsplit{4}], 'InputFormat', 'yyyyMMdd');
        else
            temp.data.Date = datetime([fsplit{5}(1:end-4), fsplit{3}, fsplit{4}], 'InputFormat', 'yyyyMMdd');
        end
    end
    
    % Remove lab/home
    if length(temp.data.Subject{1}) > 5
        temp.data.Subject{1} = temp.data.Subject{1}(1:5);
    end
    
    % Remove waveforms because we don't care for this
    data{f} = temp.data;
    if any(strcmp(data{f}.Properties.VariableNames, 'Waveforms'))
        data{f}.Waveforms = [];
    end
end

subject_ids = {'BCI02', 'BCI03', 'CRS02', 'CRS07', 'CRS08'};

% Export
VMData = cat(1, data{:});
total_charge = zeros(length(subject_ids), 64);
conversion_factor = 1e6;
% Filter VM data by participant
for pi = 1:length(subject_ids)
    s_idx = strcmp(VMData.Subject, subject_ids(pi));
    total_current = cat(2, VMData.CurrentCount{s_idx});
    all_charge = total_current .*  0.2 ./ conversion_factor; % Convert to charge in mC
    total_charge(pi, :) = sum(all_charge, 2, 'omitnan');
end

save(fullfile(DataPath, 'VMData_All'), "VMData", "total_charge")

%% Helper function to convert new channel ids to old
function elec = br2vm(elec, elec_map)
    if ismember(elec, elec_map.lateral_sensory.locations)
        elec = elec_map.lateral_sensory.numbers(elec_map.lateral_sensory.locations == elec);
    elseif ismember(elec, elec_map.medial_sensory.locations)
        elec = elec_map.medial_sensory.numbers(elec_map.medial_sensory.locations == elec);
    end
end