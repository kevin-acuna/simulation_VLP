function d = rx_receiver_description(p)
[~,~,info] = rx_receiver_response(1,p);
d = struct('Model',string(info.model),'Device',"generic",'OuterFOV_deg',p.receiver.fov_deg, ...
    'EffectiveSupport_deg',info.effective_cutoff_deg,'m_R',info.receiver_order, ...
    'Psi3dB_rad',NaN,'PsiHalf_rad',NaN,'ExponentialSlope',NaN,'UsedArea_mm2',p.receiver.area_m2*1e6, ...
    'ReferenceDeviceArea_mm2',NaN);
if isfield(p.receiver,'paper_reference')
    ref = p.receiver.paper_reference;
    d.Device = string(ref.device);
    d.ReferenceDeviceArea_mm2 = ref.device_area_mm2;
end
if isfield(p.receiver,'response_parameters')
    par = p.receiver.response_parameters;
    if isfield(par,'psi_3db_rad'), d.Psi3dB_rad = par.psi_3db_rad; end
    if isfield(par,'psi_half_rad'), d.PsiHalf_rad = par.psi_half_rad; end
    if isfield(par,'slope'), d.ExponentialSlope = par.slope; end
end
switch info.model
    case 'cosine_power'
        if info.receiver_order==1
            label=sprintf('cos(\\psi), FOV %g deg',p.receiver.fov_deg);
            reference=fullfile('Bounds (3D)','Position Error Bound','PEB_derivation.tex');
        else
            label=sprintf('cos^{%g}(\\psi), FOV %g deg',info.receiver_order,p.receiver.fov_deg);
            reference=fullfile('Bounds (3D)','Position Error Bound','PEB_derivation_mR.tex');
        end
    otherwise
        names=struct('bastiaens_sq','SQ','bastiaens_sqapprox','SQapprox','bastiaens_exp','Exp');
        label=sprintf('%s, support %.2f deg',names.(info.model),info.effective_cutoff_deg);
        reference=fullfile('Receiver models','Bastiaens 2020','PD_models_and_PEB.tex');
end
d.Label=string(label);
d.PEBDerivation=string(reference);
end
