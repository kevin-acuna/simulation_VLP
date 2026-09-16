function order = rx_receiver_order(p)
order = 1;
if isfield(p.receiver, 'm_R')
    order = p.receiver.m_R;
end
validateattributes(order, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
end
