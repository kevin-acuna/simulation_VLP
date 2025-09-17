clc, clear all, close all
Rpd = 0.63; % A/W
variance = (10^(-21.0))*(30e6)
variance_w = variance*Rpd^2  % A

variance = variance_w/(Rpd^2)