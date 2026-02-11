% Count the number of pulses
num_electrodes = 64;
data_path = "P:\users\tgh28\Experiments\Longitudinal_ICMS\vm_data_combined";
% data_path = "P:\users\tgh28\Experiments\Longitudinal_ICMS\vm_data_oldMotor";
output_path = "P:\users\tgh28\Experiments\Longitudinal_ICMS\vm_out4";
temp = table('Size', [1, 8], ...
    'VariableNames', {'Subject', 'Date', 'PulseCount', 'CurrentCount', 'Duration', 'NumSingleElec', 'NumMultiElec', 'Waveforms'}, ...
    'VariableTypes', ["string", "datetime", "cell", "cell", "double", "double", "double", "cell"]);
override = false;
flist = dir(fullfile(data_path, '*.mat'));
msg = '';
for f = 1:length(flist)
    msg = InlineProgressBar('Loading %d/%d', [f,length(flist)], msg);

    % Try to find mat file and get date
    expected_fname = flist(f).name;
    if isfile(fullfile(output_path, expected_fname)) & ~override
        continue
    elseif isfile(fullfile(data_path, expected_fname))
        fsplit = strsplit(flist(f).name, '_');
        load(fullfile(data_path, expected_fname));
    else
        warning('No .mat file found in %s', flist(f).name)
        continue
    end
    
    % Parse the date
    if strcmp(fsplit{2}, 'session')
        dn = datetime([fsplit{3}, fsplit{4}, fsplit{5}(1:4)], 'InputFormat', 'MMdduuuu');
    else
        dn = datetime([str2double(fsplit{2}), str2double(fsplit{3}), str2double(fsplit{4})]);
    end
    if isnat(dn)
        error('Could not parse date')
    end

    % Check the participant ID and load the elec map
    if contains(fsplit{1}, 'CRS02')
        elec_map = cc.analysis.load_participant_electrode_map(fsplit{1}(1:6));
    else
        elec_map = cc.analysis.load_participant_electrode_map(fsplit{1}(1:5));
    end

    % create vector for number of pulses and total amplitude
    [num_pulses, total_current] = deal(zeros(num_electrodes, 1));
    total_duration = zeros(length(VMData), 1);
    ch_waveforms = cell(num_electrodes, 1);

    % Check if ES cable switch
    if dn > datetime('01-01-2024', 'InputFormat', 'dd-MM-uuuu') && dn < datetime('02-01-2026', 'InputFormat', 'dd-MM-uuuu')
        es_flip = true;
    else
        es_flip = false;
    end
    
    % Running count
    for i = 1:length(VMData)
        for c = 1:length(VMData(i).Channels)
            % Sometimes motor exec sends fake pulses
            if (strcmpi(VMData(i).SessionType, 'MotorExperiments') && VMData(i).Channels(c) > num_electrodes) || ...
               (strcmpi(VMData(i).SessionType, 'Experiments') && VMData(i).Channels(c) > num_electrodes) || ...
                        VMData(i).Channels(c) == 0
                continue
            end

            % Check channel counting
            c_idx = VMData(i).Channels(c);
            if es_flip
                c_idx = es_channel_flip(c_idx);
            end
            if c_idx > num_electrodes % We changed from reporting cerestim output to absolute electrode number
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
    data{1, "Subject"} = fsplit(1);
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


%% Helper function to convert new channel ids to old
function elec = br2vm(elec, elec_map)
    if ismember(elec, elec_map.lateral_sensory.locations)
        elec = elec_map.lateral_sensory.numbers(elec_map.lateral_sensory.locations == elec);
    elseif ismember(elec, elec_map.medial_sensory.locations)
        elec = elec_map.medial_sensory.numbers(elec_map.medial_sensory.locations == elec);
    end
end

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