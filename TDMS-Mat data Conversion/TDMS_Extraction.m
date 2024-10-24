% Convert TDMS data
addpath(genpath('C:\GitHub\analysis\LongitudinalICMS\TDMS-Mat data Conversion'))
tld = 'C:\Users\somlab\Downloads\CRS02bHome.data.00013';
output_folder = 'blah';

flist = dir(tld);
for f = 3:length(flist)
    fflist = dir(fullfile(tld, flist(f).name));
    % Check if raw files exist
    if ~any(sum(startsWith({fflist.name}, 'DAQ') & endsWith({fflist.name}, '.tdms')))
        continue
    end
    % Convert TDMS -> Mat
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
end
