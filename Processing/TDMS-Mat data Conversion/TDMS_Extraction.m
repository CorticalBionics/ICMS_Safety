% Convert TDMS data
addpath(genpath('C:\git\LongitudinalICMS\TDMS-Mat data Conversion'))
addpath(genpath('P:\users\tgh28\ChartWithCharles'))
addpath 'C:\git\climber\src\Common\Matlab'
addpath(genpath('C:\git\rtma'))

%tld = 'P:\data_raw\human\crs_array\CRS02b\OpenLoopStim';
tld = 'P:\data_raw\human\crs_array\CRS02b\MPL_Experiments';
output_folder = 'blah';

flist = dir(tld); flist = flist(3:end);
for f = 1:length(flist)
    fflist = dir(fullfile(tld, flist(f).name));
    % Check if raw files exist
    if ~any(sum(startsWith({fflist.name}, 'DAQ') & endsWith({fflist.name}, '.tdms')))
        continue
    end
    % Convert TDMS -> Mat
    disp(fullfile(tld, flist(f).name))
    try        
        TDMSpostprocessing(fullfile(tld, flist(f).name), fullfile(tld, flist(f).name));
        disp('success')
    catch
        disp('boo')
    end
end
