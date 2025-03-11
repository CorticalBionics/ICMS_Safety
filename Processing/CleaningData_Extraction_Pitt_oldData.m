%Export cleaning data
addpath(genpath('C:\git\climber\src\VoltageMonitor\utilities'))
addpath(genpath("P:\users\tgh28\ChartWithCharles")); %For progress bar

%Set Up Folders
data_path = "P:\users\tgh28\Experiments\Longitudinal_ICMS\vm_data_combined";
output_path = "P:\users\tgh28\Experiments\Longitudinal_ICMS\cleaning_data2";

% Count the number of pulses

%Format of output data
% temp = table('Size', [1, 10], ...
%     'VariableNames', {'Subject', 'Date', 'Vmin10', 'Vinter10', 'Vmax10', 'Waveforms10', ...
%     'Vmin20', 'Vinter20', 'Vmax20', 'Waveforms20'}, ...
%     'VariableTypes', ["string", "datetime", "cell", "cell", "cell", "cell", ...
%     "cell", "cell", "cell", "cell"]);

%Get List of all the matfiles to go through
flist = dir(fullfile(data_path, '*.mat'));

msg = '';

%%

%Stim Presets
num_electrodes = 64;
pulse_hw = 50;
pulse_dur = 700; % 200 cathodic, 100 inter, 400 anodic
idx_ratio = 300 / pulse_dur;

% Set up struct for each day
data = struct('Subject', [], 'Date', [], 'Session', [], 'Set', [], 'channels', [], 'vmin', [], 'vmax', [], 'vinter', [], 'waveform', [], 'Amp', [], 'avg_waveform', []);
ii = 1;


%Go through each file
for f = 1:length(flist) %f = 20 Weird wwaveforms

    %Print loading file
    msg = InlineProgressBar('Loading %d/%d', [f,length(flist)], msg);

    % Try to find mat file and get date
    expected_fname = flist(f).name;

    if isfile(fullfile(output_path, expected_fname)) %Skip if it already has been done
        continue

    elseif isfile(fullfile(data_path, expected_fname))
        fsplit = strsplit(flist(f).name, '_');
        dn = datetime([str2double(fsplit{5}(1:4)), str2double(fsplit{3}), str2double(fsplit{4})]);
        load(fullfile(data_path, expected_fname));

    else
        warning('No .mat file found in %s', flist(f).name)
        continue
    end


    % Go through each trial
    for i = 1:length(VMData)
        
        %First check if this trial was a cleaning protocol 
        num_electrodes = length(VMData(i).Channels);
        amps = unique(cell2mat(VMData(i).Amplitudes));
        if ~all(amps == 10) && ~all(amps == 20)
                continue
        end

        [avg_vmax, avg_vinter, avg_vmin] = deal(NaN(num_electrodes, 1));
        waveform = cell(num_electrodes, 1);
        avg_waveform = NaN(num_electrodes,100);

        %Go through each ch and get waveforms and average
        for ch = 1:num_electrodes

            %Get all waveforms for cleaning protocol for that ch
            waveforms = VMData(i).Waveforms{1,ch};

            %Check that waveforms are all the right length
            if size(waveforms,1) == 160

                [v_min, v_max, v_inter] = deal(zeros(size(waveforms, 2), 1));
                saved_vmax = VMData(i).maxV{:,:};
                saved_vmin = VMData(i).minV{:,:};

                %CALCULATE PER PULSE, THEN TAKE MEDIAN (each col is wave)
                for w = 1:size(waveforms, 2)
                    wave_temp = waveforms(:,w);
    
                    %calculate intermedite voltage
                    change_in_wave = abs(diff(wave_temp));
    
                    %Get index of v_inter
                    idx_start = find(change_in_wave(1:pulse_hw/2) < (0.01 * max(abs(wave_temp))), 1, 'last') + 1; %DOUBLE CHECK
                    idx_stop = find(change_in_wave(end-pulse_hw:end) < (0.01 * max(abs(wave_temp))), 1, 'first') -1 + pulse_hw; %DOUBLE CHECK
                    inter_idx = idx_start + round((idx_stop - idx_start) * idx_ratio);
    
                    if ~isempty(inter_idx) %Skip weird waveforms
                        %Save data for each waveform
                        v_min(w) = min(wave_temp);
                        v_max(w) = max(wave_temp);
                        v_inter(w) = wave_temp(inter_idx);
                    end

                    %Double check if this matches the saved max and min 
                    if abs(min(wave_temp) - saved_vmin(w)) > 0.001
                        error('Vmin does not match for file %s, trial %d, channel %d', expected_fname, i, ch')
                    end

                    if abs(max(wave_temp) - saved_vmax(w)) > 0.001
                        error('Vmin does not match for file %s, trial %d, channel %d', expected_fname, i, ch')
                    end
                end
                
                %Get averages with median
                avg_vmin(ch_idx) = median(v_min);
                avg_vmax(ch_idx) = median(v_max);
                avg_vinter(ch_idx) = median(v_inter);
                waveform{ch_idx} = waveforms_mat;
                avg_waveform(ch_idx,:) = median(waveforms_mat, 2);
            else
               warning('Waveform length is not 160 for file %s, trial %d, channel %d', expected_fname, i, ch);
               continue;
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
            end

            %add to data struct
            data(ii) = temp;
            ii = ii + 1;
        end
    end

    % Export single file for one day of data
    % save(fullfile(output_path, expected_fname), "CleaningData")
end
return
%% Export a combined matfile
% flist = dir(fullfile(output_path, '*.mat'));
% data = cell(length(flist), 1);
% 
% for f = 1:length(flist)
%     temp = load(fullfile(output_path, flist(f).name));
%     data{f} = temp.data;
% end
% data = cat(1, data{:});

save(fullfile(output_path, 'CleaningData_All.mat'), 'data', '-v7.3')

%% make plot 

load('P:\users\tgh28\Experiments\Longitudinal_ICMS\cleaning_data\CleaningData_All.mat')

%%
implant_date = datetime('04-May-2016', 'InputFormat', 'dd-MMM-yyyy');

% Initialize
day_since_start_all = cell(64, 1);  
vinter_all = cell(64, 1);

% Collect data for each channel across all iterations
for i = 1:length(data) 
    chs = data(i).channels;
    day_since_start = days(data(i).Date - implant_date);  % Calculate days since implant

    for c = 1:length(chs)
        ch = chs(c);
        
        if data(i).Amp == 20
            % Append the day_since_start and vinter value for each channel
            day_since_start_all{ch} = [day_since_start_all{ch}; day_since_start];
            vinter_all{ch} = [vinter_all{ch}; data(i).vinter(ch)];
        end
    end
end

% plot each channel
[ch_corrs, ch_coeff] = deal(NaN(64,1));
for ch = 1%:64
    if ~isempty(day_since_start_all{ch})  % Plot only if data exists for the channel
        figure(ch);
        x = day_since_start_all{ch};
        y = vinter_all{ch};
        nan_idx = isnan(y);
        x = x(~nan_idx);
        y = y(~nan_idx);
        y = movmedian(y, 10);

        scatter(x,y, 20, "black", "filled"); hold on
        [ch_corrs(ch),cp] = corr(x,y, 'Rows', 'complete');
        p = polyfit(x,y,1);
        ch_coeff(ch) = p(1);
        plot([min(x), max(x)], polyval(p, [min(x), max(x)]), 'Color', 'k')

        title(sprintf('Ch %d', ch));
        xlabel('Days Since Implant');
        ylabel(sprintf('Interphase Voltage (%sA)', GetUnicodeChar('mu')));
        hold off;
        set(gca, 'YLim', [-8 2])
    end
end

clf; subplot(1,2,1); Swarm(1, ch_corrs, 'DS', 'Box'); subplot(1,2,2); Swarm(1, ch_coeff, 'DS', 'Box')

%% Convert dates to datetimes 
% date = '03-Jan-2017';
% datetime(date, 'InputFormat', 'dd-MMM-uuuu')