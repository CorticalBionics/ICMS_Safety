%%% Signal quality analysis
subjects = {'BCI02', 'BCI03', 'CRS02', 'CRS07', 'CRS08'};
num_participants = length(subjects);
% Load SQ, VM, and Cleaning Data
% Get list of SQ data
flist = dir(fullfile(DataPath, 'SignalQuality', '*.mat'));
SQData = cell(num_participants, 1);

% Load voltage data
load(fullfile(DataPath, "VMData_All.mat"));
VMData = data;
conversion_factor = 1e6;
total_charge = zeros(length(subjects), 64);

% Load cleaning data
load(fullfile(DataPath, 'CleaningData'));
% Remove data from before 14-Aug-2017 (different monitoring system)
min_date = datetime(736920, 'ConvertFrom', 'datenum');
for p = 1:num_participants
    idx = [cleaning_data{p}.date] > min_date;
    cleaning_data{p} = cleaning_data{p}(idx); %#ok<SAGROW>
end

% Load SQData and process VM data
implant_dates = NaT(num_participants, 1);
for pi = 1:num_participants
    % Load SQ Data
    SQData{pi} = load(fullfile(DataPath, 'SignalQuality', flist(pi).name));
    SQData{pi}.participant = flist(pi).name(1:5);
    implant_dates(pi) = datetime(SQData{pi}.implant_metadata.implant_date, 'Format', 'dd-MMM-uuuu');

    % Filter VM data by participant
    s_idx = strcmp(data.Subject, subjects(pi));
    total_current = cat(2, data.CurrentCount{s_idx});
    all_charge = total_current .*  0.2 ./ conversion_factor; % Convert to charge in mC
    total_charge(pi, :) = sum(all_charge, 2, 'omitnan');
end
SQData = cat(1, SQData{:});

clearvars data all_charge total_current s_idx pi

%% Analyze SNR/VPP/Cleaning
[SNR_r, SNR_rp, SNR_slope, Vpp_r, Vpp_rp, Vpp_slope] = deal(NaN(256, num_participants));
[Cln_r, Cln_rp, Cln_slope] = deal(NaN(64, num_participants));
[median_SNR, median_Vpp, median_vinter, sq_dates, cln_dates] = deal(cell(num_participants, 1));
[med_SNR_r, med_SNR_p, med_Vpp_r, med_Vpp_p] = deal(NaN(num_participants, 2));
[med_Cln_r, med_Cln_p] = deal(NaN(num_participants, 1));

correlation_type = 'spearman';
for pi = 1:num_participants
    % Get sensory and motor masks
    sens_idx = contains(SQData(pi).implant_metadata.array_names, 'sensory', 'IgnoreCase', true);
    sensory_mask = SQData(pi).implant_metadata.chan_indices(sens_idx);
    sensory_mask = cat(2, sensory_mask{:});
    motor_idx = contains(SQData(pi).implant_metadata.array_names, 'motor', 'IgnoreCase', true);
    motor_mask = SQData(pi).implant_metadata.chan_indices(motor_idx);
    motor_mask = cat(2, motor_mask{:});

    %%% SNR
    x = datetime(num2str(SQData(pi).session_dates'), 'Format', 'yyyyMMdd');
    x = years(x - x(1));
    sq_dates{pi} = x;
    y = cat(1, SQData(pi).signal_quality_analysis.ch_snr);
    y_snr = 10.^(y./20); % Undo log scaling
    %%% Vpp
    y_vpp = cat(1, SQData(pi).signal_quality_analysis.ch_vpp); % Same x as SNR
    
    % Correlations and slopes
    [SNR_r(:,pi), SNR_rp(:,pi)] = corr(x, y_snr, 'Rows', 'pairwise', 'type', correlation_type);
    [Vpp_r(:,pi), Vpp_rp(:,pi)] = corr(x, y_vpp, 'Rows', 'pairwise', 'type', correlation_type);

    for c = 1:256
        SNR_slope(c, pi) = nan_regression(x, y_snr(:,c));
        Vpp_slope(c, pi) = nan_regression(x, y_vpp(:,c));
    end   

    % Smooth & subsample SNR
    y_snr = movmedian(y_snr, 3, 1, 'omitnan');
    median_SNR{pi}.sensory = median(y_snr(:, sensory_mask), 2, 'omitnan');
    median_SNR{pi}.motor = median(y_snr(:, motor_mask), 2, 'omitnan');
    [med_SNR_r(pi,1), med_SNR_p(pi,1)] = corr(x, median_SNR{pi}.sensory, 'Rows', 'complete');
    [med_SNR_r(pi,2), med_SNR_p(pi,2)] = corr(x, median_SNR{pi}.motor, 'Rows', 'complete');
    % Vpp
    y_vpp = movmedian(y_vpp, 3, 1, 'omitnan');
    median_Vpp{pi}.sensory = median(y_vpp(:, sensory_mask), 2, 'omitnan');
    median_Vpp{pi}.motor = median(y_vpp(:, motor_mask), 2, 'omitnan');
    [med_Vpp_r(pi,1), med_Vpp_p(pi,1)] = corr(x, median_SNR{pi}.sensory, 'Rows', 'complete');
    [med_Vpp_r(pi,2), med_Vpp_p(pi,2)] = corr(x, median_SNR{pi}.motor, 'Rows', 'complete');
    

    %%% Cleaning
    idx = cellfun(@(c) ~isempty(c), {cleaning_data{pi}.vmin});
    x = [cleaning_data{pi}(idx).date];
    x = years(x - x(1));
    cln_dates{pi} = x';
    y = cat(2, [cleaning_data{pi}(idx).vinter]);
    y(y < -1.5) = NaN; % Disconnected channels
    for c = 1:64
        Cln_slope(c, pi) = nan_regression(x, y(c,:));
    end
    [Cln_r(:,pi), Cln_rp(:,pi)] = corr(x', y', 'Rows', 'pairwise', 'type', correlation_type);
    median_vinter{pi} = median(y, 1, 'omitmissing');
    [med_Cln_r(pi), med_Cln_p(pi)] = corr(x', median_vinter{pi}', 'Rows', 'complete');
    
end

% Holm Bonferroni correction
SNR_rp = HolmBonferroni(SNR_rp);
Vpp_rp = HolmBonferroni(Vpp_rp);
Cln_rp = HolmBonferroni(Cln_rp);
med_Cln_p = med_Cln_p * num_participants;
med_Vpp_p = med_Vpp_p .* num_participants * 2;
med_SNR_p = med_SNR_p .* num_participants * 2;

% Store in structure and save
SQAnalysis = struct();
SQAnalysis.sq_dates = sq_dates;
SQAnalysis.cln_dates = cln_dates;
SQAnalysis.SNR_r = SNR_r;
SQAnalysis.SNR_rp = SNR_rp;
SQAnalysis.SNR_slope = SNR_slope;
SQAnalysis.Vpp_r = Vpp_r;
SQAnalysis.Vpp_rp = Vpp_rp;
SQAnalysis.Vpp_slope = Vpp_slope;
SQAnalysis.Cln_r = Cln_r;
SQAnalysis.Cln_rp = Cln_rp;
SQAnalysis.Cln_slope = Cln_slope;
SQAnalysis.median_SNR = median_SNR;
SQAnalysis.median_Vpp = median_Vpp;
SQAnalysis.median_vinter = median_vinter;
SQAnalysis.med_SNR_r = med_SNR_r;
SQAnalysis.med_SNR_p = med_SNR_p;
SQAnalysis.med_Vpp_r = med_Vpp_r;
SQAnalysis.med_Vpp_p = med_Vpp_p;
SQAnalysis.med_Cln_r = med_Cln_r;
SQAnalysis.med_Cln_p = med_Cln_p;

save(fullfile(DataPath, 'SQ_Analysis'), "SQAnalysis")


%% Helper functions
function slope = nan_regression(x, y)
    slope = NaN;
    nan_idx = isnan(y);
    if sum(~nan_idx) < 10
        return
    end
    if ~all(size(y) == size(x))
        y = y';
    end
    pf = polyfit(x(~nan_idx)', y(~nan_idx)', 1);
    slope = pf(1);
end