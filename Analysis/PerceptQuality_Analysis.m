%%% Code to analyize longitudinal quality reports
load(fullfile(DataPath, 'QualityData.mat'))
PainData.P3 = load(fullfile(DataPath, 'QualityData', 'P3_pain.mat'));
PainData.P4 = load(fullfile(DataPath, 'QualityData', 'P4_pain.mat'));

[subject_list, num_subjects] = GetSubjectList();

%% Analyze quality data
num_channels = 64;
% Count the number of unique surveys
unique_surveys = zeros(num_subjects, num_channels);
for i = 1:num_subjects
    for c = 1:num_channels
        unique_surveys(i,c) = sum(QualityData(i).Responses.channel == c);
    end
end

num_perms = 1e3;
% Discretize and compute naturalness and quality frequency per year
for i = 1:num_subjects
    % Discretize to years
    % Get implant date
    if startsWith(subject_list{i}, 'BCI')
        subj_config = cc.load_config.participant(subject_list{i}, 'chicago');
    else
        subj_config = cc.load_config.participant(subject_list{i}, 'pitt');
    end
    implant_date = datetime(subj_config.implant_date, "InputFormat", "uuuu-MM-dd");

    y = years(QualityData(i).Responses.Date - implant_date);
    y_max = ceil(max(y));
    % Filter for any responses
    any_resp = any(QualityData(i).Responses{:,3:end} > 0, 2);
    
    % Compute naturalness for each year across channels
    [nat_mat, int_mat] = deal(NaN(y_max+1, num_channels));
    for c = 1:num_channels
        c_idx = QualityData(i).Responses.channel == c;
        for j = 1:y_max
            y_idx = (j-1 < y) & (y < j);
            nat_mat(j,c) = mean(QualityData(i).Responses.Naturalness(y_idx & c_idx & any_resp), 'omitnan');
            int_mat(j,c) = mean(QualityData(i).Responses.Intensity(y_idx & c_idx), 'omitnan'); % Don't filter resp for intensity
        end
    end
    QualityData(i).Naturalness = nat_mat; %#ok<*SAGROW>
    QualityData(i).Intensity = int_mat; %#ok<*SAGROW>

    % Compute quality frequency in each year
    resp_mat = QualityData(i).Responses{:, [6:end]};
    qual_mat = NaN(y_max, size(resp_mat, 2), num_channels); % year by 'distinct' quality by electrode
    for c = 1:num_channels
        c_idx = QualityData(i).Responses.channel == c;
        for j = 1:y_max
            y_idx = (j-1 < y) & (y < j);
            qual_mat(j, :, c) = mean(resp_mat(y_idx & c_idx & any_resp, :) > 0, 1) > 0.3;
        end
    end
    qual_mat = mean(qual_mat, 3, 'omitnan'); % Proportion of electrodes for each quality
    QualityData(i).Frequency = qual_mat ./ sum(qual_mat, 2); % Normalize within year

    % Permutations for quality stability
    qual_corr_mat = NaN(num_channels, y_max);
    qual_corr_mat_null = NaN(num_channels, y_max, num_perms);
    for c = 1:num_channels
        c_idx = QualityData(i).Responses.channel == c;
        x = QualityData(i).Responses.Date(c_idx & any_resp);
        y = QualityData(i).Responses{c_idx & any_resp, [6:end]}';
        % Filter out never observed qualities
        filt_idx = ~any(y > 0, 2);
        y = y(~filt_idx, :);

        if isempty(y)
            continue
        end
        
        % Pairwise distance & correlation
        mask = tril(true(length(x)), -1);
        dxp = squareform(pdist(datenum(x))); %#ok<DATNM>
        r = corr(y, 'Rows', 'pairwise');

        % Shuffle and correlate
        temp_perm_r = cell(num_perms, 1);
        for p = 1:num_perms
            y_perm = y;
            for j = 1:size(y, 2)
                y_perm(:,j) = y_perm(randperm(size(y, 1)), j);
            end
            pr = corr(y_perm, 'Rows', 'pairwise');
            temp_perm_r{p} = pr(mask);
        end
        
        % Combine within channel/year
        dy = dxp(mask) ./ 365;
        r = r(mask);
        for j = 1:y_max
            idx = dy < j & dy > j - 1;
            if sum(idx) < 10 % Only take average of high N
                continue
            end
            qual_corr_mat(c,j) = mean(r(idx), 'omitnan');
            for p = 1:num_perms
                qual_corr_mat_null(c,j,p) = mean(temp_perm_r{p}(idx), 'omitnan');
            end
        end
    end

    QualityData(i).StabilityCorrelation.corr = qual_corr_mat;
    QualityData(i).StabilityCorrelation.null = qual_corr_mat_null;
end

save(fullfile(DataPath, 'QualityAnalysis'), "QualityData", "PainData", "unique_surveys")