function i_rel = irradiance(phi,model)
% phi in degree

if strcmp(model,'poly')
    % estimation with polynomials
    p1 =[-2.87071219e-05,2.04429106e-03,-6.27359812e-02,1.85501661e-01,9.94769800e01]/100; %0 - 46
    p2 =[5.41209126e-04,-8.38922902e-02,4.37043922,-8.24163885e01,3.30525716e02]/100; %46 to 58
    p3 =[-1.1142e-04,3.3874e-02,-3.3845e+00,1.1325e+02]/100; % 58 to 90

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
end



end