%% battery.m
%%
%% Battery maths

close all;clear all;clc;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%              Flags
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

INTEGER_CELLS       = true;
P_OUT_INCLUDES_P_IN = true; % subtract power in from power out
% assumes that batter17y and generation coupled for connection to P out

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%           Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%% 18650 Cell
cell_voltage    = 3.6;  % V
% cell_capacity   = 2850; % mAh
cell_capacity   = 3500; % mAh
cell_dis_c      = 1;    % 1/h
cell_charge_c   = 0.5;  % 1/h

cell_weight     = 48;   % g
cell_dia        = 18.4; % mm
cell_height     = 65;   % mm

%cell_price      = 6;    % £
cell_price      = 5;    % £

cell_emb_c      = 117.5; % kgCO2eq/kWh
cell_rec_emb_c  = 15; % kgCO2eq/kWh


%%%%%%% P IN
%V_IN            = 450;  % V
%I_IN            = 10;   % A
% above ignored if P_IN defined
MAX_P_IN        = 8e6;  % W, max power from fuel cells
P_IN_LOAD       = 0.7;  % most efficient load percent
P_IN            = MAX_P_IN * P_IN_LOAD; % W


%%%%%%% P OUT
V_OUT           = 450;  % V
I_OUT           = 10;   % A
% above ignored if P_OUT defined
PROP_P_OUT      = 8e6;  % W, propulsion max output power
HOTEL_P_OUT     = 3e4;  % W, hotel average power usage
P_OUT           = PROP_P_OUT + HOTEL_P_OUT; % W


%%%%%%% unit conversions
cell_capacity   = 1e-3 * cell_capacity; % mAh to Ah
cell_dia        = 1e-3 * cell_dia;      % mm to m
cell_height     = 1e-3 * cell_height;   % mm to m
cell_weight     = 1e-3 * cell_weight;   % g to kg


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%          Series/Parallel
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if exist('P_OUT') % SOLVE FOR CELLS USING POWER
    
    if P_OUT_INCLUDES_P_IN
        solvable_power = P_OUT - P_IN;
    else
        solvable_power = P_OUT;
    end
    
    total_cells = solvable_power / (cell_voltage * cell_dis_c * cell_capacity);
    
    series_length   = sqrt(total_cells);
    parallel_length = series_length;
    
    if INTEGER_CELLS
        series_length   = ceil(series_length);
        parallel_length = ceil(parallel_length);
        total_cells     = series_length * parallel_length;
    end
    
    voltage_out = series_length * cell_voltage;
    current_out = parallel_length * cell_dis_c * cell_capacity;
    
else % SOLVE FOR CELLS USING VOLTAGE AND CURRENT
    series_length = V_OUT / cell_voltage;

    % c-rate = current / capacity
    required_capacity = I_OUT / cell_dis_c;
    parallel_length   = required_capacity / cell_capacity;

    if INTEGER_CELLS
        series_length   = ceil(series_length);
        parallel_length = ceil(parallel_length);
    end

    total_cells = series_length * parallel_length;
    
    voltage_out = V_OUT;
    current_out = I_OUT;

end

max_power_out = voltage_out * current_out; % W
total_capacity = parallel_length * cell_capacity; % Ah
total_capacity_Wh = total_capacity * voltage_out; % Wh

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%          Physical Space
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cell_volume  = (pi * (cell_dia/2)^2) * cell_height; % m^3

total_volume = cell_volume * total_cells; % m^3
total_weight = cell_weight * total_cells; % kg

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%             Output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('%d cells arranged %d x %d cells\n', total_cells, series_length, parallel_length);
fprintf('%.2f m3, weighs %.2f kg\n', total_volume, total_weight);
fprintf('£%.2fM\n\n', total_cells * cell_price / 1e6);

fprintf('%.2f Ah, %.2f MWh, \n', total_capacity, total_capacity_Wh / 1e6);
fprintf('%.2f V, %.2f A for %.2f MW\n', voltage_out, current_out, max_power_out / 1e6);
if P_OUT_INCLUDES_P_IN
    fprintf('Totals to %.2f MW including %.2f MW of coupled input power\n', P_OUT / 1e6, P_IN / 1e6);
end

fprintf('%.2ft (CO2e)\n', ((total_capacity_Wh / 1e3) * cell_emb_c) / 1e3);
fprintf('%.2ft (CO2e) for recycling\n', ((total_capacity_Wh / 1e3) * cell_rec_emb_c) / 1e3);
