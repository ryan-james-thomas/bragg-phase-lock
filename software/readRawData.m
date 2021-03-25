function [dataI,dataQ] = readRawData

fname = 'SavedData.bin';
fid = fopen(fname,'r');
raw = fread(fid);
fclose(fid);

numSamples = round(numel(raw)/4);
[dataI,dataQ] = deal(zeros(numSamples,1,'int16'));

mm = 1;
for nn=1:4:numel(raw)
    dataI(mm) = typecast(uint8(raw(nn+(0:1))),'int16');
    dataQ(mm) = typecast(uint8(raw(nn+(2:3))),'int16');
    mm = mm+1;
end






end