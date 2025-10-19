clear, close, clc

% Q = [-0.75 0.75 -0.75 0.75];
% Q = [-1.50 -0.75 -0.75 0.00];
Q = [-1.5 0 -1.5 1.5];
T = [0,0]; %T = [0.4,0.4]; % Position of the transmitter in 2D

stepgrid = 0.10; % steps in the testbed

results = [];
Cd = [mean(Q(1:2)),mean(Q(3:4))]-T;
Cd = atan2d(Cd(2),Cd(1));
Cd = mod(Cd,360);
for i_1 = 10:2:70 %70
    for i_2 = 10:5:70 %70
        for i_3 =  5:3:90 %90
            %set = [i_1,225,i_2,225-i_3,i_2,225+i_3];
            set = [i_1,Cd,i_2,Cd-i_3,i_2,Cd+i_3];
            %rmse = model(set, Q, stepgrid, 'datasheet');
            rmse = model(set, Q, stepgrid, 'lambertian');
            results = [results; rmse set];
        end
    end
end

best = results(find(results(:,1)==min(results(:,1))),:)


% 5.5687   38.0000  206.9395   60.0000  180.9395   60.0000  232.9395

% tested
% set = [20,180,0,0,20,270];
% set = [30,225,50,200,50,245]; % Cover another cuarter

% rmse : [set]
% 5.2966 :  66.0000  225.0000   32.0000  200.0000   32.0000  250.0000
% 4.3728   29.0000  225.0000   59.0000  207.0000   59.0000  243.0000