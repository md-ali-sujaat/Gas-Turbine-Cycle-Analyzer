function result = turbojetCycle(in)
%TURBOJETCYCLE Steady one-dimensional turbojet cycle analysis.
%
% Required inputs in structure "in":
%   altitude  - Flight altitude [m]
%   M0        - Flight Mach number
%   mdotAir   - Air mass flow rate [kg/s]
%   pi_c      - Compressor pressure ratio
%   Tt4       - Turbine inlet temperature [K]
%   eta_c     - Compressor isentropic efficiency
%   eta_t     - Turbine isentropic efficiency
%   eta_b     - Combustor efficiency
%   pi_n      - Nozzle total-pressure recovery
%
% Outputs are returned in the structure "result".

%% Constant gas properties

R = 287.05;          % Specific gas constant [J/(kg K)]

gammaAir = 1.40;
cpAir = 1004.5;      % Air specific heat [J/(kg K)]

gammaGas = 1.33;
cpGas = 1150.0;      % Combustion-gas specific heat [J/(kg K)]

LHV = 43.0e6;        % Fuel lower heating value [J/kg]

% Fixed component parameters
etaMechanical = 0.99;
diffuserPressureRecovery = 0.98;
combustorPressureRecovery = 0.95;

%% Check the inputs

if in.altitude < 0 || in.altitude > 20000
    error("Altitude must be between 0 and 20,000 m.");
end

if in.M0 < 0 || in.M0 > 3
    error("Mach number must be between 0 and 3.");
end

if in.mdotAir <= 0
    error("Air mass flow rate must be positive.");
end

if in.pi_c <= 1
    error("Compressor pressure ratio must be greater than 1.");
end

if in.Tt4 <= 0
    error("Turbine inlet temperature must be positive.");
end

efficiencies = [in.eta_c, in.eta_t, in.eta_b, in.pi_n];

if any(efficiencies <= 0 | efficiencies > 1)
    error("Efficiencies and pressure recovery must be between 0 and 1.");
end

%% Station 0: atmospheric and flight conditions

atmosphere = isaAtmosphere(in.altitude);

T0 = atmosphere.T;
p0 = atmosphere.p;

a0 = sqrt(gammaAir*R*T0);
V0 = in.M0*a0;

Tt0 = T0*(1 + 0.5*(gammaAir - 1)*in.M0^2);

Pt0 = p0*(1 + 0.5*(gammaAir - 1)*in.M0^2) ...
    ^(gammaAir/(gammaAir - 1));

%% Station 2: diffuser exit

Tt2 = Tt0;
Pt2 = diffuserPressureRecovery*Pt0;

%% Station 3: compressor exit

Pt3 = in.pi_c*Pt2;

Tt3Isentropic = Tt2*(Pt3/Pt2)^ ...
    ((gammaAir - 1)/gammaAir);

Tt3 = Tt2 + ...
    (Tt3Isentropic - Tt2)/in.eta_c;

%% Station 4: combustor exit

Tt4 = in.Tt4;
Pt4 = combustorPressureRecovery*Pt3;

if Tt4 <= Tt3
    error("Turbine inlet temperature must be greater than the compressor exit temperature.");
end

fuelAirRatio = ...
    (cpGas*Tt4 - cpAir*Tt3) / ...
    (in.eta_b*LHV - cpGas*Tt4);

if fuelAirRatio <= 0
    error("The calculated fuel-air ratio is not physically valid.");
end

%% Station 5: turbine exit

compressorSpecificWork = cpAir*(Tt3 - Tt2);

Tt5 = Tt4 - compressorSpecificWork / ...
    (etaMechanical*(1 + fuelAirRatio)*cpGas);

if Tt5 <= 0
    error("The calculated turbine exit temperature is invalid.");
end

Tt5Isentropic = Tt4 - ...
    (Tt4 - Tt5)/in.eta_t;

Pt5 = Pt4*(Tt5Isentropic/Tt4)^ ...
    (gammaGas/(gammaGas - 1));

%% Station 9: nozzle

Tt9 = Tt5;
Pt9 = in.pi_n*Pt5;

if Pt9 <= p0
    error("Nozzle total pressure must exceed ambient pressure.");
end

criticalPressureRatio = ...
    ((gammaGas + 1)/2)^ ...
    (gammaGas/(gammaGas - 1));

if Pt9/p0 >= criticalPressureRatio

    % Choked convergent nozzle
    nozzleChoked = true;
    M9 = 1.0;
    p9 = Pt9/criticalPressureRatio;

else

    % Unchoked nozzle, expanded to ambient pressure
    nozzleChoked = false;
    p9 = p0;

    M9 = sqrt( ...
        2/(gammaGas - 1) * ...
        ((Pt9/p9)^((gammaGas - 1)/gammaGas) - 1));
end

T9 = Tt9/(1 + 0.5*(gammaGas - 1)*M9^2);

a9 = sqrt(gammaGas*R*T9);
V9 = M9*a9;

rho9 = p9/(R*T9);

%% Thrust calculation

mdotFuel = fuelAirRatio*in.mdotAir;

mdotExit = in.mdotAir + mdotFuel;

nozzleExitArea = mdotExit/(rho9*V9);

momentumThrust = ...
    mdotExit*V9 - in.mdotAir*V0;

pressureThrust = ...
    (p9 - p0)*nozzleExitArea;

thrust = momentumThrust + pressureThrust;

specificThrust = thrust/in.mdotAir;

% Thrust-specific fuel consumption [kg/(N h)]
TSFC = 3600*mdotFuel/thrust;

%% Component power

compressorPower = ...
    in.mdotAir*cpAir*(Tt3 - Tt2);

turbinePower = ...
    etaMechanical*mdotExit*cpGas*(Tt4 - Tt5);

shaftPowerResidual = ...
    (turbinePower - compressorPower)/compressorPower;

%% Create the station table

station = ["0"; "2"; "3"; "4"; "5"; "9"];

location = [
    "Freestream"
    "Diffuser exit"
    "Compressor exit"
    "Combustor exit"
    "Turbine exit"
    "Nozzle"
];

totalTemperature_K = [
    Tt0
    Tt2
    Tt3
    Tt4
    Tt5
    Tt9
];

totalPressure_kPa = [
    Pt0
    Pt2
    Pt3
    Pt4
    Pt5
    Pt9
]/1000;

stationTable = table( ...
    station, ...
    location, ...
    totalTemperature_K, ...
    totalPressure_kPa, ...
    'VariableNames', { ...
        'Station', ...
        'Location', ...
        'TotalTemperature_K', ...
        'TotalPressure_kPa'});

%% Store the outputs

result.stationTable = stationTable;

result.thrust = thrust;
result.specificThrust = specificThrust;
result.TSFC = TSFC;
result.fuelAirRatio = fuelAirRatio;

result.nozzleChoked = nozzleChoked;
result.exitVelocity = V9;
result.exitMach = M9;
result.exitTemperature = T9;
result.exitPressure = p9;
result.nozzleExitArea = nozzleExitArea;

result.compressorPower = compressorPower;
result.turbinePower = turbinePower;
result.shaftPowerResidual = shaftPowerResidual;

end