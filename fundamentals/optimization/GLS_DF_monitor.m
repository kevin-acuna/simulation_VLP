function [state, options, optchanged] = GLS_DF_monitor(options, state, flag)
% GLS_DF_MONITOR  Monitoring function for GA optimization of GLS direction finding.
%
% Monitors the GA optimization process, creates visualizations of the
% evolution of orientation angles and 3D orientation patterns, and logs
% orientation values at the end of each generation.
%
% INPUTS:
%   options  - GA options structure
%   state    - Current generation state with population and scores
%   flag     - Stage indicator: 'init', 'iter', or 'done'
%
% OUTPUTS:
%   state, options, optchanged - Required GA output function signature

optchanged = false;

persistent bestHistory figAngleEvolution fig3DOrientation logFile logFilename

switch flag
    case 'init'
        bestHistory = [];
        figAngleEvolution = figure('Name', 'GLS DF Optimization - Angle Evolution', 'NumberTitle', 'off');
        fig3DOrientation  = figure('Name', 'GLS DF Optimization - 3D Orientations', 'NumberTitle', 'off');

        results_dir = 'results/GLS_DF_optimization';
        if ~exist(results_dir, 'dir'), mkdir(results_dir); end

        current_datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
        logFilename = fullfile(results_dir, sprintf('orientation_log_GLS_DF_%s.txt', current_datetime));
        logFile = fopen(logFilename, 'w');

        fprintf(logFile, '======================================================================\n');
        fprintf(logFile, 'GLS DF OPTIMIZATION — ORIENTATION VALUES LOG\n');
        fprintf(logFile, '======================================================================\n');
        fprintf(logFile, 'Log started: %s\n', datestr(now));
        fprintf(logFile, 'Format: Generation | RMS_Ang_Error(deg) | K_vector=[theta1,rho1,...]\n');
        fprintf(logFile, '======================================================================\n\n');

        fprintf('GLS DF Monitor initialized. Log file: %s\n', logFilename);

    case 'iter'
        [bestRMS, bestIdx] = min(state.Score);
        bestVector = state.Population(bestIdx, :);

        bestHistory = [bestHistory; bestVector];
        K = length(bestVector) / 2;

        % Write one line per generation to log
        k_vec_str = '[';
        for i = 1:length(bestVector)
            if i == 1
                k_vec_str = [k_vec_str, sprintf('%.3f', bestVector(i))];
            else
                k_vec_str = [k_vec_str, sprintf(',%.3f', bestVector(i))];
            end
        end
        k_vec_str = [k_vec_str, ']'];
        fprintf(logFile, '%10d | %12.6f | %s\n', state.Generation, bestRMS, k_vec_str);

        %% 1) Angle evolution plot
        figure(figAngleEvolution); clf;
        numRows = ceil(K); numCols = 2;
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
        sgtitle(sprintf('GLS DF Optimization — Gen %d  (Best RMS: %.4f°)', ...
            state.Generation, bestRMS));
        drawnow;

        %% 2) 3D orientation plot
        figure(fig3DOrientation); clf;
        nt_orientations = zeros(3, K);
        colors = lines(K);
        for i = 1:K
            theta_rad = deg2rad(bestVector(2*i-1));
            rho_rad   = deg2rad(bestVector(2*i));
            nt_orientations(:, i) = [sin(theta_rad)*cos(rho_rad);
                                      sin(theta_rad)*sin(rho_rad);
                                      -cos(theta_rad)];
        end
        hold on;
        for i = 1:K
            nt = nt_orientations(:, i);
            quiver3(0, 0, 0, nt(1), nt(2), nt(3), 0.8, ...
                'Color', colors(i,:), 'LineWidth', 3, ...
                'DisplayName', sprintf('LED %d (θ=%.1f°, ρ=%.1f°)', ...
                i, bestVector(2*i-1), bestVector(2*i)));
        end
        [X, Y, Z] = sphere(20);
        Z = -abs(Z);
        surf(X*0.3, Y*0.3, Z*0.3, 'FaceAlpha', 0.1, 'EdgeAlpha', 0.1, ...
            'FaceColor', [0.7 0.7 0.7], 'DisplayName', '');
        xlabel('X'); ylabel('Y'); zlabel('Z');
        title(sprintf('LED Orientations — Gen %d\nBest RMS: %.4f°', state.Generation, bestRMS));
        legend('Location', 'best');
        axis equal; grid on;
        view(90, 90);
        xlim([-1 1]); ylim([-1 1]); zlim([-1 0.2]);
        hold off;
        drawnow;

    case 'done'
        fprintf('\n=== GLS DF Optimization Complete ===\n');
        fprintf('Final best RMS angular error: %.4f°\n', min(state.Score));
        fprintf('Total generations: %d\n', state.Generation);

        fprintf(logFile, '\n======================================================================\n');
        fprintf(logFile, 'OPTIMIZATION COMPLETED\n');
        fprintf(logFile, '======================================================================\n');
        fprintf(logFile, 'Completion time: %s\n', datestr(now));
        fprintf(logFile, 'Total generations: %d\n', state.Generation);
        fprintf(logFile, 'Final best RMS angular error: %.6f°\n', min(state.Score));

        bestVector = bestHistory(end, :);
        K = length(bestVector) / 2;
        fprintf('\nOptimal LED orientations (GLS DF-optimized):\n');

        final_k_vec_str = '[';
        for i = 1:length(bestVector)
            if i == 1
                final_k_vec_str = [final_k_vec_str, sprintf('%.3f', bestVector(i))];
            else
                final_k_vec_str = [final_k_vec_str, sprintf(',%.3f', bestVector(i))];
            end
        end
        final_k_vec_str = [final_k_vec_str, ']'];
        fprintf(logFile, '\nFINAL OPTIMAL K_VECTOR: %s\n', final_k_vec_str);

        for i = 1:K
            fprintf('LED %d: θ = %.2f°, ρ = %.2f°\n', i, bestVector(2*i-1), bestVector(2*i));
        end

        fprintf(logFile, '======================================================================\n');
        if logFile ~= -1
            fclose(logFile);
            fprintf('Log saved to: %s\n', logFilename);
        end
end

end
