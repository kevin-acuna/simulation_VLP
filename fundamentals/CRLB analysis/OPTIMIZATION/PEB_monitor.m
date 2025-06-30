function [state, options, optchanged] = PEB_monitor(options, state, flag)
% PEB_monitor - Monitoring function for genetic algorithm optimization of PEB
%
% This function monitors the GA optimization process and creates visualizations
% of the evolution of orientation angles and 3D orientation patterns.
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
persistent bestHistory figAngleEvolution fig3DOrientation

switch flag
    case 'init'
        % Initialize history and create separate figures
        bestHistory = [];
        figAngleEvolution = figure('Name', 'PEB Optimization - Angle Evolution', 'NumberTitle', 'off');
        fig3DOrientation = figure('Name', 'PEB Optimization - 3D Orientations', 'NumberTitle', 'off');
        
    case 'iter'
        % Identify best solution (lowest PEB) in current population
        [~, bestIdx] = min(state.Score);
        bestVector = state.Population(bestIdx, :); % [theta1, rho1, theta2, rho2, ..., thetaK, rhoK]
        
        % Store this best solution in history
        bestHistory = [bestHistory; bestVector];
        
        %% =========== 1) Plot angle evolution ===========
        figure(figAngleEvolution);
        clf; % Clear figure to redraw
        numVars = size(bestHistory, 2);
        K = numVars / 2; % Number of orientations
        
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
        sgtitle(sprintf('PEB Optimization Progress - Generation %d (Best PEB: %.4f m)', ...
            state.Generation, min(state.Score)));
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
        
        % Draw coordinate system
        quiver3(0, 0, 0, 1, 0, 0, 0.5, 'r', 'LineWidth', 2); % X-axis
        quiver3(0, 0, 0, 0, 1, 0, 0.5, 'g', 'LineWidth', 2); % Y-axis
        quiver3(0, 0, 0, 0, 0, -1, 0.5, 'b', 'LineWidth', 2); % Z-axis (downward)
        
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
        surf(X*0.3, Y*0.3, Z*0.3, 'FaceAlpha', 0.1, 'EdgeAlpha', 0.1, 'FaceColor', [0.7 0.7 0.7]);
        
        % Formatting
        xlabel('X'); ylabel('Y'); zlabel('Z');
        title(sprintf('LED Orientations - Generation %d\nBest PEB: %.4f m', ...
            state.Generation, min(state.Score)));
        legend('Location', 'best');
        axis equal;
        grid on;
        view(45, 30); % Good viewing angle
        xlim([-1 1]); ylim([-1 1]); zlim([-1 0.2]);
        
        hold off;
        drawnow;
        
    case 'done'
        % Final processing when optimization is complete
        fprintf('\n=== PEB Optimization Complete ===\n');
        fprintf('Final best PEB: %.6f m\n', min(state.Score));
        fprintf('Total generations: %d\n', state.Generation);
        
        % Display final orientations
        bestVector = bestHistory(end, :);
        K = length(bestVector) / 2;
        fprintf('\nOptimal LED orientations:\n');
        for i = 1:K
            fprintf('LED %d: θ = %.2f°, ρ = %.2f°\n', i, bestVector(2*i-1), bestVector(2*i));
        end
end

end
