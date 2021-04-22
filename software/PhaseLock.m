classdef PhaseLock < handle
    properties
        t
        data
    end
    
    properties(SetAccess = immutable)
        conn
        
        f0
        df
        demod
        
        scaling
        cicRate
        
        phasec
        enableFB
        polarity
        divscale
        
        memSaveType
        samplesCollected
    end
    
    properties(SetAccess = protected)
        trigReg
        topReg
        freqOffsetReg
        freqDiffReg
        phaseControlSigReg
        phaseReg
        phaseControlReg
        freqDemodReg
        
        sampleReg
    end
    
    properties(Constant)
        CLK = 125e6;
        HOST_ADDRESS = '172.22.250.94';
        DDS_WIDTH = 27;
        CORDIC_WIDTH = 24;
    end
    
    methods
        function self = PhaseLock(varargin)
            if numel(varargin)==1
                self.conn = PhaseLockClient(varargin{1});
            else
                self.conn = PhaseLockClient(self.HOST_ADDRESS);
            end
            
            % R/W registers
            self.trigReg = PhaseLockRegister('0',self.conn);
            self.topReg = PhaseLockRegister('4',self.conn);
            self.freqOffsetReg = PhaseLockRegister('8',self.conn);
            self.freqDiffReg = PhaseLockRegister('C',self.conn);
            self.phaseControlSigReg = PhaseLockRegister('10',self.conn);
            self.phaseReg = PhaseLockRegister('14',self.conn);
            self.phaseControlReg = PhaseLockRegister('18',self.conn);
            self.freqDemodReg = PhaseLockRegister('34',self.conn);
            
            % Read-only registers
            self.sampleReg = PhaseLockRegister('01000000',self.conn);

            %Frequency generation
            self.f0 = PhaseLockParameter([0,26],self.freqOffsetReg)...
                .setLimits('lower',0,'upper',50)...
                .setFunctions('to',@(x) x*1e6/self.CLK*2^self.DDS_WIDTH,'from',@(x) x/2^self.DDS_WIDTH*self.CLK/1e6);
            self.df = PhaseLockParameter([0,26],self.freqDiffReg)...
                .setLimits('lower',0,'upper',50)...
                .setFunctions('to',@(x) x*1e6/self.CLK*2^self.DDS_WIDTH,'from',@(x) x/2^self.DDS_WIDTH*self.CLK/1e6);
            self.cicRate = PhaseLockParameter([0,7],self.phaseReg)...
                .setLimits('lower',7,'upper',11)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.scaling = PhaseLockParameter([8,11],self.phaseReg)...
                .setLimits('lower',0,'upper',15)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.phasec = PhaseLockParameter([0,31],self.phaseControlSigReg)...
                .setLimits('lower',-pi,'upper',pi)...
                .setFunctions('to',@(x) typecast(int32(x/pi*2^(self.CORDIC_WIDTH-3)),'uint32'),'from',@(x) x/2^(self.CORDIC_WIDTH-3)*pi);
            
            self.polarity = PhaseLockParameter([0,0],self.phaseControlReg)...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.enableFB = PhaseLockParameter([1,1],self.phaseControlReg)...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.divscale = PhaseLockParameter([2,5],self.phaseControlReg)...
                .setLimits('lower',0,'upper',15)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            
            self.memSaveType = PhaseLockParameter([0,3],self.topReg)...
                .setLimits('lower',0,'upper',15)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.demod = PhaseLockParameter([0,26],self.freqDemodReg)...
                .setLimits('lower',0,'upper',50)...
                .setFunctions('to',@(x) x*1e6/self.CLK*2^self.DDS_WIDTH,'from',@(x) x/2^self.DDS_WIDTH*self.CLK/1e6);
            %Read-only
            self.samplesCollected = PhaseLockParameter([0,12],self.sampleReg)...
                .setLimits('lower',0,'upper',2^13)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            
        end
        
        function self = setDefaults(self,varargin)
            self.f0.set(35);
            self.df.set(0);
            self.cicRate.set(8);
            self.scaling.set(10);
            self.phasec.set(0);
            self.enableFB.set(0);
            self.polarity.set(0);
            self.divscale.set(2);
            self.memSaveType.set(0);
            self.demod.set(0);
            self.samplesCollected.set(0);

        end
        
        function self = check(self)

        end
        
        function self = upload(self)
            self.check;
            self.freqOffsetReg.write;
            self.freqDiffReg.write;
            self.phaseControlSigReg.write;
            self.phaseReg.write;
            self.phaseControlReg.write;
            self.topReg.write;
            self.freqDemodReg.write;
            self.updateCIC;
        end
        
        function self = fetch(self)
            %Read registers
            self.freqOffsetReg.read;
            self.freqDiffReg.read;
            self.phaseControlSigReg.read;
            self.phaseReg.read;
            self.phaseControlReg.read;
            self.topReg.read;
            self.freqDemodReg.read;
            
            %Read parameters
            self.f0.get;
            self.df.get;
            self.cicRate.get;
            self.scaling.get;
            self.phasec.get;
            
            self.enableFB.get;
            self.polarity.get;
            self.divscale.get;
            self.memSaveType.get;
            self.demod.get;
            %Get number of collected samples
            self.samplesCollected.read;
            
        end
        
        function self = acquire(self)
            self.trigReg.set(1,[1,1]).write;
            self.trigReg.set(0,[1,1]);
        end
        
        function self = updateCIC(self)
            self.trigReg.set(1,[0,0]).write;
            self.trigReg.set(0,[1,1]);
        end
        
        
        function self = getData(self)
            self.samplesCollected.read;
            self.conn.write(0,'mode','fetch data','fetchType',0,'numFetch',self.samplesCollected.get);
            raw = typecast(self.conn.recvMessage,'uint8');
            
            if self.memSaveType.value == 0
                self.data = self.convertData(raw,'phase');
                self.t = 1/self.CLK*2^self.cicRate.value*(0:(numel(self.data)-1));
            else
                self.data = self.convertData(raw,'voltage');
                self.t = 1/self.CLK*(0:(numel(self.data)-1));
            end
        end
        
        function self = getPhaseData(self,numSamples,saveStreams)
            if nargin < 3
                saveStreams = 1;
            end
            self.conn.write(0,'mode','acquire phase','numSamples',numSamples,'saveStreams',saveStreams,'saveType',0);
            raw = typecast(self.conn.recvMessage,'uint8');
            d = self.convertData(raw,'phase',saveStreams);
            self.data = d;
            self.t = 1/self.CLK*2^self.cicRate.value*(0:(numSamples-1));
        end
        
        function disp(self)
            strwidth = 36;
            fprintf(1,'PhaseLock object with properties:\n');
            fprintf(1,'\t Registers\n');
            self.topReg.makeString('topReg',strwidth);
            self.freqOffsetReg.makeString('freqOffsetReg',strwidth);
            self.freqDiffReg.makeString('freqDiffReg',strwidth);
            self.phaseControlSigReg.makeString('phaseControlSigReg',strwidth);
            self.phaseReg.makeString('phaseReg',strwidth);
            self.phaseControlReg.makeString('phaseControlReg',strwidth);
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Frequency Parameters\n');
            fprintf(1,'\t\t  Center Frequency [MHz]: %.3f\n',self.f0.value);
            fprintf(1,'\t\t   Difference Freq [MHz]: %.3f\n',self.df.value);
            fprintf(1,'\t\t        Demod Freq [MHz]: %.3f\n',self.demod.value);
            fprintf(1,'\t\t         CIC Rate (log2): %d\n',self.cicRate.value);
            fprintf(1,'\t\t  CIC pre-scaling (log2): %d\n',self.scaling.value);
            fprintf(1,'\t\t    Phase Control Signal: %.3f\n',self.phasec.value);
            fprintf(1,'\t\t               Enable FB: %d\n',self.enableFB.value);
            fprintf(1,'\t\t                Polarity: %d\n',self.polarity.value);
            fprintf(1,'\t\t    Phase Actuator Scale: %d\n',self.divscale.value);
            fprintf(1,'\t\t        Memory Save Type: %d\n',self.memSaveType.value);
            
        end
        
        
    end
    
    methods(Static)
        function d = loadData(filename,dt,streams)
            if nargin == 0 || isempty(filename)
                filename = 'SavedData.bin';
            end
            
            %Load data
            fid = fopen(filename,'r');
            fseek(fid,0,'eof');
            fsize = ftell(fid);
            frewind(fid);
            x = fread(fid,fsize,'uint8');
            fclose(fid);
            
            d = PhaseLock.convertData(x,'phase',streams);
            if ~isempty(d.ph)
                N = numel(d.ph);
            elseif ~isempty(d.act)
                N = numel(d.act);
            elseif ~isempty(d.dds)
                N = numel(d.dds);
            end
            d.t = dt*(0:(N-1));
        end
        
        function varargout = convertData(raw,method,streams)
            if nargin < 3 || isempty(streams)
                streams = 1;
            end
            raw = raw(:);
            Nraw = numel(raw);
            bits = bitget(streams,1:7);
            numStreams = sum(bits);
            d = zeros(Nraw/(numStreams*4),numStreams,'uint32');
            
            raw = reshape(raw,4*numStreams,Nraw/(4*numStreams));
            for nn = 1:numStreams
                d(:,nn) = typecast(uint8(reshape(raw((nn-1)*4+(1:4),:),4*size(d,1),1)),'uint32');
            end
%                 
%             
%             mm = 1;
%             for nn=1:(numStreams*4):numel(raw)
%                 d(mm,1) = double(typecast(uint8(raw(nn+(0:3))),'int32'));
%                 d(mm,2) = double(typecast(uint8(raw(nn+(4:7))),'uint32'));
%                 d(mm,3) = double(typecast(uint8(raw(nn+(8:11))),'uint32'));
%                 mm = mm+1;
%             end
            
            switch lower(method)
                case 'voltage'
                    v = double(d)/2^12;
                    varargout{1} = v;
                case 'phase'
                    data.ph = [];
                    data.act = [];
                    data.dds = [];
                    data.I = [];
                    data.Q = [];
%                     data.idx = [];
                    if bits(1)
%                         dd = reshape(typecast(d(:,1),'uint8'),4,numel(d(:,1)));
%                         data.idx = double(dd(4,:));
%                         dd(4,:) = uint8(0);
                        data.ph = double(typecast(d(:,1),'int32'))/2^(PhaseLock.CORDIC_WIDTH-3)*pi;
                    end
                    if bits(2)
                        idx = sum(bits(1:2));
                        data.act = unwrap(double(d(:,idx))/2^(PhaseLock.CORDIC_WIDTH-3)*pi);
                    end
                    if bits(3)
                        idx = sum(bits(1:3));   
                        data.dds = unwrap(double(d(:,idx))/2^PhaseLock.DDS_WIDTH*2*pi);
                    end
                    if bits(4)
                        idx = sum(bits(1:4));
                        data.I = double(typecast(d(:,idx),'int32'));
                    end
                    if bits(5)
                        idx = sum(bits(1:5));
                        data.Q = double(typecast(d(:,idx),'int32'));
                    end
                    varargout{1} = data;
                otherwise
                    error('Data type unsupported!');
            end
        end
    end
    
end