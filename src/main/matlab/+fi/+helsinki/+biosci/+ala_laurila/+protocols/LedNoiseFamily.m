classdef LedNoiseFamily < fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol
    
    properties
        led                             % Output LED
        preTime = 100                   % Noise leading duration (ms)
        stimTime = 600                  % Noise duration (ms)
        tailTime = 100                  % Noise trailing duration (ms)
        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing
        startStdv = 0.005               % First noise standard deviation, post-smoothing (Hz)
        stdvMultiplier = 3              % Amount to multiply the starting standard deviation by with each new multiple 
        stdvMultiples = uint16(3)       % Number of standard deviation multiples in family
        repeatsPerStdv = uint16(5)      % Number of times to repeat each standard deviation multiple
        useRandomSeed = false           % Use a random seed for each standard deviation multiple?
        lightMean = 0.1                 % Noise and LED background mean (V)
        amp                             % Input amplifier
        numberOfAverages = uint16(5)    % Number of families
        interpulseInterval = 0          % Duration between noise stimuli (s)
    end
    
    properties (Hidden, Dependent)
        pulsesInFamily
    end
    
    properties (Hidden)
        ledType
        ampType
    end
    
    methods
        
        function n = get.pulsesInFamily(obj)
            n = obj.stdvMultiples * obj.repeatsPerStdv;
        end
        
        function didSetRig(obj)
            didSetRig@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()createPreviewStimuli(obj));
            function s = createPreviewStimuli(obj)
                s = cell(1, obj.pulsesInFamily);
                for i = 1:numel(s)
                    if ~obj.useRandomSeed
                        seed = 0;
                    elseif mod(i - 1, obj.repeatsPerStdv) == 0
                        seed = RandStream.shuffleSeed;
                    end
                    s{i} = obj.createLedStimulus(i, seed);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                'baselineRegion', [0 obj.preTime], ...
                'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            
            obj.rig.getDevice(obj.led).background = symphonyui.core.Measurement(obj.lightMean, 'V');
        end
        
        function [stim, stdv] = createLedStimulus(obj, pulseNum, seed)
            sdNum = floor((double(pulseNum) - 1) / double(obj.repeatsPerStdv));
            stdv = obj.stdvMultiplier^sdNum * obj.startStdv;
            
            gen = fi.helsinki.biosci.ala_laurila.stimuli.GaussianNoiseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.stDev = stdv;
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.mean = obj.lightMean;
            gen.seed = seed;
            gen.upperLimit = 10.239;
            gen.lowerLimit = -10.24;
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj, epoch);
            
            persistent seed;
            if ~obj.useRandomSeed
                seed = 0;
            elseif mod(obj.numEpochsPrepared - 1, obj.repeatsPerStdv) == 0
                seed = RandStream.shuffleSeed;
            end
            
            pulseNum = mod(obj.numEpochsPrepared - 1, obj.pulsesInFamily) + 1;
            [stim, stdv] = obj.createLedStimulus(pulseNum, seed);
            
            epoch.addParameter('stdv', stdv);
            epoch.addParameter('seed', seed);
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages * obj.pulsesInFamily;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages * obj.pulsesInFamily;
        end
        
    end
    
end

