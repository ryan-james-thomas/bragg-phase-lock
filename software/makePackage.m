function makePackage(t,ph,amp,freq,flags)
%MAKEPACKAGE This function makes a VHDL package for simulation that has a
%real pulse shape for testing the timing controller and phase lock.
%
%   MAKEPACKAGE(T,PH,AMP,FREQ,FLAGS) makes the package with times T in
%   seconds, phases PH in radians, amplitude scale factors AMP (numel(T) x
%   2 array) as values from 0 to 1, frequency difference values FREQ in
%   MHz, and flags FLAGS.  See the PhaseLockAbstract.uploadTiming method
%   for more information.
%
%   The VHDL package is given the name DataPackage.vhd and places in the
%   fpga/sources/sim/ directory.
%

t = t(:);
ph = ph(:);
% amp = amp(:);
freq = freq(:);
if nargin < 6
    flags = zeros(numel(freq),1);
else
    flags = flags(:);
end

dt = uint32([round(diff(t)*PhaseLock.CLK);1000]);
ph = int32(ph/pi*2^(PhaseLock.CORDIC_WIDTH-3));
amp = uint32(amp*(2^PhaseLock.AMP_WIDTH - 1));
freq = uint32(freq*1e6/PhaseLock.CLK*2^PhaseLock.DDS_WIDTH);
flags = uint32(flags);
%
% Duplicate last instruction but with a delay of 0, indicating
% that the timing controller should stop
%
dt(end + 1) = 0;
ph(end + 1) = ph(end);
amp(end + 1,:) = amp(end,:);
freq(end + 1) = freq(end);
flags(end + 1) = flags(end);

d = zeros(4*numel(dt),1,'uint32');
mm = 1;
for nn = 1:numel(dt)
    d(mm) = typecast(ph(nn),'uint32');
    mm = mm + 1;
    d(mm) = typecast(freq(nn),'uint32');
    mm = mm + 1;
    d(mm) = bitshift(typecast(amp(nn,2),'uint32'),12) + typecast(amp(nn,1),'uint32');
    mm = mm + 1;
    d(mm) = typecast(dt(nn),'uint32');
    d(mm) = d(mm) + bitshift(flags(nn),28);
    mm = mm + 1;
end

fid = fopen('../fpga/sources/sim/DataPackage.vhd','w');
fprintf(fid,'library IEEE;\n');
fprintf(fid,'use ieee.std_logic_1164.all;\n');
fprintf(fid,'use ieee.numeric_std.all;\n');
fprintf(fid,'package DataPackage is\n');
fprintf(fid,'type t_data_array is array(natural range <>) of std_logic_vector(31 downto 0);\n');
fprintf(fid,'constant DATA : t_data_array(%d - 1 downto 0) := (\n',numel(d));
for nn = 0:(numel(d) - 2)
    fprintf(fid,'    %d => X"%08x",\n',nn,d(nn+1));
end
fprintf(fid,'    %d => X"%08x");\n',numel(d) - 1,d(end));

fprintf(fid,'end DataPackage;\n');

fclose(fid);


end