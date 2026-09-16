function [position, direction, beta, distance] = rx_optical_position(v, power_scale, p)
magnitude = norm(v);
direction = v/magnitude;
beta = power_scale*exp(rx_receiver_order(p)*log(magnitude));
[gain, ~, m] = rx_emission_pattern(p, direction);
C = p.transmitter.power_W*(m+1)*p.receiver.area_m2 ...
    *p.receiver.filter_transmission*p.receiver.optical_gain/(2*pi);
distance = sqrt(C*gain/beta);
position = p.transmitter.position_m-distance*direction;
end
