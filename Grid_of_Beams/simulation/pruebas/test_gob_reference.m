function tests = test_gob_reference
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = gob_paths();
testCase.TestData.reference = load(fullfile(root,'referencias','python_reference.mat'));
end

function testPythonOptics(testCase)
for item = testCase.TestData.reference.reference
    r = item{1}; m = gob_model(r.config);
    verifyEqual(testCase,m.origins,r.origins,'AbsTol',1e-13);
    verifyEqual(testCase,m.directions,r.directions,'AbsTol',1e-13);
    verifyEqual(testCase,m.q,r.q,'AbsTol',1e-14,'RelTol',1e-12);
    [P,J] = gob_power(m,r.points);
    verifyLessThan(testCase,max(abs(P-r.powers)./(1e-18+abs(r.powers)),[],'all'),1e-8);
    verifyLessThan(testCase,max(abs(J-r.jacobian)./(1e-17+abs(r.jacobian)),[],'all'),1e-7);
end
end

function testPythonInformation(testCase)
for item = testCase.TestData.reference.reference
    r = item{1}; m = gob_model(r.config);
    for mode = ["known","common","per_state"]
        expected = r.information.(mode); actual = gob_information(m,r.points,gob_noise(),3,mode);
        stable = isfinite(expected.peb) & expected.peb<100;
        verifyEqual(testCase,actual.peb(stable),expected.peb(stable),'RelTol',1e-4,'AbsTol',1e-8);
        verifyEqual(testCase,actual.axis_std(:,stable),expected.axis_std(:,stable),'RelTol',1e-4,'AbsTol',1e-8);
    end
end
end

function testOriginalInitializerRegression(testCase)
r = testCase.TestData.reference.regression;
m = gob_model(gob_config(struct('tiles',9,'radii',[.012,.015])));
est = gob_estimator(m,[-1.8,1.8;-1.8,1.8],gob_noise(struct('bandwidth',200)),struct('grid_counts',[51,51],'starts',6));
fit = gob_fit(est,r.measurement);
verifyLessThan(testCase,norm(fit.position-r.position),.001);
verifyLessThan(testCase,fit.cost,600);
end

function testStudyCatalogue(testCase)
cases = gob_study_cases();
verifyEqual(testCase,numel(cases),25);
verifyEqual(testCase,numel(unique([cases.name])),25);
verifyEqual(testCase,sum([cases.gain_unknown]),3);
end

function testQuantileConvention(testCase)
verifyEqual(testCase,gob_quantile([0,10],.95),9.5,'AbsTol',1e-14);
verifyEqual(testCase,gob_quantile([0,10],.95,false),0);
verifyEqual(testCase,gob_quantile([Inf,Inf],.95,false),Inf);
end

function testCSVPreservesLensStates(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
path = fullfile(fixture.Folder,'states.csv');
original = table(["15";"12,15"],[1;2],'VariableNames',{'radii_mm','K'});
writetable(original,path); actual = gob_read_table(path);
verifyEqual(testCase,actual.radii_mm,original.radii_mm);
end

function testVolumeSampling(testCase)
cases = gob_study_cases(); c = cases([cases.name]=="tile_baseline_core_3d");
p = gob_sample_positions(c,1000,RandStream('mt19937ar','Seed',32));
verifyTrue(testCase,all(p(3,:)>=0 & p(3,:)<=1));
verifyTrue(testCase,all(abs(p(1:2,:))<=c.half_width*(3-p(3,:))/3,'all'));
end
