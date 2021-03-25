function data = readProcessedData

fname = 'SavedProcessedData.bin';
fid = fopen(fname,'r');
raw = fread(fid);
fclose(fid);

numSamples = round(numel(raw)/4);
data = zeros(numSamples,1);

mm = 1;
for nn=1:4:numel(raw)
    data(mm) = double(typecast(uint8(raw(nn+(0:3))),'uint32'));
    mm = mm+1;
end






end