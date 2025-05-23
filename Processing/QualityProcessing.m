%% Load and format quality data
% Indices of qualities from the response matrix
qual_idx = [6, 14:29, 31, 32];
% Load each participant and convert data to tables
flist = dir(fullfile(DataPath, 'QualityData', '*quality.mat'));
num_subjects = length(flist);
QualityData = struct();
for f = 1:length(flist)
    temp = load(fullfile(flist(f).folder, flist(f).name));
    QualityData(f).Subject = flist(f).name(1:2);

    % covert new hot/cold temperature scores to normal temperature scores
    % (0=cold, 10=hot)
    hot_idx = find(temp.resp_data(:,30)>5);
    temp.resp_data(hot_idx,31) = (((temp.resp_data(hot_idx,30)-5)/5)*10); %(hot = 5-10 temperature)
    cold_idx = find(temp.resp_data(:,30)<=5 & temp.resp_data(:,30) > 0);
    temp.resp_data(cold_idx,32) = ((temp.resp_data(cold_idx,30)/5)*10); %(cold = 0-5 temperature)
    temp.resp_data(:,30) = []; % delete temperature intensity, keep hot and cold

    % average over multiple sensations per channel
    flat_scores = [];
    flat_dates = {};
    da = 1;
    sessions = unique(temp.resp_data(:,2));
    for s=1:numel(sessions)
        % Find sessions with matching dates
        session_data = temp.resp_data(find(temp.resp_data(:,2) == sessions(s)), :);
        session_date = temp.s_date(find(temp.resp_data(:,2) == sessions(s)));
        session_date = session_date{1};
        channels = unique(session_data(:, 6));
        for c=1:numel(channels)
            idx_channel = find(session_data(:, 6) == channels(c));
            channel_data = session_data(idx_channel, :);
            single_data = zeros(1,size(channel_data, 2));
            if numel(idx_channel)>1
                for r=14:size(channel_data,2)
                    if sum(channel_data(:,r)>0)>1
                        single_data(1,r) = mean(channel_data(channel_data(:,r)>0,r)); % take average
                    elseif sum(channel_data(:,r)>0)==1
                        single_data(1,r) = channel_data(channel_data(:,r)>0,r); % copy over non 0 element
                    else
                        single_data(1,r) = 0;
                    end
                end
                single_data(1,1:10) = channel_data(1,1:10);
                single_data(1,11) = mode(channel_data(:,11));
                single_data(1,12) = mode(channel_data(:,12));
                single_data(1,13) = mode(channel_data(:,13));
            else
                single_data = channel_data;
            end
            flat_scores = [flat_scores; single_data]; %#ok<AGROW>
            flat_dates{da} = session_date; %#ok<SAGROW>
            da = da + 1;
        end
    end

    % Subsample
    flat_scores = flat_scores(:, qual_idx);
    resp_header = temp.response_header(qual_idx);
    % Process header
    for i = 1:length(resp_header)
        paren_idx = find(resp_header{i} == '(', 1, 'first');
        if isscalar(paren_idx)
            resp_header{i} = resp_header{i}(1:paren_idx-1);
            resp_header{i} = strrep(resp_header{i}, ' ', '');
        end
    end
    % Convert to table
    QualityData(f).Responses = table('Size', [length(flat_dates), length(resp_header)+1], ...
        'VariableTypes', ["datetime", repmat("double", 1, length(resp_header))], ...
        'VariableNames', ["Date", resp_header]);
    QualityData(f).Responses.Date = datetime(flat_dates, "InputFormat", "dd-MMM-uuuu")';
    for i = 1:length(resp_header)
        QualityData(f).Responses.(resp_header{i}) = flat_scores(:,i);
    end
end

% Run the permutations to assess stability

save(fullfile(DataPath, 'QualityData'), "QualityData")
