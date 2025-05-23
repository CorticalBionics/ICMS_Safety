% clean up workspace
clear all;
close all;

data_folder = fullfile(DataPath, 'QualityData'); % path to the data, e.g. P2_quality.mat

% analyze quality data
% Figure 1F and Supplementary Figure 3b-e
threshold = 30; % electrodes that evoke a sensation less than 30% of the time are excluded from the analysis
[freq_sensation,nr_tests] = quality_long_term(data_folder, threshold);
%%
% permute quality over time
% Supplementary Figure 3A
subject = 'P2'; % can be 'P2', 'P3', 'P4', 'C1','C2'
[mean_corr, std_corr, p] = permute_quality_over_time(data_folder,subject,freq_sensation);



