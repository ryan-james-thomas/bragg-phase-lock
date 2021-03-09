clear;

Fs = 125e6;
dt = 1/Fs;

%% Input signal
fin = 250e3*1;
T = 10e-3;
t = (0:dt:T)';
phin = 0.25 + cumsum(1e-3*randn(size(t)));
x = sin(2*pi*fin*t + phin);

%% Mixed signal
dds = [cos(2*pi*fin*t) sin(2*pi*fin*t)];
m = [x.*dds(:,1) x.*dds(:,2)];

%% Quick average of signal
% Navg = 8;
% qavg = zeros(floor(size(m,1)/Navg),2);
% tavg = zeros(size(qavg,1),1);
% for nn = 1:size(qavg,1)
%     idx = ((nn-1)*Navg+1):(nn*Navg);
%     qavg(nn,:) = mean(m(idx,:),1);
%     tavg(nn) = mean(t(idx));
% end

%% CIC filter
[qavg,tavg] = cicfilter(t,m,2^8,3);
dtnew = tavg(2)-tavg(1);

%% LP filter
% h = 2*pi*20e3*dtnew;
% f = zeros(size(qavg));
% for nn = 2:size(qavg,1)
%     f(nn,:) = h*(qavg(nn-1,:) - f(nn-1,:))+f(nn-1,:);
% end
f = qavg;

%% Phase
ph = atan2(f(:,1),f(:,2));
% h = 2*pi*50e3*Navg*dt;
% phf = zeros(size(qavg));
% for nn = 2:size(qavg,1)
%     phf(nn,:) = h*(ph(nn-1,:) - phf(nn-1,:))+phf(nn-1,:);
% end

%% Plot
figure(1);clf;
plot(t,phin);
hold on
plot(tavg,ph,'.-');
% plot(tavg,phf);
hold off;

window = ones(round(numel(phin)/8),1);
[P0,f0] = pwelch(phin,window,[],[],1/dt);
window = ones(round(numel(ph)/8),1);
[P,f] = pwelch(ph,window,[],[],1/dtnew);
figure(2);clf;
loglog(f0,P0);
hold on
loglog(f,P);

