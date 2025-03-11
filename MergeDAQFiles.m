%%% Script to combine and copy old DAQ data to output folder

out_dir = "P:\users\tgh28\Experiments\Longitudinal_ICMS\vm_data";
test_dir = "P:\data_raw\human\crs_array\CRS02b\OpenLoopStim\CRS02bHome.data.00005";

flist = dir(fullfile(test_dir, 'DAQ*.mat'));

%%
for f = 1:length(flist)
    load(fullfile(test_dir, flist(f).name))

    %TAYLOR NEEDS TO ADD SCRIPT TO MAKE SIMILAR DATA FILE 
    %load('P:\users\tgh28\Experiments\Longitudinal_ICMS\vm_data\CRS02bLab_session_01_04_2021.mat')
end
