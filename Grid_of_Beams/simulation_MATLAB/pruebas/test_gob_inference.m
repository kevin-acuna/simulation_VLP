function tests = test_gob_inference
tests = functiontests(localfunctions);
end

function testNoiseless(testCase)
configs = {gob_config(),gob_config(struct('radii',[.012,.015])), ...
    gob_config(struct('radii',[-.010,-.011],'edge_thickness',.006)), ...
    gob_config(struct('tiles',9,'radii',[.012,.015]))};
for k = 1:numel(configs)
    m = gob_model(configs{k});
    for d = [2,3]
        bounds = [-.6,.6;-.6,.6]; counts = [21,21]; p = [.2137;-.1463;0];
        if d==3, bounds = [bounds;0,1]; counts = [counts,5]; p(3) = .436; end
        est = gob_estimator(m,bounds,gob_noise(),struct('grid_counts',counts));
        result = gob_fit(est,gob_power(m,p));
        verifyEqual(testCase,result.position,p,'AbsTol',1e-7);
        verifyLessThan(testCase,result.cost,1e-10);
    end
end
end

function testDirectFisherInverse(testCase)
m = gob_model(); p = [.14;.21;.4]; [P,J] = gob_power(m,p); J = J./gob_sigma(P);
expected = sqrt(diag(inv(J'*J))); actual = gob_information(m,p);
verifyEqual(testCase,actual.axis_std,expected,'RelTol',1e-9);
end

function testGainCannotAddInformation(testCase)
m = gob_model(gob_config(struct('radii',[.012,.015]))); p = [.1,0,.4;.2,0,.1;.3,.5,.7];
a = gob_information(m,p); b = gob_information(m,p,gob_noise(),3,'common');
c = gob_information(m,p,gob_noise(),3,'per_state');
verifyTrue(testCase,all(b.peb>=a.peb));
verifyTrue(testCase,all(c.peb>=b.peb*(1-1e-6)));
end

function testDarkRegion(testCase)
a = gob_information(gob_model(),[2;2;1]);
verifyTrue(testCase,isinf(a.peb)); verifyLessThan(testCase,a.rank,3);
end

function testLabelSymmetry(testCase)
m = gob_model(); P = gob_power(m,[.18,-.18;.13,-.13;.2,.2]);
verifyEqual(testCase,sum(P(:,1)),sum(P(:,2)),'AbsTol',1e-18);
verifyGreaterThan(testCase,norm(P(:,1)-P(:,2)),1e-8);
end

function testUnknownGain(testCase)
m = gob_model(gob_config(struct('radii',[-.010,-.011],'edge_thickness',.006)));
est = gob_estimator(m,[-.8,.8;-.8,.8;0,1],gob_noise(),struct('gain_unknown',true,'starts',8));
p = [.283;-.164;.43]; fit = gob_fit(est,1.08*gob_power(m,p));
verifyEqual(testCase,fit.position,p,'AbsTol',1e-5);
verifyEqual(testCase,fit.gain,1.08,'AbsTol',1e-5);
end

function testCartesianOrdering(testCase)
p = gob_grid([0,1;10,11;20,21],[2,2,2]);
verifyEqual(testCase,p(:,1:3),[0,0,0;10,10,11;20,21,20]);
end

function testSingleSliceHeight(testCase)
c = struct('dimensions',2,'half_width',.45,'frustum',true);
p = gob_metric_grid(c,7);
verifyEqual(testCase,p(3,:),zeros(1,49));
verifyEqual(testCase,max(p(1,:)),.45,'AbsTol',1e-14);
end

function testInformationBatches(testCase)
m = gob_model(); p = repmat([.2;-.1;.3],1,513);
a = gob_information(m,p); b = gob_information(m,p(:,1));
verifyEqual(testCase,a.axis_std,repmat(b.axis_std,1,513),'RelTol',1e-12);
end
