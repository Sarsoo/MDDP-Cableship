%% power_model.m
%%
%% Vessel power model

close all;clear all;clc;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%              Flags
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

CUMULATIVE_ERRORS = false;
ITERATE = ~true;
SAVE = ~true;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%           Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ITERATIONS = 5;

CELL_TOTAL      = 159201; % from battery script
% CELL_TOTAL      = 500000;

MIN_P_IN        = 0;  % W, max power from fuel cells
MAX_P_IN        = 8e6;  % W, max power from fuel cells
P_IN_LOAD       = 0.8;  % most efficient load percent

INIT_P_OUT      = 0.70;
PROP_P_OUT      = 8e6;  % W, propulsion max output power
HOTEL_P_OUT     = 3e4;  % W, hotel average power usage

P_IN_INTERVAL   = 1e2;  % W amount that gen power increases when required
P_OUT_INTERVAL  = 2e4;  % W amount that load can varies by randomly

SIMULATION_DAYS = 1;   % days

BATT_INIT_LEVEL = 0.5;
BATT_FULL_LEVEL = 0.95;  % battery level at which the power input decreases
BATT_WARN_LEVEL = 0.4;  % battery level at which the power input increases

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%             Specs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cell_voltage    = 3.6;  % V
cell_capacity   = 2850; % mAh
cell_dis_c      = 1;    % 1/h
cell_charge_c   = 0.5;  % 1/h

cell_dis_i      = cell_capacity * cell_dis_c / 1e3; % A
cell_charge_i   = cell_capacity * cell_charge_c / 1e3; % A

batt_dis_p      = cell_dis_i * cell_voltage * CELL_TOTAL; % W
batt_charge_p   = cell_charge_i * cell_voltage * CELL_TOTAL; % W

batt_capacity   = CELL_TOTAL * cell_capacity * cell_voltage / 1e3; % Wh

P_IN            = MAX_P_IN * P_IN_LOAD; % W
P_OUT           = PROP_P_OUT + HOTEL_P_OUT; % W

sim_seconds     = SIMULATION_DAYS * 24 * 60 * 60;

%%%%%%% unit conversions
batt_capacity   = batt_capacity * 3600; % J

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%            Simulate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ITERATE; iter_range = ITERATIONS; else; iter_range = 1; end
for I=(1:iter_range)

% Arrays for time varying values
power_in           = zeros(1, sim_seconds);
battery_level      = zeros(1, sim_seconds);
power_out          = zeros(1, sim_seconds);

unused_energy      = zeros(1, sim_seconds);
unavailable_energy = zeros(1, sim_seconds);

% 'cursor' values that change throughout sim
current_p_in    = P_IN;
current_p_out   = P_OUT * INIT_P_OUT;

% Set initial value
power_in(1)     = current_p_in;
battery_level(1)= batt_capacity * BATT_INIT_LEVEL;
power_out(1)    = current_p_out;

% loop through day
for SECOND=1:sim_seconds    
    battery_net = current_p_in - current_p_out; % net power this second
    
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
        curr_battery = battery_last + min(battery_net, batt_charge_p);
        
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
        curr_battery = battery_last - discharge_p;
        
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
    
    % CHANGE LOAD
    power_out_delta = (rand - 0.5) * 2 * P_OUT_INTERVAL;
    current_p_out = min(max(current_p_out + power_out_delta, 0), P_OUT);
    
    % BATTERY LOW, INCREASE POWER IN
%     if battery_net < 0 && (battery_level(SECOND)/batt_capacity) < BATT_WARN_LEVEL
    if (battery_level(SECOND)/batt_capacity) < BATT_WARN_LEVEL
        current_p_in = min(current_p_in + P_IN_INTERVAL, MAX_P_IN);
    
    % BATTERY HIGH, DECREASE POWER IN
    elseif (battery_level(SECOND)/batt_capacity) > BATT_FULL_LEVEL
        current_p_in = max(current_p_in - P_IN_INTERVAL, MIN_P_IN);
    
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

x = (1:sim_seconds) / (60 * 60);
x_ticks = (1: sim_seconds / (60 * 60));

if SIMULATION_DAYS > 2
    x = x / 24;
    x_ticks = (1: sim_seconds / (60 * 60 * 24));
end

figure(I)
line_width = 2;
subplot(3, 1, 1);

hold on;
grid on;
plot(x, power_in / 1e6, 'g', 'LineWidth', line_width);
plot(x, power_out / 1e6, 'r', 'LineWidth', line_width);
yline(P_IN / 1e6, '--m', 'LineWidth', line_width * 0.5)
legend('Power In', 'Power Out', 'Ideal Power In');
ylabel('Power (MW)')
xlim([0 inf])
ylim([0 max(P_OUT, P_IN) / 1e6])
xticks(x_ticks)
if SIMULATION_DAYS > 2
    xlabel('Time (Days)')
else
    xlabel('Time (Hours)')
end
hold off;

% figure(2)
subplot(3, 1, 2);

hold on;
grid on;
plot(x, battery_level * 100 / batt_capacity, 'LineWidth', line_width);
legend('Battery Level');
ylabel('Capacity (%)')
xlim([0 inf])
ylim([0 100])
xticks(x_ticks)
if SIMULATION_DAYS > 2
    xlabel('Time (Days)')
else
    xlabel('Time (Hours)')
end
hold off;

subplot(3, 1, 3);

hold on;
grid on;
plot(x, unused_energy, 'g', 'LineWidth', line_width);
plot(x, unavailable_energy, 'r', 'LineWidth', line_width);
legend('Unused', 'Unavailable');
if CUMULATIVE_ERRORS
    ylabel('Energy (J)')
else
    ylabel('Power (W)')
end
xlim([0 inf])
ylim([0 inf])
xticks(x_ticks)
if SIMULATION_DAYS > 2
    xlabel('Time (Days)')
else
    xlabel('Time (Hours)')
end
hold off;

if SAVE
    print(sprintf('%i', I),'-dpng')
end

end

% FINAL STATS

if ~CUMULATIVE_ERRORS
    fprintf('%.f MJ/day of unused power\n', unused_energy(end) / (1e6 * SIMULATION_DAYS));
    fprintf('%.f MJ/day of unavailable power\n\n', unavailable_energy(end) / (1e6 * SIMULATION_DAYS));

    fprintf('%.f MJ of unused power\n', unused_energy(end) / 1e6);
    fprintf('%.f MJ of unavailable power\n', unavailable_energy(end) / 1e6);
end