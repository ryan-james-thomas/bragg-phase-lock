function [x,t] = cicfilter(t,x,R,N)

%% Integrator
xx = x;
for nn = 1:N
    xx = cumsum(xx,1);
end

%% Rate reduction
tr = t(1:R:end);
xr = xx(1:R:end,:);

%% Comb
xx = xr;
for nn = 1:N
    xx = diff(xx,1,1);
end

t = tr(1:size(xx,1));
x = R.^-N.*xx;

end