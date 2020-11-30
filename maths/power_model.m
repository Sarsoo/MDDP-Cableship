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

ITERATIONS      = 5;
% SIMULATION_DAYS = 1;   % days

CELL_TOTAL      = 159201; % from battery script
% CELL_TOTAL      = 500000;

MIN_P_IN        = 0;  % W, max power from fuel cells
MAX_P_IN        = 8e6;  % W, max power from fuel cells
P_IN_LOAD       = 0.3;  % most efficient load percent

%%%%% DP (SS7)
% MAX_P_OUT       = 3842e3;  % W
% MIN_P_OUT       = 362e3;    % W
% TITLE           = 'Dyn. Pos. Sea State 7';
% SIMULATION_DAYS = 2;   % days

%%%%% Outbound
% MAX_P_OUT       = 1600e3; % W
% MIN_P_OUT       = 600e3; % W
% TITLE           = 'Outbound Steaming';
% SIMULATION_DAYS = 3;   % days
% 
%%%%% Manouvering
% MAX_P_OUT       = 800e3; % W
% MIN_P_OUT       = 200e3; % W
% TITLE           = 'Manouvering';
% SIMULATION_DAYS = 1;   % days
% 
% %%%%% Home
% MAX_P_OUT       = 800e3; % W
% MIN_P_OUT       = 200e3; % W
% TITLE           = 'Homebound';
% SIMULATION_DAYS = 3; % days

P_IN_INTERVAL   = ( 200e3/(5*60) ) * 0.75;  % W amount that gen power increases when required
P_OUT_INTERVAL  = 1e4;  % W amount that load can varies by randomly

BATT_INIT_LEVEL = 0.5;
BATT_FULL_LEVEL = 0.9;  % battery level at which the power input decreases
BATT_WARN_LEVEL = 0.3;  % battery level at which the power input increases

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

% P_IN            = MAX_P_IN * P_IN_LOAD; % W, efficient load
P_IN            = (MIN_P_OUT + MAX_P_OUT) / 2; % W, Average power out

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
current_p_out   = (MAX_P_OUT + MIN_P_OUT) / 2;

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
    current_p_out = min(max(current_p_out + power_out_delta, MIN_P_OUT), MAX_P_OUT);
    
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

if SIMULATION_DAYS > 1
    if SIMULATION_DAYS < 4
        x_ticks = (1: sim_seconds / (60 * 60));
    else
%         x_ticks = (1: sim_seconds / (60 * 60 * 24));
    end
    
    x = x / 24;
end

% figure(I)
figure('Renderer', 'painters', 'Position', [10 10 1000 800])
% t = tiledlayout(1,1,'Padding','none');
% t.Units = 'inches';
% t.OuterPosition = [0.25 0.25 5 5];
% nexttile;

line_width = 1;
subplot(3, 1, 1);
sgtitle(TITLE);
hold on;
grid on;

plot(x, power_in / 1e6, 'g', 'LineWidth', 2);
plot(x, power_out / 1e6, 'r', 'LineWidth', 1);

max_line = yline(MAX_P_OUT / 1e6, '-c', 'LineWidth', line_width * 0.75);
min_line = yline(MIN_P_OUT / 1e6, '-c', 'LineWidth', line_width * 0.75);
max_line.Alpha = 0.5;
min_line.Alpha = 0.5;

yline(P_IN / 1e6, '--m', 'LineWidth', line_width * 0.5);

legend('P In', 'P Out', 'Max P Out', 'Min P Out', 'Ideal P In');
ylabel('Power (MW)')
xlim([0 inf])
ylim([0 ceil(max(max(power_in/1e6), max(power_out/1e6)))])
xticks(x_ticks)
if SIMULATION_DAYS > 1
    xlabel('Time (Days)')
else
    xlabel('Time (Hours)')
end
hold off;

% figure(2)
subplot(3, 1, 2);

hold on;
grid on;
plot(x, battery_level * 100 / batt_capacity, 'LineWidth', 2);
legend('Battery Level');
ylabel('Capacity (%)')
xlim([0 inf])
ylim([0 100])
xticks(x_ticks)
if SIMULATION_DAYS > 1
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
if SIMULATION_DAYS > 1
    xlabel('Time (Days)')
else
    xlabel('Time (Hours)')
end
hold off;

if SAVE
    exportgraphics(gcf, sprintf('%s-%i.png', TITLE, I), 'Resolution', '250')
end

end

% FINAL STATS

if ~CUMULATIVE_ERRORS
    fprintf('%.f MJ/day of unused power\n', unused_energy(end) / (1e6 * SIMULATION_DAYS));
    fprintf('%.f MJ/day of unavailable power\n\n', unavailable_energy(end) / (1e6 * SIMULATION_DAYS));

    fprintf('%.f MJ of unused power\n', unused_energy(end) / 1e6);
    fprintf('%.f MJ of unavailable power\n', unavailable_energy(end) / 1e6);
end