%%% Script to sanitize data structures of implant date information
[subject_list, num_subjects] = GetSubjectList();
[subject_list_alt, ~] = GetSubjectList(true);
implant_dates = NaT(num_subjects, 1);
electrode_maps = struct();
for pi = 1:num_subjects
    if contains(subject_list{pi}, 'BCI')
        site = 'chicago';
    elseif contains(subject_list{pi}, 'CRS')
        site = 'pitt';
    end
    implant_dates(pi) = datetime(cc.load_config.participant(subject_list{pi}, site).implant_date, 'InputFormat','uuuu-MM-dd');
    electrode_maps.(subject_list_alt{pi}) = cc.analysis.load_participant_electrode_map(subject_list{pi});
end
clearvars site pi
save(fullfile(DataPath, 'ElectrodeMaps.mat'), "electrode_maps")

%% Signal quality data
flist = dir(fullfile(DataPath, 'SignalQuality', '*.mat'));
SQData = cell(num_subjects, 1);
for pi = 1:num_subjects
    % Load SQ Data
    SQData{pi} = load(fullfile(DataPath, 'SignalQuality', flist(pi).name));
    SQData{pi}.participant = flist(pi).name(1:5);
end
SQData = cat(1, SQData{:});

for pi = 1:num_subjects
    sd = datetime(num2str(SQData(pi).session_dates'), 'Format', 'yyyyMMdd');
    SQData(pi).session_dates = days(sd - implant_dates(pi));
    SQData(pi).implant_metadata = rmfield(SQData(pi).implant_metadata, 'implant_date');
end

save(fullfile(DataPath, "SignalQuality.mat"), "SQData")
clearvars -except implant_dates num_subjects

%% Cleaning data
load(fullfile(DataPath, 'CleaningData'));
for pi = 1:num_subjects
    for i = 1:size(cleaning_data{pi}, 2)
        cleaning_data{pi}(i).date = days(cleaning_data{pi}(i).date - implant_dates(pi));
    end
end

save(fullfile(DataPath, "CleaningData.mat"), "cleaning_data")
clearvars -except implant_dates num_subjects

%% Detection data
load(fullfile(DataPath, 'DetectionData.mat'))
for pi = 1:num_subjects
    for i = 1:size(DetectionData{pi}, 2)
        DetectionData{pi}(i).Dates = days(DetectionData{pi}(i).Dates - implant_dates(pi));
    end
end

save(fullfile(DataPath, 'DetectionData.mat'), "DetectionData")
clearvars -except implant_dates num_subjects

%% Quality data
load(fullfile(DataPath, 'QualityData.mat'));

for pi = 1:num_subjects
    QualityData(pi).Responses.Date = days(QualityData(pi).Responses.Date - implant_dates(pi));
end

save(fullfile(DataPath, 'QualityData.mat'), "QualityData")
clearvars -except implant_dates num_subjects

%% Voltage monitor data
load(fullfile(DataPath, 'VMData_All.mat'));

dates = zeros(size(VMData, 1), 1);
for pi = 1:num_subjects
    idx = strcmp(VMData.Subject, subject_list{pi});
    dates(idx, :) = days(VMData(idx, :).Date - implant_dates(pi));
end
VMData.Date = dates;

save(fullfile(DataPath, 'VMData_All.mat'), "VMData", "total_charge");
clearvars -except implant_dates num_subjects

%% Impedances
flist = dir(fullfile(DataPath, 'Impedances', '*.mat'));
ImpedanceData = cell(num_subjects, 1);
for pi = 1:length(flist)
    % Load Data
    temp = load(fullfile(DataPath, 'Impedances', flist(pi).name));
    ImpedanceData{pi}.participant = temp.Impedance.Subject;

    if isfield(temp.Impedance, 'antDaysPostOp')
        % Get last reading if multiple impedances were measured on one day
        ud = intersect(temp.Impedance.antDaysPostOp, temp.Impedance.postDaysPostOp);
        data = zeros(length(ud), 256);
        for i = 1:length(ud)
            a_idx = find(temp.Impedance.antDaysPostOp == ud(i));
            p_idx = find(temp.Impedance.postDaysPostOp == ud(i));
            data(i, :) = mean(cat(3, temp.Impedance.antData(a_idx(end),:), temp.Impedance.postData(p_idx(end),:)), 3, 'omitnan');
        end
        ImpedanceData{pi}.dates = ud;
        ImpedanceData{pi}.impedances = data;
    else
        ImpedanceData{pi}.dates = temp.Impedance.bothDaysPostOp;
        ImpedanceData{pi}.impedances = temp.Impedance.bothData;
    end
end
ImpedanceData = cat(1, ImpedanceData{:});

save(fullfile(DataPath, 'ImpedanceData.mat'), "ImpedanceData");
clearvars -except implant_dates num_subjects
