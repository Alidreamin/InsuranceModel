% Insurance Model! SIHR

clear all
close all

% -----------------------initial condiitions------------------------------
S_u_0 = 26e6;  %26 million...this is the initial number of uninsured susceptible people (we will use US data here, for now)
S_i_0 = 300e6;  % 300 million

I_u_0 = 20; I_i_0 = 20;
%H_u_0 = 0; H_i_0 = 0;
R_u_0 = 0; R_i_0 = 0; 
%D_u_0 = 0; D_i_0 = 0; % other initial conditions

S = 326e6;
I = 40;
R = 0;

%--------- 
t0 = 1;
tf = 150; % unit = days
time_steps=150;
tee=linspace(t0,tf,time_steps);

p_i = S_i_0/(S_i_0+S_u_0); % percentage of total population that is insured
p_u = S_u_0/(S_i_0+S_u_0);

h = 0.05; % this the percentage of symptomatic infected people need ICU hospitilization...should be taken from literature or data analysis!
% h = p_u*c_u + p_i*c_i

c_i = 0.045; % we want to ensure that c_u > c_i so we start with a c_i that is slightly smaller than h

c_u = (h - p_i*c_i)/p_u; % probability that uninsured symptomatic infected will need ICU hospitalization


d_u = 0.6; % probability that uninsured ICU patient will die % we will need to find a systematic way to determine this
d_i = 0.55; % make sure d_u > d_i

alpha_u = 1/14; % rate at which ICU Hosptializations rocever
alpha_i = 1/14; 
delta_u = 1/14; % rate at which infected recover (without need for ICU hospitalization)
delta_i = 1/14;
gamma_u = 1/5;  % rate which infected go to ICU
gamma_i = 1/5;
ksi_u = 1/3;    % death rate from ICU
ksi_i = 1/3;

eta = 1/30;  % rate at which insured susceptible -> uninsured susceptible  (30 days <- we need to figure out if this is viable number!)
unemployment_vector = [3.6, 14, 10, 1, 2, 14]; % unemployment percent each month jan 2020 to june 2020...taken from https://data.bls.gov/timeseries/LNS14000000
baseline_unemployment_fraction = 3.6; % take an average pre-pandemic value
unemployment_vector = unemployment_vector-baseline_unemployment_fraction;
unemployment_vector = unemployment_vector/100; % percent -> fraction
daily_unemployment_vec = interp1(1:length(unemployment_vector), unemployment_vector, 1:1/30:length(unemployment_vector)); % adds 30 points between each end-of-month unemployment fraction 

unemployment_factor = 0; % on or off    
time_varying_beta = 0;

N = S_u_0 + S_i_0 + I_u_0 + I_i_0; % total population remains constant


%-----Let's solve this thing!
[t,y] = ode45(@(t,y) sihr(t, y, N, d_u, d_i, c_u, c_i, alpha_u, alpha_i, delta_u, delta_i, gamma_u, gamma_i, ksi_u, ksi_i, daily_unemployment_vec, eta, unemployment_factor, time_varying_beta), tee, [S_u_0, S_i_0, I_u_0, I_i_0, R_u_0, R_i_0, S, I, R]); 


%-------------Let's plot the results
%{
figure(1);
plot(t,y(:,1))
hold on
plot(t,y(:,2))
legend('S_u', 'S_i')
%}

myplot(t, y, t0, tf)

N
sprintf('%16.f', sum(y(150,7:9)))
y(150,:)


%---------------Finding R0
R0 = 0.5/(delta_u*(1-c_u) + delta_i*(1-c_i) + gamma_i*c_i + gamma_u*c_u)

R0_i = 0.5/(delta_i*(1-c_i) + gamma_i*c_i)

R0_u = 0.5/(delta_u*(1-c_u) + gamma_u*c_u)


function aprime = sihr(t, y, N, d_u, d_i, c_u, c_i, alpha_u, alpha_i, delta_u, delta_i, gamma_u, gamma_i, ksi_u, ksi_i, daily_unemployment_vec, eta, unemployment_factor, time_varying_beta_on);

S_u = y(1); 
S_i = y(2); 
I_u = y(3); 
I_i = y(4); 
%H_u = y(5); 
%H_i = y(6); 
R_u = y(5); 
R_i = y(6); 
%D_u = y(9); 
%D_i = y(10);
S = y(7);
I = y(8);
R = y(9);

I =  I_u + I_i;

beta = Beta(t, time_varying_beta_on);  % contact rate. currently an arbitrarily chosen value.  when we include age structuring, we will abandon this in favor of a contact matrix

l =0; 
g =0;

if unemployment_factor ~= 0 
    if daily_unemployment_vec(round(t)) > 0  %note: t is not necessarily an integer so we round
        l = eta*daily_unemployment_vec(round(t));
    elseif daily_unemployment_vec(round(t)) < 0
        g = -eta*daily_unemployment_vec(round(t));
    end
end
aprime = [-beta * S_u * I / N + l * S_i - g * S_u; % dS_u/dt
    -beta * S_i * I / N - l * S_i + g * S_u; % dS_i/dt
    beta * S_u * I / N - (gamma_u * c_u * I_u) - delta_u * (1-c_u) * I_u; % dI_u/dt
    beta * S_i * I / N - (gamma_i * c_i * I_i) - delta_i * (1-c_i) * I_i; % dI_i/dt
    %gamma_u * c_u * I_u - (ksi_u * d_u * H_u) - alpha_u * (1 - d_u) * H_u; % dH_u/dt
    %gamma_i * c_i * I_i - (ksi_i * d_i * H_i) - alpha_i * (1 - d_i) * H_i; % dH_i/dt
    delta_u * (1-c_u) * I_u + (gamma_u * c_u * I_u) + (delta_i * (1-c_i) * I_i + (gamma_i * c_i * I_i)); % dR_u/dt
    delta_i * (1-c_i) * I_i + (gamma_i * c_i * I_i); % dR_i/dt
    %ksi_u * d_u * H_u; % dD_u/dt
    %ksi_i * d_i * H_i;]; % dD_i/dt 
    -beta * S_u * I / N + l * S_i - g * S_u + (-beta * S_i * I / N - l * S_i + g * S_u); %dS/dt
    beta * S_u * I / N - (gamma_u * c_u * I_u) - delta_u * (1-c_u) * I_u + (beta * S_i * I / N - (gamma_i * c_i * I_i) - delta_i * (1-c_i) * I_i);
    delta_u * (1-c_u) * I_u + (gamma_u * c_u * I_u) + (delta_i * (1-c_i) * I_i + (gamma_i * c_i * I_i));];
end

function beta = Beta(t,on)
% this function returns the time-varying beta
beta = 0.5; % default value
if on == 1
    events = [0.25, 0.25, 0.25, 0.2, 0.15, 0.25]; % this is taken from data...represents changes in beta month to month starting in january
    beta_vec = interp1(1:length(events), events, 1:1/30:length(events)); % adds 30 points between each  
    beta = beta_vec(round(t));    
end
end

function myplot(t,y,t0,tf)

% below we plot the results
color = get(gca,'colororder'); % different colors for plotting

figure(2)
subplot(5,2,1)
plot(t,y(:,1),'-o','Color',color(1,:))
hold on
title('Susceptible')
xlim([t0 tf])


subplot(5,2,2)
plot(t,y(:,2),'-o','Color',color(2,:))
hold on
title('Susceptible (Insured)')
xlim([t0 tf])


subplot(5,2,3)
plot(t,y(:,3),'-o','Color',color(3,:))
hold on
title('Infected')
xlim([t0 tf])


subplot(5,2,4)
plot(t,y(:,4),'-o','Color',color(4,:))
hold on
title('Infected (Insured)')
xlim([t0 tf])


%{
subplot(5,2,5)
plot(t,y(:,5),'-o','Color',color(5,:))
hold on
title('ICU Hospitalized (Uninsured)')
xlim([t0 tf])
%}

%{
subplot(5,2,6)
plot(t,y(:,6),'-o','Color',color(6,:))
hold on
title('ICU Hospitalized (Insured)')
xlim([t0 tf])
%}


subplot(5,2,7)
plot(t,y(:,5),'-o','Color',color(5,:))
hold on
title('Recovered (Uninsured)')
xlim([t0 tf])


subplot(5,2,8)
plot(t,y(:,6),'-o','Color',color(6,:))
hold on
title('Recovered (Insured)')
xlim([t0 tf])


%{
subplot(5,2,9)
plot(t,y(:,9),'-o','Color',color(5,:))
hold on
title('Dead (Uninsured)')
xlim([t0 tf])

subplot(5,2,10)
plot(t,y(:,10),'-o','Color',color(6,:))
hold on
title('Dead (Insured)')
xlim([t0 tf])
%}
end
