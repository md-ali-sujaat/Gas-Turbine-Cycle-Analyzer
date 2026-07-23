clear;
clc;

%% Standard test case

in.altitude = 10000;
in.M0       = 0.80;
in.mdotAir  = 25;

in.pi_c = 12;
in.Tt4  = 1400;

in.eta_c = 0.86;
in.eta_t = 0.89;
in.eta_b = 0.99;
in.pi_n  = 0.99;

result = turbojetCycle(in);

tolerance = 1e-10;

%% 1. Shaft-power balance

assert( ...
    abs(result.shaftPowerResidual) < tolerance, ...
    'Shaft-power balance verification failed.');

%% 2. Recover compressor efficiency

Tt2 = result.stationTable.TotalTemperature_K(2);
Tt3 = result.stationTable.TotalTemperature_K(3);

Pt2 = result.stationTable.TotalPressure_kPa(2);
Pt3 = result.stationTable.TotalPressure_kPa(3);

gammaAir = 1.40;

Tt3s = Tt2*(Pt3/Pt2)^((gammaAir - 1)/gammaAir);

etaCompressorRecovered = ...
    (Tt3s - Tt2)/(Tt3 - Tt2);

assert( ...
    abs(etaCompressorRecovered - in.eta_c) < tolerance, ...
    'Compressor-efficiency verification failed.');

%% 3. Recover turbine efficiency

Tt4 = result.stationTable.TotalTemperature_K(4);
Tt5 = result.stationTable.TotalTemperature_K(5);

Pt4 = result.stationTable.TotalPressure_kPa(4);
Pt5 = result.stationTable.TotalPressure_kPa(5);

gammaGas = 1.33;

Tt5s = Tt4*(Pt5/Pt4)^((gammaGas - 1)/gammaGas);

etaTurbineRecovered = ...
    (Tt4 - Tt5)/(Tt4 - Tt5s);

assert( ...
    abs(etaTurbineRecovered - in.eta_t) < tolerance, ...
    'Turbine-efficiency verification failed.');

%% 4. Verify nozzle condition

atmosphere = isaAtmosphere(in.altitude);

Pt9 = result.stationTable.TotalPressure_kPa(6)*1000;

actualPressureRatio = Pt9/atmosphere.p;

criticalPressureRatio = ...
    ((gammaGas + 1)/2)^(gammaGas/(gammaGas - 1));

expectedChoked = ...
    actualPressureRatio >= criticalPressureRatio;

assert( ...
    result.nozzleChoked == expectedChoked, ...
    'Nozzle-choking verification failed.');

if result.nozzleChoked
    assert( ...
        abs(result.exitMach - 1) < tolerance, ...
        'Choked-nozzle exit Mach verification failed.');
end

%% 5. Reconstruct thrust independently

R = 287.05;

speedOfSound = ...
    sqrt(gammaAir*R*atmosphere.T);

V0 = in.M0*speedOfSound;

mdotFuel = ...
    result.fuelAirRatio*in.mdotAir;

mdotExit = ...
    in.mdotAir + mdotFuel;

momentumThrust = ...
    mdotExit*result.exitVelocity - in.mdotAir*V0;

pressureThrust = ...
    (result.exitPressure - atmosphere.p) * ...
    result.nozzleExitArea;

reconstructedThrust = ...
    momentumThrust + pressureThrust;

relativeThrustResidual = ...
    abs(reconstructedThrust - result.thrust) / ...
    abs(result.thrust);

assert( ...
    relativeThrustResidual < tolerance, ...
    'Thrust reconstruction verification failed.');

%% Report

fprintf('\nAll turbojet verification tests passed.\n\n');

fprintf('Shaft-power residual:       %.3e\n', ...
    result.shaftPowerResidual);

fprintf('Recovered compressor eta:  %.6f\n', ...
    etaCompressorRecovered);

fprintf('Recovered turbine eta:     %.6f\n', ...
    etaTurbineRecovered);

fprintf('Thrust residual:            %.3e\n', ...
    relativeThrustResidual);

fprintf('Net thrust:                 %.3f kN\n', ...
    result.thrust/1000);