function [state, options, optchanged] = PEB_Gaussian_monitor(options, state, flag)
% PEB_Gaussian_monitor - GA OutputFcn for VCSEL codebook optimization
%
% Tracks best fitness per generation and visualizes the current best codebook
% orientations on the downward unit hemisphere.

optchanged = false;
persistent bestHist figConv fig3D

switch flag
    case 'init'
        bestHist = [];
        figConv = figure('Name','Codebook GA - Convergence','NumberTitle','off');
        fig3D   = figure('Name','Codebook GA - Best Orientations','NumberTitle','off');

    case 'iter'
        bestHist(end+1) = min(state.Score); %#ok<AGROW>

        figure(figConv); clf;
        plot(0:numel(bestHist)-1, 100*bestHist, '-o', 'LineWidth', 1.2, ...
            'Color', [0.2 0.4 0.8], 'MarkerFaceColor', [0.2 0.4 0.8], 'MarkerSize', 3);
        xlabel('Generation'); ylabel('Best fitness [cm]'); grid on;
        title(sprintf('Gen %d  |  best = %.2f cm', state.Generation, 100*min(state.Score)));
        drawnow;

        [~, bi] = min(state.Score);
        v = state.Population(bi, :);
        K = numel(v)/2;
        nt = zeros(3, K);
        for i = 1:K
            t = deg2rad(v(2*i-1)); r = deg2rad(v(2*i));
            nt(:, i) = [sin(t)*cos(r); sin(t)*sin(r); -cos(t)];
        end
        figure(fig3D); clf; hold on;
        [X, Y, Z] = sphere(20); Z = -abs(Z);
        surf(0.3*X, 0.3*Y, 0.3*Z, 'FaceAlpha', 0.08, 'EdgeAlpha', 0.1, 'FaceColor', [0.7 0.7 0.7]);
        cols = lines(K);
        for i = 1:K
            quiver3(0,0,0, nt(1,i), nt(2,i), nt(3,i), 0.8, 'Color', cols(i,:), 'LineWidth', 2);
        end
        axis equal; grid on; view(0, 90);
        xlim([-1 1]); ylim([-1 1]); zlim([-1 0.2]);
        title(sprintf('Best codebook (top view) - Gen %d', state.Generation));
        hold off; drawnow;

    case 'done'
        fprintf('\n=== Codebook GA complete: best fitness = %.4f cm ===\n', 100*min(state.Score));
end
end
