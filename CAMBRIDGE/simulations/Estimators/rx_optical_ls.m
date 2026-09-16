function [v, status] = rx_optical_ls(y, a)
v = nan(3, 1);
status = "nonpositive_power_for_root";
if a.order~=1 && any(y<=0)
    return;
end
if a.order==1
    z = y;
else
    z = y.^(1/a.order);
end
v = a.H\z;
status = "success";
if ~rx_optical_domain(v, a)
    status = "outside_full_visibility_domain";
end
end
