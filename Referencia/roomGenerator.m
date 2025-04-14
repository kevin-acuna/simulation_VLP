% Bastien BECHADERGUE - LISV
% March 2024
% V2.0
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function generates a rectangular room of given length, width and 
% height, with walls composed of 'reflectors' with density N_wx, N_wy and 
% N_wz along the x, y and z axis respectively.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Input parameters %
%%%%%%%%%%%%%%%%%%%%
% - L: Length of the room along the x axis.
% - W: Width of the room along the y axis.
% - H: Height of the room along the z axis.
% - N_x: Number of wall elements considered along the x axis.
% - N_y: Number of wall elements considered along the y axis.
% - N_z: Number of wall elements considered along the z axis.
% - display_contour: If set to 1, plots the room contour. 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Output parameters %
%%%%%%%%%%%%%%%%%%%%%
% - walls: Cell containing the x, y, z coordinates of the points contained
%          in the different walls, with a resolution N_wx, N_wy and N_wz.
% - w_eq: Cartesian equations of the walls, of the form ax+by+cz+d = 0. The
%         coefficients a, b, c, d are given in this matrix. 
% - n_w: Normal vectors of the walls.
% - dA: Area of the element of surface considered as wall reflector.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [reflectors, n_w, dA, numRefPerWall, X_w, Y_w, Z_w] = roomGenerator(L, W, H, N_wx, N_wy, N_wz, display_contour)
%% Geommetrical parameters definition
% Number of walls
N_w = 6;
% First corners of the walls
w_start = [ L/2, -W/2, -H;... % Left wall
           -L/2, -W/2, -H;... % Back wall
           -L/2,  W/2, -H;... % Right wall
            L/2,  W/2, -H;... % Front wall
            L/2, -W/2,  0;... % Ceiling
            L/2, -W/2, -H];   % Floor
% Corners of the walls opposite to the first corner defined in w_start
w_end = [-L/2, -W/2,  0;... % Left wall
         -L/2,  W/2,  0;... % Back wall
          L/2,  W/2,  0;... % Right wall
          L/2, -W/2,  0;... % Front wall
         -L/2,  W/2,  0;... % Ceiling
         -L/2,  W/2, -H];   % Floor
% Dimensions of the walls along the x, y and z axis (m)
w_dim = abs(w_end-w_start);
% Normal vectors of the walls
n_w = [0, 1, 0;... % Left wall
       1, 0, 0;... % Back wall
       0,-1, 0;... % Right wall
      -1, 0, 0;... % Front wall
       0, 0,-1;... % Ceiling 
       0, 0, 1];   % Floor 
% Walls equations (coefficients a, b, c, d of the equation ax+by+cz+d = 0)
% with origin of the coordinate system at the center of the ceiling ([L/2, W/2, H])
w_eq = [0, 1, 0,  W/2;... % Left wall (x-z)
        1, 0, 0,  L/2;... % Back wall (y-z)
        0, 1, 0, -W/2;... % Right wall (x-z)
        1, 0, 0, -L/2;... % Front wall (y-z)
        0, 0, 1,    0;... % Ceiling (x-y)
        0, 0, 1,    H];   % Floor (x-y)

% Area of the reflectors on each wall
dA = [w_dim(1,1)*w_dim(1,3)/(N_wx*N_wz);... % Left wall (x-z)
      w_dim(2,2)*w_dim(2,3)/(N_wy*N_wz);... % Back wall (y-z)
      w_dim(3,1)*w_dim(3,3)/(N_wx*N_wz);... % Right wall (x-z)
      w_dim(4,2)*w_dim(4,3)/(N_wy*N_wz);... % Front wall (y-z)
      w_dim(5,1)*w_dim(5,2)/(N_wx*N_wy);... % Ceiling (x-y)
      w_dim(6,1)*w_dim(6,2)/(N_wx*N_wy)];   % Floor (x-y)

%% Walls generation
X_w = linspace(-L/2+L/(2*N_wx), L/2-L/(2*N_wx), N_wx); % Range of reflector points along x axis
Y_w = linspace(-W/2+W/(2*N_wy), W/2-W/(2*N_wy), N_wy); % Range of reflector points along y axis
Z_w = linspace(-H/(2*N_wz), -H+H/(2*N_wz), N_wz); % Range of reflector points along z axis

leftWallReflectors = zeros(1,3);
backWallReflectors = zeros(1,3);
rightWallReflectors = zeros(1,3);
frontWallReflectors = zeros(1,3);
ceilingReflectors = zeros(1,3);
floorReflectors = zeros(1,3);

for z = 1:N_wz % Back and front walls
    for y = 1:N_wy
        backWallReflectors = [backWallReflectors;...
            -L/2, Y_w(y), Z_w(z)];
        frontWallReflectors = [frontWallReflectors;...
            L/2, Y_w(y), Z_w(z)];
    end
end
for z = 1:N_wz % Left and right walls
    for x = 1:N_wx
        leftWallReflectors = [leftWallReflectors;...
            X_w(x), -W/2, Z_w(z)];
        rightWallReflectors = [rightWallReflectors;...
            X_w(x), W/2, Z_w(z)];
    end
end
for y = 1:N_wy % Ceiling and floor
    for x = 1:N_wx
        ceilingReflectors = [ceilingReflectors;...
            X_w(x), Y_w(y), 0];
        floorReflectors = [floorReflectors;...
            X_w(x), Y_w(y), -H];
    end
end

leftWallReflectors = leftWallReflectors(2:end,:);
backWallReflectors = backWallReflectors(2:end,:);
rightWallReflectors = rightWallReflectors(2:end,:);
frontWallReflectors = frontWallReflectors(2:end,:);
ceilingReflectors = ceilingReflectors(2:end,:);
floorReflectors = floorReflectors(2:end,:);

reflectors = [leftWallReflectors;...
              backWallReflectors;...
              rightWallReflectors;...
              frontWallReflectors;...
              ceilingReflectors;...
              floorReflectors];

numRefPerWall = [length(leftWallReflectors);...
              length(backWallReflectors);...
              length(rightWallReflectors);...
              length(frontWallReflectors);...
              length(ceilingReflectors);...
              length(floorReflectors)];

%% Contour plot (if required)
if(display_contour == 1)
    figure;
    for i_w = 1:N_w
        X_w = cell2mat(walls(i_w,1));
        Y_w = cell2mat(walls(i_w,2));
        Z_w = cell2mat(walls(i_w,3));
        if( w_eq(i_w,1) == 0 ) % Case of a wall along the x axis
            for i = 1:N_wx
                for k = 1:N_wz
                    contour_x(i_w,i) = X_w(i);
                    contour_y(i_w,i) = Y_w(1);
                end
            end
        elseif( w_eq(i_w,2) == 0) % Case of a wall along the y axis
            for j = 1:N_wy
                for k = 1:N_wz
                    contour_x(i_w,j) = X_w(1);
                    contour_y(i_w,j) = Y_w(j);
                end
            end
        else % Case of a wall along x and y (non-square room, not used by this function).
            for i = 1:N_wx
                for k = 1:N_wz
                    contour_x(i_w,i) = X_w(i);
                    contour_y(i_w,i) = -(w_eq(i_w,1)*X_w(i)+w_eq(i_w,3)*Z_w(k)+w_eq(i_w,4))./(w_eq(i_w,2));
                end
            end
        end
        hold on; plot(contour_x(i_w,:),contour_y(i_w,:),'-b');
    end
    str = sprintf('Room contour (with %0.3f m height)', round(H,2)); title(str);
    xlabel('x (m)'); ylabel('y (m)');  grid on;
    xlim([-L/2*1.25,L/2*1.25]); ylim([-W/2*1.25,W/2*1.25]);
end

end

