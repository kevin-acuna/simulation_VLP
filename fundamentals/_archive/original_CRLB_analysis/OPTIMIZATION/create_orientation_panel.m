%% create_orientation_panel.m
% This script creates a panel of orientation figures showing all K configurations
% from K=3 to K=9 in two different viewing angles.
%
% Author: Kevin Acuña
% Date: July 2025

clear; close all;

% Define the base path where the orientation figures are stored
results_dir = 'results';

% K values to process
k_values = 3:9;

% First, let's list all the orientation 3d fig files
orientation_fig_files = dir(fullfile(results_dir, '**', 'orientations_3d.fig'));
fprintf('Found %d orientation_3d.fig files in the results directory\n', length(orientation_fig_files));

% Print all found orientation files with their paths
if ~isempty(orientation_fig_files)
    fprintf('Found orientation files:\n');
    for i = 1:length(orientation_fig_files)
        fprintf('  %s\n', fullfile(orientation_fig_files(i).folder, orientation_fig_files(i).name));
    end
end

% Automatically associate files with K values
orientation_files_by_k = cell(1, length(k_values));

% Method 1: Look for K values in the directory path
for i = 1:length(orientation_fig_files)
    file_path = fullfile(orientation_fig_files(i).folder, orientation_fig_files(i).name);
    
    % Check for K values in the folder path
    for k_idx = 1:length(k_values)
        k = k_values(k_idx);
        
        % Check if folder path contains K<number>
        if contains(lower(orientation_fig_files(i).folder), ['k', num2str(k)]) || ...
           contains(lower(orientation_fig_files(i).folder), ['k=', num2str(k)]) || ...
           contains(lower(orientation_fig_files(i).folder), ['k ', num2str(k)])
            orientation_files_by_k{k_idx} = file_path;
            fprintf('K=%d: Associated with %s (found in path)\n', k, file_path);
            break;
        end
    end
end

% Method 2: If we didn't find enough matches, use the files in order (if they match the number of K values)
if length(orientation_fig_files) == length(k_values) && sum(cellfun(@isempty, orientation_files_by_k)) > 0
    fprintf('Using sequential assignment of files to K values\n');
    for i = 1:length(orientation_fig_files)
        if i <= length(k_values)
            orientation_files_by_k{i} = fullfile(orientation_fig_files(i).folder, orientation_fig_files(i).name);
            fprintf('K=%d: Associated with %s (sequential)\n', k_values(i), orientation_files_by_k{i});
        end
    end
end

% Create a new figure with a 2x7 grid
fig_panel = figure('Position', [50, 50, 1800, 600]);

% Create directory to save the results
output_dir = fullfile('results', 'orientation_panel');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Loop through each K value
for k_idx = 1:length(k_values)
    k = k_values(k_idx);
    
    % Check if we have an associated file for this K value
    fig_file = orientation_files_by_k{k_idx};
    
    if isempty(fig_file)
        fprintf('Warning: No orientation figure found for K=%d\n', k);
        continue;
    end
    
    fprintf('Processing K=%d: %s\n', k, fig_file);
    
    % Create two subfigures for this K value
    for row = 1:2
        % Create subplot
        subplot_idx = (row-1)*length(k_values) + k_idx;
        ax = subplot(2, length(k_values), subplot_idx);
        
        % Load the figure (this will load into current subplot)
        try
            fig_data = hgload(fig_file);
            
            % Copy contents to the subplot
            fig_axes = findobj(fig_data, 'Type', 'axes');
            if ~isempty(fig_axes)
                % Copy all children from the loaded figure to our subplot
                copyobj(get(fig_axes, 'Children'), ax);
                
                % Set the view angle based on the row
                if row == 1
                    view(ax, 45, 30); % Regular 3D view
                    title_text = sprintf('K=%d (3D view)', k);
                else
                    view(ax, 90, 90); % Top-down view
                    title_text = sprintf('K=%d (top view)', k);
                end
                
                % Configure axes properties
                axis equal;
                grid on;
                xlim([-1 1]); ylim([-1 1]); zlim([-1 0.2]);
                
                % Set title and hide legend for cleaner appearance
                title(title_text);
                
                % Make sure only the top row shows the 3D sphere
                hemisphere_obj = findobj(ax, 'Type', 'surface');
                if row == 2 && ~isempty(hemisphere_obj)
                    set(hemisphere_obj, 'Visible', 'off');
                end
                
                % Hide individual legends for cleaner appearance
                legend_obj = findobj(ax, 'Type', 'legend');
                if ~isempty(legend_obj)
                    set(legend_obj, 'Visible', 'off');
                end
            else
                title(ax, sprintf('K=%d (No axes found)', k));
            end
            
            % Close the loaded figure
            close(fig_data);
            
        catch err
            % Handle errors with loading/copying the figure
            warning('Error processing figure for K=%d: %s', k, err.message);
            title(ax, sprintf('K=%d (Error)', k));
        end
    end
end

% Create a common title for the entire figure
sgtitle('LED Orientation Configurations: K=3 to K=9', 'FontSize', 16, 'FontWeight', 'bold');

% Add a text annotation with info about the views
annotation('textbox', [0.01, 0.01, 0.5, 0.05], 'String', ...
    'Top row: 3D perspective view (45°, 30°) | Bottom row: Top-down view (90°, 90°)', ...
    'EdgeColor', 'none', 'FontSize', 12);

% Save the panel figure
current_datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
saveas(fig_panel, fullfile(output_dir, sprintf('orientations_panel_%s.fig', current_datetime)));
saveas(fig_panel, fullfile(output_dir, sprintf('orientations_panel_%s.png', current_datetime)));

fprintf('Panel figure created and saved in %s\n', output_dir);
