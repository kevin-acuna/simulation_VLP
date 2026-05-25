function d_hat = vlp_nls_fmincon(nt, Praw, m)
% VLP_NLS_FMINCON  NLS direction estimator using fmincon/SQP
%
% Solves the normalized-power NLS cost function using fmincon with SQP
% algorithm and a unit-sphere equality constraint. Uses BFGS Hessian
% approximation (generic quasi-Newton, not Gauss-Newton).
%
% Inputs:
%   nt   : 3×K  — LED orientation vectors (columns)
%   Praw : N×K  — raw power samples (rows = samples, cols = orientations)
%   m    : scalar, Lambertian order
%
% Output:
%   d_hat : 3×1 unit direction vector (Tx → Rx)

persistent opts_sqp
if isempty(opts_sqp)
    opts_sqp = optimoptions('fmincon', 'Display', 'none', 'Algorithm', 'sqp', ...
        'StepTolerance', 1e-12, 'OptimalityTolerance', 1e-12, ...
        'MaxFunctionEvaluations', 5000, 'MaxIterations', 1000);
end

K = size(nt, 2);
nt_rows = nt';  % K×3

% 1. Normalized power targets
mu_hat = mean(Praw, 1);
max_mu = max(mu_hat);
if max_mu <= 0; max_mu = 1e-12; end
p_target = mu_hat / max_mu;

% 2. Initial guess: orientation with max power
[~, idx] = max(p_target);
best_nt = nt_rows(idx, :);
x0 = [best_nt(1), best_nt(2), best_nt(3), 1.0];

% 3. Solve with fmincon/SQP
obj = @(vars) nls_cost(vars, p_target, nt_rows, m);
con = @(vars) sphere_eq(vars);
[sol, ~, ~] = fmincon(obj, x0, [], [], [], [], ...
    [-1,-1,-1,1e-3], [1,1,0,10], con, opts_sqp);

% 4. Extract unit direction
nrm = norm(sol(1:3));
if nrm < 1e-12; nrm = 1e-12; end
d_hat = sol(1:3)' / nrm;  % 3×1 column

% Sign correction (towards receiver = same hemisphere as LED orientations)
if dot(d_hat, nt(:,1)) < 0
    d_hat = -d_hat;
end
end

% --- Local: scalar cost function ---
function F = nls_cost(vars, p_target, nt_rows, m)
    v = vars(1:3);
    eta = vars(4);
    F = 0;
    for i = 1:size(nt_rows, 1)
        Q = max(0, dot(nt_rows(i,:), v));
        F = F + (eta * Q^m - p_target(i))^2;
    end
end

% --- Local: sphere equality constraint ---
function [c, ceq] = sphere_eq(vars)
    c = [];
    ceq = vars(1)^2 + vars(2)^2 + vars(3)^2 - 1;
end
