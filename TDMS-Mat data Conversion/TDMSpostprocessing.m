function [matfiles] = TDMSpostprocessing(input_dir, savedir)
% input :                 - Manually choose TDMS files to process
% 
% output:  srcpath        - path of processed TDMS files
%          tdmsfilelist   - cell array containing list of processed TDMS files
%
% Prompts user to select tdms files in which to parse through digital events.  Outputs a .mat file
% with struct variable "tdmsdata" containing data from stimulation channels and ConfigLog.
% Channels consists of fields:   |  Sets of Configlog consists of fields:
%                                |   
% snippet:  m x n                |   SpikeStartIndexSystem:  char
% mavV:     1 x n                |   Starttime:              int     
% minV:     1 x n                |   ChanConfig:             1 x 12
% inter:    1 x n                |   AmpConfig:              1 x 12
% timestamp 1 x n                |   
% moduleid  1 x n                |
%
%{n = number of stimulations (freq), (m = 160: hardcoded snippet length}

timeoffset          = 30;  % Choose an offset value to extract data:                                 
threshold           = 150; % Choose a time threshold for classifying DE to new configchan messages:  
filelimit           = 1e9; % Choose a filelimit theshold to pass data processing to new script:      
% offsetind           = 6;   % Choose an offset index to find interphase value

% Select TDMS files to process
% dataPath               = 'P:\data_raw\human\crs_array\CRS02\OpenLoopStim';
% [tdmsfiles,input_dir]  = uigetfile([dataPath,filesep,'*.tdms'],'Please Select Files to load','MultiSelect','on');
% if ~iscell(tdmsfiles)
%    tdmsfiles = {tdmsfiles};
% end
tdmsfiles = dir(fullfile(input_dir, '*.tdms'));
tdmsfiles = {tdmsfiles.name};


% Select directory to save converted TDMS files
% savedir   = uigetdir('P:\analysis\human\crs_array\CRS02\DataConversion\OpenLoopStim');
% savedir   = [savedir filesep];

% If tdms file has already been converted --> remove from list
matfiles        = regexprep(tdmsfiles,'tdms','mat');
for filescmp_idx = 1:length(tdmsfiles) 
    if  ~isempty(dir([savedir matfiles{filescmp_idx}]))
        tdmsfiles{filescmp_idx} = [];
    end
end

tdmsfiles = tdmsfiles(~cellfun(@isempty,tdmsfiles));
matfiles  = regexprep(tdmsfiles,'tdms','mat');
% skip post processing if mat files already exist
if isempty(tdmsfiles)
    disp('The selected TDMS files have already been converted.'); 
    return
end

% Find associative QL files to process
dirdata        = dir(input_dir);
dirfiles       = {dirdata.name};
indbin         = ~cellfun(@isempty, regexp(dirfiles, '.bin')) & cellfun(@isempty, regexp(dirfiles, '.Dump.'));
ql_files       = dirfiles(indbin);
startQLcmpr    = regexp(ql_files{1},'Set');
endQLcmpr      = regexp(ql_files{1},'-');
cmprQLsrc      = char(ql_files);
temp_cmprQLsrc = cmprQLsrc(:,startQLcmpr:endQLcmpr(1));
temp_cmprQLsrc = temp_cmprQLsrc(:,1:end-4);
temp_cmprQLsrc = cellstr(temp_cmprQLsrc);
% [~,iunique,~]  = unique(temp_cmprQLsrc,'rows');
% ql_files       = ql_files(iunique);
% temp_cmprQLsrc = cellstr(temp_cmprQLsrc(iunique,:));

startTDMScmpr    = regexp(tdmsfiles{1},'Set');
endTDMScmpr      = regexp(tdmsfiles{1},'-');
cmprTDMSsrc      = char(tdmsfiles);
temp_cmprTDMSsrc = cmprTDMSsrc(:,startTDMScmpr:endTDMScmpr(1));
temp_cmprTDMSsrc = temp_cmprTDMSsrc(:,1:end-3);
temp_cmprTDMSsrc = cellstr(temp_cmprTDMSsrc);
matches          = false(length(temp_cmprQLsrc),1);
for cmprind = 1:length(temp_cmprTDMSsrc)
    matches = matches + strcmp(temp_cmprTDMSsrc(cmprind),temp_cmprQLsrc); %regexp(temp_cmprQLsrc,temp_cmprTDMSsrc,'match');
end
ql_files    = ql_files(logical(matches));
ql_path     = input_dir;

matfiles  = matfiles(~cellfun(@isempty,matfiles));
matfiles  = strcat(savedir,matfiles);   % Add path to the front of matfiles
ql_files  = ql_files(~cellfun(@isempty,ql_files));

ignorelist = {'ACKNOWLEDGE', 'AJA_CONFIG', 'CERESTIM_ALIVE', 'CERESTIM_CONFIG_CHAN_ARBITRARY',...
        'CERESTIM_CONFIG_CHAN_PRESAFETY_ARBITRARY', 'CERESTIM_CONFIG_MODULE',...
        'CS_TRAIN_END', 'DEBUG_TEXT', 'MESSAGE_LOG_SAVED', 'PAUSE_SUBSCRIPTION',...
        'PICDISPLAY', 'PLAYSOUND', 'SPM_ANALOGDATA', 'SPM_ANALOGDATA', ...
        'REJECTED_SNIPPET', 'RESUME_SUBSCRIPTION', 'PHASE_RESULT', 'DISABLED_UNITS',...
        'SAVE_MESSAGE_LOG', 'SPM_CTSDATA', 'SUBSCRIBE', 'TASK_STATE_CONFIG',...
        'TDMS_CREATE', 'TIMING_MESSAGE', 'UC_MECH_STIM_CONFIGURE', 'BLOCK_START',...
        'NORMALIZATION_FACTOR', 'MUJOCO_VR_REQUEST_STATE', 'MUJOCO_VR_REPLY_STATE',...
        'MUJOCO_VR_MOTOR_MOVE', 'MUJOCO_VR_MSG', 'MUJOCO_VR_MOCAP_MOVE', ...
        'MUJOCO_GHOST_COLOR', 'CONTROL_SPACE_FEEDBACK', 'CONTROL_SPACE_COMMAND',...
        'EXEC_SCORE', 'EXTRACTION_RESPONSE', 'FINISHED_COMMAND', 'GRIPPER_FEEDBACK',...
        'GRIP_COMMAND', 'GRIP_FINISHED_COMMAND', 'PHASE_RESULT',...
        'RAW_SPIKECOUNT_N256', 'SET_START','SPM_SPIKECOUNT', 'SPIKE_SNIPPET','RAW_CTSDATA_N256',...
        'RAW_ANALOGDATA'};


% Loop through list of tdms files on each iteration to process
msg = '';
for TDMSfile_num = 1:length(tdmsfiles)
    msg = InlineProgressBar('Loading TDMS file %d/%d', [f,length(tdmsfiles)], msg);
    % fprintf('Processing TDMSfile %s\n\t\t File number:\t %d of %d \n',tdmsfiles{TDMSfile_num}, TDMSfile_num,length(tdmsfiles));
    filename       = fullfile(input_dir, tdmsfiles{TDMSfile_num});
    savefile       = fullfile(savedir, tdmsfiles{TDMSfile_num});
    fileinfo       = dir(filename);
    filesize       = fileinfo.bytes;
    
    % select the associated QL file to process   
    cur_cmprTDMSsrc     = temp_cmprTDMSsrc{TDMSfile_num};
    matches             = ~cellfun(@isempty, regexp(ql_files,cur_cmprTDMSsrc));
    quickfile           = fullfile(ql_path,ql_files(matches));
    % [~,idata]           = prepData('files',quickfile, 'get_full_log', ignorelist);
    idata = Raw2Intermediate(char(ql_path), ql_files(matches), ignorelist, false);
    if isempty(idata)
        % sprintf('prepData failed to pick up data.  Moving to next file...\n');
        continue
    end
    if filesize > filelimit 
        % fprintf('NOTE:  Large TDMS file... filesize: %d \n',filesize);
        TDMSpostprocessor_LF(timeoffset,threshold,filename,tdmsfiles,idata,savefile);
        continue
    end
    
    % Store QL data
    
    ql_fields = ~isfield(idata.QL.Data,{'STIM_SYNC_EVENT','STIM_UPDATE_EVENT'});
    if ql_fields(1) > 0
        % fprintf('Warning: STIM_SYNC_EVENT was not recorded for this file. %s \n Moving to next file... \n', filename); 
        matfiles{TDMSfile_num} = [];
        continue  
    end
    
    de_si   = idata.QL.Data.STIM_SYNC_EVENT.source_index == 0;
    de_ts   = idata.QL.Data.STIM_SYNC_EVENT.source_timestamp(de_si);
    
    if ql_fields(2) > 0
        cc_ts   = 'STIM_UPDATE_EVENT was not recorded for this file';
        % fprintf('Warning:  STIM_UPDATE_EVENT was not recorded for this file... continuing anyway... \n');
    else
        cc_si   = idata.QL.Data.STIM_UPDATE_EVENT.source_index == 0;
        cc_ts   = idata.QL.Data.STIM_UPDATE_EVENT.source_timestamp(cc_si);
    end
    
    [raw_data,~] = TDMS_readTDMSFile(filename);
    
    start_ind = 0;
    for prop_ind = 1:length(raw_data.propValues)
        start_ind = strcmp(raw_data.propNames{prop_ind},'wf_start_time');
        if any(start_ind)
            [~,start_ind] = find(start_ind);
            break
        end
    end
    if start_ind == 0
        fprintf('error reading TDMS file, moving to next file...\n');
        continue
    end
    wf_start     = raw_data.propValues{1,prop_ind}{1,start_ind};
%     if length(raw_data.propValues{1,3}) ~= 6
%         matfiles{TDMSfile_num} = [];
%         continue
%     end

    % If there aren't groups for Digital_Events or Untitled, skip to next file
    cmflag = 0;
    if length(raw_data.chanNames) ~= 4
        fprintf('Warning: Unexpected list of groups: \n');
        fprintf(' - %s \n',raw_data.groupNames{:});
        if ~any(strcmp(raw_data.groupNames,'Digital Events')) || ~any(strcmp(raw_data.groupNames,'Untitled'))
            fprintf('Skipping file %s\n',tdmsfiles{TDMSfile_num});
            matfiles{TDMSfile_num} = [];
            continue
        end
        cmflag = 1;
    end

    configmod_dim  = 15;
    configchan_dim = 12;
    if cmflag
        configmod      = idata.QL.Data.CERESTIM_CONFIG_MODULE;  % different output format from Formatconfigmod.  If there are multiple msgs and cmflag is raise this will result in an error
    else
        configmod      = Formatconfigmod(raw_data,configmod_dim);
    end
    configchan     = Formatconfigchan(raw_data,configchan_dim);  % No mechanism to handle 

    % Store list of Analog input channels recorded in TDMS file 
    aiIndexes = cell2mat(raw_data.chanIndices(strcmp(raw_data.groupNames,'Untitled')));
    deIndexes = cell2mat(raw_data.chanIndices(strcmp(raw_data.groupNames,'Digital Events')));
    ai_data   = raw_data.data(aiIndexes(3:end));
    de_data   = raw_data.data(deIndexes);
    
    if isempty(de_ts) || isempty(cell2mat(de_data))
        fprintf('Warning:  No digital events logged for this file:  %s \n Moving to next TDMS file...\n',filename)
        matfiles{TDMSfile_num} = [];
        continue
    end
    % Store Config setup information in ConfigLog
    tdmsdata.SystemStarttime  = wf_start;
  
    % Parse through Digital data
    [msgDEtable, stimDEtable, tdmsdata]       = Trgsnips(tdmsdata,timeoffset,de_data);

    % Store Messages (Data and timestamps)
    tdmsdata.Messages.ChanConfig.time       = cc_ts;
    tdmsdata.Messages.ChanConfig.data       = configchan;
    tdmsdata.Messages.ModConfig.data        = configmod;

    %  Create Channel Fields
    tdmsdata.Data(64) = struct('snippet',[],'maxV',[],'minV',[],'inter',[],'stimAmp',[],'timestamps',[],'ChanConfigMessageID',[],'DAQmod',[]);

    %  Store QuickLogger data
    % tdmsdata.QLdata                 = idata;
    % tdmsdata.DEtimetable            = stimDEtable(:,1)+timeoffset;

    % Begin TDMS postprocessing
    tdmsmrkr_idx = 1;
    mod_idx      = 1;

    if ~isempty(msgDEtable)
        for tbl_idx = 1:length(stimDEtable(:,1))
            % Compares channel configuration indexes stamps with Digital event indexes stamps to allocate data to new field
            if length(msgDEtable) > tdmsmrkr_idx && msgDEtable(tdmsmrkr_idx+1)-threshold < stimDEtable(tbl_idx,1) 
                tdmsmrkr_idx = tdmsmrkr_idx + 1;
            end
            if  length(configmod) > mod_idx && tbl_idx > idata.QL.Data.CERESTIM_CONFIG_CHAN.reps(mod_idx)
                mod_idx = mod_idx + 1;
            end
            for aichan_idx = 1:12  % **can be determined by num of channels
                if  configchan.pattern(aichan_idx,tdmsmrkr_idx) > 0 
                    chanID     = configchan.channel(aichan_idx,tdmsmrkr_idx);             
                    modID      = ['Analog_mod' num2str(aichan_idx-1)];
                    pattern    = tdmsdata.Messages.ChanConfig.data.pattern(aichan_idx,tdmsmrkr_idx);
                    stimamp    = tdmsdata.Messages.ModConfig.data(mod_idx).amp1(pattern);
                    
                    if stimDEtable(tbl_idx,2) > length(ai_data{1,aichan_idx})
                        continue
                    end
                    chan_data = ai_data{1,aichan_idx}(stimDEtable(tbl_idx,1):stimDEtable(tbl_idx,2));
                    tdmsdata.Data(chanID).snippet(:,end+1)   = chan_data';
                    tdmsdata.Data(chanID).maxV(end+1,:)      = max(chan_data);
                    tdmsdata.Data(chanID).minV(end+1,:)      = min(chan_data);
                    [~,minind]                               = min(chan_data);
                     % tdmsdata.Data(chanID).inter(end+1,:)     = chan_data(minind + configmod.interphase(1)/10);
                    if tbl_idx <= length(de_ts)
                        tdmsdata.Data(chanID).timestamps(end+1,:)                 = de_ts(tbl_idx);
                    end
                    tdmsdata.Data(chanID).ChanConfigMessageID(end+1,:)        = tdmsmrkr_idx;
                    tdmsdata.Data(chanID).stimAmp(end+1,:)                    = stimamp; 
                    tdmsdata.Data(chanID).DAQmod(end+1,:)                     = modID;
                else
                    break
                end                    
           end      
        end
    else
        disp('This TDMS file was not processed because there are no ConfigIDs listed')
    end
    matfiles    = matfiles(~cellfun(@isempty,matfiles));
    tdmsdata = tdmsdata.Data;
    save(regexprep(savefile,'.tdms','.mat'),'tdmsdata');
    clear tdmsdata;
end
% disp('TDMS post-processing complete.');
end

function [msgDEtable, stimDEtable, tdmsdata] = Trgsnips(tdmsdata,timeoffset,de_data)
%Trgsnips Summary of this function goes here
%   Parses through digital data and returns 2D array of indexed event
%   and data range to extract
%   inputs:   ddata, wf_increment
%   outputs:  stimDEtable, timestamp
stimDEtable      = [];    
stimDEtable(:,2) = cell2mat(de_data(1))-timeoffset;
if stimDEtable(1,2) < 1
    stimDEtable(1,2) = 1;
end
if isempty(cell2mat(de_data(2)))
    msgDEtable(:,1)  = 1;
else
    msgDEtable(:,1)  = cell2mat(de_data(2));
end

logstimdiff      = vertcat(true,diff(stimDEtable(:,2)) > 0);
if any(~logstimdiff)
    sprintf('Disregarding digital event markers recorded at index %d\n',find(~logstimdiff));
    tdmsdata.DEdump = find(~logstimdiff);
end
stimDEtable      = stimDEtable(logstimdiff,:);
stimDEtable(:,1) = stimDEtable(:,2) + 159;  % Hardcoded snippet length
stimDEtable      = fliplr(stimDEtable);  
end

function [configmod] = Formatconfigmod(raw_data,configmod_dim)
    % Search for configmod channel within TDMS file and store configurations in cell array
configmod  = struct('configID',[],'amp1',[],'amp2',[],'width1',[],'freq',[],'interphase',[],'CCheader',[]);
modIndexes = cell2mat(raw_data.chanIndices(strcmp(raw_data.groupNames,'Config_Mod')));
stimmods   = raw_data.data(modIndexes);
nconfig_modmsgs    = length(stimmods{1})/configmod_dim;
for stimmods_idx = 1:nconfig_modmsgs
    nxt_iter                                             = ((stimmods_idx-1)*configmod_dim)+1;
    configmod.configID(1:configmod_dim,stimmods_idx)    = stimmods{1}(nxt_iter:stimmods_idx*configmod_dim);
    configmod.amp1(1:configmod_dim,stimmods_idx)        = stimmods{2}(nxt_iter:stimmods_idx*configmod_dim);
    configmod.amp2(1:configmod_dim,stimmods_idx)        = stimmods{3}(nxt_iter:stimmods_idx*configmod_dim);
    configmod.width1(1:configmod_dim,stimmods_idx)      = stimmods{4}(nxt_iter:stimmods_idx*configmod_dim);
    configmod.freq(1:configmod_dim,stimmods_idx)        = stimmods{5}(nxt_iter:stimmods_idx*configmod_dim);
    configmod.interphase(1:configmod_dim,stimmods_idx)  = stimmods{6}(nxt_iter:stimmods_idx*configmod_dim);
    configmod.CCheader(1:configmod_dim,stimmods_idx)    = stimmods{7}(nxt_iter:stimmods_idx*configmod_dim);
end
end
function [configchan] = Formatconfigchan(raw_data,configchan_dim)
  % Search for configchan channel within TDMS file and store configurations in cell array
configchan  = struct('stop',[],'numChans',[],'channel',[],'pattern',[],'reps',[],'CMheader',[]);
chanIndexes = cell2mat(raw_data.chanIndices(strcmp(raw_data.groupNames,'Config_Chan')));
stimchans   = raw_data.data(chanIndexes);
nconfig_chanmsgs = length(stimchans{1})/12;
for stimchans_idx = 1:nconfig_chanmsgs
    nxt_iter                                                  = ((stimchans_idx-1)*configchan_dim)+1;
    configchan.stop(1:configchan_dim,stimchans_idx)          = stimchans{1}(nxt_iter:stimchans_idx*configchan_dim);
    configchan.numChans(1:configchan_dim,stimchans_idx)      = stimchans{2}(nxt_iter:stimchans_idx*configchan_dim);
    configchan.channel(1:configchan_dim,stimchans_idx)       = stimchans{3}(nxt_iter:stimchans_idx*configchan_dim);
    configchan.pattern(1:configchan_dim,stimchans_idx)       = stimchans{4}(nxt_iter:stimchans_idx*configchan_dim);
    configchan.reps(1:configchan_dim,stimchans_idx)          = stimchans{5}(nxt_iter:stimchans_idx*configchan_dim);
    configchan.CMheader(1:configchan_dim,stimchans_idx)      = stimchans{6}(nxt_iter:stimchans_idx*configchan_dim);
end
end
