function [P,ph,freq,flags,t] = makeBraggSequence(varargin)

%% Set up variables and parse inputs
t0 = 10e-3;
fwhm = 30e-6;
T = 1e-3;
appliedPhase = [0,0,0];
power = [1,1,1];
f0 = 0.5;
chirp = 0;
dt = 1e-6;
useHold = 0;
holdFreq = 5;

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
tPulse = (-5*width:dt:5*width)';
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
    P = 0.1*ones(numel(t),1);
end

for nn = 1:numPulses
    tc = t0 + (nn-1)*T;
    idx = abs(t - tc) <= 5*width;
    %
    % Set powers
    %
    P(idx) = power(nn)*exp(-(t(idx) - tc).^2/width.^2);
    %
    % Set phases
    %
    ph(idx) = appliedPhase(nn);
    %
    % Set frequencies
    %
    freq(idx) = f0 + chirp*t(idx);
    %
    % Set hold
    %
    if useHold
        flags(idx) = 2;
        i2 = find(idx,1,'last');
        flags(i2) = 0;
        freq(i2) = holdFreq;
        P(i2) = 0.1;
    end
end

t = [0;t];
ph = [ph(1);ph];
flags = [0;flags];
flags = flags + 1;
if useHold
    P = [0.1;P];
    freq = [holdFreq;freq];
else
    P = [P(1);P];
    freq = [freq(1);freq];
end



end