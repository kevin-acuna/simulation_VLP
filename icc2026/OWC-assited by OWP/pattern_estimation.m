clc, clear all, close all

% from the datasheet
datasheet = csvread('pattern_smoothed_3.csv',1,0);


% estimacion por lambertianos
phi = 0:0.5:90;
lamb =cosd(phi).^1.5;


figure(1)
hold on
plot(datasheet(:,1), datasheet(:,2)/100,'LineWidth',3,'DisplayName','Datasheet')
plot(phi,lamb,'DisplayName','Lambertian')
legend
grid minor


%%
% estimation with polynomios
p1 =[-2.87071219e-05,2.04429106e-03,-6.27359812e-02,1.85501661e-01,9.94769800e01]/100; %0 - 46
p2 =[5.41209126e-04,-8.38922902e-02,4.37043922,-8.24163885e01,3.30525716e02]/100; %46 a 58
p3 =[-1.1142e-04,3.3874e-02,-3.3845e+00,1.1325e+02]/100; % 58 a 90

phi_range = -90:0.5:90;
i_est = [];
for phi = phi_range
    phi=abs(phi);
    if phi <= 46
        i_rel = polyval(p1, phi);
    elseif phi <= 58
        i_rel = polyval(p2, phi);    
    elseif phi <= 90
        i_rel = polyval(p3, phi);
    else 
        i_rel = 0;
    end
    i_est = [i_est i_rel];
end

plot(phi_range,i_est, 'LineWidth',4,'DisplayName','Polinomial','LineStyle',':')
xline(0,  'r--', 'x=0');
xline(46, 'r--', 'x=46');
xline(58, 'r--', 'x=58');

