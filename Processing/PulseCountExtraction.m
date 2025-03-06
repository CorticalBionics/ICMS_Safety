% Count the number of pulses
num_electrodes = 64;
data_path = "T:\SessionData";
output_path = fullfile(DataPath, "VM_Info");
subject_ids = {'BCI02', 'BCI03'};
temp = table('Size', [1, 4], ...
    'VariableNames', {'Subject', 'Date', 'PulseCount', 'CurrentCount', 'Waveforms'}, ...
    'VariableTypes', ["string", "datetime", "cell", "cell"]);
for s = 1:length(subject_ids)
    % Get contents of voltage monitor directory
    vm_path = fullfile(data_path, subject_ids{s}, 'VoltageMonitor');
    flist = dir(fullfile(vm_path, 'VM*'));
    msg = '';
    for f = 3:length(flist)
        msg = InlineProgressBar('Loading %d/%d', [f,length(flist)], msg);
        % Skip anything that isn't a subfolder
        if ~flist(f).isdir
            continue
        end

        % Try to find mat file and get date
        expected_fname = sprintf('%s_%s.mat', subject_ids{s}, flist(f).name);
        expected_ffname = fullfile(vm_path, flist(f).name, expected_fname);
        if isfile(fullfile(output_path, expected_fname))
            continue
        elseif isfile(expected_ffname)
            fsplit = strsplit(flist(f).name, '_');
            dn = datetime([str2double(fsplit{2}), str2double(fsplit{3}), str2double(fsplit{4})]);
            load(expected_ffname);
        else
            warning('No .mat file found in %s', flist(f).name)
            continue
        end

        % create vector for number of pulses and total amplitude
        [num_pulses, total_current] = deal(zeros(num_electrodes, 1));
        ch_waveforms = cell(num_electrodes, 1);
        % Running count
        for i = 1:length(VMData)
            for c = 1:length(VMData(i).Channels)
                % Sometimes motor exec sends fake pulses
                if VMData(i).Channels(c) > num_electrodes || VMData(i).Channels(c) == 0 
                    continue
                end
                c_idx = VMData(i).Channels(c);
                num_pulses(c_idx) = num_pulses(c_idx) + sum(VMData(i).Amplitudes{c} > 0);
                total_current(c_idx) = total_current(c_idx) + sum(VMData(i).Amplitudes{c});
            end
        end

        % Store data in table
        data = temp;
        data{1, "Subject"} = subject_ids(s);
        data{1, "Date"} = dn;
        data{1, "PulseCount"} = {num_pulses};
        data{1, "CurrentCount"} = {total_current};
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
        temp.data.Date = datetime([fsplit{5}(1:end-4), fsplit{3}, fsplit{4}], 'InputFormat', 'yyyyMMdd');
    end
    
    % Remove location
    if length(temp.data.Subject{1}) > 5
        temp.data.Subject{1} = temp.data.Subject{1}(1:5);
    end

    data{f} = temp.data;
end
data = cat(1, data{:});

save(fullfile(DataPath, 'VMData_All'), "data")