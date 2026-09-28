function p = bastiaens2020_parameters(base, device, family, outer_fov_deg, receiver_order)
if nargin<5, receiver_order=[]; end
if ~isempty(receiver_order)
    validateattributes(receiver_order,{'numeric'},{'scalar','real','finite','positive'});
end
validateattributes(outer_fov_deg, {'numeric'}, {'scalar', 'real', 'finite', '>', 0, '<=', 90});
p = base;
switch upper(char(device))
    case 'PDA100A2'
        reference = struct('device','PDA100A2','psi_3db_rad',0.61,'psi_half_rad',0.80, ...
            'exponential_slope',2.39,'cosine_order',1.9,'device_area_mm2',75.4,'paper_transimpedance_V_per_A',4.75e4);
    case 'PDA36A2'
        reference = struct('device','PDA36A2','psi_3db_rad',0.79,'psi_half_rad',1.06, ...
            'exponential_slope',2.3,'cosine_order',0.98,'device_area_mm2',13,'paper_transimpedance_V_per_A',4.75e5);
    otherwise
        error('cambridge:PaperDevice','Choose PDA100A2 or PDA36A2.');
end
reference.doi = '10.1109/ACCESS.2020.2991298';
reference.provenance = 'Bastiaens et al., IEEE Access 2020, Table 1 and Section III-A2, published rounded parameters';
p.receiver.paper_reference = reference;
p.receiver.fov_deg = outer_fov_deg;
if isfield(p.receiver,'m_R')
    p.receiver = rmfield(p.receiver,'m_R');
end
switch lower(char(family))
    case 'sq'
        p.receiver.response_model = 'bastiaens_sq';
        p.receiver.response_parameters = struct('psi_3db_rad',reference.psi_3db_rad);
    case 'sqapprox'
        p.receiver.response_model = 'bastiaens_sqapprox';
        p.receiver.response_parameters = struct('psi_3db_rad',reference.psi_3db_rad);
    case 'exp'
        p.receiver.response_model = 'bastiaens_exp';
        p.receiver.response_parameters = struct('psi_half_rad',reference.psi_half_rad,'slope',reference.exponential_slope);
    case {'cosine','cosine_mr'}
        p.receiver.response_model = 'cosine_power';
        p.receiver.m_R = reference.cosine_order;
        if ~isempty(receiver_order), p.receiver.m_R=receiver_order; end
        p.receiver.response_parameters = struct();
    case 'cosine_1'
        p.receiver.response_model = 'cosine_power';
        p.receiver.m_R = 1;
        p.receiver.response_parameters = struct();
    otherwise
        error('cambridge:PaperFamily','Choose cosine_1, cosine (or cosine_mR), SQ, SQapprox or Exp.');
end
end
