classdef Annulus < fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol
    
    properties
        amp                             % Output amplifier
        preTime = 500                   % Annulus leading duration (ms)
        stimTime = 1000                 % Annulus duration (ms)
        tailTime = 1000                 % Annulus trailing duration (ms)
        intensity = 1.0                 % Annulus light intensity (0-1)
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        minInnerDiam = 10               % Minimum inner diameter of annulus (um)
        minOuterDiam = 200              % Minimum outer diameter of annulus  (um)
        maxInnerDiam = 400              % Maximum Inner diamater (um)
        nSteps = 10                     % Number of steps
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between annulus (s)
        keepConstant = 'area'           % keep area (or) thickness as constant
    end
    
    properties (Hidden)
        keepConstantType = symphonyui.core.PropertyType('char', 'row', {'area', 'thickness'})
        ampType
        innerDiameterVector
        log = log4m.LogManager.getLogger('fi.helsinki.biosci.ala_laurila.protocols.stage.Annulus');
        curInnerDiameter
        curOuterDiameter
    end
    
    
    properties (Dependent)
        initArea                        % Initial area
        maxOuterDiam                    % Maximum outer diameter
        initThick                       % Initial thickness
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            if isempty(obj.rig.getDevices('Stage'))
                p = [];
                return;
            end
            p = io.github.stage_vss.previews.StagePreview(panel, @()obj.createPresentation(), ...
                'windowSize', obj.rig.getDevice('Stage').getCanvasSize());
        end
        
        function prepareRun(obj)
            prepareRun@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj);
            
            obj.innerDiameterVector = linspace(obj.minInnerDiam, obj.maxInnerDiam, obj.nSteps);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('io.github.stage_vss.figures.FrameTimingFigure', obj.rig.getDevice('Stage'));
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spotDiameterPix = obj.um2pix(obj.curOuterDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            outerCircle = stage.builtin.stimuli.Ellipse();
            outerCircle.radiusX = spotDiameterPix/2;
            outerCircle.radiusY = spotDiameterPix/2;
            outerCircle.position = [canvasSize(1)/2,  canvasSize(2)/2];
            p.addStimulus(outerCircle);
            
            function i = onDuringStim(state)
                i = obj.backgroundIntensity;
                if state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3
                    i = obj.intensity;
                end
            end
            
            outerVisible = stage.builtin.controllers.PropertyController(outerCircle, 'color', @(state)onDuringStim(state));
            p.addController(outerVisible);
            
            spotDiameterPix = obj.um2pix(obj.curInnerDiameter);
            
            innerCircle = stage.builtin.stimuli.Ellipse();
            innerCircle.radiusX = spotDiameterPix/2;
            innerCircle.radiusY = spotDiameterPix/2;
            innerCircle.color = obj.backgroundIntensity;
            innerCircle.position = [canvasSize(1)/2,  canvasSize(2)/2];
            p.addStimulus(innerCircle);
            
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj, epoch);
            
            index = mod(obj.numEpochsPrepared, obj.nSteps);
            if index == 0
                obj.innerDiameterVector = obj.innerDiameterVector(randperm(obj.nSteps));
                obj.log.info(['Permuted diameter vecor ' num2str(obj.innerDiameterVector)]);
            end
            
            obj.curInnerDiameter = obj.innerDiameterVector(index + 1);
            obj.curOuterDiameter = obj.getOuterDiameter(obj.curInnerDiameter);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addParameter('curInnerDiameter', obj.curInnerDiameter);
            epoch.addParameter('curOuterDiameter', obj.curOuterDiameter);
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
        function diameter = getOuterDiameter(obj, d)
            
            if strcmp(obj.keepConstant, 'area');
                diameter = round(2 * sqrt((obj.initArea/pi) + (d./ 2) ^2));
            else
                diameter = d + obj.initThick * 2;
            end
        end
        
        function d = get.maxOuterDiam(obj)
            d = obj.getOuterDiameter(obj.maxInnerDiam);
        end
                
        function a = get.initArea(obj)
            a = pi*((obj.minOuterDiam/2) ^2 - (obj.minInnerDiam/2) ^2);
        end
        
        function initThick = get.initThick(obj)
            initThick = (obj.minOuterDiam - obj.minInnerDiam)/2;
        end
        
    end
end

