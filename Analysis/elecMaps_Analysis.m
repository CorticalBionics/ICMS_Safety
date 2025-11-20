%Statistical analysis of electrode array location

%Load percept electrode maps data - CHANGE THIS
load('P:\users\tgh28\Experiments\Longitudinal_ICMS\elecMaps.mat');
participantIDs = {'C1','C2','P2','P3','P4'};
arrayNames     = {'lateral','medial'};

%% Plot array maps to double check 

visualizePerceptMaps(percept_elecMaps, participantIDs);

%% Get Moran's I for each array 

nParticipants = numel(percept_elecMaps);
nArrays       = numel(arrayNames);

% Preallocate results table
nRows = nParticipants * nArrays * 2;
results2 = table('Size',[nRows 5], ...
                'VariableTypes', {'string','string','string','double','double'}, ...
                'VariableNames', {'Participant','Array','TimeLabel','MoranI','pValue'});
row = 1;

for p = 1:nParticipants
    pid = percept_elecMaps(p).id;  
    
    for a = 1:nArrays
        arrName = arrayNames{a};  
        
        for t = 1:2
            X = percept_elecMaps(p).arrays.(arrName).time(t).map;  
            timeLabel = percept_elecMaps(p).arrays.(arrName).time(t).label; 
           
            % Compute Moran's I with queen adjacency
            [I_obs, p_val] = moransI_queen(X, 10000);
            
            % Print to command window
            fprintf('%s %s %s: Moran''s I = %.3f, p = %.4f\n', ...
                    pid, arrName, timeLabel, I_obs, p_val);
            
            % Store in results table
            results2.Participant(row) = string(pid);
            results2.Array(row)       = string(arrName);
            results2.TimeLabel(row)   = string(timeLabel);
            results2.MoranI(row)      = I_obs;
            results2.pValue(row)      = p_val;
            row = row + 1;
        end
    end
end

%save('Sup6_moran_results.mat','results');


%% Plotting 
function visualizePerceptMaps(percept_elecMaps, participantIDs)

    nParticipants = numel(participantIDs);
    
    % Layout: rows = participants, cols = 4 (Lat Y1, Med Y1, Lat Ylast, Med Ylast)
    nCols = 4;
    
    figure('Color','w');
    
    for p = 1:nParticipants
        % find index of this participant in sensoryMaps (in case order differs)
        pIdx = find(strcmp({percept_elecMaps.id}, participantIDs{p}));
        
        for col = 1:nCols
            switch col
                case 1
                    arrName = 'lateral'; t = 1;
                case 2
                    arrName = 'medial';  t = 1;
                case 3
                    arrName = 'lateral'; t = 2;
                case 4
                    arrName = 'medial';  t = 2;
            end
            
            % Get the map (6x10) for this participant/array/time
            X = percept_elecMaps(pIdx).arrays.(arrName).time(t).map; %#ok<*FNDSB>
            
            % subplot index
            spIdx = (p-1)*nCols + col;
            ax = subplot(nParticipants, nCols, spIdx);
            
            % Plot with NaNs transparent
            imagesc(X, 'AlphaData', ~isnan(X));
            axis equal tight ij;   % 'ij' so row 1 is top
            ax.Color = [0.8 0.8 0.8];   % gray for NaNs
            colormap(ax, [0 0 0; 0 0.4470 0.7410]);
            clim([0 1]);
            ax.XTick = [];
            ax.YTick = [];
            
            % Column titles on top row only
            if p == 1
                switch col
                    case 1
                        title('Lateral - First 250 days');
                    case 2
                        title('Medial - First 250 days');
                    case 3
                        title('Lateral - Last 250 days');
                    case 4
                        title('Medial - Last 250 days');
                end
            end
            
            % Row labels on leftmost column: participant IDs
            if col == 1
                ylabel(participantIDs{p}, 'FontWeight','bold');
            end
        end
    end
end

%%
function [I_obs, p_twoSided, I_perm] = moransI_queen(X, nPerm)
% X     : R x C array with values (e.g., 0/1), NaN = excluded electrodes
% nPerm : number of permutations 

% I_obs      : observed Moran's I
% p_twoSided : two-sided permutation p-value
% I_perm     : nPerm x 1 vector of permuted Moran's I values

    %Make default permulation 10,000
    if nargin < 2
        nPerm = 10000;
    end
    
    %Convert electrode map into a double
    X = double(X);
    [R, C] = size(X);

    % Keep only wired (non-NaN) electrodes
    validMask = ~isnan(X);

    % Assign an index to each valid electrode
    n = sum(validMask(:));
    indexMap = zeros(R, C);       % 0 = invalid
    indexMap(validMask) = 1:n;    %Number electrodes to get unique index
    x = X(validMask);
    x = x(:);

    % Use queen adjacency 
    % Directions: 8 neighbors (up, down, left, right, diagonals)
    dirs = [ -1  0;   % up
              1  0;   % down
              0 -1;   % left
              0  1;   % right
             -1 -1;   % up-left
             -1  1;   % up-right
              1 -1;   % down-left
              1  1 ]; % down-right

    % Preallocate and use sparse to make code faster
    W = sparse(n, n);

    % Loop over all valid grid positions
    [rows, cols] = find(validMask);
    for k = 1:n
        r = rows(k);
        c = cols(k);

        for d = 1:size(dirs,1)
            rr = r + dirs(d,1);
            cc = c + dirs(d,2);

            if rr >= 1 && rr <= R && cc >= 1 && cc <= C ...
                    && validMask(rr,cc)

                i = indexMap(r ,c );  % current electrode index (k)
                j = indexMap(rr,cc);  % neighbor electrode index

                W(i,j) = 1; %#ok<*SPRIX>
            end
        end
    end

    % Compute observed Moran's I
    x_bar = mean(x);
    z     = x - x_bar;

    S0 = full(sum(W(:)));        % total weight
    if S0 == 0
        error('No neighbors found (S0 = 0).');
    end
    
    %Moran's I 
    I_obs = (n / S0) * (z' * W * z) / (z' * z);

    % Permutation test to get p level
    I_perm = zeros(nPerm,1);
    for p = 1:nPerm
        x_perm = x(randperm(n));
        z_perm = x_perm - mean(x_perm);
        I_perm(p) = (n / S0) * (z_perm' * W * z_perm) / (z_perm' * z_perm);
    end

    % Two-sided p-value
    p_twoSided = (sum(abs(I_perm) >= abs(I_obs)) + 1) / (nPerm + 1);
end





