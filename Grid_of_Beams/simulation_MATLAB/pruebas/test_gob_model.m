function tests = test_gob_model
tests = functiontests(localfunctions);
end

function testSnell(testCase)
c = gob_config();
m = gob_model(c);
x = m.local_xy(1,:); y = m.local_xy(2,:); R = c.radii(1);
normal = [x;y;sqrt(R^2-x.^2-y.^2)]/R;
incoming = repmat([0;0;1],1,25);
v = m.local_directions(:,:,1);
verifyEqual(testCase,vecnorm(v),ones(1,25),'AbsTol',1e-13);
verifyEqual(testCase,cross(normal,v),c.index*cross(normal,incoming),'AbsTol',1e-13);
verifyEqual(testCase,v(:,13),[0;0;1],'AbsTol',1e-13);
verifyTrue(testCase,all(v(1,:).*x<=0));
end

function testABCD(testCase)
c = gob_config(); m = gob_model(c);
f = c.radii(1)/(c.index-1); zr = pi*c.waist^2/c.wavelength;
u = c.array_lens_distance+m.thicknesses(:,1)/c.index;
den = (1-u/f).^2+(zr/f)^2;
expected = (u.*(1-u/f)-zr^2/f)./den+1i*zr./den;
verifyEqual(testCase,m.local_q(:,1),expected,'RelTol',1e-12);
B = m.thicknesses(:,1)/c.index; C = -1/f; D = 1-B/f;
verifyEqual(testCase,D-B*C,ones(25,1),'AbsTol',1e-14);
end

function testJacobian(testCase)
for tiles = [1,9]
    m = gob_model(gob_config(struct('tiles',tiles,'radii',[.013,.015,.020])));
    p = [.217;-.138;.37]; h = 1e-6;
    [~,J] = gob_power(m,p); numerical = zeros(m.n_channels,3);
    for d = 1:3
        dp = zeros(3,1); dp(d) = h;
        numerical(:,d) = (gob_power(m,p+dp)-gob_power(m,p-dp))/(2*h);
    end
    verifyLessThan(testCase,max(abs(J-numerical)./(1e-13+abs(numerical)),[],'all'),2e-5);
end
end

function testConcave(testCase)
c = gob_config(struct('radii',-.012,'edge_thickness',.004)); m = gob_model(c);
x = m.local_xy(1,:); y = m.local_xy(2,:); R = c.radii;
normal = [x/R;y/R;sqrt(1-(x.^2+y.^2)/R^2)]; v = m.local_directions(:,:,1);
verifyEqual(testCase,cross(normal,v),c.index*cross(normal,repmat([0;0;1],1,25)),'AbsTol',1e-13);
verifyTrue(testCase,all(v(1,:).*x>=0));
verifyGreaterThan(testCase,min(m.thicknesses,[],'all'),0);
end

function testInvalidGeometry(testCase)
verifyError(testCase,@()gob_model(gob_config(struct('radii',.007))),'gob:Geometry');
verifyError(testCase,@()gob_model(gob_config(struct('pitch',.003))),'gob:Geometry');
verifyError(testCase,@()gob_model(gob_config(struct('edge_thickness',-.001))),'gob:Geometry');
end

function testProjection(testCase)
m = gob_model(gob_config()); p = gob_power(m,[0;0;0]);
verifyGreaterThan(testCase,p(13),0);
verifyEqual(testCase,gob_power(m,[0;0;0],[0;0;-1]),zeros(25,1));
narrow = gob_model(gob_config(struct('fov_deg',1)));
verifyEqual(testCase,nnz(gob_power(narrow,[0;0;0])),1);
end

function testFullGridLabels(testCase)
single = gob_model(gob_config());
full = gob_model(gob_config(struct('tiles',9,'radii',[.015,.017])));
verifySize(testCase,gob_power(full,[0;0;0]),[450,1]);
verifyEqual(testCase,full.directions(:,101:125),single.directions,'AbsTol',1e-14);
verifyEqual(testCase,full.origins(:,101:125),single.origins,'AbsTol',1e-14);
end

function testTuning(testCase)
m = gob_model(gob_config(struct('radii',[.013,.020])));
verifyGreaterThan(testCase,norm(m.local_directions(:,1,1)-m.local_directions(:,1,2)),.01);
verifyGreaterThan(testCase,norm(m.local_q(:,1)-m.local_q(:,2)),1e-4);
verifyGreaterThan(testCase,norm(m.origins(:,1:25)-m.origins(:,26:50),'fro'),1e-4);
end

function testEnergyAndExitWidth(testCase)
c = gob_config(); m = gob_model(c); q = m.q(13);
zr = pi*c.waist^2/c.wavelength; u = c.array_lens_distance+m.thicknesses(13)/c.index;
verifyEqual(testCase,c.wavelength/pi*abs(q)^2/imag(q),c.waist^2*(1+(u/zr)^2),'RelTol',1e-12);
w2 = c.wavelength/pi*abs(q+3)^2/imag(q);
power = integral(@(r)2*c.power/(pi*w2)*exp(-2*r.^2/w2).*2*pi.*r,0,8*sqrt(w2));
verifyEqual(testCase,power,c.power,'RelTol',1e-10);
end

function testNoise(testCase)
n = gob_noise(struct('repeatability',0));
n2 = gob_update(n,struct('bandwidth',400));
verifyEqual(testCase,gob_sigma([0;1e-6],n2),2*gob_sigma([0;1e-6],n),'RelTol',1e-13);
verifyGreaterThan(testCase,gob_sigma(1e-6,n),gob_sigma(0,n));
end

function testFinitePD(testCase)
m = gob_model(gob_config()); p = [.1;.1;.2];
[x,y] = meshgrid(linspace(-.0005,.0005,31));
points = p+[x(:)';y(:)';zeros(1,numel(x))];
averaged = mean(gob_power(m,points),2); point = gob_power(m,p);
strong = point>max(point)*1e-4;
verifyEqual(testCase,averaged(strong),point(strong),'RelTol',.003);
end
