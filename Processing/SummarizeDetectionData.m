%%% Combine and summarize detection data across subjects
tld = 'U:\UserFolders\CharlesGreenspon\BCI_DetectionThresholds\Data';
load(fullfile(tld, 'DetectionDataAll'))

%% Make plot for each subject
u_subjects = unique({DetectionDataAll.Subject});
figure;
w = 6;
ii = 0;
for s = 1:length(u_subjects)
    % Get the subject means
    subject_idx = find(strcmp({DetectionDataAll.Subject}, u_subjects{s}));
    elec_means = [DetectionDataAll(subject_idx).MeanThreshold];
    [~,sort_idx] = sort(elec_means);
    subject_idx = subject_idx(sort_idx);

    % Make plot
    subplot(length(u_subjects), w, ii + [1,2]); hold on
        id = SubjectImplantDate(u_subjects{s}, true);
        for e = 1:length(subject_idx)
            plot(datenum(DetectionDataAll(subject_idx(e)).Dates) - id,...
                 movmedian(DetectionDataAll(subject_idx(e)).Thresholds,3) ,...
                 'Color', SubjectColors(u_subjects{s}))
        end
        xlabel('Days Since Implant')
        ylabel(sprintf('Detection Threshold (%sA)', GetUnicodeChar('mu')))

    subplot(length(u_subjects), w, ii + 3); hold on
        sub_corr = zeros(length(subject_idx),1);
        [d_all, t_all] = deal(cell(length(subject_idx),1));
        for e = 1:length(subject_idx)
            d_all{e} = datenum(DetectionDataAll(subject_idx(e)).Dates);
            t_all{e} = [DetectionDataAll(subject_idx(e)).Thresholds]';
            sub_corr(e) = corr(d_all{e}, t_all{e});
        end
        d_all = cat(1,d_all{:});
        t_all = cat(1, t_all{:});
        [r,rp] = corr(d_all, t_all, 'rows', 'complete');
        [h,tp] = ttest(sub_corr);
        Swarm(1, sub_corr, "Color", SubjectColors(u_subjects{s}), 'DS', "Box")
        set(gca, 'XLim', [.5 1.5], 'YLim', [-1 1])
        text(.6, 1, sprintf('Within: %s\nAcross: r = %0.2f, %s', pStr(tp), r, pStr(rp)))


    subplot(length(u_subjects), w, ii + [4:6]); hold on
        xt = cell(length(subject_idx),1);
        for e = 1:length(subject_idx)
            Swarm(e, DetectionDataAll(subject_idx(e)).Thresholds, 'Color', SubjectColors(u_subjects{s}),...
                "DistributionStyle", "Box", "CenterMethod", "Mean", "DistributionMethod",...
                "None", 'ErrorPercentiles', [5 25 75 95], 'ErrorMethod','Percentile')
            xt{e} = num2str(DetectionDataAll(subject_idx(e)).Channel);
        end

        set(gca, 'XTick', [1:length(subject_idx)], 'XTickLabel', xt, 'YLim', [0 100], 'XLim', [0 length(subject_idx)+1])
        xlabel('Electrode #')
%         ylabel(sprintf('Detection Threshold (%sA)', GetUnicodeChar('mu')))

    ii = ii + w;
        
end


%% Export
save(fullfile(tld, 'DetectionDataAll'), 'DetectionDataAll')