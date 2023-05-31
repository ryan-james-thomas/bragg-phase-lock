classdef PhaseLock125 < PhaseLockAbstract
    %PhaseLock125 is an instance of the PhaseLockAbstract class designed
    %for interfacing with the phase lock design for the STEMlab board
    %which has a 125 MHz clock (hence the 125!).
    
    properties(Constant)
        CLK = 125e6;                    %Clock frequency of the board
    end
    
    methods
        function self = PhaseLock125(varargin)
            %PhaseLock125 Constructor for this class.
            %
            % SELF = PhaseLock125(HOST_ADDRESS) constructs a
            % PhaseLock125 object using the given HOST_ADDRESS for
            % connecting to the remote server.  HOST_ADDRESS can be
            % neglected, in which case the default HOST_ADDRESS is used
            %
            self = self@PhaseLockAbstract(varargin{:});
        end

    end
  
end