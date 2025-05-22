function [freq_sensation,nr_tests] = quality_long_term(data_folder, threshold)

% read in the data
P2 = load(fullfile(data_folder,'P2_quality.mat'));
P3 = load(fullfile(data_folder,'P3_quality.mat'));
P4 = load(fullfile(data_folder,'P4_quality.mat'));
C1 = load(fullfile(data_folder,'C1_quality.mat'));
C2 = load(fullfile(data_folder,'C2_quality.mat'));

response_header = P2.response_header;

% flatten data
[P2_flat_scores, P2_flat_dates] = prepare_data(P2.resp_data,P2.s_date);
[P3_flat_scores, P3_flat_dates] = prepare_data(P3.resp_data,P3.s_date);
[P4_flat_scores, P4_flat_dates] = prepare_data(P4.resp_data,P4.s_date);
[C1_flat_scores, C1_flat_dates] = prepare_data(C1.resp_data,C1.s_date);
[C2_flat_scores, C2_flat_dates] = prepare_data(C2.resp_data,C2.s_date);
% append data
all_data = [P2_flat_scores; P3_flat_scores; P4_flat_scores; C1_flat_scores; C2_flat_scores];

% nr tests per electrode
% sensations detected per electrode
channels = [1:64];
nr_tests = zeros(numel(channels),5);
sensation_detected = zeros(numel(channels),5);
for s=1:numel(unique(all_data(:,1)))
    subject_data = all_data(all_data(:,1)==s,:);
    for c=1:numel(channels)
        channel_data = subject_data(subject_data(:,6)==c,:);
        nr_tests(c,s) = size(channel_data,1);
        sensation_detected(c,s) = sum(sum(channel_data(:,14:end)>0,2)>0);
    end
end
freq_sensation = sensation_detected./nr_tests*100; % frequency of a perceived sensation at each electrode

% get quality data per year
dates = P2_flat_dates;
scores = P2_flat_scores;
[first,second,third,fourth,fifth,sixth,seventh,eight,ninth,last] = sort_dates(datetime(dates)); % get 4 equally spaced dates
[freq1, pain_intensity1] = get_freq_qualities(scores(datetime(dates)<=last,:),freq_sensation); % get frequency of quality across this time range
dates = P3_flat_dates;
scores = P3_flat_scores;
[first,second,third,fourth,fifth,sixth,seventh,eight,ninth,last] = sort_dates(datetime(dates)); % get 4 equally spaced dates
[freq2, pain_intensity2] = get_freq_qualities(scores(datetime(dates)<=last,:),freq_sensation); % get frequency of quality across this time range
dates = P4_flat_dates;
scores = P4_flat_scores;
[first,second,third,fourth,fifth,sixth,seventh,eight,ninth,last] = sort_dates(datetime(dates)); % get 4 equally spaced dates
[freq3, pain_intensity3] = get_freq_qualities(scores(datetime(dates)<=last,:),freq_sensation); % get frequency of quality across this time range
dates = C1_flat_dates;
scores = C1_flat_scores;
[first,second,third,fourth,fifth,sixth,seventh,eight,ninth,last] = sort_dates(datetime(dates)); % get 4 equally spaced dates
[freq4, pain_intensity4] = get_freq_qualities(scores(datetime(dates)<=last,:),freq_sensation); % get frequency of quality across this time range
dates = C2_flat_dates;
scores = C2_flat_scores;
[first,second,third,fourth,fifth,sixth,seventh,eight,ninth,last] = sort_dates(datetime(dates)); % get 4 equally spaced dates
[freq5, pain_intensity5] = get_freq_qualities(scores(datetime(dates)<=last,:),freq_sensation); % get frequency of quality across this time range

% total amount of pain reported
% average intensity pain (16)
perc_pain = [sum(P2_flat_scores(:,16)>0)/sum(sum(P2_flat_scores(:,14:end),2)>0) sum(P3_flat_scores(:,16)>0)/sum(sum(P3_flat_scores(:,14:end),2)>0) ...
             sum(P4_flat_scores(:,16)>0)/sum(sum(P4_flat_scores(:,14:end),2)>0) sum(C1_flat_scores(:,16)>0)/sum(sum(C1_flat_scores(:,14:end),2)>0) ...
             sum(C2_flat_scores(:,16)>0)/sum(sum(C2_flat_scores(:,14:end),2)>0)]*100;
pain_intensity = [pain_intensity1(freq1(:,1)>threshold)' pain_intensity2(freq2(:,1)>threshold)' pain_intensity3(freq3(:,1)>threshold)' ...
                  pain_intensity4(freq4(:,1)>threshold)' pain_intensity5(freq5(:,1)>threshold)'];
intensity_group = [ones(1,sum(freq1(:,1)>threshold)) ones(1,sum(freq2(:,1)>threshold))*2 ones(1,sum(freq3(:,1)>threshold))*3 ...
                   ones(1,sum(freq4(:,1)>threshold))*4 ones(1,sum(freq5(:,1)>threshold))*5]; 

pain07 = load(fullfile(data_folder,'P3_pain.mat'));
pain08 = load(fullfile(data_folder,'P4_pain.mat'));
               
figure;
subplot(1,3,1)
bar(round(mode(nr_tests)));
ylabel('#Surveys')
subplot(1,3,2)
bar(perc_pain);
hold on;
set(gca,'FontSize',15);
xticks([1:5]);
xticklabels({'P2','P3','P4','C1','C2'});
xlim([0,6])
ylim([0 100]);
ylabel('pain reported(%)')
set(gca,'FontSize',15);
subplot(1,3,3)
i25 = prctile(pain_intensity,25);
i75 = prctile(pain_intensity,75);
imedian = median(pain_intensity);
p25 = prctile([pain07.uPain pain08.uPain],25);
p75 = prctile([pain07.uPain pain08.uPain],75);
pmedian = median([pain07.uPain pain08.uPain]);
swarmchart([ones(size(pain07.uPain)) ones(size(pain08.uPain)) ones(size(pain_intensity))*2],[pain07.uPain pain08.uPain pain_intensity],[],[ones(size(pain07.uPain))*2 ones(size(pain08.uPain))*3 intensity_group],'filled')
hold on;
plot([1 1],[p25 p75],'k','LineWidth',2);
scatter(1,pmedian,150,'k');
plot([2 2],[i25 i75],'k','LineWidth',2);
scatter(2,imedian,150,'k');
ylim([0 10]);
xlim([0.5 2.5]);
ylabel('pain intensity')
set(gca,'FontSize',15);

% calc naturalness per year
dates = P2_flat_dates;
scores = P2_flat_scores;
[first,second,third,fourth,fifth,sixth,seventh,eight,ninth,last] = sort_dates(datetime(dates)); % score each year
[mean_intensity1(:,1)] = calcIntensity(scores(datetime(dates)<first,:),15);
[mean_intensity1(:,2)] = calcIntensity(scores(datetime(dates)>=first & datetime(dates)<second,:),15);
[mean_intensity1(:,3)] = calcIntensity(scores(datetime(dates)>=second & datetime(dates)<third,:),15);
[mean_intensity1(:,4)] = calcIntensity(scores(datetime(dates)>=third & datetime(dates)<fourth,:),15);
[mean_intensity1(:,5)] = calcIntensity(scores(datetime(dates)>=fourth & datetime(dates)<fifth,:),15);
[mean_intensity1(:,6)] = calcIntensity(scores(datetime(dates)>=fifth & datetime(dates)<sixth,:),15);
[mean_intensity1(:,7)] = calcIntensity(scores(datetime(dates)>=sixth & datetime(dates)<seventh,:),15);
[mean_intensity1(:,8)] = calcIntensity(scores(datetime(dates)>=seventh & datetime(dates)<eight,:),15);
[mean_intensity1(:,9)] = calcIntensity(scores(datetime(dates)>=eight & datetime(dates)<ninth,:),15);
[mean_intensity1(:,10)] = calcIntensity(scores(datetime(dates)>=ninth,:),15);

dates = P3_flat_dates;
scores = P3_flat_scores;
[first,second,third,fourth,fifth,sixth,seventh,eight,ninth,last] = sort_dates(datetime(dates)); % score each year
[mean_intensity2(:,1)] = calcIntensity(scores(datetime(dates)<first,:),15);
[mean_intensity2(:,2)] = calcIntensity(scores(datetime(dates)>=first & datetime(dates)<second,:),15);
[mean_intensity2(:,3)] = calcIntensity(scores(datetime(dates)>=second & datetime(dates)<third,:),15);
[mean_intensity2(:,4)] = calcIntensity(scores(datetime(dates)>=third,:),15);

dates = P4_flat_dates;
scores = P4_flat_scores;
[first,second,third,fourth,fifth,sixth,seventh,eight,ninth,last] = sort_dates(datetime(dates)); % score each year
[mean_intensity3(:,1)] = calcIntensity(scores(datetime(dates)<first,:),15);
[mean_intensity3(:,2)] = calcIntensity(scores(datetime(dates)>=first,:),15);

dates = C1_flat_dates;
scores = C1_flat_scores;
[first,second,third,fourth,fifth,sixth,seventh,eight,ninth,last] = sort_dates(datetime(dates)); % score each year
[mean_intensity4(:,1)] = calcIntensity(scores(datetime(dates)<first,:),15);
[mean_intensity4(:,2)] = calcIntensity(scores(datetime(dates)>=first & datetime(dates)<second,:),15);
[mean_intensity4(:,3)] = calcIntensity(scores(datetime(dates)>=second & datetime(dates)<third,:),15);
[mean_intensity4(:,4)] = calcIntensity(scores(datetime(dates)>=third & datetime(dates)<fourth,:),15);
[mean_intensity4(:,5)] = calcIntensity(scores(datetime(dates)>=fourth,:),15);

dates = C2_flat_dates;
scores = C2_flat_scores;
[first,second,third,fourth,fifth,sixth,seventh,eight,ninth,last] = sort_dates(datetime(dates)); % score each year
[mean_intensity5(:,1)] = calcIntensity(scores(datetime(dates)<first,:),15);
[mean_intensity5(:,2)] = calcIntensity(scores(datetime(dates)>=first,:),15);

for i=1:size(mean_intensity1,2)
    mean_intensity1(mean_intensity1(:,i)<0,i) = 0;
end
for i=1:size(mean_intensity2,2)
    mean_intensity2(mean_intensity2(:,i)<0,i) = 0;
end
for i=1:size(mean_intensity3,2)
    mean_intensity3(mean_intensity3(:,i)<0,i) = 0;
end
for i=1:size(mean_intensity4,2)
    mean_intensity4(mean_intensity4(:,i)<0,i) = 0;
end
for i=1:size(mean_intensity5,2)
    mean_intensity5(mean_intensity5(:,i)<0,i) = 0;
end

mean_intensity = mean_intensity4;
idx1 = find(mean_intensity(:,1)>0);
idx2 = find(mean_intensity(:,end)>0);
idx3 = intersect(idx1,idx2)
[p,h,stats] = signrank(mean_intensity(idx3,1),mean_intensity(idx3,end))

figure;
plot([1:10],[mean(nonzeros(mean_intensity1(:,1))) mean(nonzeros(mean_intensity1(:,2))) mean(nonzeros(mean_intensity1(:,3))) mean(nonzeros(mean_intensity1(:,4))) mean(nonzeros(mean_intensity1(:,5))) ...
             mean(nonzeros(mean_intensity1(:,6))) mean(nonzeros(mean_intensity1(:,7))) mean(nonzeros(mean_intensity1(:,8))) mean(nonzeros(mean_intensity1(:,9))) mean(nonzeros(mean_intensity1(:,10)))],'b','LineWidth',2); hold on
plot([1:10],[mean(nonzeros(mean_intensity1(:,1)))+std(nonzeros(mean_intensity1(:,1))) mean(nonzeros(mean_intensity1(:,2)))+std(nonzeros(mean_intensity1(:,2))) mean(nonzeros(mean_intensity1(:,3)))+std(nonzeros(mean_intensity1(:,3))) ...
            mean(nonzeros(mean_intensity1(:,4)))+std(nonzeros(mean_intensity1(:,4))) mean(nonzeros(mean_intensity1(:,5)))+std(nonzeros(mean_intensity1(:,5))) mean(nonzeros(mean_intensity1(:,6)))+std(nonzeros(mean_intensity1(:,6)))  ...
            mean(nonzeros(mean_intensity1(:,7)))+std(nonzeros(mean_intensity1(:,7))) mean(nonzeros(mean_intensity1(:,8)))+std(nonzeros(mean_intensity1(:,8))) mean(nonzeros(mean_intensity1(:,9)))+std(nonzeros(mean_intensity1(:,9))) mean(nonzeros(mean_intensity1(:,10)))+std(nonzeros(mean_intensity1(:,10)))],'b');
plot([1:10],[mean(nonzeros(mean_intensity1(:,1)))-std(nonzeros(mean_intensity1(:,1))) mean(nonzeros(mean_intensity1(:,2)))-std(nonzeros(mean_intensity1(:,2))) mean(nonzeros(mean_intensity1(:,3)))-std(nonzeros(mean_intensity1(:,3))) ...
            mean(nonzeros(mean_intensity1(:,4)))-std(nonzeros(mean_intensity1(:,4))) mean(nonzeros(mean_intensity1(:,5)))-std(nonzeros(mean_intensity1(:,5))) mean(nonzeros(mean_intensity1(:,6)))-std(nonzeros(mean_intensity1(:,6)))  ...
            mean(nonzeros(mean_intensity1(:,7)))-std(nonzeros(mean_intensity1(:,7))) mean(nonzeros(mean_intensity1(:,8)))-std(nonzeros(mean_intensity1(:,8))) mean(nonzeros(mean_intensity1(:,9)))-std(nonzeros(mean_intensity1(:,9))) mean(nonzeros(mean_intensity1(:,10)))-std(nonzeros(mean_intensity1(:,10)))],'b');

        
plot([1:4],[mean(nonzeros(mean_intensity2(:,1))) mean(nonzeros(mean_intensity2(:,2))) mean(nonzeros(mean_intensity2(:,3))) mean(nonzeros(mean_intensity2(:,4)))],'r','LineWidth',2);
plot([1:4],[mean(nonzeros(mean_intensity2(:,1)))+std(nonzeros(mean_intensity2(:,1))) mean(nonzeros(mean_intensity2(:,2)))+std(nonzeros(mean_intensity2(:,2))) ...
            mean(nonzeros(mean_intensity2(:,3)))+std(nonzeros(mean_intensity2(:,3))) mean(nonzeros(mean_intensity2(:,4)))+std(nonzeros(mean_intensity2(:,4)))],'r');
plot([1:4],[mean(nonzeros(mean_intensity2(:,1)))-std(nonzeros(mean_intensity2(:,1))) mean(nonzeros(mean_intensity2(:,2)))-std(nonzeros(mean_intensity2(:,2))) ...
            mean(nonzeros(mean_intensity2(:,3)))-std(nonzeros(mean_intensity2(:,3))) mean(nonzeros(mean_intensity2(:,4)))-std(nonzeros(mean_intensity2(:,4)))],'r');

plot([1:2],[mean(nonzeros(mean_intensity3(:,1))) mean(nonzeros(mean_intensity3(:,2)))],'g','LineWidth',2);
plot([1:2],[mean(nonzeros(mean_intensity3(:,1)))+std(nonzeros(mean_intensity3(:,1))) mean(nonzeros(mean_intensity3(:,2)))+std(nonzeros(mean_intensity3(:,2)))],'g');
plot([1:2],[mean(nonzeros(mean_intensity3(:,1)))-std(nonzeros(mean_intensity3(:,1))) mean(nonzeros(mean_intensity3(:,2)))-std(nonzeros(mean_intensity3(:,2)))],'g');

plot([1:5],[mean(nonzeros(mean_intensity4(:,1))) mean(nonzeros(mean_intensity4(:,2))) mean(nonzeros(mean_intensity4(:,3))) mean(nonzeros(mean_intensity4(:,3))) mean(nonzeros(mean_intensity4(:,5)))],'c','LineWidth',2);
plot([1:5],[mean(nonzeros(mean_intensity4(:,1)))+std(nonzeros(mean_intensity4(:,1))) mean(nonzeros(mean_intensity4(:,2)))+std(nonzeros(mean_intensity4(:,2))) ...
            mean(nonzeros(mean_intensity4(:,3)))+std(nonzeros(mean_intensity4(:,3))) mean(nonzeros(mean_intensity4(:,3)))+std(nonzeros(mean_intensity4(:,3))) mean(nonzeros(mean_intensity4(:,5)))+std(nonzeros(mean_intensity4(:,5)))],'c');
plot([1:5],[mean(nonzeros(mean_intensity4(:,1)))-std(nonzeros(mean_intensity4(:,1))) mean(nonzeros(mean_intensity4(:,2)))-std(nonzeros(mean_intensity4(:,2))) ...
            mean(nonzeros(mean_intensity4(:,3)))-std(nonzeros(mean_intensity4(:,3))) mean(nonzeros(mean_intensity4(:,3)))-std(nonzeros(mean_intensity4(:,3))) mean(nonzeros(mean_intensity4(:,5)))-std(nonzeros(mean_intensity4(:,5)))],'c');

plot([1:2],[mean(nonzeros(mean_intensity5(:,1))) mean(nonzeros(mean_intensity5(:,2)))],'m','LineWidth',2);
plot([1:2],[mean(nonzeros(mean_intensity5(:,1)))+std(nonzeros(mean_intensity5(:,1))) mean(nonzeros(mean_intensity5(:,2)))+std(nonzeros(mean_intensity5(:,2)))],'m');
plot([1:2],[mean(nonzeros(mean_intensity5(:,1)))-std(nonzeros(mean_intensity5(:,1))) mean(nonzeros(mean_intensity5(:,2)))-std(nonzeros(mean_intensity5(:,2)))],'m');
ylim([0 10])
