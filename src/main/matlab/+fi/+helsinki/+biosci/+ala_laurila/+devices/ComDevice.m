classdef ComDevice < handle
    
    properties(Access = private)
        com
    end
    
    methods
        
        function obj = ComDevice(port, baudRate, dataBits, stopBits, terminator)

            obj.com = serial(port,...
                'BaudRate', baudRate,...
                'DataBits', dataBits,...
                'StopBits', stopBits,...
                'Terminator', terminator);
        end
        
        function send(obj, cmd, delay)
            try
                fopen(obj.com);
                fprintf(obj.com, cmd);
                
                if nargin == 3
                    pause(delay);
                end
                fclose(obj.com);
            catch
                disp('send error to com');
            end
        end
        
        function str = query(obj, cmd, delay)
            str = [];           
            try
                fopen(obj.com);
                fprintf(obj.com, cmd);
                
                if nargin == 2
                    pause(delay);
                end
                
                while (get(obj.com, 'BytesAvailable')~=0)
                    txt = fscanf(obj.com, '%s');
                    if txt == '>'
                        break;
                    end
                    str = txt;
                end
                fclose(obj.com);
            catch
                disp('read error from com');
            end
        end
        
        function delete(obj)
            if ~ isempty(obj.com)
                delete(obj.com);
            end
        end
    end
end

