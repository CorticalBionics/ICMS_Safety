% clean up workspace
clear all;
close all;

data_folder = '/Users/verbaar/Documents/UPgh_Pittsburgh_Rubicon/surveys/raw_data/'; % path to the data
subject = 'CRS02b'; % can be: CRS02b, CRS07, CRS08, BCI02, or BCI03

% read in survey quality data
[resp_data,response_header,s_date] = read_in_qualiy_data_final(data_folder,subject);

% analyze quality data
% Figure 1F and Supplementary Figure 3b-e
threshold = 30; % electrodes that evoke a sensation less than 30% of the time are excluded from the analysis
[freq_sensation,nr_tests] = quality_long_term(data_folder, threshold);

% permute quality over time
% Supplementary Figure 3A
[mean_corr, std_corr, p] = permute_quality_over_time(data_folder,subject,freq_sensation);



