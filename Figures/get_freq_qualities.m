function [freq, pain_intensity] = get_freq_qualities(subject_data, freq_sensation)
    qualities = [16:32];
    channels = [1:64];
    
    freq = zeros(numel(channels),numel(qualities));
    pain_intensity = zeros(numel(channels),1);
    for c=1:numel(channels)
        channel_data = subject_data(subject_data(:,6)==c,:);
        if ~isempty(channel_data)
            if size(channel_data,1) > 1
                freq(c,:) = sum(channel_data(:,qualities)>0)/sum(sum(channel_data(:,14:end)>0,2)>0)*100; % how many times quality reported out of all times that a sensation was detected on this channel
            else
                freq(c,:) = [channel_data(:,qualities)>0]*100; % how many times quality reported out of all times that a sensation was detected on this channel
            end
                pain_intensity(c) = mean(channel_data(channel_data(:,16)>0,16));

            if freq_sensation(c) < 30 % less than 30% of times are sensation was detected on this channel
                freq(c,:) = zeros(size(freq(c,:)))*-1; % set to -1
                pain_intensity(c) = -1;
            end
        end
    end
end