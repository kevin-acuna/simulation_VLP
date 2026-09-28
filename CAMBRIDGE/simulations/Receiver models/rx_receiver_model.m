function name = rx_receiver_model(p)
name = 'cosine_power';
if isfield(p.receiver, 'response_model')
    name = char(p.receiver.response_model);
end
assert(any(strcmp(name, {'cosine_power','bastiaens_sq','bastiaens_sqapprox','bastiaens_exp'})), ...
    'cambridge:ReceiverModel', 'Unknown receiver response model: %s.', name);
end
