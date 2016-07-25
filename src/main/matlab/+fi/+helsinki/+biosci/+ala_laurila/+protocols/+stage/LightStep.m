classdef LightStep < fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol
    
    properties (Constant)
        identifier = 'edu.northwestern.SchwartzLab.LightStep'
        version = 4
        displayName = 'Light Step'
    end
    
    properties
        amp
        %times in ms
        preTime = 250	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 500	% Spot trailing duration (ms)
        
        %mean (bg) and amplitude of pulse
        intensity = 0.1;
        
        %spot size in microns, use rigConfig to set microns per pixel
        spotSize = 200;
        numberOfEpochs = 50;
    end
    
    properties (Hidden)
        ampType
    end
    
    methods
      
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);

            %set bg
            p.setBackgroundColor(obj.meanLevel);
            
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
            spot.radiusY = spot.radiusX;
            %spot.color = obj.intensity;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            function c = onDuringStim(state, preTime, stimTime, intensity, meanLevel)
                if state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3
                    c = intensity;
                else
                    c = meanLevel;
                end
            end
            
            controller = stage.builtin.controllers.PropertyController(spot, 'color', @(s)onDuringStim(s, obj.preTime, obj.stimTime, obj.intensity, obj.meanLevel));
            p.addController(controller);
                        
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfEpochs;
        end
        
        
    end
    
end
