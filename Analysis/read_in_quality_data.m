function [resp_data,response_header,s_date] = read_in_quality_data(data_folder,subject)

if strcmp(subject,'CRS02b')
    sub = 1;
elseif strcmp(subject,'CRS07')
    sub = 2;
elseif strcmp(subject,'CRS08')
    sub = 3;
elseif strcmp(subject,'BCI02')
    sub = 4;
else
    sub = 5;
end

% get all sessions for this participant
files = dir(fullfile(data_folder,subject,'OpenLoopStim')); % subject folder
dirFlags = [files.isdir]; % all files in this folder
subFolders = files(dirFlags); % extract only directories.
session = {subFolders(3:end).name}; % folder names: start at 3 to skip . and ..

% Survey reports:
%
% Quality:
% - How natural did the sensation feel: totally unnatural - totally natural (free scale)
% - Depth of sensation: skin surface, below skin, Both, None of above
% - Pain assessment scale: 0 (no pain) - 10 (worst possible)
% 
% Mechanical
% - Touch
% - Pressure
% - Tapping
% - Poke
% - Sharp
% (intensity of each is judged on 0 (faint) -10 (intense) scale)
% 
% Movement:
% - Vibration
% - buzzing
% - Sparkle
% (intensity of each is judged on 0 (faint) -10 (intense) scale)
% - body/limb/joint
% - across skin
% (1 present, or 0 not present)
% 
% Paresthesia:
% - electrical
% - tickle
% - itch
% - tingle
% (intensity of each is judged on 0 (faint) -10 (intense) scale)
% 
% Temperature
% - hot
% - cold
% (or a slider 0 (cold) - 10 (warm), in old survey)

response_header = {'subject','session','set','trial','rep','channel','amplitude','frequency','duration','nrSensations',...
                    'Depth (1 = skin surface, 2 = below skin, 3 = both, 0 = none of above, 4 = above skin, 5 = below and above, 6 = above and surface, 7 = above, below and surface)', ...
                    'Movement-Body/limb/joint (0-10)','Movement-across skin (0-10)',...
                    'Intensity (free scale)',...
                    'Naturalness (free scale)','Pain (0=no pain, 10 = worst possible)',...
                    'Mechanical-Touch (0-10)', 'Mechanical-Pressure (0-10)','Mechanical-Tapping (0-10)',...
                    'Mechanical-Poke (0-10)', 'Mechanical-Sharp (0-10)',...
                    'Movement-Vibration (0-10)','Movement-Buzzing (0-10)','Movement-Sparkle(0-10)', 'Movement-Flutter(0-10)'...
                    'Paresthesia - Electrical (0-10)', 'Paresthesia - Tickle (0-10)', 'Paresthesia - Itch (0-10)',...
                    'Paresthesia - Tingle (0-10)', 'Temperature (0=cold, 10=hot)', 'Hot', 'Cold', 'Other'};
                
resp_data = [];
s_date = {};
da = 1;
for s=1:numel(session)
    cd(fullfile(data_folder,subject,'OpenLoopStim',session{s})); % go to current session directory
    stimFiles = dir(['StimData.','*.mat']); % get all stim files in this session
    selectedStim = [];
    tr = 1;
    for ss=1:numel(stimFiles) % for each stim file
        file = stimFiles(ss).name; % current stim file
        trial_identifier = split(erase(erase(file,'StimData.'),'*.mat'),'.');
        trialFiles = dir(['StimData.',trial_identifier{1},'.',trial_identifier{2},'.',trial_identifier{3},'*.mat']); % get corresponding StimData file
        stimdata = load(trialFiles(end).name);
        stimdata = stimdata.stimDataObj;
        if strcmp(stimdata.trialType, 'Parameter Variation') || strcmp(stimdata.trialType, 'SurveyData') && ~iscell(stimdata.amplitude)
            stimAmp = stimdata.amplitude;
            stimFreq = stimdata.frequency;
            stimDur = stimdata.duration;
            if ~isempty(stimAmp)
                if stimAmp >= 60 && stimFreq == 100 && stimDur == 1 % select only 60uA, 100Hz, 1sec stims (standard survey)
                    selectedStim{tr} = trialFiles(end).name; % get stim file of last rep only
                    tr = tr+1;
                end
            end
        end
    end
    selectedStim = unique(selectedStim);
    numel(selectedStim)
    
    stim_channels = [];
    
    allRespFiles = dir(['Resp.','*_RadioCheckSlider.yml']); % check if there are any response files
    survey_data = 1;
    if isempty(allRespFiles)
        survey_data = 0;
    end

    for ss=1:numel(selectedStim) % go through selected stim files
        file = selectedStim{ss}; % current stim file    
        stimdata = load(file);
        % find corresponding stim channel
        stimdata = load(file);
        stimdata = stimdata.stimDataObj;
        stimChannel = stimdata.channel;
        if numel(stimChannel)==1
            if strcmp(subject,'CRS07') && strcmp(session{s},'CRS07Home.data.00052') % cerestim was swapped
                if stimChannel > 32
                    stimChannel = stimChannel - 32;
                else 
                    stimChannel = stimChannel + 32;
                end
            end
            stim_channels = [stim_channels; stimChannel];
            session_date = stimdata.sessionInfo.date;

            % stim parameters
            stimAmp = stimdata.amplitude;
            stimFreq = stimdata.frequency;
            stimDur = stimdata.duration;

            trial_identifier = split(erase(erase(file,'StimData.'),'*.mat'),'.');
            trial = str2num(erase(trial_identifier{3},'Trial'));
            set = str2num(erase(trial_identifier{1},'Set'));
            rep = str2num(erase(trial_identifier{4},'Rep'));
            respFiles = dir(['Resp.',trial_identifier{1},'.',trial_identifier{3},'*_RadioCheckSlider.yml']); % get corresponding response file
            
            

            if isempty(respFiles) && survey_data == 1 % no sensation detected
                resp_data = [resp_data; sub s set trial rep stimChannel stimAmp stimFreq stimDur 0 0 ...
                                0 0 0 ...
                                0 0 0 0 0 ...
                                0 0 0 0 0 ...
                                0 0 0 0 ...
                                0 0 0 0 0];
                s_date{da} = session_date;
                da = da+1;
            elseif survey_data == 0 % survey data not present
                OLSfile = dir(['OLSData','*.mat']);
                if ~isempty(OLSfile)
                    OLSData = load(OLSfile.name);
                    OLSData = OLSData.(erase(OLSfile.name,'.mat'));

                    % intensity, naturalness, pain, touch, pressure, sharp,
                    % poke, sparkle, flutter, vibration, buzzing, tapping,
                    % BodyLimbJoint, AcrossSkin, Electrical, Tickle, Itch,
                    % Tingle, Hot, Cold, Other

                    % responses
                    OLSset = find([OLSData.Set] == set);
                    nrSensations = OLSData(OLSset).SDO.SensationID+1;

                    for sen=1:nrSensations % add each sensation
                        qualityOLS = OLSData(OLSset).SDO.Quality(sen,:);

                        % overall intensity
                        intensity = qualityOLS.Intensity;

                        % naturalness
                        naturalness = qualityOLS.Naturalness;

                        % depth
                        if sum([OLSData(OLSset).SDO.Location(sen).SkinSurface, OLSData(OLSset).SDO.Location(sen).BelowSkin, OLSData(OLSset).SDO.Location(sen).AboveSkin])>0
                            depth = -2;
                            if OLSData(OLSset).SDO.Location(sen).SkinSurface == 1
                                depth = 1;
                            end
                            if OLSData(OLSset).SDO.Location(sen).BelowSkin == 1
                                depth = 2;
                            end
                            if OLSData(OLSset).SDO.Location(sen).SkinSurface == 1 && OLSData(OLSset).SDO.Location(sen).BelowSkin == 1
                                depth = 3;
                            end
                            if OLSData(OLSset).SDO.Location(sen).AboveSkin == 1
                                depth = 4;
                            end
                            if OLSData(OLSset).SDO.Location(sen).AboveSkin == 1 && OLSData(OLSset).SDO.Location(sen).BelowSkin == 1
                                depth = 5;
                            end
                            if OLSData(OLSset).SDO.Location(sen).AboveSkin == 1 && OLSData(OLSset).SDO.Location(sen).SkinSurface == 1
                                depth = 6;   
                            end
                            if OLSData(OLSset).SDO.Location(sen).SkinSurface == 1 && OLSData(OLSset).SDO.Location(sen).AboveSkin == 1 && OLSData(OLSset).SDO.Location(sen).BelowSkin == 1
                                depth = 7;  
                            end
                        else
                            depth = -1;
                        end

                        % pain
                        pain = qualityOLS.Pain;

                        % Mechanical
                        touch = qualityOLS.Touch;
                        pressure = qualityOLS.Pressure;
                        tapping = qualityOLS.Tapping;
                        poke = qualityOLS.Tapping;
                        sharp = qualityOLS.Sharp;

                        % Movement
                        vibration = qualityOLS.Vibration;
                        buzzing = qualityOLS.Buzzing;
                        sparkle = qualityOLS.Sparkle;
                        if isfield(qualityOLS,'Flutter')
                            flutter = qualityOLS.Flutter;
                        else
                            flutter = -1;
                        end

                        acrossSkin = qualityOLS.AcrossSkin;
                        body = qualityOLS.BodyLimbJoint;

                        % Paresthesia
                        %
                        % Electrical
                        electrical = qualityOLS.Electrical;

                        % Tickle
                        tickle = qualityOLS.Tickle;
                        itch = qualityOLS.Itch;
                        tingle = qualityOLS.Tingle;

                        % Hot
                        hot = qualityOLS.Hot;
                        cold = qualityOLS.Cold;
                        temp = -1;
                        other = qualityOLS.Other;

                        resp_data = [resp_data; sub s set trial rep stimChannel stimAmp stimFreq stimDur nrSensations ...
                                    depth body acrossSkin ...
                                    intensity naturalness pain ...
                                    touch pressure tapping poke sharp ...
                                    vibration buzzing sparkle flutter ...
                                    electrical tickle itch tingle ...
                                    temp hot cold other];

                        s_date{da} = session_date;
                        da = da+1;
                    end 
                end
            else % sensation detected, survey data present
                for r=1:numel(respFiles)
                    resp = yaml.loadFile(respFiles(r).name);

                    % responses
                    sensationNames = fieldnames(resp);
                    nrSensations = numel(sensationNames);

                    for sen=1:nrSensations % add each sensation

                         % overall intensity
                        if isfield(resp.(sensationNames{sen}),'intensitySlider')
                            intensity = resp.(sensationNames{sen}).intensitySlider;
                        else
                            intensity = -1;
                        end

                        % naturalness
                        if isfield(resp.(sensationNames{sen}),'naturalSlider')
                            naturalness = resp.(sensationNames{sen}).naturalSlider;
                        else
                            naturalness = 0;
                        end

                        % depth
                        if isfield(resp.(sensationNames{sen}),'depth')
                            depth = -2;
                            if strcmp(resp.(sensationNames{sen}).depth,'Skin surface') || isfield(resp.(sensationNames{sen}).depth,'SkinSurface')
                                depth = 1;
                            end
                            if strcmp(resp.(sensationNames{sen}).depth,'Below skin') || isfield(resp.(sensationNames{sen}).depth,'BelowSkin')
                                depth = 2;
                            end
                            if strcmp(resp.(sensationNames{sen}).depth,'Both') || (isfield(resp.(sensationNames{sen}).depth,'SkinSurface') && isfield(resp.(sensationNames{sen}).depth,'BelowSkin'))
                                depth = 3;
                            end
                            if strcmp(resp.(sensationNames{sen}).depth,'None of above') || (isstruct(resp.(sensationNames{sen}).depth) && length(fieldnames(resp.(sensationNames{sen}).depth))==0)
                                depth = 0;
                            end
                            if strcmp(resp.(sensationNames{sen}).depth,'Above Skin') || isfield(resp.(sensationNames{sen}).depth,'AboveSkin')
                                depth = 4;
                            end
                            if isfield(resp.(sensationNames{sen}).depth,'AboveSkin') && isfield(resp.(sensationNames{sen}).depth,'BelowSkin')
                                depth = 5;
                            end
                            if isfield(resp.(sensationNames{sen}).depth,'AboveSkin') && isfield(resp.(sensationNames{sen}).depth,'SkinSurface')
                                depth = 6;   
                            end
                            if isfield(resp.(sensationNames{sen}).depth,'AboveSkin') && isfield(resp.(sensationNames{sen}).depth,'SkinSurface') && isfield(resp.(sensationNames{sen}).depth,'BelowSkin')
                                depth = 7;  
                            end
                        else
                            depth = -1;
                        end

                         % pain
                        if isfield(resp.(sensationNames{sen}),'painSlider')
                            pain = resp.(sensationNames{sen}).painSlider;
                        else
                            pain = 0;
                        end

                        % Mechanical
                        if isfield(resp.(sensationNames{sen}),'mechIntensitySlider') % old survey with a single intensity
                            if isfield(resp.(sensationNames{sen}),'mechanical')
                                % get list of reported sensations
                                mechSensations = [];
                                for m=1:numel(resp.(sensationNames{sen}).mechanical)
                                    if numel(resp.(sensationNames{sen}).mechanical) > 1
                                        mechSensations{m} = cell2mat(resp.(sensationNames{sen}).mechanical{m});
                                    else
                                        mechSensations = resp.(sensationNames{sen}).mechanical{m};
                                    end
                                end

                                % touch
                                if ismember('Touch',mechSensations)
                                    touch = resp.(sensationNames{sen}).mechIntensitySlider;
                                else
                                    touch = 0;
                                end

                                % pressure
                                if ismember('Pressure',mechSensations)
                                    pressure = resp.(sensationNames{sen}).mechIntensitySlider;
                                else
                                    pressure = 0;
                                end

                                % tapping
                                if ismember('Tapping',mechSensations)
                                    tapping = resp.(sensationNames{sen}).mechIntensitySlider;
                                else
                                    tapping = 0;
                                end

                                % poke
                                if ismember('Poke',mechSensations)
                                    poke = resp.(sensationNames{sen}).mechIntensitySlider;
                                else
                                    poke = 0;
                                end

                                % sharp
                                if ismember('Sharp',mechSensations)
                                    sharp = resp.(sensationNames{sen}).mechIntensitySlider;
                                else
                                    sharp = 0;
                                end
                            end
                        elseif isfield(resp.(sensationNames{sen}),'mechanical')
                            if isfield(resp.(sensationNames{sen}).mechanical,'Touch')
                                touch = resp.(sensationNames{sen}).mechanical.Touch;
                            else
                                touch = 0;
                            end
                            if isfield(resp.(sensationNames{sen}).mechanical,'Pressure')
                                pressure = resp.(sensationNames{sen}).mechanical.Pressure;
                            else
                                pressure = 0;
                            end
                            if isfield(resp.(sensationNames{sen}).mechanical,'Tapping')
                                tapping = resp.(sensationNames{sen}).mechanical.Tapping;
                            else
                                tapping = 0;
                            end
                            if isfield(resp.(sensationNames{sen}).mechanical,'Poke')
                                poke = resp.(sensationNames{sen}).mechanical.Poke;
                            else
                                poke = 0;
                            end
                            if isfield(resp.(sensationNames{sen}).mechanical,'Sharp')
                                sharp = resp.(sensationNames{sen}).mechanical.Sharp;
                            else
                                sharp = 0;
                            end
                        else
                            touch = 0;
                            pressure = 0;
                            tapping = 0;
                            poke = 0;
                            sharp = 0;
                        end

                        % Movement
                        if isfield(resp.(sensationNames{sen}),'moveIntensitySlider') % old survey with a single intensity  
                            if isfield(resp.(sensationNames{sen}),'movement')
                                % get list of reported sensations
                                moveSensations = [];
                                for m=1:numel(resp.(sensationNames{sen}).movement)
                                    if numel(resp.(sensationNames{sen}).movement) > 1
                                        moveSensations{m} = cell2mat(resp.(sensationNames{sen}).movement{m});
                                    else
                                        moveSensations = resp.(sensationNames{sen}).movement{m};
                                    end
                                end

                                % Vibration
                                if ismember('Vibration',moveSensations)
                                    vibration = resp.(sensationNames{sen}).moveIntensitySlider;
                                else
                                    vibration = 0;
                                end

                                % Buzzing
                                if ismember('Buzzing',moveSensations)
                                    buzzing = resp.(sensationNames{sen}).moveIntensitySlider;
                                else
                                    buzzing = 0;
                                end

                                % Sparkle
                                if ismember('Sparkle',moveSensations)
                                    sparkle = resp.(sensationNames{sen}).moveIntensitySlider;
                                else
                                    sparkle = 0;
                                end
                            end
                        elseif isfield(resp.(sensationNames{sen}),'movement')
                            if isfield(resp.(sensationNames{sen}).movement,'Vibration')
                                vibration = resp.(sensationNames{sen}).movement.Vibration;
                            else
                                vibration = 0;
                            end
                            if isfield(resp.(sensationNames{sen}).movement,'Buzzing')
                                buzzing = resp.(sensationNames{sen}).movement.Buzzing;
                            else
                                buzzing = 0;
                            end
                            if isfield(resp.(sensationNames{sen}).movement,'Sparkle')
                                sparkle = resp.(sensationNames{sen}).movement.Sparkle;
                            else
                                sparkle = 0;
                            end
                            if isfield(resp.(sensationNames{sen}).movement,'Flutter')
                                flutter = resp.(sensationNames{sen}).movement.Flutter;
                            else
                                flutter = 0;
                            end
                        else
                            vibration = 0;
                            buzzing = 0;
                            sparkle = 0;
                            flutter = 0;
                        end

                        if isfield(resp.(sensationNames{sen}),'movement_directional')
                            % get list of reported sensations
                            moveSensations = [];
                            for m=1:numel(resp.(sensationNames{sen}).movement_directional)
                                if numel(resp.(sensationNames{sen}).movement_directional) > 1
                                    moveSensations{m} = cell2mat(resp.(sensationNames{sen}).movement_directional{m});
                                else
                                    moveSensations = resp.(sensationNames{sen}).movement_directional{m};
                                end
                            end

                            % across skin
                            if ismember('Across skin',moveSensations)
                                acrossSkin = 1;
                            else
                                acrossSkin = 0;
                            end

                            % Body/limb/joint
                            if ismember('Body/limb/joint',moveSensations)
                                body = 1;
                            else
                                body = 0;
                            end
                        else
                            acrossSkin = 0;
                            body = 0;
                        end

                        % in new survey, parastheasia sensations include the intensity
                        % directly. The old one has a separate e.g. tingleIntensitySlider
                        % field.

                        % Paresthesia
                        %
                        % Electrical
                        if isfield(resp.(sensationNames{sen}),'electrical')
                            if isfield(resp.(sensationNames{sen}),'electricalIntensitySlider')
                                electrical = resp.(sensationNames{sen}).electricalIntensitySlider;
                            else
                                if isfield(resp.(sensationNames{sen}).electrical,'Electrical')
                                    electrical = resp.(sensationNames{sen}).electrical.Electrical;
                                else
                                    electrical = 0;
                                end
                            end
                        else
                            electrical = 0;
                        end

                        % Tickle
                        if isfield(resp.(sensationNames{sen}),'tickle')
                            if isfield(resp.(sensationNames{sen}),'tickleIntensitySlider')
                                tickle = resp.(sensationNames{sen}).tickleIntensitySlider;
                            else
                                if isfield(resp.(sensationNames{sen}).tickle,'Tickle')
                                    tickle = resp.(sensationNames{sen}).tickle.Tickle;
                                else
                                    tickle = 0;
                                end
                            end
                        else
                            tickle = 0;
                        end

                        % Itch
                        if isfield(resp.(sensationNames{sen}),'itch')
                            if isfield(resp.(sensationNames{sen}),'itchIntensitySlider')
                                itch = resp.(sensationNames{sen}).itchIntensitySlider;
                            else
                                if isfield(resp.(sensationNames{sen}).itch,'Itch')
                                    itch = resp.(sensationNames{sen}).itch.Itch;
                                else
                                    itch = 0;
                                end
                            end
                        else
                            itch = 0;
                        end

                        % Tingle
                        if isfield(resp.(sensationNames{sen}),'tingle')
                            if isfield(resp.(sensationNames{sen}),'tingleIntensitySlider')
                                tingle = resp.(sensationNames{sen}).tingleIntensitySlider;
                            else
                                if isfield(resp.(sensationNames{sen}).tingle,'Tingle')
                                    tingle = resp.(sensationNames{sen}).tingle.Tingle;
                                else
                                    tingle = 0;
                                end
                            end
                        else
                            tingle = 0;
                        end

                        % in new survey Temperature is judged for Hot (0-10) or Cold (0-10)
                        % Temperature (0=cold, 10=hot)
                        if isfield(resp.(sensationNames{sen}),'temperature') 
                            if isfield(resp.(sensationNames{sen}).temperature,'Hot')
                                hot = resp.(sensationNames{sen}).temperature.Hot;
                                temp = 0;
                                cold = 0;
                            end
                            if isfield(resp.(sensationNames{sen}).temperature,'Cold')
                                cold = resp.(sensationNames{sen}).temperature.Cold; % never happens for CRS02b
                                temp = 0;
                                hot = 0;
                            end
                            if ~isfield(resp.(sensationNames{sen}).temperature,'Cold') && ~isfield(resp.(sensationNames{sen}).temperature,'Hot')
                                if length(fieldnames(resp.(sensationNames{sen}).temperature)) == 0
                                    temp = 0;
                                else
                                    temp = resp.(sensationNames{sen}).temperature;
                                end
                                hot = 0;
                                cold = 0;
                            end
                        elseif isfield(resp.(sensationNames{sen}),'tempSlider')
                            temp = resp.(sensationNames{sen}).tempSlider;
                            cold = 0;
                            hot = 0;
                        else
                            temp = 0;
                            cold = 0;
                            hot = 0;
                        end

                        if isfield(resp.(sensationNames{sen}),'other') 
                            other = resp.(sensationNames{sen}).Other;
                        else
                            other = -1;
                        end


                        % make data corrections based on lab log
                        if strcmp(subject,'CRS02b')
                            if strcmp(session{s},'CRS02bLab.data.00441') && strcmp(trial_identifier{2},'Trial0011')
                                acrossSkin = 0;
                            end
                            if strcmp(session{s},'CRS02bLab.data.00398') && stimChannel == 25
                                tingle = 1;
                            end
                            if strcmp(session{s},'CRS02bHome.data.00111') && stimChannel == 23
                                tingle = 1;
                            end
                            if strcmp(session{s},'CRS02bLab.data.00436') && stimChannel == 17
                                pressure = 1;
                            end
                        end   

                        resp_data = [resp_data; sub s set trial rep stimChannel stimAmp stimFreq stimDur nrSensations ...
                                    depth body acrossSkin ...
                                    intensity naturalness pain ...
                                    touch pressure tapping poke sharp ...
                                    vibration buzzing sparkle flutter ...
                                    electrical tickle itch tingle ...
                                    temp hot cold other];

                        s_date{da} = session_date;
                        da = da+1;
                    end  
                end
            end
        end 
    end
    unique(resp_data(resp_data(:,2)==s,4))';
    sort(stim_channels)';
end
save([subject,'_resp_data.mat'],'resp_data','response_header','s_date');