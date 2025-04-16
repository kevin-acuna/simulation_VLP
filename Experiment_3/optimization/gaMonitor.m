function [state, options, optchanged] = gaMonitor(options, state, flag)
    % GAMONITOR Función de monitoreo para GA que grafica:
    % 1) La evolución de los ángulos a lo largo de las generaciones (en una figura).
    % 2) La orientación 3D de la mejor solución en cada generación (en otra figura).
    %
    % Entradas:
    %   options  - Estructura de opciones de GA.
    %   state    - Estado de la generación actual, incluye población y puntuaciones.
    %   flag     - Indicador de etapa ('init', 'iter' o 'done').
    %
    % Salidas:
    %   state, options, optchanged - requerido para la firma de la función de salida.

    optchanged = false;

    % Usar variables persistentes para almacenar datos y manipuladores de figuras a través de generaciones
    persistent bestHistory figAngleEvolution fig3DOrientation

    switch flag
        case 'init'
            % Inicializar historial y crear figuras separadas
            bestHistory = [];
            figAngleEvolution = figure('Name','Evolución de Ángulos','NumberTitle','off');
            fig3DOrientation  = figure('Name','Orientación 3D','NumberTitle','off');

        case 'iter'
            % Identificar la mejor solución (puntuación más baja) en la población actual
            [~, bestIdx] = min(state.Score);
            bestVector   = state.Population(bestIdx, :);  % [theta1, rho1, theta2, rho2, ..., thetan, rhon]

            % Almacenar esta mejor solución en el historial
            bestHistory = [bestHistory; bestVector];

            %% =========== 1) Graficar la evolución del ángulo ===========
            figure(figAngleEvolution);
            clf;  % Limpiar la figura para redibujar
            numVars = size(bestHistory, 2);
            
            % Calcular dimensiones de subgráficos según el número de variables
            numRows = ceil(numVars/2);
            numCols = 2; % Usar siempre 2 columnas para pares theta/rho
            
            for i = 1:numVars
                subplot(numRows, numCols, i);
                plot(bestHistory(:, i), 'o-', 'LineWidth', 1.5);
                xlabel('Generación');
                
                % Etiquetar según si es theta o rho
                if mod(i, 2) == 1 % Índices impares son valores theta
                    ylabel(sprintf('Theta %d (°)', ceil(i/2)));
                    title(sprintf('Evolución de Theta %d', ceil(i/2)));
                    ylim([-2 62]);
                else % Índices pares son valores rho
                    ylabel(sprintf('Rho %d (°)', i/2));
                    title(sprintf('Evolución de Rho %d', i/2));
                    ylim([-2 362]);
                end
                grid on;
            end
            drawnow;

            %% =========== 2) Graficar la orientación 3D de cada transmisor ===========
            figure(fig3DOrientation);
            clf; 
            hold on;
            axis equal;
            grid on;
            % Configuramos el eje para que las flechas sean claramente visibles de -1 a +1
            axis([-1 1 -1 1 -1 1]);
            title(sprintf('Generation %d', state.Generation));

            % Extraer ángulos para cada transmisor
            % bestVector = [theta1, rho1, theta2, rho2, ..., thetan, rhon]
            % En grados => convertir a radianes
            % Definiremos el vector unitario como:
            %   X = sin(theta)*cos(rho)
            %   Y = sin(theta)*sin(rho)
            %   Z = -cos(theta)
            % de modo que theta=0 => vector está a lo largo de -Z.
            
            % Determinar número de orientaciones
            numOrientations = length(bestVector) / 2;
            
            % Crear un mapa de colores para las orientaciones
            colors = lines(numOrientations);

            for tx = 1:numOrientations
                theta_deg = bestVector(2*(tx-1) + 1);
                rho_deg   = bestVector(2*(tx-1) + 2);

                % Convertir a radianes
                theta_rad = deg2rad(theta_deg);
                rho_rad   = deg2rad(rho_deg);

                % Vector unitario
                x_u = sin(theta_rad)*cos(rho_rad);
                y_u = sin(theta_rad)*sin(rho_rad);
                z_u = -cos(theta_rad);

                % Graficar el vector desde (0,0,0) hasta (x_u, y_u, z_u)
                % Usar diferentes colores para cada transmisor desde el mapa de colores
                quiver3(0, 0, 0, x_u, y_u, z_u, ...
                    'Color', colors(tx,:), ...
                    'LineWidth', 2, ...
                    'MaxHeadSize', 1.0, ...
                    'AutoScale','off');
            end

            % Gráfica de estimación de posición
            % Llamar a rmseCalculator para obtener el error RMS, pero necesitamos obtener x_est, y_est, etc.
            % Usaremos la función positionEstimator para obtener estos valores
            [x_est, y_est, x_real, y_real] = positionEstimator(bestVector);
            scatter(x_real, y_real, 'o', 'MarkerEdgeColor', "k"); 
            scatter(x_est, y_est, 'x', 'MarkerEdgeColor', [0.8500 0.3250 0.0980]);
            

            axis([-1.2 1.2 -1.2 1.2 -2 0])
            % Fijar un buen ángulo de vista 3D
            view([0 90]);  % Ajustar según se desee

            hold off;
            drawnow;

        case 'done'
            % Opcional: cualquier acción final cuando GA termina
    end
end
