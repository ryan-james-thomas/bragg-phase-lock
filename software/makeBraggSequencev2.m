function [P,ph,freq,flags,t] = makeBraggSequencev2(varargin)

%% Set up variables and parse inputs
t0 = 30e-3;
k = 2*pi*384229441689483/const.c;
recoil = const.hbar*k^2/(4*pi*const.mRb);
fwhm = 30e-6;
T = 1e-3;
appliedPhase = [0,0,0];
power = [0.5,1,0.5];
f0 = 4*recoil/8/1e6;
chirp = 25.106258428/8;
dt = 1e-6;
useHold = 0;
holdFreq = 2;
holdAmp = 0.1;
calibration = load('calibration-high-gain','power');
% calibration = load('calibration','power');

if mod(numel(varargin),2) ~= 0
    error('Arguments must appear as name/value pairs!');
else
    for nn = 1:2:numel(varargin)
        v = varargin{nn+1};
        switch lower(varargin{nn})
            case 't0'
                t0 = v;
            case 't'
                T = v;
            case 'dt'
                dt = v;
            case {'width','fwhm'}
                fwhm = v;
            case {'appliedphase','phase'}
                appliedPhase = v;
            case 'power'
                power = v;
            case 'f0'
                f0 = v;
            case 'chirp'
                chirp = v;
            case 'usehold'
                useHold = v;
            case 'holdfreq'
                holdFreq = v;
            case 'holdamp'
                holdAmp = v;
            otherwise
                error('Option %s not supported',varargin{nn});
        end
    end
end

%% Conditions on the time step and the Bragg order
if fwhm > 50e-6
    dt = ceil(fwhm/50e-6)*1e-6;
end
     
%% Calculate intermediate values
numPulses = numel(power);
width = fwhm/(2*sqrt(log(2)));

%% Create vectors
max_t_pulse = 3*width;
tPulse = [-1000e-6,-max_t_pulse:dt:max_t_pulse]';
t = repmat(tPulse,1,numPulses);
for  nn = 1:numPulses
    t(:,nn) = t(:,nn) + t0 + (nn-1)*T;
end
t = t(:);
%
% Set powers, phases, and frequencies
%
[P,ph,freq,flags] = deal(zeros(numel(t),1));
if useHold
    freq = holdFreq*ones(numel(t),1);
    flags = zeros(numel(t),1);
    P = holdAmp*ones(numel(t),1);
end

for nn = 1:numPulses
    tc = t0 + (nn-1)*T;
    idx = abs(t - tc) <= (max_t_pulse + 5*dt);
    %
    % Set powers
    %
    P(idx) = power(nn)*exp(-(t(idx) - tc).^2/width.^2);
    %
    % Set phases
    %
%     if nn > 1
%         ph(idx) = appliedPhase(nn - 1);
%     end
    ph(idx) = appliedPhase(nn);
    %
    % Set frequencies
    %
    freq(idx) = f0 + chirp*tc;
    %
    % Set hold
    %
    if useHold
        flags(idx) = 2;
        i2 = find(idx,1,'first');
        flags(i2 - 1) = 0;
        freq(i2 - 1) = holdFreq;
        P(i2 - 1) = holdAmp;
        ph(i2 - 1) = appliedPhase(min(numPulses,nn));
    else
        i2 = find(idx,1,'first');
        freq(i2 - 1) = freq(i2);
        P(i2 - 1) = 0;
        ph(i2 - 1) = ph(i2);
    end
end

if useHold
    t = [0;t];
    ph = [ph(1);ph];
    flags = [0;flags];
    flags = flags + 1;
    flags(1) = 0;   %Disables lock for first point with no amplitude
    P = [0;P];
    freq = [holdFreq;freq];
else
    t = [0;t];
    ph = [ph(1);ph];
    flags = [0;flags];
    flags = flags + 1;
    P = [0;P];
    freq = [freq(1);freq];
end

if numel(P) > numel(t)
    t = [t;t(end) + dt];
end

cp = (calibration.power.ch1(:,2) - calibration.power.ch1(1,2)) + (calibration.power.ch2(:,2) - calibration.power.ch2(1,2));
f = @(x) interp1(cp./max(cp),calibration.power.ch1(:,1),x,'pchip');

P = f(P);

end