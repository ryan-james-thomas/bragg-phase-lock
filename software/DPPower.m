classdef DPPower < handle
    properties
        rawI
        rawQ
        tSample
        data
        signal
        tPulse
    end
    
    properties(SetAccess = immutable)
        conn
        
        delay
        samplesPerPulse
        log2Avgs
        samplesCollected
        numpulses
        
        sumStart
        subStart
        sumWidth
    end
    
    properties(SetAccess = protected)
        trigReg0
        sharedReg0

        avgReg0
        sampleReg0
        integrateReg0
        numpulseReg0

    end
    
    properties(Constant)
        CLK = 125e6;
        MAX_SUM_RANGE = 2^11-1;
        HOST_ADDRESS = '172.22.250.189';
    end
    
    methods
        function self = DPPower(varargin)
            if numel(varargin)==1
                self.conn = DPFeedbackClient(varargin{1});
            else
                self.conn = DPFeedbackClient(self.HOST_ADDRESS);
            end
            
            self.trigReg0 = DPFeedbackRegister('0',self.conn);
            self.sharedReg0 = DPFeedbackRegister('4',self.conn);

            self.avgReg0 = DPFeedbackRegister('8',self.conn);
            self.integrateReg0 = DPFeedbackRegister('C',self.conn);
            
            self.sampleReg0 = DPFeedbackRegister('01000000',self.conn);
            self.numpulseReg0 = DPFeedbackRegister('01000004',self.conn);
            
            %Initial processing
            self.delay = DPFeedbackParameter([0,13],self.avgReg0)...
                .setLimits('lower',0,'upper',1e-6)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            self.samplesPerPulse = DPFeedbackParameter([14,27],self.avgReg0)...
                .setLimits('lower',0,'upper',2^14-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.log2Avgs = DPFeedbackParameter([28,31],self.avgReg0)...
                .setLimits('lower',0,'upper',2^4-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.samplesCollected = DPFeedbackParameter([0,14],self.sampleReg0)...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.numpulses = DPFeedbackParameter([0,14],self.numpulseReg0)...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) round(x/2));
            
            %Secondary processing
            self.sumStart = DPFeedbackParameter([0,10],self.integrateReg0)...
                .setLimits('lower',0,'upper',2^11-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.subStart = DPFeedbackParameter([11,21],self.integrateReg0)...
                .setLimits('lower',0,'upper',2^11-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.sumWidth = DPFeedbackParameter([22,31],self.integrateReg0)...
                .setLimits('lower',0,'upper',2^10-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
        end
        
        function self = setDefaults(self,varargin)            
            self.delay.set(0);
            self.samplesPerPulse.set(250);
            self.log2Avgs.set(0);
            
            self.sumStart.set(10);
            self.subStart.set(150);
            self.sumWidth.set(50);
            
            self.numpulses.set(0);
        end
        
        function self = check(self)            
            if self.sumStart.get+self.sumWidth.get > self.MAX_SUM_RANGE
                error('End of summation range is larger than %d',self.MAX_SUM_RANGE);
            elseif self.subStart.get+self.sumWidth.get > self.MAX_SUM_RANGE
                error('End of subtraction range is larger than %d',self.MAX_SUM_RANGE);
            end
            
            if self.sumStart.get >= self.subStart.get
                error('Start of summation interval is after subtraction interval');
            elseif self.sumStart.get+self.sumWidth.get >= self.subStart.get
                error('Summation interval overlaps with subtraction interval');
            elseif self.subStart.get >= self.samplesPerPulse.get || self.subStart.get+self.sumWidth.get >= self.samplesPerPulse.get
                error('Subtraction interval is outside of number sample collection range')
            end

        end
        
        function self = upload(self)
            self.check;
            self.avgReg0.write;
            self.integrateReg0.write;
        end
        
        function self = fetch(self)
            %Read registers
            self.avgReg0.read;
            self.integrateReg0.read;
            self.sampleReg0.read;
            
            %Read parameters 
            self.delay.get;
            self.samplesPerPulse.get;
            self.log2Avgs.get;
            
            self.sumStart.get;
            self.subStart.get;
            self.sumWidth.get;
            
            %Get number of collected samples
            self.samplesCollected.read;
            self.numpulses.read;
            
        end
        
        function self = copyfb(self,fb)
            if isa(fb,'DPFeedback')
                self.log2Avgs.set(fb.log2Avgs.value);
                self.delay.set(fb.delay.value);
                self.samplesPerPulse.set(fb.samplesPerPulse.value);
                self.sumStart.set(fb.sumStart.value);
                self.subStart.set(fb.subStart.value);
                self.sumWidth.set(fb.sumWidth.value);
            else
                error('Input must be a DPFeedback object');
            end
            
        end
        
        function self = reset(self)
            self.trigReg0.set(0,[0,31]).write;
        end
        
        function self = getRaw(self)
            self.samplesCollected.read;
            N = self.numpulses.read.get;
            self.conn.write(0,'mode','fetch raw','numFetch',self.samplesCollected.get);
            raw = typecast(self.conn.recvMessage,'uint8');
            [dataI,dataQ] = deal(zeros(self.samplesCollected.value,1));

            mm = 1;
            for nn=1:4:numel(raw)
                dataI(mm) = double(typecast(uint8(raw(nn+(0:1))),'int16'));
                dataQ(mm) = double(typecast(uint8(raw(nn+(2:3))),'int16'));
                mm = mm+1;
            end
            
            if self.samplesPerPulse.get*N > numel(dataI)
                maxpulses = floor(numel(dataI)/self.samplesPerPulse.get);
            else
                maxpulses = N;
            end
            idx = 1:(maxpulses*self.samplesPerPulse.get);
            self.rawI = reshape(dataI(idx),self.samplesPerPulse.get,maxpulses);
            self.rawQ = reshape(dataQ(idx),self.samplesPerPulse.get,maxpulses);
            
            self.tSample = 2^self.log2Avgs.get/self.CLK*(0:(self.samplesPerPulse.get-1))';
        end
        
        function self = getProcessed(self,period)
            N = self.numpulses.read.get;
            self.conn.write(0,'mode','fetch processed','numFetch',2*N);
            raw = typecast(self.conn.recvMessage,'uint8');
            
            self.data = zeros(N,2);
            mm = 1;
            for nn=1:8:numel(raw)
                self.data(mm,1) = double(typecast(uint8(raw(nn+(0:3))),'int32'));
                self.data(mm,2) = double(typecast(uint8(raw(nn+(4:7))),'int32'));
                mm = mm+1;
            end
            self.data = self.data/self.sumWidth.value;
            self.signal = self.data(:,1);
            
            if nargin==1
                period = 1;
            end
            self.tPulse = period*(0:(N-1))';
        end
        
        function v = integrate(self)
            sumidx = (self.sumStart.get):(self.sumStart.get+self.sumWidth.get);
            subidx = (self.subStart.get):(self.subStart.get+self.sumWidth.get);
            v(:,1) = sum(self.rawI(sumidx,:),1)'-sum(self.rawI(subidx,:),1)';
            v(:,2) = sum(self.rawQ(sumidx,:),1)'-sum(self.rawQ(subidx,:),1)';
        end
        
        function disp(self)
            fprintf(1,'DPPower object with properties:\n');
            fprintf(1,'\t Registers\n');
            fprintf(1,'\t\t    sharedReg0: %08x\n',self.sharedReg0.value);
            fprintf(1,'\t\t       avgReg0: %08x\n',self.avgReg0.value);
            fprintf(1,'\t\t    sampleReg0: %08x\n',self.sampleReg0.value);
            fprintf(1,'\t\t integrateReg0: %08x\n',self.integrateReg0.value);
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Averaging Parameters\n');
            fprintf(1,'\t\t             Delay: %.2e s\n',self.delay.value);
            fprintf(1,'\t\t Samples per pulse: %d\n',self.samplesPerPulse.value);
            fprintf(1,'\t\t   log2(# of avgs): %d\n',self.log2Avgs.value);
            fprintf(1,'\t ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
            fprintf(1,'\t Integration Parameters\n');
            fprintf(1,'\t\t   Start of summation window: %d\n',self.sumStart.value);
            fprintf(1,'\t\t Start of subtraction window: %d\n',self.subStart.value);
            fprintf(1,'\t\t Width of integration window: %d\n',self.sumWidth.value);
            fprintf(1,'\t\t Number of samples collected: %d\n',self.samplesCollected.value);
            fprintf(1,'\t\t  Number of pulses collected: %d\n',self.numpulses.value);
        end
        
        
    end
    
end