% Convert TDMS data
addpath(genpath('C:\git\LongitudinalICMS\TDMS-Mat data Conversion'))
addpath(genpath('P:\users\tgh28\ChartWithCharles'))
addpath 'C:\git\climber\src\Common\Matlab'
addpath(genpath('C:\git\rtma'))

tld = 'P:\data_raw\human\crs_array\CRS02b\OpenLoopStim';
output_folder = 'blah';

flist = dir(tld); flist = flist(3:end);
successful_extraction = false(size(flist));
for f = 1:length(flist)
    fflist = dir(fullfile(tld, flist(f).name));
    % Check if raw files exist
    if ~any(sum(startsWith({fflist.name}, 'DAQ') & endsWith({fflist.name}, '.tdms')))
        continue
    end
    % Convert TDMS -> Mat
    try
        TDMSpostprocessing(fullfile(tld, flist(f).name), fullfile(tld, flist(f).name));
    
        % Combine .mat files and move to output folder
        fflist = dir(fullfile(tld, flist(f).name));
        idx = startsWith({fflist.name}, 'DAQ') & endsWith({fflist.name}, '.mat');
        fflist = fflist(idx);
        temp = struct();
        for i = 1:length(fflist)
            load(fullfile(fflist(i).folder, fflist(i).name))
            %%% Start working from here
            % Check if all amps are 10 or 20
            % Add to the structure of the same format
            break
        end
        successful_extraction(f) = true;
    catch
        disp('boo')
    end
end
