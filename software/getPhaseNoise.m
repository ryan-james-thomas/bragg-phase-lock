function data = getPhaseNoise(t,v)

%% Estimate frequency
N = numel(v);
fest = 1e6;
% idx = [1:1e3,round(N/2)+(0:1e3),(N-1e3):N];
idx = 1:1e3;
nlf = nonlinfit(t(idx),v(idx));
nlf.setFitFunc(@(a,f,phi,y0,x) a*sin(2*pi*f*x+phi)+y0);
nlf.bounds([0,fest*(1-1e-3),-pi,-0.1],[100,fest*(1+1e-3),pi,0.1],[1,fest,0,0]);
nlf.fit;
% figure(5);clf;
% plot(t(idx),v(idx),'o');
% hold on;
% plot(t,nlf.f(t));
fest = nlf.c(2,1);
fprintf(1,'Estimated frequency is %.3f\n',fest);

%% Compute I, Q and phi
I = v.*sin(2*pi*fest*t);
Q = v.*cos(2*pi*fest*t);
% fc = fest;
fc = 20e3;

% Nfft = 2^(ceil(log2(numel(v))))-1;
% Nfft = numel(v);
% dt = t(2) - t(1);
% t = t(1:Nfft);
% f = 1/(2*dt)*linspace(-1,1,Nfft)';
% % Filt = abs(f) < fc;
% Filt = 1./(1+2i*(f/fc)-2*(f/fc).^2-1i*(f/fc).^3);
% Ifft = fftshift(fft(I,Nfft));
% Qfft = fftshift(fft(Q,Nfft));
% 
% Ifilt = real(ifft(ifftshift(Filt.*Ifft),Nfft));
% Qfilt = real(ifft(ifftshift(Filt.*Qfft),Nfft));

Ifilt = cicf

phi = unwrap(atan2(Qfilt,Ifilt));

%% Detrend
phi = phi(1e3:end-1e3);
t = t(1e3:end-1e3);
idx = floor(linspace(1,numel(t),1000));
lf = linfit(t(idx),phi(idx));
% lf.setFitFunc(@(x) [ones(size(x(:))) x(:) x(:).^2]);
lf.setFitFunc('poly',1);
lf.fit;
figure(20);clf;
lf.plot;
% phitest = detrend(phi,1);
phi = phi - lf.f(t);
% plot(t,phi);
% hold on;
% plot(t,phitest);

% phism = smooth(phi,ceil(1./dt));
% phi = phi - phism;
% phi = phi(1e3:end-1e3);
% t = t(1e3:end-1e3);

%% Compute power spectrum
% phi = phi(1:end/2);
% t = t(1:end/2);
N = numel(phi);
phifft = fft(phi);
phifft = phifft/(sqrt(2)*N);
phifft(2:end) = 2*phifft(2:end);
phifft = phifft(1:floor(N/2));

f = 1/dt*(0:(N-1))'/N;
f = f(1:floor(N/2));

figure(10);clf;
subplot(1,2,1);
plot(t,phi,'.-');

subplot(1,2,2);
loglog(f,abs(phifft).^2/(f(2)-f(1)));

data.t = t;
data.phi = phi;
data.fft = phifft;
data.f = f;
data.psd = abs(phifft).^2/(f(2)-f(1));



end