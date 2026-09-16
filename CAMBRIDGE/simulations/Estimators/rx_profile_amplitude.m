function beta = rx_profile_amplitude(y, u, a)
s = a.H*u;
if any(s<=0)
    beta = NaN;
    return;
end
shape = s.^a.order;
weighted = a.weights.*shape;
beta = (weighted'*(a.weights.*y))/(weighted'*weighted);
if beta<=0 || ~isfinite(beta)
    beta = NaN;
end
end
