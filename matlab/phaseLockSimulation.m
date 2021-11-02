%
% Simulate phase lock behaviour
%
% clear;
%
% Sample rate and time of master clock
%
Fs = 125e6;
dt = 1/Fs;
%
% Time and other constants
%
T = 1e-3;
t = (0:dt:T)';
N = numel(t);
%
% Frequency and demodulation settings
%
f0 = 1e6;   %Frequency of beat-note
R = 2^8;    %Decimation factor
dtavg = dt*R;
%
% PID values
%
Kp = 50;
Ki = 150;
divisor = 8;
%% Input signals
ph_i = zeros(N,1);          %"Real" phase signal
ph_c = zeros(N,1);          %Applied "control" phase signal
ph_m = zeros(ceil(N/R),1);  %Measured phase signal
ph_s = zeros(ceil(N/R),1);  %Measured phase relative to start
err = zeros(ceil(N/R),1);   %Error signal
u = zeros(ceil(N/R),1);     %Actuator signal
% r = pi/2/2*(1 + tanh((t(1:R:N) - 500e-6)/20e-6));
r = 0*pi/2*(t(1:R:N) > 500e-6);
%
% Signal function and mixing function
%
sigfunc = @(t,ph) (1+0.0*randn)*sin(2*pi*f0*t + ph);
mixfunc = @(t) [cos(2*pi*f0*t) sin(2*pi*f0*t)];
%
% Signal (x) and mixing values (mix)
%
x = zeros(N,1);
[mix,m] = deal(zeros(N,2));
x(1) = sigfunc(t(1),ph_i(1,:));
mix(1,:) = mixfunc(t(1));

tavg = [];
xavg = [];
mm = 1;
phdev = 0;

for nn = 2:N
    %
    % Set current phase
    %
    ph_c(nn) = mod(u(mm),2*pi);
    phdev = phdev + 5e-3*randn;
    ph_i(nn) = ph_c(nn) + phdev;
    %
    % Create new mixing signals
    %
    x(nn) = sigfunc(t(nn),ph_i(nn,:));
    mix(nn,:) = mixfunc(t(nn));
    m(nn,:) = [x(nn).*mix(nn,1) x(nn).*mix(nn,2)];

    if mod(nn,R) == 0
        %
        % Perform filtering of multiplied signals to get measured phase
        %
        [xavg,tavg] = cicfilter(t(1:nn),m(1:nn,:),R,3);
        mm = 1 + ceil(nn/R);
        if isempty(xavg)
            ph_m(mm) = 0;
        else
            ph_m(mm) = atan2(xavg(end,1),xavg(end,2));
        end
        
        tmp = ph_m(mm) - ph_m(mm-1);
        if tmp > 1.0*pi
            tmp = tmp - 2*pi;
        elseif tmp < -1.0*pi
            tmp = tmp + 2*pi;
        end
        ph_s(mm) = ph_s(mm-1) + tmp;
        err(mm) = (r(mm) - ph_s(mm));

        u(mm) = u(mm-1) + 2^-divisor*(Kp*(err(mm) - err(mm-1)) + 0.5*Ki*(err(mm) + err(mm-1)));
    end
    
end

%%
figure(1);clf;
plot(t,unwrap(ph_i),'.-');
hold on;
plot(t(1:R:N),ph_m,'.-');
plot(t,unwrap(ph_c),'.-');
% hold off;
grid on;


