function [power_in,battery_level,power_out,unused_energy,unavailable_energy, batt_capacity] = ...
    power_sim(MAX_P_OUT, MIN_P_OUT, MAX_P_IN, MIN_P_IN, SIMULATION_DAYS, init_p_out, init_p_in, init_battery, CUMULATIVE_ERRORS, extra_p_out)
%POWER_SIM Summary of this function goes here

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%             Specs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

CELL_TOTAL      = 159201; % from battery script

CHARGE_EFF      = 0.8;
DISCHARGE_EFF   = 0.8;

P_IN_INTERVAL   = ( 200e3/(5*60) ) * 0.75;  % W amount that gen power increases when required
P_OUT_INTERVAL  = 1e4;  % W amount that load can varies by randomly

cell_voltage    = 3.6;  % V
cell_capacity   = 2850; % mAh
cell_dis_c      = 1;    % 1/h
cell_charge_c   = 0.5;  % 1/h

cell_dis_i      = cell_capacity * cell_dis_c / 1e3; % A
cell_charge_i   = cell_capacity * cell_charge_c / 1e3; % A

batt_dis_p      = cell_dis_i * cell_voltage * CELL_TOTAL; % W
batt_charge_p   = cell_charge_i * cell_voltage * CELL_TOTAL; % W

batt_capacity   = CELL_TOTAL * cell_capacity * cell_voltage / 1e3; % Wh

% P_IN            = MAX_P_IN * P_IN_LOAD; % W, efficient load
P_IN            = (MIN_P_OUT + MAX_P_OUT) / 2; % W, Average power out

sim_seconds     = SIMULATION_DAYS * 24 * 60 * 60;

%%%%%%% unit conversions
batt_capacity   = batt_capacity * 3600; % J

BATT_FULL_LEVEL = 0.8;  % battery level at which the power input decreases
BATT_WARN_LEVEL = 0.5;  % battery level at which the power input increases

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%            Simulate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Arrays for time varying values
power_in           = zeros(1, sim_seconds);
battery_level      = zeros(1, sim_seconds);
power_out          = zeros(1, sim_seconds);

unused_energy      = zeros(1, sim_seconds);
unavailable_energy = zeros(1, sim_seconds);

% 'cursor' values that change throughout sim
current_p_in    = P_IN;
current_p_out   = (MAX_P_OUT + MIN_P_OUT) / 2;

% Set initial value
power_in(1)     = init_p_in;
if init_battery == -1
    battery_level(1)= 0.5*batt_capacity;
else
    battery_level(1)= init_battery;
end
power_out(1)    = init_p_out;

EXTRA_POWER = false;
if exist('extra_p_out')
    EXTRA_POWER = true;
end

% loop through day
for SECOND=1:sim_seconds    
    battery_net = current_p_in - current_p_out; % net power this second
    
    if EXTRA_POWER
        battery_net = battery_net - sum(extra_p_out(:, SECOND));
    end
    
    % get last energy value at the battery
    % set cumulative values
    if SECOND == 1
        battery_last = battery_level(1);
        if CUMULATIVE_ERRORS
            unused_energy(SECOND) = unused_energy(1); % cumulative
            unavailable_energy(SECOND) = unavailable_energy(1); % cumulative
        end    
    else
        battery_last = battery_level(SECOND - 1);
        if CUMULATIVE_ERRORS
            unused_energy(SECOND) = unused_energy(SECOND - 1); % cumulative
            unavailable_energy(SECOND) = unavailable_energy(SECOND - 1); % cumulative
        end
    end
    
    % CHARGING
    if battery_net > 0
        curr_battery = battery_last + min(battery_net, batt_charge_p) * CHARGE_EFF;
        
        % TOO MUCH FOR BATTERY CAPACITY
        if batt_capacity < curr_battery
            unused_energy(SECOND) = unused_energy(SECOND) + abs(batt_capacity - curr_battery); 
        end
        
        % TOO MUCH CURRENT FOR BATTERY
        if battery_net > batt_charge_p
            unused_energy(SECOND) = unused_energy(SECOND) + battery_net - batt_charge_p; 
        end
        
    % DISCHARGING
    else
        discharge_p = min(abs(battery_net), batt_dis_p);
        curr_battery = battery_last - discharge_p / DISCHARGE_EFF;
        
        % BATTERY EMPTY
        if curr_battery < 0
            unavailable_energy(SECOND) = unavailable_energy(SECOND) + abs(curr_battery); 
        end
        
        % TOO MUCH CURRENT FOR BATTERY
        if abs(battery_net) > batt_dis_p
            unavailable_energy(SECOND) = unavailable_energy(SECOND) + abs(battery_net) - batt_dis_p; 
        end
    end
    
    % STORE VALUES
    power_in(SECOND) = current_p_in;
    battery_level(SECOND) = max(min(curr_battery, batt_capacity), 0);
    power_out(SECOND) = current_p_out;
    
    if EXTRA_POWER
        power_out(SECOND) = power_out(SECOND) + sum(extra_p_out(:, SECOND));
    end
    
    % CHANGE LOAD
    power_out_delta = (rand - 0.5) * 2 * P_OUT_INTERVAL;
    current_p_out = min(max(current_p_out + power_out_delta, MIN_P_OUT), MAX_P_OUT);
    
    batt_percent = (battery_level(SECOND)/batt_capacity);
    
    % BATTERY LOW, INCREASE POWER IN
%     if battery_net < 0 && batt_percent < BATT_WARN_LEVEL
    if batt_percent < BATT_WARN_LEVEL
        percent_diff = (BATT_WARN_LEVEL - batt_percent) / BATT_WARN_LEVEL;
        current_p_in = min(current_p_in + percent_diff * P_IN_INTERVAL, MAX_P_IN);
    
    % BATTERY HIGH, DECREASE POWER IN
    elseif batt_percent > BATT_FULL_LEVEL && batt_percent < 1
        percent_diff = 1 - (abs(BATT_FULL_LEVEL - batt_percent) / (1 - BATT_FULL_LEVEL));
        current_p_in = max(current_p_in - percent_diff * P_IN_INTERVAL, MIN_P_IN);
    
    % NEITHER, RELAX TO EFFICIENT STATE
    else
        delta_to_efficiency = P_IN - current_p_in;
        if delta_to_efficiency > 0
            current_p_in = min(current_p_in + P_IN_INTERVAL, P_IN);
        else
            current_p_in = max(current_p_in - P_IN_INTERVAL, P_IN);
        end
    end
end

end

