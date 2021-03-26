classdef PhaseLock < handle
    properties
        t
        data
    end
    
    properties(SetAccess = immutable)
        conn
        
        f0
        df
        fmult
        
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
        
        sampleReg
    end
    
    properties(Constant)
        CLK = 125e6;
        HOST_ADDRESS = '172.22.250.94';
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
            
            % Read-only registers
            self.sampleReg = PhaseLockRegister('01000000',self.conn);

            %Frequency generation
            self.f0 = PhaseLockParameter([0,26],self.freqOffsetReg)...
                .setLimits('lower',0,'upper',50)...
                .setFunctions('to',@(x) x*1e6/self.CLK*2^27,'from',@(x) x/2^27*self.CLK/1e6);
            self.df = PhaseLockParameter([0,26],self.freqDiffReg)...
                .setLimits('lower',0,'upper',50)...
                .setFunctions('to',@(x) x*1e6/self.CLK*2^27,'from',@(x) x/2^27*self.CLK/1e6);
            self.cicRate = PhaseLockParameter([0,7],self.phaseReg)...
                .setLimits('lower',7,'upper',11)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.scaling = PhaseLockParameter([8,11],self.phaseReg)...
                .setLimits('lower',0,'upper',15)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.phasec = PhaseLockParameter([0,23],self.phaseControlSigReg)...
                .setLimits('lower',-pi,'upper',pi)...
                .setFunctions('to',@(x) typecast(int16(x/pi*2^13),'uint16'),'from',@(x) x/2^13*pi);
            
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
            self.fmult = PhaseLockParameter([4,7],self.topReg)...
                .setLimits('lower',0,'upper',15)...
                .setFunctions('to',@(x) x,'from',@(x) x);
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
            self.fmult.set(3);
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
            self.fmult.get;
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
        
        function self = getPhaseData(self,numSamples,saveType)
            if nargin < 3
                saveType = 0;
            end
            self.conn.write(0,'mode','acquire phase','numSamples',numSamples,'saveType',saveType);
            raw = typecast(self.conn.recvMessage,'uint8');
            [ph,act,dds] = self.convertData(raw,'phase');
            self.data = [ph,act,dds];
            self.t = 1/self.CLK*2^self.cicRate.value*(0:(size(self.data,1)-1));
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
            fprintf(1,'\t\t         CIC Rate (log2): %d\n',self.cicRate.value);
            fprintf(1,'\t\t  CIC pre-scaling (log2): %d\n',self.scaling.value);
            fprintf(1,'\t\t    Phase Control Signal: %.3f\n',self.phasec.value);
            fprintf(1,'\t\t               Enable FB: %d\n',self.enableFB.value);
            fprintf(1,'\t\t                Polarity: %d\n',self.polarity.value);
            fprintf(1,'\t\t    Phase Actuator Scale: %d\n',self.divscale.value);
            fprintf(1,'\t\t        Memory Save Type: %d\n',self.memSaveType.value);
            fprintf(1,'\t\t    Difference Freq Mult: %d\n',self.fmult.value);
        end
        
        
    end
    
    methods(Static)
        function [y,t] = loadData(filename,dt)
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
            
            [ph,act,dds] = PhaseLock.convertData(x,'phase');
            t = dt*(0:(numel(ph)-1));
            y = [ph,act,dds];
        end
        
        function varargout = convertData(raw,method)
            Nraw = numel(raw);
            d = zeros(Nraw/8,3);

            mm = 1;
            for nn=1:8:numel(raw)
                d(mm,1) = double(typecast(uint8(raw(nn+(0:1))),'int16'));
                d(mm,2) = double(typecast(uint8(raw(nn+(2:3))),'int16'));
                d(mm,3) = double(typecast(uint8(raw(nn+(4:7))),'uint32'));
                mm = mm+1;
            end
            
            switch lower(method)
                case 'voltage'
                    v = double(d)/2^12;
                    varargout{1} = v;
                case 'phase'
                    ph = double(d(:,1))/2^13*pi;
                    act = double(d(:,2))/2^14*2*pi;
                    dds = double(d(:,3))/2^27*2*pi;
                    varargout = {ph,act,dds};
                otherwise
                    error('Data type unsupported!');
            end
        end
    end
    
end