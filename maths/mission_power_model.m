%% power_model.m
%%
%% Vessel power model

close all;clear all;clc;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%              Flags
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

CUMULATIVE_ERRORS = false;
ITERATE = ~true;
SAVE = true;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%           Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
day_to_seconds = 24*60*60;
hours_to_seconds = 60*60;

MIN_P_IN        = 0;  % W, max power from fuel cells
MAX_P_IN        = 8e6;  % W, max power from fuel cells
P_IN_LOAD       = 0.3;  % most efficient load percent

%%%%% DP (SS7)
dp_MAX_P_OUT       = 3842e3;  % W
dp_MIN_P_OUT       = 362e3;    % W
dp_SIMULATION_DAYS = 2;   % days

cable_drum      = get_extra_p(dp_SIMULATION_DAYS*day_to_seconds, 3*hours_to_seconds, 1.5*hours_to_seconds, 946.26e3);
cable_lower     = get_extra_p(dp_SIMULATION_DAYS*day_to_seconds, 40*hours_to_seconds, 1.5*hours_to_seconds, 908.41e3);
crane           = get_extra_p(dp_SIMULATION_DAYS*day_to_seconds, 12*hours_to_seconds, 15*60, 245.25e3);
rov_launch      = get_extra_p(dp_SIMULATION_DAYS*day_to_seconds, 8*hours_to_seconds, 20*60, 454.2e3);
dp_EXTRA_P      = [cable_drum ; cable_lower ; crane ; rov_launch];

%%%%% Outbound
out_MAX_P_OUT       = 1600e3; % W
out_MIN_P_OUT       = 600e3; % W
out_SIMULATION_DAYS = 3;   % days
% 
%%%%% Manouvering
man_MAX_P_OUT       = 800e3; % W
man_MIN_P_OUT       = 200e3; % W
man_SIMULATION_DAYS = 1;   % days

% %%%%% Home
home_MAX_P_OUT       = 800e3; % W
home_MIN_P_OUT       = 200e3; % W
home_SIMULATION_DAYS = 3; % days

BATT_INIT_LEVEL = 0.5;

SIMULATION_DAYS = out_SIMULATION_DAYS + (2 * man_SIMULATION_DAYS) + (2 * dp_SIMULATION_DAYS) + home_SIMULATION_DAYS;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%            Simulate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% outbound
p_av = (out_MAX_P_OUT + out_MIN_P_OUT) / 2;
[power_in,battery_level,power_out,unused_energy,unavailable_energy, batt_capacity] = power_sim(out_MAX_P_OUT, out_MIN_P_OUT, MAX_P_IN, MIN_P_IN, out_SIMULATION_DAYS, p_av, p_av, -1, CUMULATIVE_ERRORS);

% manouvering
[p_in,b_level,p_out,u_energy,una_energy, ~] = power_sim(man_MAX_P_OUT, man_MIN_P_OUT, MAX_P_IN, MIN_P_IN, man_SIMULATION_DAYS, power_out(end), power_in(end), battery_level(end), CUMULATIVE_ERRORS);
power_in = [power_in p_in];
battery_level = [battery_level b_level];
power_out = [power_out p_out];
unused_energy = [unused_energy u_energy];
unavailable_energy = [unavailable_energy una_energy];

% DP
[p_in,b_level,p_out,u_energy,una_energy, ~] = power_sim(dp_MAX_P_OUT, dp_MIN_P_OUT, MAX_P_IN, MIN_P_IN, dp_SIMULATION_DAYS, power_out(end), power_in(end), battery_level(end), CUMULATIVE_ERRORS, dp_EXTRA_P);
power_in = [power_in p_in];
battery_level = [battery_level b_level];
power_out = [power_out p_out];
unused_energy = [unused_energy u_energy];
unavailable_energy = [unavailable_energy una_energy];

% manouvering
[p_in,b_level,p_out,u_energy,una_energy, ~] = power_sim(man_MAX_P_OUT, man_MIN_P_OUT, MAX_P_IN, MIN_P_IN, man_SIMULATION_DAYS, power_out(end), power_in(end), battery_level(end), CUMULATIVE_ERRORS);
power_in = [power_in p_in];
battery_level = [battery_level b_level];
power_out = [power_out p_out];
unused_energy = [unused_energy u_energy];
unavailable_energy = [unavailable_energy una_energy];

% DP
[p_in,b_level,p_out,u_energy,una_energy, ~] = power_sim(dp_MAX_P_OUT, dp_MIN_P_OUT, MAX_P_IN, MIN_P_IN, dp_SIMULATION_DAYS, power_out(end), power_in(end), battery_level(end), CUMULATIVE_ERRORS, dp_EXTRA_P);
power_in = [power_in p_in];
battery_level = [battery_level b_level];
power_out = [power_out p_out];
unused_energy = [unused_energy u_energy];
unavailable_energy = [unavailable_energy una_energy];

% home
[p_in,b_level,p_out,u_energy,una_energy, ~] = power_sim(home_MAX_P_OUT, home_MIN_P_OUT, MAX_P_IN, MIN_P_IN, home_SIMULATION_DAYS, power_out(end), power_in(end), battery_level(end), CUMULATIVE_ERRORS);
power_in = [power_in p_in];
battery_level = [battery_level b_level];
power_out = [power_out p_out];
unused_energy = [unused_energy u_energy];
unavailable_energy = [unavailable_energy una_energy];

sim_seconds = length(power_in);

x = (1:sim_seconds) / (60 * 60 * 24);
x_ticks = (1: sim_seconds / (60 * 60 * 24));

figure('Renderer', 'painters', 'Position', [10 10 1000 800])

line_width = 1;
subplot(3, 1, 1);
%sgtitle('Mission Power Usage');
% sgtitle(TITLE);
hold on;
grid on;

plot(x, power_in / 1e6, 'g', 'LineWidth', 2);
plot(x, power_out / 1e6, 'r', 'LineWidth', 1);

% max_line = yline(MAX_P_OUT / 1e6, '-c', 'LineWidth', line_width * 0.75);
% min_line = yline(MIN_P_OUT / 1e6, '-c', 'LineWidth', line_width * 0.75);
% max_line.Alpha = 0.5;
% min_line.Alpha = 0.5;

% yline(P_IN / 1e6, '--m', 'LineWidth', line_width * 0.5);

legend('P In', 'P Out');
ylabel('Power (MW)')
xlim([0 inf])
ylim([0 ceil(max(max(power_in/1e6), max(power_out/1e6)))])
xticks(x_ticks)
xlabel('Time (Days)')
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
xlabel('Time (Days)')
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
xlabel('Time (Days)')
hold off;

if SAVE
    exportgraphics(gcf, sprintf('mission.png'), 'Resolution', '250', 'ContentType','vector')
end

% FINAL STATS

if CUMULATIVE_ERRORS
    fprintf('%.f MJ/day of unused power\n', unused_energy(end) / (1e6 * SIMULATION_DAYS));
    fprintf('%.f MJ/day of unavailable power\n\n', unavailable_energy(end) / (1e6 * SIMULATION_DAYS));

    fprintf('%.f MJ of unused power\n', unused_energy(end) / 1e6);
    fprintf('%.f MJ of unavailable power\n', unavailable_energy(end) / 1e6);
end