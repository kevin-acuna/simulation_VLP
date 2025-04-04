% Bastien BECHADERGUE - LISV
% April 2024
% V1.0
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function computes the line-of-sight and non line-of-sight gain of 
% the optical wireless channel between an optical transmitter with given 
% properties and an optical receiver with given properties at a given 
% location, when they are both placed in a room with given properties.
% Remark: This function calls four other functions - h_LOS, H_f, r_f, and 
% t_f - defined in [1] and implemented with comments below.
%
% [1] H. Schultz, "Frequency-Domain Simulation of the Indoor Wireless
% Optical Communication Channel," IEEE Transactions on Communications,
% vol. 64, no. 6, June 2016.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Input parameters %
%%%%%%%%%%%%%%%%%%%%
% - param_t: Constant parameters of the transmitters.
% - i_t: Index of transmitter to consider.
% - param_w: Constant parameters of the room.
% - param_r: Constant parameters of the receiver.
% - x, y, z: Cartesian coordinates of the receiver.
% - bounceOrderDecomposition: Enables the computation of the contribution 
%                             of each order of bounce to the NLOS channel 
%                             gain .
% - bounceOrder: Maximum order of bounce to consider. 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Output parameters %
%%%%%%%%%%%%%%%%%%%%%
% - channelGainLOS: Gain of the line-of-sight optical wireles channel.
% - channelGainNLOS: Gain of the non line-of-sight optical wireles channel.
% - bounceOrderGain: Contribution of each order of bounce to the total NLOS
%                    channel gain (computed only if input variable
%                    bounceOrderDecomposition = 1, zeros otherwise).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [channelGainLOS, channelGainNLOS, bounceOrderGain] = opticalWirelessChannel(param_t, i_t, param_w, param_r, x, y, z, bounceOrderDecomposition, bounceOrder)
%% PARAMETERS AND MATRICES INITIALIZATION
N = size(param_w{1},1); % Number of wall reflectors
G_rho = param_w{7}; % Reflectivity factors of the wall reflectors
I = eye(N); % Unity matrix
t = zeros(N,1); % Tx-to-wall reflectors links
r = zeros(1,N); % Wall reflectors-to-Rx links
H = zeros(N,N); % Wall reflectors-to-wall reflectors links
bounceOrderGain = zeros(1, bounceOrder); % Channel gain of each order of bounce

%% COMPUTATION OF THE LOS CHANNEL GAIN
channelGainLOS = h_LOS(param_t, 1, param_r, x, y, z);

%% COMPUTATION OF THE NLOS CHANNEL GAIN (INFINITE NUMBER OF BOUNCES)
for i_w = 1:N % Computation of "t(f)", "r(f)", and "H(f)" 
    t(i_w) = t_f(param_t, i_t, param_w, i_w);
    r(i_w) = r_f(param_w, i_w, param_r, x, y, z);
    for j_w = 1:N
        H(i_w,j_w) = H_f(param_w, i_w, j_w);
    end
end
t(isnan(t)) = 0; r(isnan(r)) = 0; H(isnan(H)) = 0; % Removal of same plane/same point cases
s_f = inv(I-H*G_rho); % Computation of "(I-H(f)*G_rho)^{-1}"
s_f(isnan(s_f)) = 0; % Removal of same plane/same point cases
channelGainNLOS = r*G_rho*s_f*t; % NLOS channel gain

%% COMPUTATION OF THE NLOS CHANNEL GAIN (INFINITE NUMBER OF BOUNCES)
if( bounceOrderDecomposition == 1)
    for i_b = 1:bounceOrder
        bounceOrderGain(i_b) = r*G_rho*(H*G_rho)^(i_b-1)*t;
    end
end

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function computes the gain of the line-of-sight optical wireless 
% channel in a given configuration, as defined in (4) of [1] 
% (where it is named \eta_{Rx,Tx}).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Input parameters %
%%%%%%%%%%%%%%%%%%%%
% - param_t: Constant parameters of the transmitters.
% - i_t: Index of transmitter to consider.
% - param_r: Constant parameters of the receiver.
% - x, y, z: Cartesian coordinates of the receiver. 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Output parameters %
%%%%%%%%%%%%%%%%%%%%%
% - h_LOS: Gain of the line-of-sight optical wireles channel.
% - d_tr: Absolute distance between the transmitter and receiver [m].
% - cos_phi: Irradiance angle (i.e. angle between the normal vector of the
%            transmitter and the direction of emission)
% - cos_psi: Incidence angle (i.e. angle between the normal vector of the
%            receiver and the direction of reception)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [h_LOS, d_tr, cos_phi, cos_psi] = h_LOS(param_t, i_t, param_r, x, y, z)
%% PARAMETERS AND MATRICES INITIALIZATION
T = param_t{1}(i_t,:); % Transmitter coordinates
n_t = param_t{2}(i_t,:); % Transmitter normal
m = param_t{3}(i_t); % Transmitter Lambertian order
A_det = param_r{1}; % Receiver sensitive area
n_r = param_r{2}; % Receiver normal
FOV = param_r{3}; % Reveiver field of view
R = [x,y,z]; % Receiver coordinates
%% COMPUTATION OF THE LOS CHANNEL
d_tr = sqrt(dot(R-T,R-T)); % distance between Tx to Rx
v_tr = (R-T)./norm(R-T);
cos_phi = dot(n_t,v_tr); % angle of view of Rx from Tx
cos_psi = dot(n_r,-v_tr); % angle of view of Tx from Rx
if( abs(acosd(cos_psi)) <= FOV && cos_phi > 0 )
    h_LOS = (m+1)*A_det/(2*pi*d_tr^2)*abs(cos_phi)^m*abs(cos_psi); % Channel DC gain (no units)
else
    h_LOS = 0;
end

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function computes the channel gain between two wall reflectors in a 
% given environement. Included in a loop, it eventually enables to compute 
% the vector H(f), as defined in (18) of [1].
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Input parameters %
%%%%%%%%%%%%%%%%%%%%
% - param_w: Constant parameters of the room.
% - i_w: Index of the transmitting wall reflector.
% - j_w: Index of the receiving wall reflector.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Output parameters %
%%%%%%%%%%%%%%%%%%%%%
% - h_ww: Gain of the line-of-sight optical wireles channel between the 
%         two wall reflectors considered.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function h_ww = H_f(param_w, i_w, j_w)
%% PARAMETERS AND MATRICES INITIALIZATION
W_T = param_w{1}(i_w,:); % Coordinates of the transmitting reflector
W_R = param_w{1}(j_w,:); % Coordinates of the receiving reflector
n_w = param_w{2}; % Normal vectors of the walls
dA = param_w{3}; % Areas of the reflectors
L = param_w{4}; W = param_w{5}; H = param_w{6}; % Length, width and height of the room [m]

%% COMPUTATION OF THE LOS CHANNEL GAIN BETWEEN THE TWO WALL REFLECTORS
d_ww = norm(W_R-W_T); % Distance between reflector i and reflector j
v_ww = (W_R-W_T)./d_ww; % Normal vector from reflector i to reflector j

if( W_T(2) == -W/2 ) % If the transmitting wall is the left wall
    cos_theta = dot(n_w(1,:),v_ww);
    if( W_R(2) == -W/2 ) % If the receiving wall is the left wall
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif( W_R(1) == -L/2 ) % If the receiving wall is the back wall
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif( W_R(2) == W/2) % If the receiving wall is the right wall
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif( W_R(1) == L/2 ) % If the receiving wall is the front wall
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif( W_R(3) == 0 ) % If the receiving wall is the ceiling
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif( W_R(3) == -H ) % If the receiving wall is the floor
        A = dA(6);
        cos_psi = dot (n_w(6,:), -v_ww);
    end

elseif( W_T(1) == -L/2 ) % If the transmitting wall is the back wall
    cos_theta = dot(n_w(2,:),v_ww);
    if( W_R(2) == -W/2 ) % If the receiving wall is the left wall
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif( W_R(1) == -L/2 ) % If the receiving wall is the back wall
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif( W_R(2) == W/2) % If the receiving wall is the right wall
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif( W_R(1) == L/2 ) % If the receiving wall is the front wall
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif( W_R(3) == 0 ) % If the receiving wall is the ceiling
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif( W_R(3) == -H ) % If the receiving wall is the floor
        A = dA(6);
        cos_psi = dot (n_w(6,:), -v_ww);
    end

elseif( W_T(2) == W/2 ) % If the transmitting wall is the right wall
    cos_theta = dot(n_w(3,:),v_ww);
    if( W_R(2) == -W/2 ) % If the receiving wall is the left wall
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif( W_R(1) == -L/2 ) % If the receiving wall is the back wall
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif( W_R(2) == W/2) % If the receiving wall is the right wall
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif( W_R(1) == L/2 ) % If the receiving wall is the front wall
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif( W_R(3) == 0 ) % If the receiving wall is the ceiling
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif( W_R(3) == -H ) % If the receiving wall is the floor
        A = dA(6);
        cos_psi = dot (n_w(6,:), -v_ww);
    end

elseif( W_T(1) == L/2 ) % If the transmitting wall is the front wall
    cos_theta = dot(n_w(4,:),v_ww);
    if( W_R(2) == -W/2 ) % If the receiving wall is the left wall
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif( W_R(1) == -L/2 ) % If the receiving wall is the back wall
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif( W_R(2) == W/2) % If the receiving wall is the right wall
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif( W_R(1) == L/2 ) % If the receiving wall is the front wall
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif( W_R(3) == 0 ) % If the receiving wall is the ceiling
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif( W_R(3) == -H ) % If the receiving wall is the floor
        A = dA(6);
        cos_psi = dot (n_w(6,:), -v_ww);
    end

elseif( W_T(3) == 0 ) % If the transmitting wall is the ceiling
    cos_theta = dot(n_w(5,:),v_ww);
    if( W_R(2) == -W/2 ) % If the receiving wall is the left wall
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif( W_R(1) == -L/2 ) % If the receiving wall is the back wall
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif( W_R(2) == W/2) % If the receiving wall is the right wall
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif( W_R(1) == L/2 ) % If the receiving wall is the front wall
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif( W_R(3) == 0 ) % If the receiving wall is the ceiling
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif( W_R(3) == -H ) % If the receiving wall is the floor
        A = dA(6);
        cos_psi = dot (n_w(6,:), -v_ww);
    end

elseif( W_T(3) == -H ) % If the transmitting wall is the floor
    cos_theta = dot(n_w(6,:),v_ww);
    if( W_R(2) == -W/2 ) % If the receiving wall is the left wall
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif( W_R(1) == -L/2 ) % If the receiving wall is the back wall
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif( W_R(2) == W/2) % If the receiving wall is the right wall
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif( W_R(1) == L/2 ) % If the receiving wall is the front wall
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif( W_R(3) == 0 ) % If the receiving wall is the ceiling
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif( W_R(3) == -H ) % If the receiving wall is the floor
        A = dA(6);
        cos_psi = dot (n_w(6,:), -v_ww);
    end

end

h_ww = A/(pi*d_ww^2)*abs(cos_theta)*abs(cos_psi);

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function computes the channel gain between a wall reflector and a
% receiver in a given environement. Included in a loop, it eventually 
% enables to compute the vector r(f) as defined in (20) of [1].
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Input parameters %
%%%%%%%%%%%%%%%%%%%%
% - param_w: Constant parameters of the room.
% - i_w: Index of the transmitting wall reflector.
% - param_r: Constant parameters of the receiver.
% - x, y, z: Cartesian coordinates of the receiver. 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Output parameters %
%%%%%%%%%%%%%%%%%%%%%
% - h_wr: Gain of the line-of-sight optical wireles channel between the 
%         wall reflector considered and the receiver.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function h_wr = r_f(param_w, i_w, param_r, x, y, z)
%% PARAMETERS AND MATRICES INITIALIZATION
WR = param_w{1}(i_w,:);
n_w = param_w{2};
L = param_w{4}; W = param_w{5}; H = param_w{6}; % Length, width and height of the room [m]
A_det = param_r{1}; % Receiver sensitive area
n_r = param_r{2}; % Receiver normal
FOV = param_r{3}; % Receiver field of view
R = [x,y,z]; % Cartesian coordinates of the receiver

%% COMPUTATION OF THE LOS CHANNEL GAIN BETWEEN THE WALL REFLECTOR AND RECEIVER
d_wr = norm(R-WR); % Distance from Tx to wall
v_wr = (R-WR)./d_wr;

if( WR(2) == -W/2 ) % If the transmitting wall is the left wall
    cos_theta = dot(n_w(1,:), v_wr);
elseif( WR(1) == -L/2 ) % If the transmitting wall is the back wall
    cos_theta = dot(n_w(2,:), v_wr);
elseif( WR(2) == W/2 ) % If the transmitting wall is the right wall
    cos_theta = dot(n_w(3,:), v_wr);
elseif( WR(1) == L/2 ) % If the transmitting wall is the front wall
    cos_theta = dot(n_w(4,:), v_wr);
elseif( WR(3) == 0 ) % If the transmitting wall is the ceiling
    cos_theta = dot(n_w(5,:), v_wr);
elseif( WR(3) == -H ) % If the transmitting wall is the floor
    cos_theta = dot(n_w(6,:), v_wr);
end

cos_psi = dot(n_r, -v_wr); % angle of view of Tx from Rx

if( abs(acosd(cos_psi)) <= FOV )
    h_wr = A_det/(pi*d_wr^2)*abs(cos_theta)*abs(cos_psi); % Channel DC gain (no units)
else
    h_wr = 0;
end

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function computes the channel gain between a given trnasmitter and
% a given wall reflector in a given environement. Included in a loop, it 
% eventually enables to compute the vector t(f) as defined in (17) of [1].
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Input parameters %
%%%%%%%%%%%%%%%%%%%%
% - param_t: Constant parameters of the transmitters.
% - i_t: Index of transmitter to consider.
% - param_w: Constant parameters of the room.
% - i_w: Index of the transmitting wall reflector.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Output parameters %
%%%%%%%%%%%%%%%%%%%%%
% - h_tw: Gain of the line-of-sight optical wireles channel between the 
%         wall reflector considered and the receiver.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function h_tw = t_f(param_t, i_t, param_w, i_w) 
%% PARAMETERS AND MATRICES INITIALIZATION
T   = param_t{1}(i_t,:); % Coordinates of the i_t-th transmitter
n_t = param_t{2}(i_t,:); % Transmitter normal
m   = param_t{3}(i_t); % Transmitter Lambertian order
WR   = param_w{1}(i_w,:); % Coordinates of the i_w-th reflector
n_w = param_w{2};
dA  = param_w{3};
L = param_w{4}; W = param_w{5}; H = param_w{6}; % Length, width and height of the room (m)

%% COMPUTATION OF THE LOS CHANNEL GAIN BETWEEN THE WALL REFLECTOR AND RECEIVER
d_tw = norm(WR-T); % Distance from Tx to the i_w-th wall reflector
v_tw = (WR-T)./d_tw; % Unit vector from Tx to the i_w-th wall reflector
cos_theta = dot(n_t,v_tw); % Angle of view of i_w-th wall reflector from Tx

if( WR(2) == -W/2 ) % If reflector of the left wall
    A = dA(1);
    cos_psi = dot(n_w(1,:),-v_tw);
elseif( WR(1) == -L/2 ) % If reflector of the back wall
    A = dA(2);
    cos_psi = dot(n_w(2,:),-v_tw);
elseif( WR(2) == W/2 ) % If reflector of the right wall
    A = dA(3);
    cos_psi = dot(n_w(3,:),-v_tw);
elseif( WR(1) == L/2 ) % If reflector of the front wall
    A = dA(4);
    cos_psi = dot(n_w(4,:),-v_tw);
elseif( WR(3) == 0 ) % If reflector of the ceiling
    A = dA(5);
    cos_psi = dot(n_w(5,:),-v_tw);
elseif( WR(3) == -H )   % If reflector of the floor
    A = dA(6);
    cos_psi = dot(n_w(6,:),-v_tw);
end

if( cos_theta > 0 )
    h_tw = (m+1)*A/(2*pi*d_tw^2)*abs(cos_theta)^m*abs(cos_psi); % Channel DC gain (no units)
else
    h_tw = 0;
end


end







