function data = getPhaseNoise(t,v)
t = t(:);
v = v(:);

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