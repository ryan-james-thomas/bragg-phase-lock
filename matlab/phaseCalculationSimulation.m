clear;

Fs = 125e6;
dt = 1/Fs;

%% Input signal
fin = 250e3*1;
T = 10e-3;
t = (0:dt:T)';
phin = (2*pi*randn-pi) + cumsum(10*pi*(Fs)^-0.5*randn(size(t)));
x = sin(2*pi*fin*t + phin);

%% Mixed signal
dds = [cos(2*pi*fin*t) sin(2*pi*fin*t)];
m = [x.*dds(:,1) x.*dds(:,2)];

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

%% Wrap
dph = [0;diff(ph)];
for nn = 1:numel(dph)
    if dph(nn) > 1.0*pi
        dph(nn) = dph(nn) - 2*pi;
    elseif dph(nn) < -1.0*pi
        dph(nn) = dph(nn) + 2*pi;
    end
end
phw = cumsum(dph);
% phin = cumsum([0;diff(phin)]);
phin = phin - phin(1);

%% Plot
figure(1);clf;
plot(t,phin);
hold on
plot(tavg,phw,'.-');
% hold on
% plot(tavg,ph/pi,'--')
% plot(tavg,phf);
hold off;
grid on;

window = ones(round(numel(phin)/4),1);
[P0,f0] = pwelch(phin,window,[],[],1/dt);
window = ones(round(numel(ph)/4),1);
[P,f] = pwelch(ph,window,[],[],1/dtnew);

% figure(2);clf;
% loglog(f0,P0);
% hold on
% loglog(f,P);


