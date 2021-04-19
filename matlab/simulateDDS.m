function simulateDDS

clk = 125e6;

phaseWidth = 27;
outputWidth = 14;

f0 = 36e6;
df = 0.125e6;

%%
N = 1e4;

dds1 = zeros(N,1,'uint32');
dds2 = zeros(N,1,'uint32');

for nn = 2:N
    dds1(nn) = mod(dds1(nn-1) + floor((f0+df)/clk*2^(phaseWidth)),2^phaseWidth);
    dds2(nn) = mod(dds2(nn-1) + floor((f0-df)/clk*2^(phaseWidth)),2^phaseWidth);
    
end

%%
figure(12);clf;
plot(dds1,'.-');
hold on;
plot(dds2,'.-');

figure(13);clf;
dds1r = double(dds1)*2^(outputWidth - phaseWidth);
dds2r = double(dds2)*2^(outputWidth - phaseWidth);
% plot(dds1r,'.-');
% hold on;
plot(floor(dds1r)-floor(dds2r),'o');


