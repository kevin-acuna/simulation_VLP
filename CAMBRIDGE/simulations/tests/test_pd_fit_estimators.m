function tests = test_pd_fit_estimators
tests=functiontests(localfunctions);
end

function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath')))); cambridge_setup();
t.TestData.base=rx_test_parameters();
end

function testSearchSeedsStayOnUnitSphere(t)
p=bastiaens2020_parameters(t.TestData.base,'PDA100A2','SQ',90);
a=pd_fit_context(rx_cone_normals(5,20),p,[],struct());
verifyEqual(t,sum(a.seeds.^2,1),ones(1,size(a.seeds,2)),'AbsTol',1e-13);
verifyGreaterThan(t,min(a.q'*a.seeds),0);
end

function testNoiselessFitsForAllFamilies(t)
n=rx_cone_normals(5,20); r=[.2;-.15;.6];
for family={'SQ','SQapprox','Exp'}
    p=bastiaens2020_parameters(t.TestData.base,'PDA100A2',family{1},90);
    y=rx_channel(r,n,p);
    for method={'joint_nls','profile_nls','ratio_gls','ratio_wls'}
        [estimate,info]=pd_fit_estimate(method{1},y,n,p);
        verifyTrue(t,info.success, char(info.status));
        verifyEqual(t,estimate,r,'AbsTol',2e-6);
    end
end
end

function testProfileAndRatioJacobians(t)
p=bastiaens2020_parameters(t.TestData.base,'PDA100A2','SQ',90);
n=rx_cone_normals(7,25); y=rx_channel([.2;-.1;.5],n,p); y=y/max(y);
a=pd_fit_context(n,p,[],struct()); a=pd_fit_observation(a,y);
u=[.1;.05;1]; u=u/norm(u); gamma=1.2;
for method={'joint_nls','profile_nls','ratio_gls','ratio_wls'}
    [~,J]=pd_fit_residual(u,gamma,y,a,method{1});
    E=rx_tangent_basis(u); numeric=zeros(size(J)); step=1e-5;
    for j=1:size(J,2)
        if j<=2
            plus=cos(step)*u+sin(step)*E(:,j); minus=cos(step)*u-sin(step)*E(:,j);
            ra=pd_fit_residual(plus,gamma,y,a,method{1}); rb=pd_fit_residual(minus,gamma,y,a,method{1});
        else
            ra=pd_fit_residual(u,gamma*exp(step),y,a,method{1});
            rb=pd_fit_residual(u,gamma*exp(-step),y,a,method{1});
        end
        numeric(:,j)=(ra-rb)/(2*step);
    end
    verifyLessThan(t,norm(J-numeric,'fro')/norm(J,'fro'),2e-7);
end
end

function testAffineSQapproxClosedForm(t)
p=bastiaens2020_parameters(t.TestData.base,'PDA100A2','SQapprox',90);
n=rx_cone_normals(5,20); r=[.2;-.1;.6];
y=rx_channel(r,n,p)+1e-8*[1;-.5;.2;-.3;.4];
[a,ia]=pd_fit_estimate('sqapprox_ls',y,n,p);
[b,ib]=pd_fit_estimate('profile_nls',y,n,p);
verifyTrue(t,ia.success && ib.success);
verifyEqual(t,a,b,'AbsTol',2e-6);
verifyEqual(t,ia.objective,ib.objective,'AbsTol',1e-6);
p=bastiaens2020_parameters(t.TestData.base,'PDA100A2','SQ',90);
verifyError(t,@() pd_fit_estimate('sqapprox_ls',y,n,p),'cambridge:SQapproxRequired');
end

function testNonlinearRankMustUseActualJacobian(t)
p=bastiaens2020_parameters(t.TestData.base,'PDA100A2','SQ',90);
n=rx_normals([5 15 30 45 55],[0 0 0 0 0]);
r=[.1;.3;.5];
[peb,info]=rx_peb(r,n,p);
verifyEqual(t,rank(n'),2);
verifyEqual(t,info.rank,3);
verifyTrue(t,isfinite(peb));
mirror=r; mirror(2)=-mirror(2);
verifyEqual(t,rx_channel(r,n,p),rx_channel(mirror,n,p),'AbsTol',1e-20);
end
