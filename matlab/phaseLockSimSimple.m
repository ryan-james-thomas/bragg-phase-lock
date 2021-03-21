clear;

Fs = 125e6;
dt = 1/Fs;

T = 10e-3;
t = (0:dt:T)';
N = numel(t);
f0 = 250e3;

%% Input signals
ph = zeros(N,2);
phc = zeros(N,2);
x = zeros(N,1);
dds = zeros(N,2);
m = zeros(N,2);
ph(1,:) = pi*(2*rand(1,2)-1)*0;
sigfunc = @(t,ph) (1+0.0*randn)*sin(2*pi*f0*t+4*(ph(2)-ph(1)));
x(1) = sigfunc(t(1),ph(1,:));
ddsfunc = @(t) [cos(2*pi*f0*t) sin(2*pi*f0*t)];
dds(1,:) = ddsfunc(t(1));

R = 2^8;
dtavg = dt*R;
tavg = [];
xavg = [];

u = 0;
r = 0;
Kp = 0.125;
Ki = 1/8*2*pi*3e3*dt*R;
phdev = [0,0];

for nn = 2:N
%     phc(nn,2) = phc(nn-1,2)*0 + u(end);
    phdev = phdev + 6/sqrt(Fs)*randn(1,2);
    ph(nn,:) = phc(nn,:) + phdev;
    
    if mod(nn,R) == 0
        mm = floor(nn/R);
        tavg(mm) = t(nn);
        phw(mm) = 4*mean(ph((nn-R+1):nn,2) - ph((nn-R+1):nn,1));
%         phw(mm) = 4*(ph(nn,2) - ph(nn,1));
        e = r - phw(mm);
        if mm == 1
            u(mm) = 0.25*e;
        else
            u(mm) = u(mm-1) + 0.25*e;
        end
    end
    
end

%%
figure(1);clf;
plot(t,4*diff(ph,1,2),'.-');
hold on;
plot(tavg,phw,'.-');
plot(t,phc(:,2),'.-');
hold off;
grid on;


