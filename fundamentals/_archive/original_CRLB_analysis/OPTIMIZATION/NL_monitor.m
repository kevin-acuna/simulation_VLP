function [state, options, optchanged] = NL_monitor(options, state, flag)
% NL_monitor - Monitoring function for genetic algorithm optimization of NL case
%
% This function monitors the GA optimization process, creates visualizations
% of the evolution of orientation angles and 3D orientation patterns, and
% saves a detailed log of orientation values for each generation.
%
% INPUTS:
%   options  - GA options structure
%   state    - Current generation state with population and scores
%   flag     - Stage indicator ('init', 'iter', or 'done')
%
% OUTPUTS:
%   state, options, optchanged - Required for GA output function signature

optchanged = false;

% Use persistent variables to store data and figure handles across generations
persistent bestHistory figAngleEvolution fig3DOrientation logFile logFilename

switch flag
    case 'init'
        % Initialize history and create separate figures
        bestHistory = [];
        figAngleEvolution = figure('Name', 'NL Optimization - Angle Evolution', 'NumberTitle', 'off');
        fig3DOrientation = figure('Name', 'NL Optimization - 3D Orientations', 'NumberTitle', 'off');
        
        % Create log file for orientation values
        results_dir = 'optimization/NL';
        
        % Create results directory if it doesn't exist
        if ~exist(results_dir, 'dir')
            mkdir(results_dir);
        end
        
        current_datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
        logFilename = fullfile(results_dir, sprintf('orientation_log_NL_%s.txt', current_datetime));
        logFile = fopen(logFilename, 'w');
        
        % Write header to log file
        fprintf(logFile, '======================================================================\n');
        fprintf(logFile, 'NL OPTIMIZATION - ORIENTATION VALUES LOG\n');
        fprintf(logFile, '======================================================================\n');
        fprintf(logFile, 'Log started: %s\n', datestr(now));
        fprintf(logFile, 'Format: Generation | RMS_Error | K_vector=[theta1,rho1,theta2,rho2,...]\n');
        fprintf(logFile, '======================================================================\n\n');
        
        fprintf('NL Monitor initialized. Orientation log file: %s\n', logFilename);
        
    case 'iter'
        % Identify best solution (lowest RMS error) in current population
        [bestRMS, bestIdx] = min(state.Score);
        bestVector = state.Population(bestIdx, :); % [theta1, rho1, theta2, rho2, ..., thetaK, rhoK]
        
        % Store this best solution in history
        bestHistory = [bestHistory; bestVector];
        
        % Calculate number of orientations
        numVars = size(bestVector, 2);
        K = numVars / 2; % Number of orientations
        
        % Write generation data to log file - single line format
        % Create K vector string: [theta1,rho1,theta2,rho2,...]
        k_vector_str = '[';
        for i = 1:length(bestVector)
            if i == 1
                k_vector_str = [k_vector_str, sprintf('%.3f', bestVector(i))];
            else
                k_vector_str = [k_vector_str, sprintf(',%.3f', bestVector(i))];
            end
        end
        k_vector_str = [k_vector_str, ']'];
        
        % Write single line per generation
        fprintf(logFile, '%10d | %9.6f | %s\n', state.Generation, bestRMS, k_vector_str);
        
        % In MATLAB, file buffer is automatically managed
        % No need for manual flush like in Octave
        
        %% =========== 1) Plot angle evolution ===========
        figure(figAngleEvolution);
        clf; % Clear figure to redraw
        
        % Calculate subplot dimensions
        numRows = ceil(K);
        numCols = 2; % Always use 2 columns for theta/rho pairs
        
        for i = 1:K
            % Plot theta (elevation angle)
            subplot(numRows, numCols, 2*i-1);
            plot(bestHistory(:, 2*i-1), 'o-', 'LineWidth', 1.5, 'Color', [0.2 0.4 0.8]);
            xlabel('Generation');
            ylabel(sprintf('Theta %d (°)', i));
            title(sprintf('Evolution of Theta %d (Elevation)', i));
            ylim([0 90]);
            grid on;
            
            % Plot rho (azimuth angle)
            subplot(numRows, numCols, 2*i);
            plot(bestHistory(:, 2*i), 'o-', 'LineWidth', 1.5, 'Color', [0.8 0.4 0.2]);
            xlabel('Generation');
            ylabel(sprintf('Rho %d (°)', i));
            title(sprintf('Evolution of Rho %d (Azimuth)', i));
            ylim([0 360]);
            grid on;
        end
        
        % Add overall title
        sgtitle(sprintf('NL Optimization Progress - Generation %d (Best RMS: %.6f m)', ...
            state.Generation, bestRMS));
        drawnow;
        
        %% =========== 2) Plot 3D orientations ===========
        figure(fig3DOrientation);
        clf;
        
        % Convert current best orientations to 3D unit vectors
        nt_orientations = zeros(3, K);
        colors = lines(K); % Different colors for each orientation
        
        for i = 1:K
            theta_deg = bestVector(2*i-1);
            rho_deg = bestVector(2*i);
            
            % Convert to radians
            theta_rad = deg2rad(theta_deg);
            rho_rad = deg2rad(rho_deg);
            
            % Convert to 3D unit vector (pointing downward)
            nt_orientations(:, i) = [
                sin(theta_rad) * cos(rho_rad);
                sin(theta_rad) * sin(rho_rad);
                -cos(theta_rad)
            ];
        end
        
        % Create 3D visualization
        hold on;
        
        % Draw LED orientations
        for i = 1:K
            nt = nt_orientations(:, i);
            quiver3(0, 0, 0, nt(1), nt(2), nt(3), 0.8, ...
                'Color', colors(i, :), 'LineWidth', 3, ...
                'DisplayName', sprintf('LED %d (θ=%.1f°, ρ=%.1f°)', ...
                i, bestVector(2*i-1), bestVector(2*i)));
        end
        
        % Draw unit sphere (lower hemisphere)
        [X, Y, Z] = sphere(20);
        Z = -abs(Z); % Only lower hemisphere
        surf(X*0.3, Y*0.3, Z*0.3, 'FaceAlpha', 0.1, 'EdgeAlpha', 0.1, 'FaceColor', [0.7 0.7 0.7], 'DisplayName', '');
        
        % Formatting
        xlabel('X'); ylabel('Y'); zlabel('Z');
        title(sprintf('LED Orientations - Generation %d\nBest RMS: %.6f m', ...
            state.Generation, bestRMS));
        legend('Location', 'best');
        axis equal;
        grid on;
        view(90,90)
        xlim([-1 1]); ylim([-1 1]); zlim([-1 0.2]);
        
        hold off;
        drawnow;
        
    case 'done'
        % Final processing when optimization is complete
        fprintf('\n=== NL Optimization Complete ===\n');
        fprintf('Final best RMS: %.6f m\n', min(state.Score));
        fprintf('Total generations: %d\n', state.Generation);
        
        % Write final summary to log file
        fprintf(logFile, '\n======================================================================\n');
        fprintf(logFile, 'OPTIMIZATION COMPLETED\n');
        fprintf(logFile, '======================================================================\n');
        fprintf(logFile, 'Completion time: %s\n', datestr(now));
        fprintf(logFile, 'Total generations: %d\n', state.Generation);
        fprintf(logFile, 'Final best RMS error: %.6f m\n', min(state.Score));
        
        % Display and log final optimal vector
        bestVector = bestHistory(end, :);
        K = length(bestVector) / 2;
        fprintf('\nOptimal LED orientations:\n');
        
        % Create final K vector string
        final_k_vector_str = '[';
        for i = 1:length(bestVector)
            if i == 1
                final_k_vector_str = [final_k_vector_str, sprintf('%.3f', bestVector(i))];
            else
                final_k_vector_str = [final_k_vector_str, sprintf(',%.3f', bestVector(i))];
            end
        end
        final_k_vector_str = [final_k_vector_str, ']'];
        
        fprintf(logFile, '\nFINAL OPTIMAL K_VECTOR: %s\n', final_k_vector_str);
        
        % Also display individual orientations for console output
        for i = 1:K
            theta_deg = bestVector(2*i-1);
            rho_deg = bestVector(2*i);
            fprintf('LED %d: θ = %.2f°, ρ = %.2f°\n', i, theta_deg, rho_deg);
        end
        
        fprintf(logFile, '======================================================================\n');
        
        % Close log file
        if logFile ~= -1
            fclose(logFile);
            fprintf('Orientation log saved to: %s\n', logFilename);
        end
end

end
