addpath(genpath(fullfile(getenv('STIMULATION_MODULES'), 'legacy\VoltageMonitor\utilities')))
tld = 'T:\SessionData';
subj_list = {'BCI02', 'BCI03'};

for s = 1:length(subj_list)
    subj_path = fullfile(tld, subj_list{s}, 'VoltageMonitor');
    vm_collection_list = dir(subj_path);
    for c = 1:size(vm_collection_list,1)
        if contains(vm_collection_list(c).name, 'VM') == 0
            continue
        end
        vm_path = fullfile(subj_path, vm_collection_list(c).name);
        mat_fname = sprintf('%s_VM_%s.mat', subj_list{s}, vm_collection_list(c).name(4:end));
        
        if exist(fullfile(vm_path, mat_fname), 'file') == 2
            continue
        end
    
        % Load the JSON
        json_fname = sprintf('%s_session_%s.json', subj_list{s}, vm_collection_list(c).name(4:end));
        fprintf('Loading %s\n', json_fname)
    
        try
            VMData = VoltageMonitor_JSON2MAT(fullfile(vm_path, json_fname));
        catch ME
            % Display warning message 
            fprintf('Error processing %s: %s\n', vm_collection_list(c).name, ME.message);
            continue
        end
        
        % Export
        if ~isempty(VMData(1).SubjectID)
            fprintf('Saving: %s\n', mat_fname)
            save(fullfile(vm_path, mat_fname), 'VMData')
        end
    end % Collection date
end
