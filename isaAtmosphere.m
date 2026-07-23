function atmosphere = isaAtmosphere(h)
%ISAATMOSPHERE Simplified International Standard Atmosphere model.
%
% Input:
%   h - Altitude above sea level [m]
%
% Output:
%   atmosphere.T   - Static temperature [K]
%   atmosphere.p   - Static pressure [Pa]
%   atmosphere.rho - Air density [kg/m^3]

arguments
    h (1,1) double {mustBeFinite, mustBeNonnegative}
end

if h > 20000
    error("isaAtmosphere:AltitudeOutOfRange", ...
        "Altitude must not exceed 20,000 m.");
end

% Constants
T0 = 288.15;        % Sea-level temperature [K]
p0 = 101325;        % Sea-level pressure [Pa]
g  = 9.80665;       % Gravitational acceleration [m/s^2]
R  = 287.05;        % Specific gas constant for air [J/(kg K)]
L  = -0.0065;       % Tropospheric temperature lapse rate [K/m]

if h <= 11000

    % Troposphere
    T = T0 + L*h;

    p = p0*(T/T0)^(-g/(L*R));

else

    % Conditions at 11 km
    T11 = T0 + L*11000;

    p11 = p0*(T11/T0)^(-g/(L*R));

    % Lower stratosphere: constant temperature
    T = T11;

    p = p11*exp( ...
        -g*(h - 11000)/(R*T));
end

rho = p/(R*T);

atmosphere = struct( ...
    "T", T, ...
    "p", p, ...
    "rho", rho);

end