function data = analyzePhaseNoise(data)
t = data.t(:);
v = data.v(:);

%% Estimate frequency
N = numel(v);
fest = 1e6;
% idx = [1:1e3,round(N/2)+(0:1e3),(N-1e3):N];
% idx = 1:1e3;
% ex = ~(mod(t,10e-3)<10e-6);
ex = t>10e-6;
nlf = nonlinfit(t,v,0.01,ex);
nlf.setFitFunc(@(a,f,phi,y0,x) a*sin(2*pi*f*x+phi)+y0);
nlf.bounds([0,fest*(1-1e-3),-pi,-0.1],[1,fest*(1+1e-3),pi,0.1],[range(nlf.y)/2,fest,0,0]);
nlf.fit;
fest = nlf.c(2,1);
fprintf(1,'Estimated frequency is %.3f\n',fest);

%% Compute I, Q and phi
I = v.*sin(2*pi*fest*t);
Q = v.*cos(2*pi*fest*t);

R = 2^2;
Ifilt = cicfilter(t,I,R,3);
Qfilt = cicfilter(t,Q,R,3);

phi = atan2(Qfilt,Ifilt);
t = (t(2)-t(1))*R*(0:(numel(Ifilt)-1));
dt = t(2)-t(1);
phi = unwrap(phi);
%% Detrend
phi = detrend(phi,1);

%% Compute power spectrum
[P,f] = pwelch(phi,ones(floor(numel(phi)/8),1),[],[],1/dt);
data.psd = P;
data.f = f;


end