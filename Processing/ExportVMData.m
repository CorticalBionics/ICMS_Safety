addpath(genpath(fullfile(getenv('STIMULATION_MODULES'), 'legacy\VoltageMonitor\utilities')))
%%% Export Voltage Monitor Data
tld = "P:\users\tgh28\Experiments\Longitudinal_ICMS\vm_data";

% List of sessions/collections
vm_collection_list = dir(fullfile(tld));
for collection = 1:size(vm_collection_list,1)
    if contains(vm_collection_list(collection).name, 'session') == 0
        continue
    end
    fname = sprintf('%s.mat', vm_collection_list(collection).name);
    
    if exist(fullfile(tld, fname), 'file') == 2 || exist(fullfile(tld, vm_collection_list(collection).name), 'file') == 2
        continue
    end

    % Load the JSON
    fprintf('Loading %s\n', fname)

    try
        VMData = VoltageMonitor_JSON2MAT(fullfile(vm_collection_list(collection).folder,...
                                              vm_collection_list(collection).name));
    catch ME
        % Display warning message 
        fprintf('Error processing %s: %s\n', vm_collection_list(collection).name, ME.message);
        continue
    end
    
    % Export
    if ~isempty(VMData(1).SubjectID)
        fprintf('Saving: %s\n', fname)
        save(fullfile(tld, fname), 'VMData')
    end
end % Collection date
