classdef (Abstract) AlaLaurilaStageProtocol < fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol
    
    methods (Abstract)
        p = createPresentation(obj);
    end
    
    methods
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj, epoch);
            %epoch.shouldWaitForTrigger = true;
        end
        
        function controllerDidStartHardware(obj)
            controllerDidStartHardware@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj);
            obj.rig.getDevice('Stage').play(obj.createPresentation(), obj.preTime);
        end
        
        function tf = shouldContinuePreloadingEpochs(obj) %#ok<MANU>
            tf = false;
        end
        
        function tf = shouldWaitToContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared > obj.numEpochsCompleted || obj.numIntervalsPrepared > obj.numIntervalsCompleted;
        end
        
        function completeRun(obj)
            completeRun@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj);
            obj.rig.getDevice('Stage').clearMemory();
        end
        
        function [tf, msg] = isValid(obj)
            [tf, msg] = isValid@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj);
            if tf
                tf = ~isempty(obj.rig.getDevices('Stage'));
                msg = 'No stage';
            end
        end
        
    end
    
    methods (Access = protected)
        
        function p = um2pix(obj, um)
            stages = obj.rig.getDevices('Stage');
            if isempty(stages)
                micronsPerPixel = 1;
            else
                micronsPerPixel = stages{1}.getConfigurationSetting('micronsPerPixel');
            end
            p = round(um / micronsPerPixel);
        end
        
    end
    
end

