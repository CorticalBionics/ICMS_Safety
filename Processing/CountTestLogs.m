%% Chicago
tld = 'T:\SessionData';
subjects = {'BCI02', 'BCI03'};
tlc = zeros(size(subjects));

for s = 1:length(subjects)
    tlpath = fullfile(tld, subjects{s}, 'TestLogManager');
    flist = dir(fullfile(tlpath, '*.pdf'));
    names = {flist.name};
    for n = 1:length(names)
        fsplit = strsplit(names{n}, '_');
        if startsWith(names{n}, subjects{s})
            if contains(fsplit{2}, '.pdf')
                fsplit{2} = fsplit{2}(1:end-4);
            end
            names{n} = fsplit{2};
        elseif startsWith(names{n}, 'TestingLog')
            fcat = strjoin(fsplit(2:4), '_');
            if contains(fcat, '.pdf')
                fcat = fcat(1:end-4);
            end
            names{n} = fcat;
        end
    end
    tlc(s) = length(unique(names));
end

%% Pitt
% tld = 'P:\data_raw\human\crs_array';
% subjects = {'CRS02b', 'CRS07', 'CRS08'};
% min_year = 2015;
% current_year = year(datetime("today"));
% year_range = min_year:current_year;
% 
% 
% for s = 1:length(subjects)
%     for y = 1:length(year_range)
% 
%     end
% end

%(as of 5/15/25)
%CRS02b 
%2015 May - Dec: 9 + 12 + 13 + 13 + 5 + 8 + 10 + 6 = 76
%2016 Jan - Dec: 10 + 13 + 14 + 5 + 8 + 8 + 9 + 7 + 10 + 9 + 10 + 9 = 112
%2017 Jan - Dec: 11+11+13+13+10+12+13+9+14+11+14+11+9 = 151
%2018 Jan - Dec: 14+11+12+10+13+18+13+15+5+13+9+9 = 142
%2019 Jan - Dec: 17+10+12+5+9+13+13+12+16+12+12+10 = 141
%2020 Jan - Dec: 12+11+3+0+0+3+13+11+10+10+7+9 = 89
%2021 Jan - Dec: 5+16+16+12+10+13+9+8+9+9+12+9 = 128
%2022 Jan - Dec: 7+8+12+7+11+14+6+11+11+10+9+7 = 113
%2023 Jan - Dec: 11+10+13+10+13+4+11+13+10+5+9+6 = 115
%2024 Jan - Dec: 13+11+12+10+8+11+12+10+12+10+8+8 = 125
%2025 Jan - May: 10+8+10+6+4 = 38
%Home session = 107 
%Total= 76+112+151+142+141+89+128+113+115+125+38+107= 1337

%CRS07
%2020 Aug - Dec: 3+9+9+5+5 = 31
%2021 Jan - Dec: 6+7+4+8+6+6+3+8+9+6+3+1 = 67
%2022 Jan - Dec: 3+6+8+7+7+0+4+7+11+11+10+8 = 82
%2023 Jan - Dec: 9+11+10+5+4+3+2+2 = 46
%2024 Jan - Dec: 7+5+6+9+5+6+8+0+5+7+2+1 = 61
%2025 Jan - Feb: 4+4 = 8
%Total = 31 + 67 + 82 + 46 + 61 + 8 = 295

%CRS08
%2023 Apr - Dec: 4+9+10+13+13+3+6+10+6 = 74
%2024 Jan - Dec: 6+6+10+11+15+8+7+7+9+8+2+6 = 95
%2025 Jan - May: 4+2+3+8+1 = 18
%Total = 74 + 95 + 18 = 187

%% (as of 7/27/25)
%CRS02b 
%2015 May - Dec: 9 + 12 + 13 + 13 + 5 + 8 + 10 + 6 = 76
%2016 Jan - Dec: 10 + 13 + 14 + 5 + 8 + 8 + 9 + 7 + 10 + 9 + 10 + 9 = 112
%2017 Jan - Dec: 11+11+13+13+10+12+13+9+14+11+14+11+9 = 151
%2018 Jan - Dec: 14+11+12+10+13+18+13+15+5+13+9+9 = 142
%2019 Jan - Dec: 17+10+12+5+9+13+13+12+16+12+12+10 = 141
%2020 Jan - Dec: 12+11+3+0+0+3+13+11+10+10+7+9 = 89
%2021 Jan - Dec: 5+16+16+12+10+13+9+8+9+9+12+9 = 128
%2022 Jan - Dec: 7+8+12+7+11+14+6+11+11+10+9+7 = 113
%2023 Jan - Dec: 11+10+13+10+13+4+11+13+10+5+9+6 = 115
%2024 Jan - Dec: 13+11+12+10+8+11+12+10+12+10+8+8 = 125
%2025 Jan - Jul: 10+8+10+6+4+11+9 = 58
%Home session = 107 
%Total= 76+112+151+142+141+89+128+113+115+125+58+107= 1357

%CRS07
%2020 Aug - Dec: 3+9+9+5+5 = 31
%2021 Jan - Dec: 6+7+4+8+6+6+3+8+9+6+3+1 = 67
%2022 Jan - Dec: 3+6+8+7+7+0+4+7+11+11+10+8 = 82
%2023 Jan - Dec: 9+11+10+5+4+3+2+2 = 46
%2024 Jan - Dec: 7+5+6+9+5+6+8+0+5+7+2+1 = 61
%2025 Jan - Feb: 4+4 = 8
%Total = 31 + 67 + 82 + 46 + 61 + 8 = 295

%CRS08
%2023 Apr - Dec: 4+9+10+13+13+3+6+10+6 = 74
%2024 Jan - Dec: 6+6+10+11+15+8+7+7+9+8+2+6 = 95
%2025 Jan - Jul: 4+2+3+8+1+4+0 = 22
%Total = 74 + 95 + 22 = 191