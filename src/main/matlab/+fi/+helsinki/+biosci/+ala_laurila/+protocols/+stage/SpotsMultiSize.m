classdef SpotsMultiSize < fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol
    
    properties (Constant)
        identifier = 'edu.northwestern.SchwartzLab.SpotsMultiSize'
        version = 3
        displayName = 'Spots Multiple Sizes'
    end
    
    properties
        amp
        %times in ms
        preTime = 500	% Spot leading duration (ms)
        stimTime = 500	% Spot duration (ms)
        tailTime = 500	% Spot trailing duration (ms)
        
        %mean (bg) and amplitude of pulse
        intensity = 0.1;
        
        %stim size in microns, use rigConfig to set microns per pixel
        minSize = 50
        numberOfSizeSteps = 10
        maxSize = 1500
        numberOfCyles = 2;
        
        logScaling = false % scale spot size logarithmically (more precision in smaller sizes)
    end
    
    properties (Hidden)
        ampType
        curSize
        sizes
    end
    
    methods
        
        function prepareRun(obj)
            prepareRun@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj);
            
            %set spot size vector
            if ~obj.logScaling
                obj.sizes = linspace(obj.minSize, obj.maxSize, obj.numberOfSizeSteps);
            else
                obj.sizes = logspace(log10(obj.minSize), log10(obj.maxSize), obj.numberOfSizeSteps);
            end

        end
        
        function prepareEpoch(obj, epoch)
            % Call the base method.
            prepareEpoch@StageProtocol(obj, epoch);
            
            % Randomize sizes if this is a new set
            if mod(obj.numEpochsQueued, obj.Nsteps) == 0
               obj.sizes = obj.sizes(randperm(obj.numberOfSizeSteps)); 
            end
            
            % compute current size and add parameter for it
            sizeInd = mod(obj.numEpochsQueued, obj.numberOfSizeSteps) + 1;
            
            %get current position
            obj.curSize = obj.sizes(sizeInd);
            epoch.addParameter('curSpotSize', obj.curSize);
        end
        
        
        function preparePresentation(obj, presentation)
            %set bg
            obj.setBackground(presentation);
            
            spot = Ellipse();
            spot.radiusX = round(obj.curSize / 2 / obj.rigConfig.micronsPerPixel); %convert to pixels
            spot.radiusY = spot.radiusX;
            %spot.color = obj.intensity;
            spot.position = [obj.windowSize(1)/2, obj.windowSize(2)/2];
            presentation.addStimulus(spot);
            
            function c = onDuringStim(state, preTime, stimTime, intensity, meanLevel)
                if state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3
                    c = intensity;
                else
                    c = meanLevel;
                end
            end
            
            controller = PropertyController(spot, 'color', @(s)onDuringStim(s, obj.preTime, obj.stimTime, obj.intensity, obj.meanLevel));
            presentation.addController(controller);
            
            preparePresentation@StageProtocol(obj, presentation);
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfCycles * obj.numberOfSizeSteps;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfCycles * obj.numberOfSizeSteps;
        end
        
        
    end
    
end