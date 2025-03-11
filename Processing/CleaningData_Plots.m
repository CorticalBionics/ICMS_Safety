%% load data
addpath(genpath('C:\git\climber\src\VoltageMonitor\utilities'))
addpath(genpath("P:\users\tgh28\ChartWithCharles")); %For progress bar

% load('P:\users\tgh28\Experiments\Longitudinal_ICMS\cleaning_data\CleaningData_All.mat')
% 
% %% Sort data by date for better plotting
% % Extract the dates from the data structure
% dates = [data.Date];
% 
% % Sort the structure array based on the Date field
% [~, sort_idx] = sort(dates);
% 
% % Reorder the data array using the sorting indices
% data_sorted = data(sort_idx);

%% Select participant
participant = 'CRS02b';

%Select channel
wanted_ch = 19;

%% Set Presets
if strcmp(participant, 'CRS02b')
    implant_date = datetime('04-May-2015', 'InputFormat', 'dd-MMM-yyyy');
elseif strcmp(participant, 'CRS07') %#ok<UNRCH>
    implant_date = datetime('12-Aug-2020', 'InputFormat', 'dd-MMM-yyyy');
elseif strcmp(participant, 'CRS08')
    implant_date = datetime('05-Apr-2023', 'InputFormat', 'dd-MMM-yyyy');
else
    error('Participant ID not recognized')
end

c_vmin = [95 15 64]./255; %purple
c_vmax = [99 132 117]./255; %green
c_vinter = [227 100 20]./255; %orange

%% Filter data

% Initialize
day_since_start_all = cell(64, 1);
day_since_start_all_20 = cell(64, 1);

vmax_10 = cell(64, 1);
vinter_10 = cell(64, 1);
vmin_10 = cell(64, 1);

vmax_20 = cell(64, 1);
vinter_20 = cell(64, 1);
vmin_20  = cell(64, 1);

waveforms_10 = [];
waveforms_20 = [];


% Collect data for each channel across all iterations
for i = 1:length(data_sorted)
    if contains(data_sorted(i).Subject, participant) %Check if correct participant

        chs = data_sorted(i).channels;
        day_since_start = days(data_sorted(i).Date - implant_date);  % Calculate days since implant

        for c = 1:length(chs)
            ch = chs(c);

            if data_sorted(i).Amp == 10
                % Append the day_since_start and vinter value for each channel
                day_since_start_all{ch} = [day_since_start_all{ch}; day_since_start];
                vmax_10{ch} = [vmax_10{ch}; data_sorted(i).vmax(ch)];
                vinter_10{ch} = [vinter_10{ch}; data_sorted(i).vinter(ch)];
                vmin_10{ch} = [vmin_10{ch}; data_sorted(i).vmin(ch)];

                if ch == wanted_ch
                    waveforms_10 = [waveforms_10; data_sorted(i).avg_waveform(wanted_ch,:)]; %#ok<AGROW>
                end

            elseif data_sorted(i).Amp == 20
                day_since_start_all_20{ch} = [day_since_start_all_20{ch}; day_since_start];

                vmax_20{ch} = [vmax_20{ch}; data_sorted(i).vmax(ch)];
                vinter_20{ch} = [vinter_20{ch}; data_sorted(i).vinter(ch)];
                vmin_20{ch} = [vmin_20{ch}; data_sorted(i).vmin(ch)];

                if ch == wanted_ch
                    waveforms_20 = [waveforms_20; data_sorted(i).avg_waveform(wanted_ch,:)]; %#ok<AGROW>
                end

            end
        end
    end
end


%% Plot waveforms

downsample_value = 13; %Need to fix this
total_time_us = 700; x = 1:100;

%Create colormap
n_lines_10 = floor(length(waveforms_10) / downsample_value);
n_lines_20 = floor(length(waveforms_20) / downsample_value);
colormap_10 = [180 4 36; 154 3 30; 100 2 20]./ 255; %Red
colormap_20 = [28 132 156; 15 76 92; 9 44 52]./ 255; %Blue

color_10 = interp1(linspace(0,1,size(colormap_10,1)), colormap_10, linspace(0,1,n_lines_10));
color_20 = interp1(linspace(0,1,size(colormap_20,1)), colormap_20, linspace(0,1,n_lines_20));


% Plot waveforms_10
for i = 1:downsample_value:length(waveforms_10)
    color_idx = min(floor(i / downsample_value) + 1, n_lines_10);  % Cap index at n_lines_10
    plot(linspace(-40,960,100), waveforms_10(i,:), 'Color', color_10(color_idx, :)); hold on;
end

% Add a colorbar for waveforms_10
colormap(colormap_10);  % Apply colormap for waveforms_10
colorbar_handle_10 = colorbar;
clim([0 1]);  % Set the color axis limits
set(colorbar_handle_10, 'Ticks', [0, 1], 'TickLabels', {'10\muA Early', '10\muA Late'});


% Plot waveforms_20
for i = 1:downsample_value:length(waveforms_20)
    color_idx = min(floor(i / downsample_value) + 1, n_lines_20);  % Cap index at n_lines_20
    plot(linspace(-40,960,100), waveforms_20(i,:), 'Color', color_20(color_idx, :)); hold on;
end

% Add a colorbar for waveforms_20
colormap(colormap_20);  % Apply colormap for waveforms_20
colorbar_handle_20 = colorbar;
caxis([0 1]);  % Set the color axis limits
set(colorbar_handle_20, 'Ticks', [0, 1], 'TickLabels', {'20\muA Early', '20\muA Late'});

xlabel('Time (\mus)');
%ylabel('Voltage (\muA)')
ylabel('Voltage (a.u)');

set(gca,'TickDir','Out','FontSize',15); box off

hold off;

%% Plot over time for participant

ch = wanted_ch;
alpha_value = 0.5;


for i = 1:2

    figure();
    if i == 1
        x = day_since_start_all{wanted_ch};
        amp = 10;

        y_min = vmin_10{wanted_ch};
        y_inter = vinter_10{wanted_ch};
        y_max = vmax_10{wanted_ch};
        line_style = '-';

    elseif i == 2
        x = day_since_start_all_20{wanted_ch};
        amp = 20;

        y_min = vmin_20{wanted_ch};
        y_inter = vinter_20{wanted_ch};
        y_max = vmax_20{wanted_ch};
        line_style = '--';
    end

    %Remove NaNs
    nan_idx = isnan(y_inter);

    x = x(~nan_idx);

    y_inter = y_inter(~nan_idx);
    y_inter = movmedian(y_inter, 10);

    y_min = y_min(~nan_idx);
    y_min = movmedian(y_min, 10);

    y_max = y_max(~nan_idx);
    y_max = movmedian(y_max, 10);

    %Plot Scatter
    scatter(x, y_min, 20, c_vmin, 'filled', 'MarkerFaceAlpha', alpha_value); hold on;
    scatter(x, y_inter, 20, c_vinter, 'filled', 'MarkerFaceAlpha', alpha_value);
    scatter(x, y_max, 20, c_vmax, 'filled', 'MarkerFaceAlpha', alpha_value);

    % Correlation and linear fit for vmin (purple)
    [ch_corrs_vmin(ch), cp_vmin] = corr(x, y_min, 'Rows', 'complete'); %#ok<*SAGROW>
    p_vmin = polyfit(x, y_min, 1);
    ch_coeff_vmin(ch) = p_vmin(1);
    plot([min(x), max(x)], polyval(p_vmin, [min(x), max(x)]), 'Color', c_vmin, 'LineStyle', line_style, 'LineWidth', 2);  % Fit line in purple

    % Correlation and linear fit for vinter (orange)
    [ch_corrs_vinter(ch), cp_vinter] = corr(x, y_inter, 'Rows', 'complete');
    p_vinter = polyfit(x, y_inter, 1);
    ch_coeff_vinter(ch) = p_vinter(1);
    plot([min(x), max(x)], polyval(p_vinter, [min(x), max(x)]), 'Color', c_vinter, 'LineStyle', line_style, 'LineWidth', 2);  % Fit line in orange

    % Correlation and linear fit for vmax (green)
    [ch_corrs_vmax(ch), cp_vmax] = corr(x, y_max, 'Rows', 'complete');
    p_vmax = polyfit(x, y_max, 1);
    ch_coeff_vmax(ch) = p_vmax(1);
    plot([min(x), max(x)], polyval(p_vmax, [min(x), max(x)]), 'Color', c_vmax, 'LineStyle', line_style, 'LineWidth', 2);  % Fit line in green

    title(sprintf('Ch %d - %d%sA', ch, amp, GetUnicodeChar('mu')));
    xlabel('Days Since Implant');
    %ylabel(sprintf('Voltage (%sA)', GetUnicodeChar('mu')));
    ylabel(sprintf('Voltage (a.u.)');

    set(gca,'TickDir','Out','FontSize',15); box off
    set(gca, 'YLim', [-3 1]);

    hold off;
    set(gcf, "Position", [100 100 700 500])
end

hold off;




%% plot correlations for all

for i = 1:2
    [ch_corrs_vmin, ch_coeff_vmin] = deal(NaN(64,1));
    [ch_corrs_vinter, ch_coeff_vinter] = deal(NaN(64,1));
    [ch_corrs_vmax, ch_coeff_vmax] = deal(NaN(64,1));

    for ch = 1:10%:64
        if ~isempty(day_since_start_all{ch})  % Plot only if data exists for the channel

            if i == 1
                x = day_since_start_all{ch};
                amp = 10;

                y_min = vmin_10{ch};
                y_inter = vinter_10{ch};
                y_max = vmax_10{ch};
                line_style = '-';

            elseif i == 2
                x = day_since_start_all_20{ch};
                amp = 20;

                y_min = vmin_20{ch};
                y_inter = vinter_20{ch};
                y_max = vmax_20{ch};
                line_style = '--';
            end

            %Remove NaNs
            nan_idx = isnan(y_inter);
            x = x(~nan_idx);
            y_inter = y_inter(~nan_idx);
            y_inter = movmedian(y_inter, 10);
            y_min = y_min(~nan_idx);
            y_min = movmedian(y_min, 10);
            y_max = y_max(~nan_idx);
            y_max = movmedian(y_max, 10);

            %Get correlation (ignore cp?)
            [ch_corrs_vmin(ch),cp] = corr(x,y_min, 'Rows', 'complete');
            [ch_corrs_vinter(ch),cp] = corr(x,y_inter, 'Rows', 'complete');
            [ch_corrs_vmax(ch),cp] = corr(x,y_max, 'Rows', 'complete');

            %Get best fit line
            p_min = polyfit(x,y_min,1);
            p_inter = polyfit(x,y_inter,1);
            p_max = polyfit(x,y_max,1);

            %Get coeffs
            ch_coeff_vmin(ch) = p_min(1);
            ch_coeff_vinter(ch) = p_inter(1);
            ch_coeff_vmax(ch) = p_max(1);


        end
    end
    
    for iii = 1:3

        if iii == 1
            ch_corrs = ch_corrs_vmin;
            ch_coeff = ch_coeff_vmin;
            suplot_title = 'Vmin';
        elseif iii == 2
            ch_corrs = ch_corrs_vinter;
            ch_coeff = ch_coeff_vinter;
            suplot_title = 'Vinter';
        else
            ch_corrs = ch_corrs_vmax;
            ch_coeff = ch_coeff_vmax;
            suplot_title = 'Vmax';
        end



        figure();
        subplot(1,2,1); Swarm(1, ch_corrs(:,1), 'DS', 'Box');
        ylabel(sprintf('%s Correlation', suplot_title));
        set(gca,'TickDir','Out','FontSize',15); box off


        subplot(1,2,2); Swarm(1, ch_coeff(:,1), 'DS', 'Box');
        ylabel(sprintf('%s Correlation Coeff', suplot_title));
        set(gca,'TickDir','Out','FontSize',15); box off


        sgtitle(sprintf('All Chs - %d%sA', amp, GetUnicodeChar('mu')));
        set(gca,'TickDir','Out','FontSize',15); box off

        set(gcf, "Position", [100 100 700 500])

    end
end