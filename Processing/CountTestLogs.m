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
