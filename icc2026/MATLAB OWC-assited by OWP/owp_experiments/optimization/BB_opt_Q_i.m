
clear all, close all, clc

% set = [20,180,0,0,20,270];
% set = [30,225,50,200,50,245]; % Cover another cuarter
T = [0.4,0.4];

Q1 = [-0.75 0 0 0.75];
Q2 = [0 0.75 0 0.75];
Q3 = [-0.75 0 -0.75 0];
Q4 = [0 0.75 -0.75 0];

Q5 = [-1.5 -0.75 0 0.75];
Q6 = [-1.5 -0.75 -0.75 0];

Q = [Q1;Q2;Q3;Q4;Q5;Q6]; %define areas
NQ = size(Q,1);
gridstep = 0.25; % steps in the testbed


for i_Q = 1:NQ
    results = [];
    Cd = [mean(Q(i_Q,1:2)),mean(Q(i_Q,3:4))]-T;
    Cd = atan2d(Cd(2),Cd(1));
    Cd = mod(Cd,360);
    for i_1 = 0:2:60
        for i_2 = 10:10:60
            for i_3 =  5:5:45
                set = [i_1,Cd,i_2,Cd-i_3,i_2,Cd+i_3];
                rmse = model(set,Q(i_Q,:),gridstep,'datasheet');
                results = [results; rmse set];
            end
        end
    end
    
    try
        set_opt(i_Q,:) = results(find(results(:,1)==min(results(:,1))),:);
    catch
        a=1
    end
end

set_opt

rmse = set_opt(:,1);
orientations = set_opt(:,2:end);

save 'set_opt_per_Q.mat' Q orientations  rmse
% rmse : [set]
% 5.2966 :  66.0000  225.0000   32.0000  200.0000   32.0000  250.0000
% 4.3728   29.0000  225.0000   59.0000  207.0000   59.0000  243.0000