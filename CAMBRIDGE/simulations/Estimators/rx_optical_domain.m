function valid = rx_optical_domain(v, a)
magnitude = norm(v);
valid = all(isfinite(v)) && magnitude>0;
if valid
    u = v/magnitude;
    valid = a.q'*u>0 && all(a.H*u>a.fov_cosine) && all(a.H*u>0);
end
end
