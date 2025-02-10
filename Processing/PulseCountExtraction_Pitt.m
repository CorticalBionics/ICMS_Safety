% Count the number of pulses
num_electrodes = 64;
data_path = "P:\users\tgh28\Experiments\Longitudinal_ICMS\vm_data";
output_path = "P:\users\tgh28\Experiments\Longitudinal_ICMS\vm_out";
temp = table('Size', [1, 4], ...
    'VariableNames', {'Subject', 'Date', 'PulseCount', 'CurrentCount'}, ...
    'VariableTypes', ["string", "datetime", "cell", "cell"]);
flist = dir(fullfile(data_path, '*.mat'));
msg = '';
for f = 1:length(flist)
    msg = InlineProgressBar('Loading %d/%d', [f,length(flist)], msg);

    % Try to find mat file and get date
    expected_fname = flist(f).name;
    if isfile(fullfile(output_path, expected_fname))
        continue
    elseif isfile(fullfile(data_path, expected_fname))
        fsplit = strsplit(flist(f).name, '_');
        dn = datetime([str2double(fsplit{2}), str2double(fsplit{3}), str2double(fsplit{4})]);
        load(fullfile(data_path, expected_fname));
    else
        warning('No .mat file found in %s', flist(f).name)
        continue
    end

    % create vector for number of pulses and total amplitude
    [num_pulses, total_current] = deal(zeros(num_electrodes, 1));
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
    fs = strsplit(expected_fname, '_');
    data = temp;
    data{1, "Subject"} = fs(1);
    data{1, "Date"} = dn;
    data{1, "PulseCount"} = {num_pulses};
    data{1, "CurrentCount"} = {total_current};
    
    % Export
    save(fullfile(output_path, expected_fname), "data")
end

%% Combine data
flist = dir(fullfile(output_path, '*.mat'));
data = cell(length(flist), 1);

for f = 1:length(flist)
    temp = load(fullfile(output_path, flist(f).name));
    data{f} = temp.data;
end
data = cat(1, data{:});

save(fullfile(output_path, 'VMData_All'), "data")