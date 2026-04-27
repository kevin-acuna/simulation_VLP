%% Extract LED Orientations Summary from Optimization Logs
% This script extracts optimal LED orientations from all optimization logs
% and creates a summary file in the requested format

clear all; clc; close all;

% Base directory
base_dir = 'c:\Users\Owner\Documents\UVSQ\simulation_VLP\fundamentals\CRLB analysis\OPTIMIZATION\optimization\room_3x3';

% Define the K values and their corresponding log files
log_files = {
    'K_3\optimization_log_2025-07-27_18-02-42.txt', 3;
    'K_4\optimization_log_2025-07-27_18-18-26.txt', 4;
    'K_5\optimization_log_2025-07-27_18-23-04.txt', 5;
    'K_6\optimization_log_2025-07-27_18-44-33.txt', 6;
    'K_7\optimization_log_2025-07-27_18-29-56.txt', 7;
    'K_8\optimization_log_2025-07-27_18-47-35.txt', 8;
    'K_9\optimization_log_2025-07-27_18-53-02.txt', 9;
    'K_10\optimization_log_2025-07-27_18-57-59.txt', 10;
    'K_6_exp1\optimization_log_2025-07-27_18-26-14.txt', 6
};

% Output file
output_file = fullfile(base_dir, 'orientations_summary.txt');

% Open output file for writing
fid = fopen(output_file, 'w');

fprintf('Extracting LED orientations from optimization logs...\n');
fprintf('Results will be saved to: %s\n\n', output_file);

% Process each log file
for i = 1:size(log_files, 1)
    log_path = fullfile(base_dir, log_files{i, 1});
    K_val = log_files{i, 2};
    
    fprintf('Processing K_%d...\n', K_val);
    
    % Read the log file
    try
        fid_log = fopen(log_path, 'r');
        if fid_log == -1
            fprintf('  Warning: Could not open %s\n', log_path);
            continue;
        end
        
        % Read all lines
        lines = {};
        while ~feof(fid_log)
            line = fgetl(fid_log);
            if ischar(line)
                lines{end+1} = line;
            end
        end
        fclose(fid_log);
        
        % Find the optimal orientations section
        orientations = [];
        in_results_section = false;
        
        for j = 1:length(lines)
            line = lines{j};
            
            % Look for the final results section
            if contains(line, 'OPTIMIZATION RESULTS FOR K')
                in_results_section = true;
                continue;
            end
            
            % Extract LED orientations in the results section
            if in_results_section && contains(line, 'LED') && contains(line, 'θ =') && contains(line, 'ρ =')
                % Parse line like: "  LED 1: θ =  35.40°, ρ = 140.13° → n_t = [-0.445,  0.371, -0.815]"
                tokens = regexp(line, 'θ\s*=\s*([\d.]+)°.*ρ\s*=\s*([\d.]+)°', 'tokens');
                if ~isempty(tokens)
                    elevation = str2double(tokens{1}{1});
                    azimuth = str2double(tokens{1}{2});
                    orientations = [orientations, elevation, azimuth];
                end
            end
        end
        
        % Write to output file
        if ~isempty(orientations)
            if i == size(log_files, 1) && K_val == 6  % K_6_exp1 case
                fprintf(fid, 'K_%d_exp1=[', K_val);
            else
                fprintf(fid, 'K_%d=[', K_val);
            end
            
            for k = 1:length(orientations)
                if k < length(orientations)
                    fprintf(fid, '%.2f,', orientations(k));
                else
                    fprintf(fid, '%.2f', orientations(k));
                end
            end
            fprintf(fid, ']\n');
            
            fprintf('  ✓ Extracted %d orientations\n', length(orientations)/2);
        else
            fprintf('  ✗ No orientations found\n');
        end
        
    catch ME
        fprintf('  Error processing %s: %s\n', log_path, ME.message);
    end
end

fclose(fid);

fprintf('\n=== Summary completed ===\n');
fprintf('Output file: %s\n', output_file);

% Display the contents of the output file
fprintf('\n=== Contents of orientations_summary.txt ===\n');
type(output_file);
