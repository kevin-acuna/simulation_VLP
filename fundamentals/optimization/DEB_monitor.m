function [state, options, optchanged] = DEB_monitor(options, state, flag)
% DEB_monitor - Monitoring function for GA optimization of DEB
%
% Monitors the GA optimization process, creates visualizations of the
% evolution of orientation angles and 3D orientation patterns.
%
% INPUTS:
%   options  - GA options structure
%   state    - Current generation state with population and scores
%   flag     - Stage indicator ('init', 'iter', or 'done')
%
% OUTPUTS:
%   state, options, optchanged - Required for GA output function signature

optchanged = false;

persistent bestHistory figAngleEvolution fig3DOrientation

switch flag
    case 'init'
        bestHistory = [];
        figAngleEvolution = figure('Name', 'DEB Optimization - Angle Evolution', 'NumberTitle', 'off');
        fig3DOrientation = figure('Name', 'DEB Optimization - 3D Orientations', 'NumberTitle', 'off');
        
    case 'iter'
        [~, bestIdx] = min(state.Score);
        bestVector = state.Population(bestIdx, :);
        bestHistory = [bestHistory; bestVector];
        
        %% 1) Plot angle evolution
        figure(figAngleEvolution);
        clf;
        numVars = size(bestHistory, 2);
        K = numVars / 2;
        numRows = ceil(K);
        numCols = 2;
        
        for i = 1:K
            subplot(numRows, numCols, 2*i-1);
            plot(bestHistory(:, 2*i-1), 'o-', 'LineWidth', 1.5, 'Color', [0.2 0.4 0.8]);
            xlabel('Generation'); ylabel(sprintf('Theta %d (°)', i));
            title(sprintf('Theta %d (Elevation)', i));
            ylim([0 90]); grid on;
            
            subplot(numRows, numCols, 2*i);
            plot(bestHistory(:, 2*i), 'o-', 'LineWidth', 1.5, 'Color', [0.8 0.4 0.2]);
            xlabel('Generation'); ylabel(sprintf('Rho %d (°)', i));
            title(sprintf('Rho %d (Azimuth)', i));
            ylim([0 360]); grid on;
        end
        
        best_deb_deg = min(state.Score) * 180/pi;
        sgtitle(sprintf('DEB Optimization - Gen %d (Best DEB: %.4f cho = %.3f°)', ...
            state.Generation, min(state.Score), best_deb_deg));
        drawnow;
        
        %% 2) Plot 3D orientations
        figure(fig3DOrientation);
        clf;
        
        nt_orientations = zeros(3, K);
        colors = lines(K);
        
        for i = 1:K
            theta_rad = deg2rad(bestVector(2*i-1));
            rho_rad = deg2rad(bestVector(2*i));
            nt_orientations(:, i) = [sin(theta_rad)*cos(rho_rad); 
                                      sin(theta_rad)*sin(rho_rad); 
                                      -cos(theta_rad)];
        end
        
        hold on;
        for i = 1:K
            nt = nt_orientations(:, i);
            quiver3(0, 0, 0, nt(1), nt(2), nt(3), 0.8, ...
                'Color', colors(i, :), 'LineWidth', 3, ...
                'DisplayName', sprintf('LED %d (θ=%.1f°, ρ=%.1f°)', ...
                i, bestVector(2*i-1), bestVector(2*i)));
        end
        
        [X, Y, Z] = sphere(20);
        Z = -abs(Z);
        surf(X*0.3, Y*0.3, Z*0.3, 'FaceAlpha', 0.1, 'EdgeAlpha', 0.1, ...
            'FaceColor', [0.7 0.7 0.7], 'DisplayName', '');
        
        xlabel('X'); ylabel('Y'); zlabel('Z');
        title(sprintf('LED Orientations - Gen %d\nBest DEB: %.4f cho (%.3f°)', ...
            state.Generation, min(state.Score), best_deb_deg));
        legend('Location', 'best');
        axis equal; grid on;
        view(90, 90);
        xlim([-1 1]); ylim([-1 1]); zlim([-1 0.2]);
        hold off;
        drawnow;
        
    case 'done'
        fprintf('\n=== DEB Optimization Complete ===\n');
        fprintf('Final best DEB: %.6f (chordal) = %.4f°\n', min(state.Score), min(state.Score)*180/pi);
        fprintf('Total generations: %d\n', state.Generation);
        
        bestVector = bestHistory(end, :);
        K = length(bestVector) / 2;
        fprintf('\nOptimal LED orientations (DEB-optimized):\n');
        for i = 1:K
            fprintf('LED %d: θ = %.2f°, ρ = %.2f°\n', i, bestVector(2*i-1), bestVector(2*i));
        end
end

end
