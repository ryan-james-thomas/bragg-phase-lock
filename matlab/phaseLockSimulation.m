clear;

Fs = 125e6;
dt = 1/Fs;

T = 1e-3;
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
r = (1+tanh((t-t(round(N/2)))/20e-6))/2*pi/2;
% r = (t > t(round(N/2)))*pi/2;
Kp = 0.125;
Ki = 1/8*2*pi*3e3*dt*R;
phdev = [0,0];

for nn = 2:N
    phc(nn,2) = u(end);
%     phdev = sin(2*pi*100*t(nn)).*[-0.5,0.5];
    phdev = phdev + 1/sqrt(Fs)*randn(1,2);
    ph(nn,:) = phc(nn,:) + phdev;
    
    x(nn) = sigfunc(t(nn),ph(nn,:));
    dds(nn,:) = ddsfunc(t(nn));
    
    m(nn,:) = [x(nn).*dds(nn,1) x(nn).*dds(nn,2)];
    
    
    if mod(nn,R) == 0
        [xavg,tavg] = cicfilter(t(1:nn),m(1:nn,:),R,3);
        phnew = atan2(xavg(:,1),xavg(:,2));
        dph = [0;diff(phnew)];
        for mm = 1:numel(dph)
            if dph(mm) > 1.0*pi
                dph(mm) = dph(mm) - 2*pi;
            elseif dph(mm) < -1.0*pi
                dph(mm) = dph(mm) + 2*pi;
            end
        end
        phw = cumsum(dph);
        e = r(nn) - phw;
        if numel(e) == 1
            u(1) = 0;
        else
            u(numel(e)) = u(numel(e)-1) + 0.25*e(end);
        end
%         if numel(e) == 1
%             u(end+1) = u(end) + Kp*e(end) + Ki*e(end);
%         else
%             u(end+1) = u(end) + Kp*(e(end)-e(end-1)) + Ki*(e(end)+e(end-1));
%         end

%         u(numel(e)) = 0.25*e(end);

%         ph(nn,2) = ph(nn,2) + u(end);
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


