function [state, options, optchanged] = evolution_orientation(options, state, flag)
    % Custom output function for GA. It plots:
    % 1) The evolution of the 6 angles over generations (in one figure).
    % 2) The 3D orientation of the best solution in each generation (in another figure).
    %
    % Inputs:
    %   options  - GA options structure.
    %   state    - Current generation state, includes population and scores.
    %   flag     - Stage indicator ('init', 'iter', or 'done').
    %
    % Outputs:
    %   state, options, optchanged - required for the output function signature.

    optchanged = false;

    % Use persistent variables to store data and figure handles across generations
    persistent bestHistory figAngleEvolution fig3DOrientation

    switch flag
        case 'init'
            % Initialize history and create separate figures
            bestHistory = [];
            figAngleEvolution = figure('Name','Angles Evolution','NumberTitle','off');
            fig3DOrientation  = figure('Name','3D Orientation','NumberTitle','off');

        case 'iter'
            % Identify the best solution (lowest score) in the current population
            [~, bestIdx] = min(state.Score);
            bestVector   = state.Population(bestIdx, :);  % [theta1, rho1, theta2, rho2, theta3, rho3]

            % Store this best solution in the history
            bestHistory = [bestHistory; bestVector];

            %% =========== 1) Plot the angle evolution ===========
            figure(figAngleEvolution);
            clf;  % Clear the figure to redraw
            numVars = size(bestHistory, 2);
            for i = 1:numVars
                subplot(3, 2, i);
                plot(bestHistory(:, i), 'o-', 'LineWidth', 1.5);
                xlabel('Generation');
                ylabel(sprintf('Angle x(%d)', i));
                title(sprintf('Evolution of x(%d)', i));
                if (mod(i,2)==1)
                    ylim([-2 62]);
                else
                    ylim([-2 362]);
                end
                grid on;
            end
            drawnow;

            %% =========== 2) Plot the 3D orientation of each transmitter ===========
            figure(fig3DOrientation);
            clf; 
            hold on;
            axis equal;
            grid on;
            % We set the axis so arrows are clearly visible from -1 to +1
            axis([-1 1 -1 1 -1 1]);
            title(sprintf('3D Orientation at Generation %d', state.Generation));

            % Extract angles for each transmitter
            % bestVector = [theta1, rho1, theta2, rho2, theta3, rho3]
            % In degrees => convert to radians
            % We'll define the unit vector as:
            %   X = sin(theta)*cos(rho)
            %   Y = sin(theta)*sin(rho)
            %   Z = -cos(theta)
            % so that theta=0 => vector is along -Z.
            % NOTE: adjust if your definition differs.

            for tx = 1:3
                theta_deg = bestVector(2*(tx-1) + 1);
                rho_deg   = bestVector(2*(tx-1) + 2);

                theta_rad = deg2rad(theta_deg);
                rho_rad   = deg2rad(rho_deg);

                % Unit vector
                x_u = sin(theta_rad)*cos(rho_rad);
                y_u = sin(theta_rad)*sin(rho_rad);
                z_u = -cos(theta_rad);

                % Plot the quiver from (0,0,0) to (x_u, y_u, z_u)
                % Use different colors for each transmitter
                switch tx
                    case 1
                        c = [0.0000 0.4470 0.7410];  % Red
                    case 2
                        c = [0.8500 0.3250 0.0980];  % Green
                    case 3
                        c = [0.9290 0.6940 0.1250];  % Blue
                end

                quiver3(0, 0, 0, x_u, y_u, z_u, ...
                    'Color', c, ...
                    'LineWidth', 2, ...
                    'MaxHeadSize', 1.0, ...
                    'AutoScale','off');
            end

            % Grafica de estimacion de posicon
            [x_est, y_est, x_real, y_real] = xest_RMS_orientation(bestVector);
            scatter(x_real, y_real, 'o', 'MarkerEdgeColor', "k"); 
            scatter(x_est, y_est, 'x', 'MarkerEdgeColor', [0.8500 0.3250 0.0980]);
            

            axis([-1.2 1.2 -1.2 1.2 -2 0])
            % Fix a nice 3D view angle
            view([0 90]);  % Adjust as you wish

            hold off;
            drawnow;

        case 'done'
            % Optional: any final actions when GA finishes
    end
end
