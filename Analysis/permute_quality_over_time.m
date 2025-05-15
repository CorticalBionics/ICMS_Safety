function [mean_corr, std_corr, p] = permute_quality_over_time(data_folder,subject,freq_sensation)

data = load(fullfile(data_folder,subject,[subject,'_resp_data.mat']));

response_header = data.response_header;

% flatten data: if more than one sensation is reported in response to
% single electrode stimulation, combine these multiple sensation reports
% into a single one. 
[flat_scores, flat_dates] = prepare_data(data.resp_data,data.s_date);

% sort data per full survey (minimum of 40 electrodes per survey)
scores = flat_scores;
dates = flat_dates;
[a,i] = sort(datetime(dates),'ascend');
scores = scores(i,:);
dates = dates(i);
scores = scores(:,[6,15,17:23,26:29]);
labels = response_header([6,15,17:23,26:29]);
labels = ['session',labels];
unique_dates = unique(datetime(dates),'stable');
current_survey = zeros(64,1);
current_data = zeros(64,numel(labels)+1);
session_nr = 1;
current_data(:,1) = session_nr;
current_data(:,2) = zeros(64,1);
current_data(:,3) = [1:64];
surveys = [];
survey_date = [];
previous_session = unique_dates(1); % first date
for d=1:numel(unique_dates)
    session_idx = find(dates==unique_dates(d));
    session = scores(session_idx,:);
    if size(session,1)>1
        diff_dates = split(between(datetime(previous_session),datetime(unique_dates(d))),{'months','days'});
        if diff_dates <= 2 && sum(current_survey)<62 % this survey fits within time schedule
            for s=1:size(session,1) % keep adding data to current count
                current_survey(session(s,1)) = 1;
                current_data(session(s,1),:) = [session_nr current_survey(session(s,1)) session(s,:)];
            end
            
            if d==numel(unique_dates) % this was the last survey
                if sum(current_survey)>40
                    % normalize naturalness within session
                    s_min = min(nonzeros(current_data(:,4)));
                    s_max = max(nonzeros(current_data(:,4)));
                    zero_entries = find(current_data(:,4)==0);
                    current_data(:,4) = ((current_data(:,4) - s_min) / (s_max - s_min)) * 10;
                    current_data(zero_entries,4) = 0;

                    % save last survey
                    surveys = [surveys; current_data]; 
                    survey_date = [survey_date unique_dates(d)]
                end
            end
        else
            sum(current_survey)
            if sum(current_survey)>40
                % normalize naturalness within session
                s_min = min(nonzeros(current_data(:,4)));
                s_max = max(nonzeros(current_data(:,4)));
                zero_entries = find(current_data(:,4)==0);
                current_data(:,4) = ((current_data(:,4) - s_min) / (s_max - s_min)) * 10;
                current_data(zero_entries,4) = 0;

                % save last survey
                surveys = [surveys; current_data]; 
            end
            current_survey = zeros(64,1); % start new count
            current_data = zeros(64,numel(labels)+1); % clear data
            session_nr = session_nr+1; 
            survey_date = [survey_date unique_dates(d-1)]

            % start new survey
            current_data(:,1) = session_nr;
            current_data(:,2) = zeros(64,1);
            current_data(:,3) = [1:64];
            for s=1:size(session,1) 
                current_survey(session(s,1)) = 1;
                current_data(session(s,1),:) = [session_nr current_survey(session(s,1)) session(s,:)];
            end
            previous_session = unique_dates(d);
        end
    end
    
end

% delete never used qualities
bad_idx = find(sum(surveys)==0);
surveys(:,bad_idx) = [];
labels(bad_idx) = [];
% delete electrodes with 30% sensation detected
bad_idx = find(freq_sensation(:,1)<30);
to_delete = find(ismember(surveys(:,3),bad_idx));
surveys(to_delete,:) = [];

% Pearson correlation between surveys at different timepoints
unique_surveys = unique(surveys(:,1),'stable');
within_elect_corr = [];
within_elect_dist = [];
in_between = [];
for s=1:numel(unique_surveys)
    survey1 = surveys(surveys(:,1)==unique_surveys(s),:);
    date1 = survey_date(s);
    for ss=s+1:numel(unique_surveys)
        survey2 = surveys(surveys(:,1)==unique_surveys(ss),:);
        date2 = survey_date(ss);
        in_between = [in_between datenum(datetime(date2))-datenum(datetime(date1))];
        [R,p] = corrcoef(survey1(:,5:end),survey2(:,5:end));
        within_elect_corr = [within_elect_corr R(2)]; % D];
        within_elect_dist = [within_elect_dist abs(s-ss)];
    end
end

% calculate mean and std over electrode over time
unique_dist = unique(in_between);
max_year = max(unique_dist)/365
mean_corr = [];
std_corr = [];
dr = [0:0.5:floor(max_year)];
for d=1:numel(dr)
    if d==numel(dr)
        idx = find(in_between >= dr(d)*365);
    else
        idx = find(in_between >= dr(d)*365 & in_between < (dr(d+1)*365));
    end
    mean_corr = [mean_corr mean(within_elect_corr(idx))];
    std_corr = [std_corr std(within_elect_corr(idx))];
end

% permute sensation quality
nr_p = 100;
p_mean_corr = zeros(nr_p,numel(dr));
p_std_corr = zeros(nr_p,numel(dr));
for p=1:nr_p % 1000 permutations
    p
    p_surveys = surveys;
    within_elect_corr_p = [];
    within_elect_dist_p = [];
    in_between_p = [];
    for s=1:numel(unique_surveys)
        survey1 = p_surveys(p_surveys(:,1)==unique_surveys(s),:);
        date1 = survey_date(s);
        for e=1:size(survey1,1)
            random_c = randperm(size(survey1,2)); % permute quality assignment
            random_c(random_c<5) = [];
            survey1(e,5:end) = survey1(e,random_c);
        end
        
        for ss=s+1:numel(unique_surveys)
            survey2 = p_surveys(p_surveys(:,1)==unique_surveys(ss),:);
            date2 = survey_date(ss);
            for e=1:size(survey2,1)
                random_c = randperm(size(survey2,2)); % permute quality assignment
                random_c(random_c<5) = [];
                survey2(e,5:end) = survey2(e,random_c);
            end
            
            [R,pp] = corrcoef(survey1(:,5:end),survey2(:,5:end));
            within_elect_corr_p = [within_elect_corr_p R(2)]; %D];
            within_elect_dist_p = [within_elect_dist_p abs(s-ss)];
            in_between_p = [in_between_p datenum(datetime(date2))-datenum(datetime(date1))];
        end
    end
    
    % calculate mean and std over electrode over time
    unique_dist = unique(in_between_p);
    max_year = max(unique_dist)/365;
    mean_c = [];
    std_c = [];
    dr = [0:0.5:floor(max_year)];
    for d=1:numel(dr)
        if d==numel(dr)
            idx = find(in_between_p >= dr(d)*365);
        else
            idx = find(in_between_p >= dr(d)*365 & in_between_p < (dr(d+1)*365));
        end
        mean_c = [mean_c mean(within_elect_corr_p(idx))];
        std_c = [std_c std(within_elect_corr_p(idx))];
    end
    p_mean_corr(p,:) = mean_c;
    p_std_corr(p,:) = std_c;
end
a = (sum(p_mean_corr>mean_corr)/nr_p);
d = find(a>0.05);
if ~isempty(d)
    p = (numel(d)+1)/nr_p
else
    p = 1/nr_p
end

% plot result
figure;
plot(mean_corr,'b','LineWidth',2); hold on;
plot(mean_corr+std_corr,'b');
plot(mean_corr-std_corr,'b');
plot(mean(p_mean_corr),'k','LineWidth',2);
plot(mean(p_mean_corr)+mean(p_std_corr),'k');
plot(mean(p_mean_corr)-mean(p_std_corr),'k');
ylabel('Pearson R')
xlabel('Distance (years)')
ylim([0 1])
xlim([1 numel(mean_corr)])
xticks([1:numel(mean_corr)])
dr = [0.5:0.5:floor(max_year)+0.5];
xticklabels(dr)