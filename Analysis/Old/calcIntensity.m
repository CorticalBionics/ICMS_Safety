function [mean_intensity] = calcIntensity(data,qualityIdx)
    channels = [1:64];
    
    mean_intensity = zeros(numel(channels),1);
    for c=1:numel(channels)
        channel_data = data(data(:,6)==c,:);
        if ~isempty(channel_data)
            if sum(channel_data(:,qualityIdx)>0)>1 % at least two sensations detected
                mean_intensity(c) = mean(channel_data(channel_data(:,qualityIdx)>0,qualityIdx)); 
            elseif sum(channel_data(:,qualityIdx)>0)>0 % at least one sensation detected
                mean_intensity(c) = channel_data(channel_data(:,qualityIdx)>0,qualityIdx); 
            else
                mean_intensity(c) = -1;
            end            
        end
    end
end