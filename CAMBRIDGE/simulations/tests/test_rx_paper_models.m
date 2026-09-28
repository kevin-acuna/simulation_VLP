function tests = test_rx_paper_models
tests = functiontests(localfunctions);
end

function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath')))); cambridge_setup();
t.TestData.p = rx_test_parameters();
end

function testPublishedParametersAndThreeDBDefinition(t)
for device = {'PDA100A2','PDA36A2'}
    p = bastiaens2020_parameters(t.TestData.p, device{1}, 'SQ', 90);
    angle = p.receiver.response_parameters.psi_3db_rad;
    [h, dh, info] = rx_receiver_response([1 cos(angle)], p);
    a = (1-1/sqrt(2))/angle^2;
    verifyEqual(t, h, [1 1/sqrt(2)], 'AbsTol', 2e-15);
    verifyEqual(t, dh(1), 2*a, 'RelTol', 1e-14);
    verifyEqual(t, info.effective_cutoff_deg, rad2deg(1/sqrt(a)), 'RelTol', 1e-14);
    verifyFalse(t, isfield(p.receiver, 'm_R'));
    verifyEqual(t, p.receiver.area_m2, t.TestData.p.receiver.area_m2);
end
end

function testIntrinsicCutoffIsNotOldFOV(t)
p = bastiaens2020_parameters(t.TestData.p, 'PDA100A2', 'SQ', 90);
[h,~,info] = rx_receiver_response(cosd([46 60 70 100]),p);
verifyGreaterThan(t,h(1),0);
verifyGreaterThan(t,h(2),0);
verifyEqual(t,h(3:4),[0 0]);
verifyGreaterThan(t,info.effective_cutoff_deg,64);
verifyLessThan(t,info.effective_cutoff_deg,65);
n = rx_cone_normals(5, info.effective_cutoff_deg);
verifyTrue(t,isnan(rx_peb([0;0;0.5],n,p)));
p.receiver.fov_deg = 46;
[h,~,info] = rx_receiver_response(cosd([45 50]),p);
verifyGreaterThan(t,h(1),0); verifyEqual(t,h(2),0);
verifyEqual(t,info.effective_cutoff_deg,46,'AbsTol',1e-12);
end

function testGenericChannelGradients(t)
n = rx_cone_normals(7,30);
r = [0 .25 1;0 -.15 .4;.5 .9 1.2];
for family = {'SQ','SQapprox','Exp'}
    p = bastiaens2020_parameters(t.TestData.p,'PDA100A2',family{1},90);
    [~,J,info] = rx_channel(r,n,p);
    verifyFalse(t,any(info.boundary));
    numerical = zeros(size(J));
    for j = 1:3
        step = zeros(3,1); step(j)=1e-5;
        difference = (rx_channel(r+step,n,p)-rx_channel(r-step,n,p))/(2e-5);
        numerical(:,j,:) = reshape(difference,7,1,[]);
    end
    verifyLessThan(t,norm(J(:)-numerical(:))/norm(J(:)),2e-7);
    verifyTrue(t,isreal(J));
end
end

function testAxialGeneralResponseBound(t)
for family = {'SQ','SQapprox','Exp'}
    p = bastiaens2020_parameters(t.TestData.p,'PDA100A2',family{1},90);
    theta=20; K=5; r=[0;0;.5];
    [h,dh] = rx_receiver_response(cosd(theta),p);
    [peb,info]=rx_peb(r,rx_cone_normals(K,theta),p);
    C=info.radiometric_constant_W_m2; d=info.distance_m;
    expected=sqrt(p.noise.variance_W2*d^6/(1000*K*C^2)*(4/(dh^2*sind(theta)^2)+1/(4*h^2)));
    verifyEqual(t,peb,expected,'RelTol',1e-12);
    verifyEqual(t,rx_peb(r,rx_cone_normals(5,0),p),Inf);
    a=rx_pose_error_peb(r,rx_cone_normals(K,theta),p,1000,1,'independent');
    [b,~]=rx_pose_error_peb(r,rx_cone_normals(K,theta),p,1000,1,'independent');
    verifyEqual(t,a,b,'RelTol',1e-11);
    verifyGreaterThan(t,a,peb);
end
end

function testLegacyEstimatorsCannotSilentlyUsePaperModel(t)
p = bastiaens2020_parameters(t.TestData.p,'PDA100A2','SQ',90);
n = rx_cone_normals(5,20);
y = rx_channel([0;0;.5],n,p);
verifyError(t,@() rx_estimate('GLS',y,n,p),'cambridge:CosineModelRequired');
verifyError(t,@() rx_receiver_order(p),'cambridge:CosineModelRequired');
verifyError(t,@() rx_actuation_moments([0;0;.5],n,p,1000,1),'cambridge:CosineModelRequired');
p.receiver.m_R=1.9;
verifyError(t,@() rx_channel([0;0;.5],n,p),'cambridge:ConflictingReceiverParameters');
end

function testSelectableCosineOrdersAndIndependentCutoffs(t)
base=t.TestData.p;
plain=bastiaens2020_parameters(base,'PDA100A2','cosine_1',42);
power=bastiaens2020_parameters(base,'PDA100A2','cosine_mR',42,2.3);
verifyEqual(t,plain.receiver.m_R,1);
verifyEqual(t,power.receiver.m_R,2.3);
verifyEqual(t,plain.transmitter.half_angle_power_deg,base.transmitter.half_angle_power_deg);
verifyEqual(t,rx_receiver_response(cosd([30 43]),plain),[cosd(30) 0],'AbsTol',1e-14);
verifyEqual(t,rx_receiver_response(cosd([30 43]),power),[cosd(30)^2.3 0],'AbsTol',1e-14);
reference=base; reference.receiver.m_R=1; reference.receiver.fov_deg=42;
n=rx_cone_normals(5,20); positions=[0 .2;0 -.1;.5 .6];
verifyEqual(t,rx_peb(positions,n,plain),rx_peb(positions,n,reference),'RelTol',1e-13);
d=rx_receiver_description(plain);
verifyTrue(t,isfile(fullfile(cambridge_setup(),d.PEBDerivation)));
verifyTrue(t,endsWith(d.PEBDerivation,'PEB_derivation.tex'));
end

function testDefaultCasesAndRequestedOrder(t)
base=t.TestData.p;
cases=bastiaens2020_cases(base,'PDA100A2',90,42);
verifyEqual(t,{cases.id},{'cosine_1','cosine_mR','paper_SQ'});
verifyEqual(t,cases(1).parameters.receiver.fov_deg,42);
verifyEqual(t,cases(2).parameters.receiver.fov_deg,42);
verifyEqual(t,cases(3).parameters.receiver.fov_deg,90);
chosen=bastiaens2020_cases(base,'PDA100A2',70,35,{'SQ','cosine_1'});
verifyEqual(t,{chosen.id},{'paper_SQ','cosine_1'});
verifyTrue(t,startsWith(chosen(1).label,'SQ'));
verifyTrue(t,contains(chosen(2).label,'35'));
end

function testResponseLabelsFollowCurvesAndCutoffs(t)
e=struct('devices',{{'PDA100A2'}},'families',{{'SQ','cosine_1','cosine'}}, ...
    'angles_deg',0:0.1:90,'outer_fov_deg',90,'cosine_fov_deg',40,'m_R',1.9);
r=study_pd_responses(t.TestData.p,e);
verifyGreaterThan(t,r.curves{1,1}.response(501),0);
verifyEqual(t,r.curves{1,2}.response(501),0);
verifyEqual(t,r.curves{1,3}.response(501),0);
style=ieee_plot_style(); style.visible='off'; style.export=false; style.x_limits=[-10 120];
figures=plot_pd_responses(r,style); cleanup=onCleanup(@() close(figures));
for f=figures
    ax=findall(f,'Type','axes'); verifyEqual(t,ax.XLim,[0 90]);
    lg=findall(f,'Type','legend');
    verifyEqual(t,string(lg.String(:)),string(r.labels(1,:)'));
end
end

function testSingleSelectedModelPlotsWithoutSQ(t)
p=t.TestData.p; p.design.coverage_threshold_cm=10;
p.environment.x_m=[-.2 .2]; p.environment.y_m=0; p.environment.z_m=.5;
p.environment.validation_x_m=[-.2 0 .2]; p.environment.validation_y_m=0; p.environment.validation_z_m=.5;
e=struct('device','PDA100A2','families',{{'cosine_1'}},'outer_fov_deg',90,'cosine_fov_deg',46, ...
    'm_R',[],'K',5,'tilt_values_deg',[0 10 20],'azimuth_offset_deg',0,'budget','per_orientation', ...
    'orientation_std_deg',1,'orientation_structure','independent','minimum_coverage_percent',95, ...
    'near_peak_loss_pp',1,'map_heights_m',.5,'plot_max_tilt_deg',90);
r=study_pd_K5(p,e);
verifyNumElements(t,r.cases,1);
style=ieee_plot_style(); style.visible='off'; style.export=false;
figures=plot_pd_K5(r,style); cleanup=onCleanup(@() close(figures));
verifyNumElements(t,figures,3);
for f=figures(1:2)
    axes=findall(f,'Type','axes');
    for ax=axes', verifyEqual(t,ax.XLim,[0 90]); end
end
verifyTrue(t,contains(figures(3).UserData.export_name,'cosine_1'));
axes=findall(figures(2),'Type','axes');
for ax=axes'
    reference=findall(ax,'Tag','PEB_10cm_reference');
    assertNumElements(t,reference,1);
    verifyEqual(t,reference.Value,10);
    verifyEqual(t,reference.LineStyle,':');
    verifyEqual(t,reference.Color,[.5 .5 .5]);
    verifyEqual(t,reference.HandleVisibility,'off');
end
end
