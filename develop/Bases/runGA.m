function runGA()
    rng('default'); 

    % Number of decision variables:
    nvars = 6;  % [theta1, rho1, theta2, rho2, theta3, rho3]

    % Lower (lb) and upper (ub) bounds for each variable:
    % In this example, theta in [0, 60] (degrees) and rho in [0, 360] (degrees).
    lb = [0,   0,   0,   0,   0,   0 ];
    ub = [60, 360, 60, 360, 60, 360];

    % Linear or nonlinear constraints (none in this example)
    A = []; b = [];
    Aeq = []; beq = [];
    nonlcon = [];

    % GA options
    options = optimoptions('ga', ...
        'PopulationSize',   100, ...
        'MaxGenerations',   50, ...
        'CrossoverFraction', 0.6, ... 
        'Display',          'iter', ...
        'PlotFcn',          {@gaplotbestf}, ...  % Standard GA plot for best fitness
        'OutputFcn',        @evolution_orientation); % Custom output function

    
    % Run GA
    [xOpt, fvalOpt, exitflag, output] = ga(@RMS_orientation, nvars, ...
                                           A, b, Aeq, beq, lb, ub, ...
                                           nonlcon, options);

%     % Run GA
%     [xOpt, fvalOpt, exitflag, output] = ga(@Complex_Cost_Orientation, nvars, ...
%                                            A, b, Aeq, beq, lb, ub, ...
%                                            nonlcon, options);

    % Display results
    fprintf('Best solution found:\n');
    disp(xOpt);
    fprintf('RMS (cost) at this solution: %f\n', fvalOpt);
    fprintf('Additional info:\n');
    disp(output);
end

%'UseParallel',      true, ...