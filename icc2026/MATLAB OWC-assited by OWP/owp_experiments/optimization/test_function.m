
clear all, close all, clc

% set = [20,180,0,0,20,270];
% set = [30,225,50,200,50,245]; % Cover another cuarter



results = [];

for i_1 = 20:70
    for i_2 = 30:60
        for i_3 =  5:45
            set = [i_1,225,i_2,225-i_3,i_2,225+i_3];
            rmse = model(set);
            results = [results; rmse set];
        end
    end
end

best = results(find(results(:,1)==min(results(:,1))),:)

% rmse : [set]
% 5.2966 :  66.0000  225.0000   32.0000  200.0000   32.0000  250.0000
% 4.3728   29.0000  225.0000   59.0000  207.0000   59.0000  243.0000