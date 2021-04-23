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
        
        cicRate
        
        phasec
        enableFB
        polarity
        Kp
        Ki
        divisor
        
        samplesCollected
    end
    
    properties(SetAccess = protected)
        trigReg
        topReg
        freqOffsetReg
        freqDiffReg
        freqDemodReg
        phaseControlSigReg
        phaseCalcReg
        phaseControlReg
        phaseGainReg
        
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
            %
            % Freq generation registers
            %
            self.freqOffsetReg = PhaseLockRegister('8',self.conn);
            self.freqDiffReg = PhaseLockRegister('C',self.conn);
            self.freqDemodReg = PhaseLockRegister('10',self.conn);
            %
            % Phase control/calculation registers
            self.phaseControlSigReg = PhaseLockRegister('14',self.conn);
            self.phaseCalcReg = PhaseLockRegister('18',self.conn);
            self.phaseControlReg = PhaseLockRegister('1C',self.conn);
            self.phaseGainReg = PhaseLockRegister('20',self.conn);
            
            % Read-only registers
            self.sampleReg = PhaseLockRegister('01000000',self.conn);

            %
            %Frequency generation
            %
            self.f0 = PhaseLockParameter([0,26],self.freqOffsetReg)...
                .setLimits('lower',0,'upper',50)...
                .setFunctions('to',@(x) x*1e6/self.CLK*2^self.DDS_WIDTH,'from',@(x) x/2^self.DDS_WIDTH*self.CLK/1e6);
            self.df = PhaseLockParameter([0,26],self.freqDiffReg)...
                .setLimits('lower',0,'upper',50)...
                .setFunctions('to',@(x) x*1e6/self.CLK*2^self.DDS_WIDTH,'from',@(x) x/2^self.DDS_WIDTH*self.CLK/1e6);
            self.demod = PhaseLockParameter([0,26],self.freqDemodReg)...
                .setLimits('lower',0,'upper',2^27)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            %
            % Phase calculation
            %
            self.cicRate = PhaseLockParameter([0,7],self.phaseCalcReg)...
                .setLimits('lower',7,'upper',11)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            %
            % Phase control signal
            %
            self.phasec = PhaseLockParameter([0,31],self.phaseControlSigReg)...
                .setLimits('lower',-pi,'upper',pi)...
                .setFunctions('to',@(x) typecast(int32(x/pi*2^(self.CORDIC_WIDTH-3)),'uint32'),'from',@(x) x/2^(self.CORDIC_WIDTH-3)*pi);
            %
            % Phase control parameters
            %
            self.polarity = PhaseLockParameter([0,0],self.phaseControlReg)...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.enableFB = PhaseLockParameter([1,1],self.phaseControlReg)...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            %
            % Phase controller gains
            %
            self.Kp = PhaseLockParameter([0,7],self.phaseGainReg)...
                .setLimits('lower',0,'upper',255)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.Ki = PhaseLockParameter([8,15],self.phaseGainReg)...
                .setLimits('lower',0,'upper',255)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.divisor = PhaseLockParameter([24,31],self.phaseGainReg)...
                .setLimits('lower',0,'upper',255)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            
            %Read-only
            self.samplesCollected = PhaseLockParameter([0,12],self.sampleReg)...
                .setLimits('lower',0,'upper',2^13)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            
        end
        
        function self = setDefaults(self,varargin)
            %
            % Frequency parameters
            %
            self.f0.set(35);
            self.df.set(0);
            self.demod.set(0);
            %
            % Phase calculation
            %
            self.cicRate.set(8);
            %
            % Phase control
            %
            self.phasec.set(0);
            self.enableFB.set(0);
            self.polarity.set(0);
            self.Kp.set(1);
            self.Ki.set(1);
            self.divisor.set(3);
            
            self.samplesCollected.set(0);

        end
        
        function self = check(self)

        end
        
        function self = upload(self)
            self.check;
            self.freqOffsetReg.write;
            self.freqDiffReg.write;
            self.freqDemodReg.write;
            self.phaseControlSigReg.write;
            self.phaseCalcReg.write;
            self.phaseControlReg.write;
            self.phaseGainReg.write;
            self.topReg.write;
            
            self.updateCIC;
        end
        
        function self = fetch(self)
            %Read registers
            self.freqOffsetReg.read;
            self.freqDiffReg.read;
            self.freqDemodReg.read;
            self.phaseControlSigReg.read;
            self.phaseCalcReg.read;
            self.phaseControlReg.read;
            self.phaseGainReg.read;
            self.topReg.read;
            
            
            %Read parameters
            self.f0.get;
            self.df.get;
            self.demod.get;
            self.cicRate.get;
            self.phasec.get;
            
            self.enableFB.get;
            self.polarity.get;
            self.Kp.get;
            self.Ki.get;
            self.divisor.get;
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
            self.freqDemodReg.makeString('freqDemodReg',strwidth);
            self.phaseControlSigReg.makeString('phaseControlSigReg',strwidth);
            self.phaseCalcReg.makeString('phaseCalcReg',strwidth);
            self.phaseControlReg.makeString('phaseControlReg',strwidth);
            self.phaseGainReg.makeString('phaseGainReg',strwidth);
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Frequency Parameters\n');
            fprintf(1,'\t\t%25s: %.3f\n','Center Frequency [MHz]',self.f0.value);
            fprintf(1,'\t\t%25s: %.3f\n','Difference Freq [MHz]',self.df.value);
            fprintf(1,'\t\t%25s: %d\n','Demod Freq [int]',self.df.value);
            fprintf(1,'\t\t%25s: %d\n','CIC Rate (log2)',self.cicRate.value);
            fprintf(1,'\t\t%25s: %.3f\n','Phase control signal',self.phasec.value);
            fprintf(1,'\t\t%25s: %d\n','Enable FB',self.enableFB.value);
            fprintf(1,'\t\t%25s: %d\n','Polarity',self.polarity.value);
            fprintf(1,'\t\t%25s: %d\n','Kp',self.Kp.value);
            fprintf(1,'\t\t%25s: %d\n','Ki',self.Ki.value);
            fprintf(1,'\t\t%25s: %d\n','Divisor',self.divisor.value);
            
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
            
            switch lower(method)
                case 'voltage'
                    v = double(d)/2^12;
                    varargout{1} = v;
                case 'phase'
                    data.ph = [];
                    data.act = [];
                    data.dds = [];
                    if bits(1)
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
                    varargout{1} = data;
                otherwise
                    error('Data type unsupported!');
            end
        end
    end
    
end