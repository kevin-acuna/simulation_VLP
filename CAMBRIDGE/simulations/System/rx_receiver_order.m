function order = rx_receiver_order(p)
assert(strcmp(rx_receiver_model(p),'cosine_power'), 'cambridge:CosineModelRequired', ...
    'This algorithm requires cos(psi)^m_R. Use the Bastiaens 2020 estimators for a paper response model.');
order = 1;
if isfield(p.receiver, 'm_R')
    order = p.receiver.m_R;
end
validateattributes(order, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
end
