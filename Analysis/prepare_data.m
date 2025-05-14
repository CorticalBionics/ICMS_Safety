function [flat_scores, flat_dates] = prepare_data(resp_data, s_date)
    % covert new hot/cold temperature scores to normal temperature scores
    % (0=cold, 10=hot)
    hot_idx = find(resp_data(:,30)>5);
    resp_data(hot_idx,31) = (((resp_data(hot_idx,30)-5)/5)*10); %(hot = 5-10 temperature)
    cold_idx = find(resp_data(:,30)<=5 & resp_data(:,30) > 0);
    resp_data(cold_idx,32) = ((resp_data(cold_idx,30)/5)*10); %(cold = 0-5 temperature)
    resp_data(:,30) = []; % delete temperature intensity, keep hot and cold

    % average over multiple sensations per channel
    flat_scores = [];
    flat_dates = [];
    da = 1;
    sessions = unique(resp_data(:,2));
    for s=1:numel(sessions)
        session_data = resp_data(find(resp_data(:,2)==sessions(s)),:);
        session_date = s_date(find(resp_data(:,2)==sessions(s)));
        session_date = session_date{1};
        channels = unique(session_data(:,6));
        for c=1:numel(channels)
            idx_channel = find(session_data(:,6)==channels(c));
            channel_data = session_data(idx_channel,:);
            single_data = zeros(1,size(channel_data,2));
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
            flat_scores = [flat_scores; single_data];
            flat_dates{da} = session_date;
            da = da+1;
        end
    end
end