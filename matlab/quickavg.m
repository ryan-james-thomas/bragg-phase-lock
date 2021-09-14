function [x,t] = quickavg(t,x,R)

t = t(:);
x = x(:);
blocks = floor(numel(x)/R);
xx = reshape(x(1:(blocks*R)),blocks,R);
x = mean(xx,2);
dt = t(2) - t(1);
t = (R*dt)*(0:(numel(x)-1));
t = t(:);



end