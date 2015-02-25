%zinput v1.7
%
%zinput: a ginput replacement
%
%usage #1: [x y] = zinput (crosshairtype,prop,val,...);
%usage #2: [x y] = zinput (prop,val,...);  
%usage #3: [x y clicktype] = ...
%
%return values:
%
%the x and y coordinates of where the mouse click was detected
%optionally, as the last return value, the 'selectiontype' returned by the click ({normal} | extend | alt | open)
%
%arguments:
%
%'type' or 'style' can be one of 'circle', 'square', 'axes', 'horizontal',
%'vertical', 'crosshair', and specifies the type of the crosshair. Default
%is 'axes'
%
%'colour' or 'color' can be any standard colour argument accepted by MATLAB,
%e.g. 'r' for red. See the MATLAB documentation for further information
%about the possible values. Default is 'r'.
%
%'radius' (double) specifies the radius of the 'circle' style
%crosshair, the distance of the sides of the 'square' style crosshair from
%the centre point (half the side of the side), and the size of the
%'crosshair' style crosshair in terms of the distance from its farthest
%point to the centre point. All values are in pixels. Has no effect for
%other crosshair styles. Default is 5.0.
%
%'circledetail' (positive integer) specifies show smooth the drawn circles
%will look like: these values will be scaled by the radius, displaced by the
%center coordinates, and connected, in order to draw a circle. Larger
%values may result in slower updating speed. Default is 30.
%
%If the x and y axes have different scales, drawing circles becomes more complicated.
%In that case, 
%- if only 'radius' is specified, the relative lengths of the two axes of the
%  drawn ellipse will be the same as the ratio of the two axes of the current
%  figure, with 'radius' corresponding to the half-minor axes of the ellipse
%  (producing something visually resembling a circle)
%- if both 'xradius' and 'yradius' are specified, these will determine the
%  half-axis lengths of the ellipse in the x and y direction, respectively
%- if only one of 'xradius' and 'yradius' is specified, the other will be
%  scaled up or down from the specified value according to the relative
%  scale of the x and the y axes of the current figure
%  (producing something visually resembling a circle)

function [wherex wherey varargout] = zinput(varargin) %crosshairtype, crosshairradius, circledetail, hobj, eventdata
    
    crosshairvertical = NaN; %through the cursor
    crosshairhorizontal = NaN; %through the cursor
    crosshairpoint = NaN;
    crosshairtop = NaN; %top of the cursor
    crosshairbottom = NaN; %bottom of the cursor
    crosshairleft = NaN; %left of the cursor
    crosshairright = NaN; %right of the cursor
    crosshairlefttoright = NaN; %through the cursor
    crosshairtoptobottom = NaN; %through the cursor
    
    pressedposition = NaN;
    pressedtype = NaN;
    
    %parsing input arguments
    inputindex=1;
    while (inputindex<=numel(varargin))
        if strcmpi(varargin{inputindex}, 'type') || strcmpi(varargin{inputindex}, 'style')
            crosshairtype = varargin{inputindex+1};
            inputindex=inputindex+2;
        elseif strcmpi(varargin{inputindex}, 'radius')
            crosshairradius = varargin{inputindex+1};
            inputindex=inputindex+2;
        elseif strcmpi(varargin{inputindex}, 'xradius')
            xradius = varargin{inputindex+1};
            inputindex=inputindex+2;
        elseif strcmpi(varargin{inputindex}, 'yradius')
            yradius = varargin{inputindex+1};
            inputindex=inputindex+2;
        elseif strcmpi(varargin{inputindex}, 'colour')|| strcmpi(varargin{inputindex}, 'color') || strcmpi(varargin{inputindex}, 'c')
            crosshaircolour = varargin{inputindex+1};
            inputindex=inputindex+2;
        elseif strcmpi(varargin{inputindex}, 'circledetail')  || strcmpi(varargin{inputindex}, 'circle detail')
            circledetail = varargin{inputindex+1};
            inputindex=inputindex+2;
        elseif strcmpi(varargin{inputindex}, 'keeplimits') || strcmpi(varargin{inputindex}, 'keep limits')
            keeplimits = varargin{inputindex+1};
            inputindex=inputindex+2;
        elseif inputindex == 1
            crosshairtype=varargin{inputindex}; %in case the specified crosshair style is invalid, it will be detected when deciding what motionfcn to set, and it will fall back to the default value
            inputindex = inputindex+1;
        else
            fprintf(2, 'Warning: zinput does not understand argument %s . Ignoring it and continuing.\n', varargin{inputindex});
            inputindex=inputindex+1;
        end
    end

    %Setting default/fallback values in case some optional arguments were
    %not specified
    if exist('crosshairtype', 'var') ~= 1
        crosshairtype = 'axes';
    end
    if exist('crosshairradius', 'var') ~= 1
        crosshairradius = 5.0;
    end
    if exist('xradius', 'var') ~= 1
        xradius = NaN;
    end
    if exist('yradius', 'var') ~= 1
        yradius = NaN;
    end
    if exist('circledetail', 'var') ~= 1
        circledetail = 30;
    end
    if exist('crosshaircolour', 'var') ~= 1
        crosshaircolour = 'r';
    end
    if exist('keeplimits', 'var') ~= 1
        keeplimits = true;
    end
    
    circlepointsx=cos((0:circledetail)*2*pi/circledetail);
    circlepointsy=sin((0:circledetail)*2*pi/circledetail);
    crosshaircircle = NaN(circledetail,1);
    
    if keeplimits
        originalxlimits = get(gca, 'XLim');
        originalylimits = get(gca, 'YLim');
    end

    if strcmpi(crosshairtype, 'circle') == 1
        set(gcf,'windowbuttonmotionfcn',@drawcirclecrosshair);
    elseif strcmpi(crosshairtype, 'square') == 1
        set(gcf,'windowbuttonmotionfcn',@drawsquarecrosshair);
    elseif strcmpi(crosshairtype, 'vertical') == 1
        set(gcf,'windowbuttonmotionfcn',@drawverticalcrosshair);
    elseif strcmpi(crosshairtype, 'horizontal') == 1
        set(gcf,'windowbuttonmotionfcn',@drawhorizontalcrosshair);
    elseif strcmpi(crosshairtype, 'crosshair') == 1
        set(gcf,'windowbuttonmotionfcn',@drawcrosshaircrosshair);
    else %'axes' is the default
        set(gcf,'windowbuttonmotionfcn',@drawaxescrosshair); %this default is needed in case the specified crosshair style is invalid
    end
    
    %main loop: redraw crosshair as often as possible until a click is detected
    while numel(pressedposition) == 1 && isnan(pressedposition) %as soon as it is updated, exit the loop
        if keeplimits
            set(gca, 'XLim', originalxlimits);
            set(gca, 'YLim', originalylimits);
        end
        drawnow;
        if (numel(pressedposition) == 1 && isnan(pressedposition)) %ensuring that in the unlikely case that the button is pressed while drawnow is taking place (instead of during uiwait), and so uiresume had been triggered without being in a uiwait, uiwait will not be started (as there will be no corresponding uiresume for it as the crosshair had already been deleted)
            uiwait;
        end
    end
    wherex = pressedposition(1);
    wherey = pressedposition(2);
    varargout(1) =  {pressedtype};

    function drawverticalcrosshair (hobj, eventdata) %#ok<INUSD>
        cursorlocation = get(gca,'currentpoint');
        ylimits = get(gca, 'YLim'); %YLimits could in principle change while looking for the position to click so it makes sense to update it every time
        if ~ishandle(crosshairvertical)
            crosshairvertical = line([cursorlocation(1,1) cursorlocation(1,1)], ylimits);
            set(crosshairvertical, 'Color', crosshaircolour);
            set(crosshairvertical, 'ButtonDownFcn', @pressedcrosshair);
        else
            set(crosshairvertical, 'XData', [cursorlocation(1,1) cursorlocation(1,1)], 'YData', ylimits);
        end
        uiresume(gcf);
    end

    function drawhorizontalcrosshair (hobj, eventdata) %#ok<INUSD>
        cursorlocation = get(gca,'currentpoint');
        xlimits = get(gca, 'XLim'); %XLimits could in principle change while looking for the position to click so it makes sense to update it every time
        if ~ishandle(crosshairhorizontal)
            crosshairhorizontal = line(xlimits, [cursorlocation(1,2) cursorlocation(1,2)]);
            set(crosshairhorizontal, 'Color', crosshaircolour);
            set(crosshairhorizontal, 'ButtonDownFcn', @pressedcrosshair);
        else
            set(crosshairhorizontal, 'XData', xlimits, 'YData', [cursorlocation(1,2) cursorlocation(1,2)]);
        end
        uiresume(gcf);
    end

    function drawaxescrosshair (hobj, eventdata) %#ok<INUSD>
        cursorlocation = get(gca,'currentpoint');
        xlimits = get(gca, 'XLim'); %XLimits could in principle change while looking for the position to click so it makes sense to update it every time
        ylimits = get(gca, 'YLim'); %YLimits could in principle change while looking for the position to click so it makes sense to update it every time
        if ~ishandle(crosshairvertical)
            crosshairvertical = line([cursorlocation(1,1) cursorlocation(1,1)], ylimits);
            set(crosshairvertical, 'Color', crosshaircolour);
            set(crosshairvertical, 'ButtonDownFcn', @pressedcrosshair);
        else
            set(crosshairvertical, 'XData', [cursorlocation(1,1) cursorlocation(1,1)], 'YData', ylimits);
        end
        if ~ishandle(crosshairhorizontal)
            crosshairhorizontal = line(xlimits, [cursorlocation(1,2) cursorlocation(1,2)]);
            set(crosshairhorizontal, 'Color', crosshaircolour);
            set(crosshairhorizontal, 'ButtonDownFcn', @pressedcrosshair);
        else
            set(crosshairhorizontal, 'XData', xlimits, 'YData', [cursorlocation(1,2) cursorlocation(1,2)]);
        end
        uiresume(gcf);
    end

    function drawcrosshaircrosshair (hobj, eventdata) %#ok<INUSD>
        cursorlocation = get(gca,'currentpoint');
        if ~ishandle(crosshairtoptobottom)
            crosshairtoptobottom = line([cursorlocation(1,1) cursorlocation(1,1)], [cursorlocation(1,2)-crosshairradius cursorlocation(1,2)+crosshairradius]);
            set(crosshairtoptobottom, 'Color', crosshaircolour);
            set(crosshairtoptobottom, 'ButtonDownFcn', @pressedcrosshair);
        else
            set(crosshairtoptobottom, 'XData', [cursorlocation(1,1) cursorlocation(1,1)], 'YData', [cursorlocation(1,2)-crosshairradius cursorlocation(1,2)+crosshairradius]);
        end
        if ~ishandle(crosshairlefttoright)
            crosshairlefttoright = line([cursorlocation(1,1)-crosshairradius cursorlocation(1,1)+crosshairradius], [cursorlocation(1,2) cursorlocation(1,2)]);
            set(crosshairlefttoright, 'Color', crosshaircolour);
            set(crosshairlefttoright, 'ButtonDownFcn', @pressedcrosshair);
        else
            set(crosshairlefttoright, 'XData', [cursorlocation(1,1)-crosshairradius cursorlocation(1,1)+crosshairradius], 'YData', [cursorlocation(1,2) cursorlocation(1,2)]);
        end
        uiresume(gcf);
    end

    function drawsquarecrosshair (hobj, eventdata) %#ok<INUSD>
        cursorlocation = get(gca,'currentpoint');
        if ~ishandle(crosshairpoint)
            crosshairpoint = line([cursorlocation(1,1) cursorlocation(1,1)],[cursorlocation(1,2) cursorlocation(1,2)]);
            set(crosshairpoint, 'Color', crosshaircolour);
            set(crosshairpoint, 'ButtonDownFcn', @pressedcrosshair);
            crosshairleft = line([cursorlocation(1,1)-crosshairradius cursorlocation(1,1)-crosshairradius], [cursorlocation(1,2)-crosshairradius cursorlocation(1,2)+crosshairradius]);
            set(crosshairleft, 'Color', crosshaircolour);
            set(crosshairleft, 'ButtonDownFcn', @pressedcrosshair);
            crosshairright = line([cursorlocation(1,1)+crosshairradius cursorlocation(1,1)+crosshairradius], [cursorlocation(1,2)-crosshairradius cursorlocation(1,2)+crosshairradius]);
            set(crosshairright, 'Color', crosshaircolour);
            set(crosshairright, 'ButtonDownFcn', @pressedcrosshair);
            crosshairtop = line([cursorlocation(1,1)-crosshairradius cursorlocation(1,1)+crosshairradius], [cursorlocation(1,2)-crosshairradius cursorlocation(1,2)-crosshairradius]);
            set(crosshairtop, 'Color', crosshaircolour);
            set(crosshairtop, 'ButtonDownFcn', @pressedcrosshair);
            crosshairbottom = line([cursorlocation(1,1)-crosshairradius cursorlocation(1,1)+crosshairradius], [cursorlocation(1,2)+crosshairradius cursorlocation(1,2)+crosshairradius]);
            set(crosshairbottom, 'Color', crosshaircolour);
            set(crosshairbottom, 'ButtonDownFcn', @pressedcrosshair);
        else
            set(crosshairpoint, 'XData', [cursorlocation(1,1) cursorlocation(1,1)], 'YData', [cursorlocation(1,2) cursorlocation(1,2)]);
            set(crosshairleft, 'XData', [cursorlocation(1,1)-crosshairradius cursorlocation(1,1)-crosshairradius], 'YData', [cursorlocation(1,2)-crosshairradius cursorlocation(1,2)+crosshairradius]);
            set(crosshairright, 'XData', [cursorlocation(1,1)+crosshairradius cursorlocation(1,1)+crosshairradius], 'YData', [cursorlocation(1,2)-crosshairradius cursorlocation(1,2)+crosshairradius]);
            set(crosshairtop, 'XData', [cursorlocation(1,1)-crosshairradius cursorlocation(1,1)+crosshairradius], 'YData', [cursorlocation(1,2)-crosshairradius cursorlocation(1,2)-crosshairradius]);
            set(crosshairbottom, 'XData', [cursorlocation(1,1)-crosshairradius cursorlocation(1,1)+crosshairradius], 'YData', [cursorlocation(1,2)+crosshairradius cursorlocation(1,2)+crosshairradius]);
        end
        uiresume(gcf);
    end

    function drawcirclecrosshair (hobj, eventdata) %#ok<INUSD>
        cursorlocation = get(gca,'currentpoint');
        ylimits = get(gca, 'YLim'); %YLimits could in principle change while looking for the position to click so it makes sense to update it every time
        xlimits = get(gca, 'XLim'); %XLimits could in principle change while looking for the position to click so it makes sense to update it every time
        xinterval = max(xlimits) - min(xlimits);
        yinterval = max(ylimits) - min(ylimits);
        if isnan(xradius) && isnan(yradius)
            xscaleratio = xinterval/min([xinterval, yinterval]);
            yscaleratio = yinterval/min([xinterval, yinterval]);
        elseif ~isnan(xradius) && ~isnan(yradius)
            crosshairradius = 1;
            xscaleratio = xradius;
            yscaleratio = yradius;
        elseif ~isnan(xradius) && isnan(yradius)
            crosshairradius = 1;
            xscaleratio = xradius;
            yscaleratio = xradius*yinterval/xinterval;
        elseif isnan(xradius) && ~isnan(yradius)
            crosshairradius = 1;
            yscaleratio = yradius;
            xscaleratio = yradius*xinterval/yinterval;
        end
        if ~ishandle(crosshaircircle(1))
            for i=1:circledetail
                if i < circledetail
                    nexti = i+1;
                else
                    nexti = 1;
                end
                crosshaircircle(i) = line([cursorlocation(1,1)+circlepointsx(i)*crosshairradius*xscaleratio cursorlocation(1,1)+circlepointsx(nexti)*crosshairradius*xscaleratio], [cursorlocation(1,2)+circlepointsy(i)*crosshairradius*yscaleratio cursorlocation(1,2)+circlepointsy(nexti)*crosshairradius*yscaleratio]);
                set(crosshaircircle(i), 'Color', crosshaircolour);
                set(crosshaircircle(i), 'ButtonDownFcn', @pressedcrosshair);
            end
            crosshairpoint = line([cursorlocation(1,1) cursorlocation(1,1)],[cursorlocation(1,2) cursorlocation(1,2)]);
            set(crosshairpoint, 'Color', crosshaircolour);
            set(crosshairpoint, 'ButtonDownFcn', @pressedcrosshair);
        else
            for i=1:circledetail
                if i < circledetail
                    nexti = i+1;
                else
                    nexti = 1;
                end
                set(crosshaircircle(i), 'XData', [cursorlocation(1,1)+circlepointsx(i)*crosshairradius*xscaleratio cursorlocation(1,1)+circlepointsx(nexti)*crosshairradius*xscaleratio], 'YData', [cursorlocation(1,2)+circlepointsy(i)*crosshairradius*yscaleratio cursorlocation(1,2)+circlepointsy(nexti)*crosshairradius*yscaleratio]);
            end
            set(crosshairpoint, 'XData', [cursorlocation(1,1) cursorlocation(1,1)], 'YData', [cursorlocation(1,2) cursorlocation(1,2)]);
        end
        uiresume(gcf);
    end

    function pressedcrosshair (hobj, eventdata) %#ok<INUSD>
        set(gcf, 'windowbuttonmotionfcn', '');
        if ishandle(crosshairvertical)
            delete(crosshairvertical);
        end
        if ishandle(crosshairhorizontal)
            delete(crosshairhorizontal);
        end
        if ishandle(crosshairpoint)
            delete(crosshairpoint);
        end
        if ishandle(crosshairleft)
            delete(crosshairleft);
        end
        if ishandle(crosshairright)
            delete(crosshairright);
        end
        if ishandle(crosshairtop)
            delete(crosshairtop);
        end
        if ishandle(crosshairbottom)
            delete(crosshairbottom);
        end
        if ishandle(crosshairlefttoright)
            delete(crosshairlefttoright);
        end
        if ishandle(crosshairtoptobottom)
            delete(crosshairtoptobottom);
        end
        for i=1:circledetail
            if ishandle(crosshaircircle(i))
                delete(crosshaircircle(i));
            end
        end
        pressedposition = get(gca, 'currentpoint');
        pressedposition = [pressedposition(1,1) pressedposition(1,2)];
        pressedtype = get(gcf, 'selectiontype');
        uiresume(gcf);
    end

end