function TDMSpostprocessor_LF(timeoffset,threshold,filename,tdmsfiles,idata,savefile)
% TDMS processor to handle larger files 
% selects data subsets instead of reading all raw data
%
% - Called from TDMSpostprocessing.m if filesize exceeds a limit

[tempstruct,metastruct]   = TDMS_readTDMSFile(filename,'GET_DATA_OPTION','getNone');
tdms_tempdata             = struct('tdmsStruct',tempstruct,'metaStruct',metastruct,'TDMS_filename',filename);
wf_start     = tempstruct.propValues{1,3}{1,1};
chnames      = tempstruct.chanNames{1,length(tempstruct.chanNames)}(3:end);
if length(tempstruct.propValues{1,3}) ~= 6
    return
end

% Exit if no Digital Events were logged
ql_fields = ~isfield(idata.QL.Data,{'STIM_SYNC_EVENT','STIM_UPDATE_EVENT'});
if ql_fields(1) > 0
    fprintf('Warning: No digital data was recorded...moving to next file'); 
    return
end
de_si   = idata.QL.Data.STIM_SYNC_EVENT.source_index == 0;
de_ts   = idata.QL.Data.STIM_SYNC_EVENT.source_timestamp(de_si);
% Store QL data

if ql_fields(2) > 0
    cc_ts   = 'STIM_UPDATE_EVENT was not recorded for this file';
    fprintf('Warning:  STIM_UPDATE_EVENT was not recorded for this file... continuing anyway... ');
else
    cc_si   = idata.QL.Data.STIM_UPDATE_EVENT.source_index == 0;
    cc_ts   = idata.QL.Data.STIM_UPDATE_EVENT.source_timestamp(cc_si);
end


% If there aren't three groups (data,chan_config,amp_config) then skip to next file
if length(tempstruct.chanNames) ~= 4
    fprintf('Warning: Unexpected list of groups: \n');
    fprintf(' - %s \n',tempstruct.groupNames{:});
    if ~any(strcmp(tempstruct.groupNames,'Digital Events')) || ~any(strcmp(tempstruct.groupNames,'Untitled'))
        fprintf('Skipping file %s\n',tdmsfiles{TDMSfile_num});
        return
    end
end

% Search for Channel group within TDMS file and store configurations in cell array

configmod           = idata.QL.Data.CERESTIM_CONFIG_MODULE;
configchan          = idata.QL.Data.CERESTIM_CONFIG_CHAN;

% Store list of Digital Events recorded in TDMS file
% grpread_inc =  500;
% if length(de_ts) > grpread_inc
% de_data.stim = [];
% temp_dets    = [1 grpread_inc];
%     while temp_dets(2) ~= 0
%         de_data.stim = horzcat(de_data.stim,TDMS_readChannelOrGroup(tdms_tempdata,'Digital Events','Stim Indexes',temp_dets));
%         if temp_dets(2)+grpread_inc < length(de_ts)
%             temp_dets    = [length(de_data.stim) grpread_inc];
%         else
%             temp_dets    = [length(de_data.stim) (length(de_ts)-length(de_data.stim))];
%         end
%     end
% else
de_data.stim = TDMS_readChannelOrGroup(tdms_tempdata,'Digital Events','Stim Indexes',[1 metastruct.numberDataPoints(27)]); % hardcoded --> shouldn't change, but still...
% end
de_data.ccm  = TDMS_readChannelOrGroup(tdms_tempdata,'Digital Events','Msg Indexes',[1 metastruct.numberDataPoints(28)]); % hardcoded --> shouldn't change, but still...

% Store Config setup information in ConfigLog
tdmsdata.SystemStarttime  = wf_start;

% Parse through Digital data
[msgDEtable, stimDEtable, tdmsdata]       = Trgsnips(tdmsdata,timeoffset,de_data);

if isempty(stimDEtable)
    fprintf('Warning:  No digital events recorded in this file:  %s \n Moving to next TDMS file...',filename)
    return
end



% Store Messages (Data and timestamps)
tdmsdata.Messages.ChanConfig.time       = cc_ts;
tdmsdata.Messages.ChanConfig.data       = configchan;
tdmsdata.Messages.ModConfig.data        = configmod; 

% Create Channel Fields
tdmsdata.Data(64) = struct('snippet',[],'maxV',[],'minV',[],'inter',[],'stimAmp',[],'timestamps',[],'ChanConfigMessageID',[],'DAQmod',[]);

% Store QuickLogger data
tdmsdata.QLdata         = idata;
tdmsdata.DEtimetable    = stimDEtable(:,1)+timeoffset;

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
                chan_data  = TDMS_readChannelOrGroup(tdms_tempdata,'Untitled',chnames(aichan_idx),stimDEtable(tbl_idx,:));
                tdmsdata.Data(chanID).snippet(:,end+1)   = chan_data';
                tdmsdata.Data(chanID).maxV(end+1,:)      = max(chan_data);
                tdmsdata.Data(chanID).minV(end+1,:)      = min(chan_data);
                [~,minind]                               = min(chan_data);
                tdmsdata.Data(chanID).inter(end+1,:)     = chan_data(minind + configmod.interphase(1,tdmsmrkr_idx)/10);
                tdmsdata.Data(chanID).timestamps(end+1,:)                 = de_ts(tbl_idx);
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
save(regexprep(savefile,'.tdms','.mat'),'tdmsdata');
toc
end

function [msgDEtable, stimDEtable, tdmsdata] = Trgsnips(tdmsdata,timeoffset,de_data)
%Trgsnips Summary of this function goes here
%   Parses through digital data and returns 2D array of indexed event
%   and data range to extract
%   inputs:   ddata, wf_increment
%   outputs:  stimDEtable, timestamp
stimDEtable      = [];    
stimDEtable(:,2) = de_data.stim-timeoffset;
logstimdiff      = vertcat(true,diff(stimDEtable(:,2)) > 0);
if any(~logstimdiff)
    sprintf('Disregarding digital event markers recorded at index %d\n',find(~logstimdiff));
    tdmsdata.DEdump = find(~logstimdiff);
end
stimDEtable      = stimDEtable(logstimdiff,:);
if stimDEtable(1,2) < 1
    stimDEtable(1,2) = 1;
end

msgDEtable(:,1)  = de_data.ccm;
stimDEtable(:,1) = 159;  % Hardcoded snippet length
stimDEtable      = fliplr(stimDEtable);
    
end
