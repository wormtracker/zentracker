function zentracker

    version = '2.15';
    
    %"CONSTANTS" used for specifying which parameter we're looking at
    CONST_DISPLAY_SPEED = 1;
    CONST_DISPLAY_X = 2;
    CONST_DISPLAY_Y = 3;
    CONST_DISPLAY_LENGTH = 4;
    CONST_DISPLAY_WIDTH = 5;
    CONST_DISPLAY_AREA = 6;
    CONST_DISPLAY_PERIMETER = 7;
    CONST_DISPLAY_ECCENTRICITY = 8;
    CONST_DISPLAY_SOLIDITY = 9;
    CONST_DISPLAY_ORIENTATION = 10;
    CONST_DISPLAY_COMPACTNESS = 11;
    CONST_DISPLAY_DIRECTIONCHANGE = 12;
    CONST_DISPLAY_REVERSAL = 13;
    CONST_DISPLAY_OMEGA = 14;
    CONST_DISPLAY_LEAVING = 15;
    CONST_DISPLAY_RETURNING = 16;
    CONST_DISPLAY_NNUMBER = 17;
    
    CONST_AREA_EVERYWHERE = 1;
    CONST_AREA_RECTANGLE = 2;
    CONST_AREA_SQUARE = 3;
    CONST_AREA_CIRCLE = 4;
    CONST_AREA_POLYGON = 5;
    
    %These are for manual reversal detection
    CONST_BUTTON_NONE = 0;
    CONST_BUTTON_HEAD = -1;
    CONST_BUTTON_INVALID = -2;
    CONST_BUTTON_ABORT = -3;
    
    CONST_BEHAVIOUR_UNKNOWN = 0;
    CONST_BEHAVIOUR_FORWARDS = 1;
    CONST_BEHAVIOUR_REVERSAL = 2;
    CONST_BEHAVIOUR_OMEGA = 3; %frames where the worm is actually executing the omega turn
    CONST_BEHAVIOUR_INVALID = 4;
    
    CONST_TARGET_NOMANSLAND = 0;
    CONST_TARGET_STARTINGAREA = 1;
    CONST_TARGET_ENDINGAREA = 2;
    CONST_TARGET_INVALID = 4;
    
    set(0,'DefaultAxesLineStyleOrder',{'-',':','--','-.'}); %When plotting results, cycle through different line styles in addition to the different colours so that there is more combinations possible
    
    circlepointsx=cos((0:30)*2*pi/30); %30 = how smooth the drawn circles will be. these values will be scaled by the radius, displaced by the center coordinates, and connected with a plot to draw a circle
    circlepointsy=sin((0:30)*2*pi/30);
    
%    thresholdingfilter = daubcqf(4); %fspecial('gaussian',[15,15],2);
    disklike = strel('disk', 1, 4); %structuring element used for erosion and dilation ([0 1 0; 1 1 1; 0 1 0])
    
    moviecache = struct('data', []);
    cachedframe = [];
    cachedindex = NaN;
    
    gradnormmatrix = [];
    gradnorm = false;
    timenorm = false;
    darkfield = false;
    
    files = '';
    directory = pwd; %default directory is the current directory
    selectedfiles = [];
    readerfailuredisplayed = [];
    
    savefilesuffix = '-ztdata.mat';
    savefilesuffixprevious = '-analysisdata.mat'; %for backwards compatibility
    
    %This is for light flash detection (which indicates when the stimuli occurs), which is disabled in this version
    flashed = []; 
    flashindices = [];
    flashx = NaN;
    flashy = NaN;
    
    objects.duration = []; %duration is in frames the amount of time the object exists
    objects = [];%struct('frame', [], 'time', [], 'x', [], 'y', [], 'length', [], 'width', [], 'area', [], 'perimeter', [], 'eccentricity', [], 'speed', [], 'directionchange', [], 'behaviour', []);
    
    lastframe = NaN;
    lasttime = NaN;
    framerate = NaN;
    scalingfactor = 1;
    movingaverage = 0;
    speedsmoothing = 1;
    longest = 0;
    
    moviewidth = 0; %in pixels
    movieheight = 0; %in pixels
    %meshes area used for quickly calculating the distances from all points in a matrix to a specific point
    meshx = [];
    meshy = [];
    
    detectionarea = []; %logical matrix representing locations at which pixels can be thresholded
    measurementarea = []; %logical matrix representing centroid locations at which pixels can be considered valid
    startingarea = []; %logical matrix representing a starting area with respect to which we can quantify e.g. leaving
    endingarea = []; %logical matrix representing an ending area with respect to which we can quantify e.g. leaving
    
    validspeedmin = 0; %um/s
    validspeedmax = 0; %um/s
    validlengthmin = 0; %um
    validlengthmax = 0; %um
    validwidthmin = 0; %um
    validwidthmax = 0; %um
    validareamin = 30000; %um^2
    validareamax = 120000; %um^2
    validperimetermin = 0; %um
    validperimetermax = 2800; %um
    valideccentricitymin = 0;
    valideccentricitymax = 0;
    
    detectomegas = true;
    omegadurationmin = 1; %s. Minimum omega turn duration
    omegadurationmindefault = omegadurationmin;
    omegadisplacementmax = 50; %um. Maximum centroid displacement between the first and the last frame of an omega-turn that can still be accepted as an omega
    omegatolerance = 1; %s. Maximum duration of valid non-omega interval between two omega-flagged timepoints that could still be considered part of the same omega turn
    omegatolerancedefault = omegatolerance;
    omegaeccentricity = 0.80; %worms with an eccentricity value below this will be considered to be doing an omega-turn
    omegacompactness = 30; %worms with a compactness value (perimeter^2/area) below this will be considered to be doing an omega turn
    omegasoliditymin = 0.575; %worms with a solidity lower than this will not be considered doing an omega
    
    revdisplacementwindow = 1; %s. Coordinate-displacements will be calculated between the current coordinates and the coordinates this much time ago
    revdisplacementwindowdefault = revdisplacementwindow;
    revangle = 60; %degrees. The critical angle-difference which is still considered moving in the same direction
    revdistance = 60; %um. The critical distance the worm has to travel between frames i and i for it not to be considered dwelling there for the purposes of reversal detection
    revdurationmax = 7.5; %s. Maximum duration of a reversal in frames
    revdurationmaxdefault = revdurationmax;
    revextrapolate = 1; %s. Maximum successive duration for which the direction can be extrapolated based on the direction in the previous timepoint, if known
    revextrapolatedefault = revextrapolate;
    revdisplayduration = 15; %s . Minimum movie interval to try to show (if available) during manual direction recognition
    movieFPS = 10; %FPS of the "movie" displayed during manual reversal detection
    moviemaxduration = 2; %s. How long the "movie" displayed during manual reversal detection can last at most
    
    wormshowframe = NaN;
    
    moviefiles = {};
    movieindicator = NaN;
    frameindicator = NaN;
    
    timefrom = NaN;
    timeuntil = NaN;
    
    wormid = NaN;
    allobjects = true;
    
    identitydisplay = true;
    detectionareadisplay = true;
    thresholdeddisplay = true;
    measurementareadisplay = true;
    targetareadisplay = true;
    
    averagedisplay = true;
    
    meanperimeter = NaN; %used for scaling the floating texts that show the identities of the worms; also used in omega-detection
    maximumtextsize = 14;
    averagetextsize = 11;
    minimumtextsize = 9;
    
    pixelmax = 255; %the maximum intensity value of a pixel. defaults to that of an 8-bit image, but will be queried and updated (if possible) when loading a new movie
    
    detectionradius = 200; %radius when specifying which areas should be thresholdable (this is the size of the "paintbrush"; this value is NOT involved in the actual thresholding - only in setting up the area that can be thresholded)
    thresholdsizemin = 20000; %um^2 . Contiguous above-threshold areas smaller than this should not be classified as objects
    thresholdsizemax = Inf; %um^2 . Contiguous above-threshold areas larger than this should not be classified as objects
    thresholdspeedmax = 600; %um/s
    thresholdintensity = 100; %pixel intensity value
    
    measurementradius = 200; %um . Radius when specifying which areas should be valid (this is the size of the "paintbrush"; this value is NOT involved in the actual validity checking - only in setting up the area where objects can be considered valid)
    
    validdurationminimum = 5; %s
    
    trytoloadfps = true;
    checknf = true;
    cachemovie = false;
    %exportdisplay = false;
    
    moviereaderobjects = struct([]);
    qtreaders = struct([]);
    tiffservers = struct([]);
    bfreaders = struct([]);
    avireadworks = false;
    qtserveravailable = false;
    tiffserveravailable = false;
    
    waitbarfps = 20;

    saveversion = [];
    
    oldwarningstate = [];
    
    advancedvalidityfigure = []; %this figure handle is global so that we can delete the figure when loading analysis data
    advancedrevfigure = []; %this figure handle is global so that we can delete the figure when loading analysis data
    advancedomegafigure = []; %this figure handle is global so that we can delete the figure when loading analysis data
    
    %Also for manual detection
    whichbuttonpressed = 0; %this needs to be greater in scope than any subfunction because I want to choose how to proceed in a subfunction using uicontrol pushbuttons with a callback for (setting whichbuttonpressed and doing uiresume), and whichbuttonpressed would be local to the callback otherwise
    
    handles.fig = figure('Name',['Zen Tracker version ' version],'NumberTitle','off', ...
        'Visible','on','Color',get(0,'defaultUicontrolBackgroundColor'), 'Units','Normalized',...
        'DefaultUicontrolUnits','Normalized', 'DeleteFcn', @savesettings);
    
    %%%%%
    handles.datapanel = uipanel(handles.fig,'Title','File selection','Units','Normalized',...
        'DefaultUicontrolUnits','Normalized','Position',[0.00 0.00 0.20 1.00]);
    handles.folder = uicontrol(handles.datapanel,'Style','Edit','String',directory,'HorizontalAlignment','left','BackgroundColor','w','Position',[0.00 0.95 0.7 0.05],'Callback',@updatefilelist);
    handles.browse = uicontrol(handles.datapanel,'Style','Pushbutton','String','Browse','Position',[0.85 0.95 0.15 0.05],'Callback',@browse);
    handles.files = uicontrol(handles.datapanel,'Style','Listbox','String',files, 'BackgroundColor','w', 'Position',[0.00 0.15 1.00 0.80],'Max',intmax('uint32'),'Callback',@selectfile);
    handles.updatefiles = uicontrol(handles.datapanel, 'Style','Pushbutton','String','Refresh','Position',[0.70 0.95 0.15 0.05],'Callback',@updatefilelist);

    handles.read = uicontrol(handles.datapanel,'Style','Pushbutton','String','Read movie','Position',[0.00 0.083 0.60 0.067],'Callback',@readmovie);
    handles.exportastxt = uicontrol(handles.datapanel,'Style','Pushbutton','String','Export as txt','Position',[0.00 0.050 0.60 0.033],'Callback',@exportastxt);
    handles.trytoloadfps = uicontrol(handles.datapanel,'Style','Checkbox','String','Autoload FPS if possible','Position',[0.60 0.1166 0.40 0.0333],'Value', trytoloadfps, 'Callback', {@setvalue, 'logical', 'setglobal', 'trytoloadfps'});
    handles.checknf = uicontrol(handles.datapanel,'Style','Checkbox','String','Confirm duration', 'Position',[0.60 0.0833 0.40 0.0333],'Value', checknf, 'Callback', {@setvalue, 'logical', 'setglobal', 'checknf'});
    handles.cachemovie = uicontrol(handles.datapanel,'Style','Checkbox','String','Cache movie', 'Position',[0.60 0.05 0.40 0.0333],'Value', cachemovie, 'Callback', {@setvalue, 'logical', 'setglobal', 'cachemovie'});
    handles.loadanalysis = uicontrol(handles.datapanel, 'Style','Pushbutton','String','Load analysis','Position',[0.00 0.00 0.50 0.05],'Callback',@loadanalysis);
    handles.saveanalysis = uicontrol(handles.datapanel, 'Style','Pushbutton','String','Save analysis','Position',[0.50 0.00 0.50 0.05],'Callback',@saveanalysis);

    
    %%%%%
    handles.displaypanel = uipanel(handles.fig,'Title','Display','Units','Normalized',...
        'DefaultUicontrolUnits','Normalized','Position',[0.20 0.00 0.60 1.00]);
    handles.img = axes('Parent',handles.displaypanel,'Visible','on','Position',[0.10 0.20 0.80 0.70]);
    
    %%%%%
    handles.scalepanel = uipanel(handles.fig,'Title','Scale setup','Units','Normalized',...
        'DefaultUicontrolUnits','Normalized','Position',[0.80 0.90 0.10 0.10]);
    
    handles.scalingfactortext = uicontrol(handles.scalepanel, 'Style', 'Text', 'String', 'Scaling factor', 'Position', [0.00 0.65 0.50 0.30]);
    handles.scalingfactor = uicontrol(handles.scalepanel, 'Style', 'Edit', 'String', num2str(scalingfactor), 'Position', [0.05 0.05 0.40 0.65], 'Callback', {@setvalue, 'min', realmin, 'default', 1, 'setglobal', 'scalingfactor', 'showit'});
    handles.setscaling = uicontrol(handles.scalepanel, 'Style', 'Pushbutton', 'String', 'Set scale', 'Position', [0.50 0.05 0.50 0.90], 'Callback', @setscaling);
    
    %%%%%
    handles.detectionpanel = uipanel(handles.fig,'Title','Detection','Units','Normalized',...
        'DefaultUicontrolUnits','Normalized','Position',[0.80 0.55 0.10 0.35]);
    
    handles.detectionwhat = uicontrol(handles.detectionpanel, 'Style','Popupmenu', 'String', {'Add to detection area', 'Remove from detection area'}, 'Position', [0.05 0.90 0.90 0.10], 'Value', 1);
    handles.detectionwhere = uicontrol(handles.detectionpanel, 'Style','Popupmenu', 'String', {'Everywhere', 'Rectangle', 'Square', 'Circle', 'Polygon'}, 'Position', [0.05 0.80 0.90 0.10], 'Value', 5);
    handles.detectionradiustext = uicontrol(handles.detectionpanel, 'Style', 'Text', 'String', 'Radius (um)', 'Position', [0.05 0.73 0.40 0.06]);
    handles.detectionradius = uicontrol(handles.detectionpanel, 'Style', 'Edit', 'String', num2str(detectionradius), 'Position', [0.05 0.63 0.40 0.10], 'Callback', {@setvalue, 'min', 0, 'default', 10, 'setglobal', 'detectionradius'});
    handles.setdetectionarea = uicontrol(handles.detectionpanel, 'Style', 'Pushbutton', 'String', 'Mark area', 'Position', [0.50 0.63 0.50 0.17], 'Callback', {@markarea, 'threshold'});
    
    handles.thresholdsizetext = uicontrol(handles.detectionpanel, 'Style', 'Text', 'String', 'Detection size (um^2)', 'Position', [0.00 0.54 1.00 0.06]);
    handles.thresholdsizemin = uicontrol(handles.detectionpanel, 'Style', 'Edit', 'String', num2str(thresholdsizemin), 'Position', [0.05 0.44 0.40 0.10], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'setglobal', 'thresholdsizemin', 'showit'});
    handles.thresholdsizedash = uicontrol(handles.detectionpanel, 'Style', 'Text', 'String', '-', 'Position', [0.46 0.44 0.08 0.08]);
    handles.thresholdsizemax = uicontrol(handles.detectionpanel, 'Style', 'Edit', 'String', num2str(thresholdsizemax), 'Position', [0.55 0.44 0.40 0.10], 'Callback', {@setvalue, 'min', 1, 'default', Inf, 'setglobal', 'thresholdsizemax', 'showit'});
    
    handles.thresholdintensitytext = uicontrol(handles.detectionpanel, 'Style', 'Text', 'String', 'Intensity', 'Position', [0.00 0.33 0.50 0.06]);
    handles.thresholdintensity = uicontrol(handles.detectionpanel, 'Style', 'Edit', 'String', num2str(thresholdintensity), 'Position', [0.05 0.23 0.40 0.10], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'max', 'pixelmax', 'setglobal', 'thresholdintensity', 'showit'});
    handles.thresholdspeedmaxtext = uicontrol(handles.detectionpanel, 'Style', 'Text', 'String', {'Max speed', '(um/s)'}, 'Position', [0.50 0.33 0.50 0.10]);
    handles.thresholdspeedmax = uicontrol(handles.detectionpanel, 'Style', 'Edit', 'String', num2str(thresholdspeedmax), 'Position', [0.55 0.23 0.40 0.10], 'Callback', {@setvalue, 'min', 0, 'default', Inf, 'setglobal', 'thresholdspeedmax', 'showit'});
    
    handles.gradnorm = uicontrol(handles.detectionpanel, 'Style', 'Checkbox', 'String', 'Grad norm', 'Position', [0.00 0.15 0.50 0.07], 'Value', gradnorm, 'Callback', @setgradnorm);
    handles.timenorm = uicontrol(handles.detectionpanel, 'Style', 'Checkbox', 'String', 'Time norm', 'Position', [0.00 0.075 0.50 0.07], 'Value', timenorm, 'Callback', @settimenorm);
    handles.darkfield = uicontrol(handles.detectionpanel, 'Style', 'Checkbox', 'String', 'Dark field', 'Position', [0.00 0.00 0.50 0.07], 'Value', timenorm, 'Callback', @setdarkfield);
    
    handles.trackobjects = uicontrol(handles.detectionpanel, 'Style', 'Pushbutton', 'String', 'Track', 'Position', [0.50 0.00 0.50 0.20], 'Callback', @trackobjects);
    
    %%%%%
    handles.displaysettingspanel = uipanel(handles.fig,'Title','Display','Units','Normalized',...
        'DefaultUicontrolUnits','Normalized','Position',[0.80 0.40 0.10 0.15]);
    
    handles.identitydisplay = uicontrol(handles.displaysettingspanel , 'Style', 'Checkbox', 'String', 'Identities', 'Position', [0.05 0.80 0.90 0.20], 'Value', identitydisplay, 'Callback', {@setvalue, 'logical', 'setglobal', 'identitydisplay', 'showit'});
    handles.detectionareadisplay = uicontrol(handles.displaysettingspanel , 'Style', 'Checkbox', 'String', 'Detection area', 'Position', [0.05 0.60 0.90 0.20], 'Value', detectionareadisplay, 'Callback', {@setvalue, 'logical', 'setglobal', 'detectionareadisplay', 'showit'});
    handles.thresholdeddisplay = uicontrol(handles.displaysettingspanel , 'Style', 'Checkbox', 'String', 'Thresholded pixels', 'Position', [0.05 0.40 0.90 0.20], 'Value', thresholdeddisplay, 'Callback', {@setvalue, 'logical', 'setglobal', 'thresholdeddisplay', 'showit'});
    handles.measurementareadisplay = uicontrol(handles.displaysettingspanel , 'Style', 'Checkbox', 'String', 'Measurement area', 'Position', [0.05 0.20 0.90 0.20], 'Value', measurementareadisplay, 'Callback', {@setvalue, 'logical', 'setglobal', 'measurementareadisplay', 'showit'});
    handles.targetareadisplay = uicontrol(handles.displaysettingspanel , 'Style', 'Checkbox', 'String', 'Target areas', 'Position', [0.05 0.00 0.90 0.20], 'Value', targetareadisplay, 'Callback', {@setvalue, 'logical', 'setglobal', 'targetareadisplay', 'showit'});
    
    
    %%%%%
    handles.manipulatepanel = uipanel(handles.fig, 'Title','Select and manipulate','Units','Normalized',...
        'DefaultUicontrolUnits','Normalized','Position',[0.80 0.10 0.10 0.30]);
    
    handles.timefromtext = uicontrol(handles.manipulatepanel, 'Style', 'Text', 'String', 'from (s)', 'Position', [0.05 0.90 0.40 0.07]);
    handles.timeuntiltext = uicontrol(handles.manipulatepanel, 'Style', 'Text', 'String', 'until (s)', 'Position', [0.55 0.90 0.40 0.07]);
    handles.timefromset = uicontrol(handles.manipulatepanel, 'Style', 'Pushbutton', 'String', 'cur', 'Position', [0.00 0.80 0.20 0.10], 'Callback', @settimefromcurrent);
    handles.timefrom = uicontrol(handles.manipulatepanel, 'Style', 'Edit', 'String', '-', 'Position', [0.20 0.80 0.30 0.10], 'Callback', {@setvalue, 'round', 'framerate', 'min', 0, 'max', 'lasttime', 'setglobal', 'timefrom'});
    handles.timeuntil = uicontrol(handles.manipulatepanel, 'Style', 'Edit', 'String', '-', 'Position', [0.50 0.80 0.30 0.10], 'Callback', {@setvalue, 'round', 'framerate', 'min', 0, 'max', 'lasttime', 'setglobal', 'timeuntil'});
    handles.timeuntilset = uicontrol(handles.manipulatepanel, 'Style', 'Pushbutton', 'String', 'cur', 'Position', [0.80 0.80 0.20 0.10], 'Callback', @settimeuntilcurrent);
    
    handles.wormidtext = uicontrol(handles.manipulatepanel, 'Style', 'Text', 'String', 'ID', 'Position', [0.00 0.70 0.50 0.07]);
    handles.wormid = uicontrol(handles.manipulatepanel, 'Style', 'Edit', 'String', '-', 'Position', [0.05 0.60 0.40 0.10], 'Callback', {@setvalue, 'round', 1, 'min', 1, 'max', 'numel(objects)', 'setglobal', 'wormid'});
    %handles.setid = uicontrol(handles.manipulatepanel, 'Style', 'Edit', 'String', '-', 'Position', [0.55 0.45 0.40 0.10], 'Callback', @setwormid);
    handles.getobject = uicontrol(handles.manipulatepanel, 'Style', 'Pushbutton', 'String', 'Pick', 'Position', [0.50 0.60 0.50 0.15], 'Callback', @getobject);
        
    handles.allobjects = uicontrol(handles.manipulatepanel, 'Style', 'Checkbox', 'String', 'All objects', 'Position', [0.05 0.45 0.90 0.10], 'Value', allobjects, 'Callback', @setallobjects);
    
    handles.behaviour = uicontrol(handles.manipulatepanel', 'Style', 'Popupmenu', 'String', {'Unknown', 'Forwards', 'Reversal', 'Omega', 'Invalid'}, 'Value', 1, 'Position', [0.05 0.30 0.90 0.12]);
    handles.setbehaviour = uicontrol(handles.manipulatepanel', 'Style', 'Pushbutton', 'String', 'Set behaviour', 'Position', [0.05 0.15 0.90 0.15], 'Callback', @setbehaviour);
    
    handles.deleteobject = uicontrol(handles.manipulatepanel, 'Style', 'Pushbutton', 'String', 'Delete object', 'Position', [0.10 0.00 0.80 0.10], 'Callback', @deleteobject);
    
    
    %%%%%
    handles.validpanel = uipanel(handles.fig,'Title','Valid measurements','Units','Normalized',...
        'DefaultUicontrolUnits','Normalized','Position',[0.90 0.65 0.10 0.35]);
    handles.measurementwhat = uicontrol(handles.validpanel, 'Style','Popupmenu', 'String', {'Add to measurement area', 'Remove from measurement area', 'Add to starting area', 'Remove from starting area', 'Add to ending area', 'Remove from ending area'}, 'Position', [0.05 0.90 0.90 0.10], 'Value', 1);
    handles.measurementwhere = uicontrol(handles.validpanel, 'Style','Popupmenu', 'String', {'Everywhere', 'Rectangle', 'Square', 'Circle', 'Polygon'}, 'Position', [0.05 0.80 0.90 0.10], 'Value', 5);
    handles.measurementradiustext = uicontrol(handles.validpanel, 'Style', 'Text', 'String', 'Radius (um)', 'Position', [0.05 0.73 0.40 0.06]);
    handles.measurementradius = uicontrol(handles.validpanel, 'Style', 'Edit', 'String', num2str(measurementradius), 'Position', [0.05 0.63 0.40 0.10], 'Callback', {@setvalue, 'min', 0, 'default', 10, 'setglobal', 'measurementradius'});
    handles.set = uicontrol(handles.validpanel, 'Style', 'Pushbutton', 'String', 'Mark area', 'Position', [0.50 0.63 0.50 0.17], 'Callback', {@markarea, 'measurementlike'});

    handles.validadvanced = uicontrol(handles.validpanel, 'Style', 'Pushbutton', 'String', 'Advanced settings', 'Position', [0.10 0.50 0.80 0.10], 'Callback', @validityadvanced);
    handles.validcheck = uicontrol(handles.validpanel, 'Style', 'Pushbutton', 'String', '(Re)check validity!', 'Position', [0.05 0.35 0.90 0.13], 'Callback', @validitycheck);
    handles.targetcheck = uicontrol(handles.validpanel, 'Style', 'Pushbutton', 'String', '(Re)check targets', 'Position', [0.05 0.23 0.90 0.10], 'Callback', @targetcheck);
    
    handles.validdurationcheck = uicontrol(handles.validpanel, 'Style', 'Pushbutton', 'String', 'Check duration', 'Position', [0.00 0.10 0.60 0.10], 'Callback', @validdurationcheck);
    handles.validdurationcheckstyle = uicontrol(handles.validpanel, 'Style', 'Popupmenu', 'String', {'Mark as invalid', 'Delete'}, 'Position', [0.00 0.00 0.60 0.10], 'Value', 1);
    handles.validdurationminimumtext = uicontrol(handles.validpanel, 'Style', 'Text', 'String', {'Min duration', '(s)'}, 'Position', [0.60 0.10 0.40 0.10]);
    handles.validdurationminimum = uicontrol(handles.validpanel, 'Style', 'Edit', 'String', num2str(validdurationminimum), 'Position', [0.60 0.00 0.40 0.10], 'Callback', {@setvalue, 'min', 0, 'default', 1, 'setglobal', 'validdurationminimum'});
    
    %%%%%
    handles.resultspanel = uipanel(handles.fig, 'Title','Results','Units','Normalized',...
        'DefaultUicontrolUnits','Normalized','Position',[0.90 0.00 0.10 0.35]);
    
    handles.averagedisplay = uicontrol(handles.resultspanel, 'Style', 'Checkbox', 'String', 'Average across objects', 'Position', [0.05 0.90 0.90 0.10], 'Value', averagedisplay, 'Callback', {@setvalue, 'logical', 'setglobal', 'averagedisplay'});
    
    handles.movingaveragetext = uicontrol(handles.resultspanel, 'Style','Text','String','Moving average (s)', 'Position', [0.10 0.80 0.80 0.06]);
    handles.movingaverage = uicontrol(handles.resultspanel, 'Style','Edit','String','0', 'Position', [0.10 0.70 0.80 0.10], 'Callback', {@setvalue, 'min', 0, 'round', 'framerate', 'setglobal', 'movingaverage', 'default', 0});
    
    handles.longesttext = uicontrol(handles.resultspanel, 'Style','Text','String','Only longest n', 'Position', [0.10 0.60 0.80 0.06]);
    handles.longest = uicontrol(handles.resultspanel, 'Style','Edit','String','0', 'Position', [0.10 0.50 0.80 0.10], 'Callback', {@setvalue, 'min', 0, 'round', 1, 'setglobal', 'longest', 'default', 0});
    handles.speedsmoothingtext = uicontrol(handles.resultspanel, 'Style','Text','String','Speed smoothing (frames)', 'Position', [0.10 0.40 0.80 0.06]);
    handles.speedsmoothing = uicontrol(handles.resultspanel, 'Style','Edit','String',num2str(speedsmoothing), 'Position', [0.10 0.30 0.80 0.10], 'Callback', {@setvalue, 'min', 1, 'round', 1, 'setglobal', 'speedsmoothing', 'default', 1});
    
    handles.plotwhat = uicontrol(handles.resultspanel, 'Style', 'Popupmenu', 'String', {'Speed', 'X coordinates', 'Y coordinates', 'Length', 'Width', 'Area', 'Perimeter', 'Eccentricity', 'Solidity', 'Orientation', 'Compactness', 'Direction change', 'Reversals', 'Omega turns', 'Leaving', 'Returning', 'Valid N-numbers'}, 'Position', [0.05 0.15 0.90 0.10], 'Value', 1);
    handles.plotit = uicontrol(handles.resultspanel, 'Style', 'Pushbutton', 'String', 'Plot it', 'Position', [0.05 0.00 0.90 0.15], 'Callback', @plotit);
    
    %%%%%
    handles.reversalpanel = uipanel(handles.fig, 'Title','Reversal detection','Units','Normalized',...
        'DefaultUicontrolUnits','Normalized','Position',[0.90 0.35 0.10 0.30]);
    
    handles.revadvanced = uicontrol(handles.reversalpanel, 'Style', 'Pushbutton', 'String', 'Adv rev settings', 'Position', [0.10 0.90 0.80 0.10], 'Callback', @revadvanced);
    handles.omegaadvanced = uicontrol(handles.reversalpanel, 'Style', 'Pushbutton', 'String', 'Adv omg settings', 'Position', [0.10 0.80 0.80 0.10], 'Callback', @omegaadvanced);
    
    handles.detectomegas = uicontrol(handles.reversalpanel, 'Style', 'Checkbox', 'String', 'Detect omegas', 'Position', [0.10 0.70 0.80 0.10], 'Value', detectomegas, 'Callback', {@setvalue, 'logical', 'setglobal', 'detectomegas'});
    
    handles.omegaeccentricitytext = uicontrol(handles.reversalpanel, 'Style','Text','String','Omega eccentricity', 'Position', [0.00 0.60 1.00 0.08]);
    handles.omegaeccentricity = uicontrol(handles.reversalpanel, 'Style','Edit','String',num2str(omegaeccentricity), 'Position', [0.20 0.48 0.60 0.12], 'Callback', {@setvalue, 'min', 0, 'max', 1, 'setglobal', 'omegaeccentricity', 'default', omegaeccentricity});
    
    handles.revdisplaydurationtext = uicontrol(handles.reversalpanel, 'Style','Text','String','Display (s)', 'Position', [0.00 0.36 0.50 0.08]);
    handles.revdisplayduration = uicontrol(handles.reversalpanel, 'Style','Edit','String',num2str(revdisplayduration), 'Position', [0.00 0.24 0.50 0.12], 'Callback', {@setvalue, 'min', 1, 'setglobal', 'revdisplayduration', 'default', revdisplayduration});
    
    handles.revangletext = uicontrol(handles.reversalpanel, 'Style','Text','String','Angle (deg)', 'Position', [0.50 0.36 0.50 0.08]);
    handles.revangle = uicontrol(handles.reversalpanel, 'Style','Edit','String',num2str(revangle), 'Position', [0.50 0.24 0.50 0.12], 'Callback', {@setvalue, 'min', 0, 'max', 180, 'setglobal', 'revangle', 'default', revangle});
    
    handles.manualdetectreversals = uicontrol(handles.reversalpanel, 'Style', 'Pushbutton', 'String', 'Manual', 'Position', [0.00 0.00 0.50 0.20], 'Callback', @manualdetectreversals);
    handles.autodetectreversals = uicontrol(handles.reversalpanel, 'Style', 'Pushbutton', 'String', 'Auto', 'Position', [0.50 0.00 0.50 0.20], 'Callback', @autodetectreversals);

    handles.setlightarea = uicontrol(handles.fig, 'Style', 'Pushbutton', 'String', 'Area', 'Position', [0.80 0.055 0.033 0.035], 'Callback', @setflasharea, 'Enable', 'off');
    handles.detectlightflash = uicontrol(handles.fig, 'Style', 'Pushbutton', 'String', 'Detect', 'Position', [0.834 0.055 0.033 0.035], 'Callback', @detectlightflash);
    handles.spectraldensity = uicontrol(handles.fig, 'Style', 'Pushbutton', 'String', 'SpecDens', 'Position', [0.867 0.055 0.033 0.035], 'Callback', @spectraldensity);
    %handles.exportdisplay = uicontrol(handles.resultspanel, 'Style','Checkbox','String','Export displayed values','Position', [0.05 0.00 0.90 0.05], 'Value',exportdisplay);
    
    %%%
    handles.debuggingpanel = uipanel(handles.fig, 'Title','Debug','Units','Normalized',...
        'DefaultUicontrolUnits','Normalized','Position',[0.80 0.00 0.10 0.05]);
    handles.debugging = uicontrol(handles.debuggingpanel,'Style','Pushbutton','String','Debugging function','Position',[0.00 0.00 1.00 1.00],'Callback',@debuggingfunction);
    %%%
    
    if ismac %Macs suck and newer versions don't have arrows for sliders, so we have to do it ourselves
        handles.wormshowframeslider = uicontrol(handles.displaypanel,'Style','Slider',...
        'Position',[0.10 0.00 0.60 0.04], 'Callback',@setframeslider);
        handles.wormshowplusone = uicontrol(handles.displaypanel, 'Style', 'Pushbutton','String', '>',...
        'Position',[0.70 0.00 0.05 0.04], 'Callback', {@moveslider, 1});
        handles.wormshowplusone = uicontrol(handles.displaypanel, 'Style', 'Pushbutton','String', '>>',...
        'Position',[0.75 0.00 0.05 0.04], 'Callback', {@moveslider, 10});
        handles.wormshowminusone = uicontrol(handles.displaypanel, 'Style', 'Pushbutton','String', '<',...
        'Position',[0.05 0.00 0.05 0.04], 'Callback', {@moveslider, -1});
        handles.wormshowminusone = uicontrol(handles.displaypanel, 'Style', 'Pushbutton','String', '<<',...
        'Position',[0.00 0.00 0.05 0.04], 'Callback', {@moveslider, -10});
    else
        handles.wormshowframeslider = uicontrol(handles.displaypanel,'Style','Slider',...
        'Position',[0.00 0.00 0.80 0.07], 'Callback',@setframeslider);
    end
    
    handles.wormshowsettimetext = uicontrol(handles.displaypanel,'Style','Text','String','Time (s)',...
    'Position',[0.80 0.04 0.10 0.03]);
    handles.wormshowsettime = uicontrol(handles.displaypanel,'Style','Edit','Value', converttotime(wormshowframe),...
    'Position',[0.80 0.00 0.10 0.04],'Callback',@settime);
    handles.wormshowsetframetext = uicontrol(handles.displaypanel,'Style','Text','String','Frame',...
    'Position',[0.90 0.04 0.10 0.03]);
    handles.wormshowsetframe = uicontrol(handles.displaypanel,'Style','Edit','Value', wormshowframe,...
    'Position',[0.90 0.00 0.10 0.04],'Callback',@setframe);
    
    trytoload = {'saveversion', 'objects', 'timefrom', 'timeuntil', 'scalingfactor', 'movingaverage', 'speedsmoothing', 'meanperimeter',...
            'longest', 'validdurationminimum', 'validspeedmin', 'validspeedmax', 'validlengthmin', 'validlengthmax', 'measurementarea', 'startingarea', 'endingarea',...
            'validwidthmin', 'validwidthmax', 'validareamin', 'validareamax', 'validperimetermin', 'validperimetermax', 'valideccentricitymin', 'valideccentricitymax',...
            'identitydisplay', 'detectionareadisplay', 'thresholdeddisplay', 'measurementareadisplay', 'targetareadisplay', 'wormid', 'allobjects', 'averagedisplay', 'detectionarea',... 
            'thresholdsizemin', 'thresholdsizemax', 'thresholdintensity', 'thresholdspeedmax', 'pixelmax', 'measurementradius', 'detectionradius',...
            'revdisplacementwindow', 'revangle', 'revdistance', 'revdurationmax', 'revextrapolate', 'revdisplayduration',...
            'detectomegas', 'omegaeccentricity', 'omegadurationmin', 'omegadisplacementmax', 'omegatolerance', 'omegacompactness', 'omegasoliditymin',...
            'flashed', 'flashindices', 'flashx', 'flashy', 'gradnorm', 'timenorm', 'darkfield', 'gradnormmatrix'};
            %we're deliberately not flagging 'lasttime' and 'lastframe' to be to loaded, because 1) they're set up anyway during readmovie() and 2) in multi-file movies, the first movie can be analysed alone, or together with the subsequent ones, and the lasttime/lastframe values would be different if we were to save and load them, whereas if we rely on readmovie to give us lasttime and lastframe, it's always set up correctly
    trytosetstring = {'timefrom', 'timeuntil', 'movingaverage', 'longest', 'speedsmoothing', 'wormid', 'scalingfactor', 'validdurationminimum'...
            'thresholdsizemin', 'thresholdsizemax', 'thresholdintensity', 'thresholdspeedmax', 'measurementradius', 'detectionradius',...
            'revangle', 'revdisplayduration', 'omegaeccentricity'};
    trytosetvalue = {'identitydisplay', 'detectionareadisplay', 'thresholdeddisplay', 'measurementareadisplay', 'targetareadisplay', 'wormshowframeslider', 'allobjects', ...
        'averagedisplay', 'detectionwhat', 'detectionwhere', 'measurementwhat', 'measurementwhere', 'validdurationcheckstyle', 'trytoloadfps',...
        'detectomegas', 'gradnorm', 'timenorm', 'darkfield'};
    %variables mentioned in the saveonly array below are
    saveonly = {'selectedfiles', 'lastframe', 'lasttime', 'framerate', 'movieindicator', 'frameindicator'};
    
    loadsettings;
    initialize;
    updatefilelist;
    
    function initialize
        
        oldwarningstate = warning('query', 'all'); %we store the warning state prior to launching zentracker, to enable us to restore it when zentracker exits
        
        %do not display FunctionToBeRemoved warnings. In terms of native readers, we use Videoreader class (the newest/current native way to read videos as of 2012b), it's just that for the sake of other Matlab versions and other platforms, mmreader, avireader, etc, are still available as fallback options.
        warning('off', 'MATLAB:avifinfo:FunctionToBeRemoved');
        warning('off', 'MATLAB:aviinfo:FunctionToBeRemoved');
        warning('off', 'MATLAB:aviread:FunctionToBeRemoved');
        warning('off', 'MATLAB:mmreader:isPlatformSupported:FunctionToBeRemoved');
        warning('off', 'MATLAB:audiovideo:avifinfo:FunctionToBeRemoved');
        warning('off', 'MATLAB:audiovideo:aviinfo:FunctionToBeRemoved');
        warning('off', 'MATLAB:audiovideo:aviread:FunctionToBeRemoved');
        warning('off', 'MATLAB:audiovideo:mmreader:isPlatformSupportedToBeRemoved');
        
        %make sure that QTFrameServer.jar is added to the java class path if and only if it is available
        try
            
            qtjavafound = false;
            qtserveravailable = false;
            tiffserveravailable = false;
            bioformatsavailable = false;
            locitoolsavailable = false;
            
            %we first check the java class path
            classpath = javaclasspath;
            for i=1:numel(classpath)
                if strfind(classpath{i}, 'QTFrameServer.jar') == numel(classpath{i}) - numel('QTFrameServer.jar') + 1; %if one of the paths is a direct link to a QTFrameServer.jar (because it ends with QTFrameServer.jar),
                    if exist(classpath{i}, 'file') == 2 %see if it actually exists
                        qtserveravailable = true; %if it does exist, then we found it,
                    else
                        javarmpath(classpath{i}); %if it doesn't actually exist, then it should be removed from the java path
                    end
                end
                if strfind(classpath{i}, 'QTJava.jar') == numel(classpath{i}) - numel('QTJava.jar') + 1;
                    if exist(classpath{i}, 'file') == 2
                        qtjavafound = true;
                    end
                end
                if strfind(classpath{i}, 'TIFFServer.jar') == numel(classpath{i}) - numel('TIFFServer.jar') + 1; %if one of the paths is a direct link to a TIFFServer.jar (because it ends with TIFFServer.jar),
                    if exist(classpath{i}, 'file') == 2 %see if it actually exists
                        tiffserveravailable = true; %if it does exist, then we found it,
                    else
                        javarmpath(classpath{i}); %if it doesn't actually exist, then it should be removed from the java path
                    end
                end
                if strfind(classpath{i}, 'bioformats_package.jar') == numel(classpath{i}) - numel('bioformats_package.jar') + 1; %if one of the paths is a direct link to a bioformats_package.jar (because it ends with bioformats_package.jar),
                    if exist(classpath{i}, 'file') == 2 %see if it actually exists
                        bioformatsavailable = true; %if it does exist, then we found it,
                    else
                        javarmpath(classpath{i}); %if it doesn't actually exist, then it should be removed from the java path
                    end
                end
                if strfind(classpath{i}, 'loci_tools.jar') == numel(classpath{i}) - numel('loci_tools.jar') + 1; %if one of the paths is a direct link to a loci_tools.jar (because it ends with loci_tools.jar),
                    if exist(classpath{i}, 'file') == 2 %see if it actually exists
                        locitoolsavailable = true; %if it does exist, then we found it,
                    else
                        javarmpath(classpath{i}); %if it doesn't actually exist, then it should be removed from the java path
                    end
                end
            end
            
            trytoadd = cell(0);
            if ~qtserveravailable
                trytoadd{end+1} = 'QTFrameServer.jar';
            end
            if ~tiffserveravailable
                trytoadd{end+1} = 'TIFFServer.jar';
            end
            if ~bioformatsavailable
                trytoadd{end+1} = 'bioformats_package.jar';
            end
            if ~locitoolsavailable
                trytoadd{end+1} = 'loci_tools.jar';
            end
            
            if ~isempty(trytoadd)
                pathsline = path;
                separator = pathsep;
                whereseparated = [0, strfind(pathsline, separator), numel(pathsline)+1];
                paths = [];
                for i=1:numel(whereseparated)-1
                    paths{i} = pathsline(whereseparated(i)+1:whereseparated(i+1)-1); %#ok<AGROW>
                end
                for i=1:numel(paths)
                    for tryi = 1:numel(trytoadd)
                        currentfullfile = fullfile(paths{i}, trytoadd{tryi});
                        if exist(currentfullfile, 'file') == 2
                            javaaddpath(currentfullfile);
                            if strcmpi(trytoadd{tryi}, 'QTFrameServer.jar')
                                qtserveravailable = true;
                            elseif strcmpi(trytoadd{tryi}, 'TIFFServer.jar')
                                tiffserveravailable = true;
                            end
                        end
                    end
                end
            end
            
            if ~qtjavafound %ispc && qtserveravailable && 
                qtjavalocations32 = {'C:\Program Files (x86)\QuickTime\QTSystem\QTJava.jar',...
                    'C:\Program Files (x86)\Java\jre9\lib\ext\QTJava.jar', 'C:\Program Files (x86)\Java\jre8\lib\ext\QTJava.jar',...
                    'C:\Program Files (x86)\Java\jre7\lib\ext\QTJava.jar', 'C:\Program Files (x86)\Java\jre6\lib\ext\QTJava.jar',...
                    'C:\Program Files (x86)\Java\jre5\lib\ext\QTJava.jar', 'C:\Program Files (x86)\Java\jre\lib\ext\QTJava.jar'};
                qtjavalocationsnormal = {'C:\Program Files\QuickTime\QTSystem\QTJava.jar',...
                    'C:\Program Files\Java\jre9\lib\ext\QTJava.jar', 'C:\Program Files\Java\jre8\lib\ext\QTJava.jar',...
                    'C:\Program Files\Java\jre7\lib\ext\QTJava.jar', 'C:\Program Files\Java\jre6\lib\ext\QTJava.jar',...
                    'C:\Program Files\Java\jre5\lib\ext\QTJava.jar', 'C:\Program Files\Java\jre\lib\ext\QTJava.jar'};
                if ~isempty(strfind(computer('arch'), '32')) %if Matlab sees 32-bit, we might still be on a 64-bit platform just with 32-bit Matlab, in which case loading a 64-bit version of QTJava may be problematic
                    qtjavalocations = [qtjavalocations32 qtjavalocationsnormal]; %so on 32-bit Matlab we first look in the 32-bit-specific folders, and only then in the normal/general folders
                else
                    qtjavalocations = [qtjavalocationsnormal qtjavalocations32]; %and on 64-bit Matlab we first look in the normal (64-bit) folders first, and only then in the 32-bit folders
                end
                for i=1:numel(qtjavalocations);
                    if exist(qtjavalocations{i}, 'file') == 2
                        javaaddpath(qtjavalocations{i});
                        break; %one QTJava should be enough
                    end
                end
            end
        
        catch, err = lasterror; %#ok<CTCH,LERR> %if some error occurred while fiddling with the QTFrameServer.jar file, then just don't use it %catch err would be nicer, but that doesn't work on older versions of Matlab
            fprintf(2, 'Warning: there was an unexpected error while trying to locate the QTFrameServer.jar file.\n');
            fprintf(2, '%s\n', err.message);
            qtserveravailable = false;
        end
    end
    

    function varargout = plotit (hobj, eventdata, whichparameter, silent, forceaverage) %#ok<INUSL>
        
        if exist('whichparameter', 'var') ~= 1
            whichparameter = get(handles.plotwhat, 'Value');
        end
        if exist('silent', 'var') ~= 1
            silent = false;
        end
        if exist('forceaverage', 'var') ~= 1
            forceaverage = false;
        end
        
        if ~isempty(objects)
            
            if any(startingarea(:)) && any(endingarea(:))
                calculateforSE = true;
            else
                calculateforSE = false;
            end
            
            if ~silent
                %warning the user when trying to plot results without having performed validity checking first %only if ~silent, i.e. if the user normally asked for a plot
                if ~anyinvalid
                    if strcmp(questdlg('Warning: a lack of invalid objects indicates that the validity-checking step may have been skipped. Plotting the data without excluding invalid objects such as merged worms or dirt will produce inaccurate results. Use the "check validity" button before plotting to automatically exclude such objects.','Warning: validity checking may have been skipped','Proceed anyway','Cancel and fix it','Cancel and fix it'),'Cancel and fix it')
                        return;
                    end
                end
                
                figure; %popupfigure
                %set(datacursormode(popupfigure),'UpdateFcn',@datacursorupdate)
            end

            if averagedisplay || forceaverage %mean
                
                if ~silent && (whichparameter == CONST_DISPLAY_LEAVING || whichparameter == CONST_DISPLAY_RETURNING)
                    if whichparameter == CONST_DISPLAY_LEAVING
                        foodtxtfile = fopen(sprintf('%s-foodleaving.txt', selectedfiles{1}), 'w');
                    elseif whichparameter == CONST_DISPLAY_RETURNING
                        foodtxtfile = fopen(sprintf('%s-foodentering.txt', selectedfiles{1}), 'w');
                    end
                    timeinterval = 60; %s
                    timepoints = 0:timeinterval:floor(lasttime/timeinterval)*timeinterval;
                    if whichparameter == CONST_DISPLAY_LEAVING
                        eventtypestring = 'leaving';
                        originstring = 'starting';
                    elseif whichparameter == CONST_DISPLAY_RETURNING
                        eventtypestring = 'returning';
                        originstring = 'ending';
                    end
                    fprintf(foodtxtfile, 'Starting time (s)\t%s%s events\tMax worms in the %s area\n', upper(eventtypestring(1)), eventtypestring(2:end), originstring);
                    maxwormsvalid = zeros(1, lastframe);
                    areasum = zeros(1, lastframe);
                    medianareas = NaN(1, numel(objects));
                    for i=1:numel(objects)
                        currentframes = objects(i).frame;
                        currentbehaviours = objects(i).behaviour;
                        medianareas(i) = median(objects(i).area(objects(i).behaviour ~= CONST_BEHAVIOUR_INVALID));
                        currentpositiongood = false(1, numel(currentframes));
                        if whichparameter == CONST_DISPLAY_LEAVING
                            currentpositiongood(objects(i).target == CONST_TARGET_STARTINGAREA) = true;
                        elseif whichparameter == CONST_DISPLAY_RETURNING
                            currentpositiongood(objects(i).target == CONST_TARGET_ENDINGAREA) = true;
                        else
                            currentpositiongood(:) = false;
                        end
                        maxwormsvalid(currentframes(currentpositiongood & currentbehaviours ~= CONST_BEHAVIOUR_INVALID)) = maxwormsvalid(currentframes(currentpositiongood & currentbehaviours ~= CONST_BEHAVIOUR_INVALID)) + 1;
                        areasum(currentframes(currentpositiongood)) = areasum(currentframes(currentpositiongood)) + objects(i).area(currentpositiongood);
                    end
                    medianwormarea = nanmedian(medianareas);
                    maxwormsperarea = round(areasum / medianwormarea);
                    maxworms = max(maxwormsvalid, maxwormsperarea);
                    eventsoverall = 0;
                    for whichinterval = 2:numel(timepoints)
                        eventssofar = 0;
                        for i=1:numel(objects)
                            currenttimes = objects(i).time;
                            currentbehaviours = objects(i).behaviour;
                            currentbehaviours(currenttimes < timepoints(whichinterval-1) | currenttimes >= timepoints(whichinterval)) = CONST_BEHAVIOUR_INVALID;
                            
                            currentevents = objects(i).targetreached(currentbehaviours ~= CONST_BEHAVIOUR_INVALID);
                            if whichparameter == CONST_DISPLAY_LEAVING
                                eventssofar = eventssofar + sum(currentevents == CONST_TARGET_ENDINGAREA);
                            elseif whichparameter == CONST_DISPLAY_RETURNING
                                eventssofar = eventssofar + sum(currentevents == CONST_TARGET_STARTINGAREA);
                            end
                            eventdenominator = nanmax(maxworms(converttoframe(timepoints(whichinterval-1)):converttoframe(timepoints(whichinterval))));
                        end
                        eventsoverall = eventsoverall + eventssofar;
                        fprintf('Between %.0fs - %.0fs : %d %s events over %d worms in the %s area\n', timepoints(whichinterval-1), timepoints(whichinterval), eventssofar, eventtypestring, eventdenominator, originstring);
                        fprintf(foodtxtfile, '%f\t%d\t%d\n', timepoints(whichinterval-1), eventssofar, eventdenominator);
                    end
                    overallmaxtime = sum(maxworms) / framerate;
                    fprintf('Overall: %f %s events per worm per %ds spent in the %s area\n', eventsoverall/overallmaxtime*timeinterval, eventtypestring, timeinterval, originstring);
                    fprintf(foodtxtfile, 'Overall:\t%f\t%s events per worm per %ds spent in the %s area\n', eventsoverall/overallmaxtime*timeinterval, eventtypestring, timeinterval, originstring);
                    fclose(foodtxtfile);
                end
                
                sumdata = zeros(1, lastframe);
                countdata = zeros(1, lastframe);
                meandata = NaN(1, lastframe);
                overallsumdata = 0;
                overallcountdata = 0;
                
                %starting area
                Ssumdata = zeros(1, lastframe);
                Scountdata = zeros(1, lastframe);
                Smeandata = NaN(1, lastframe);
                Soverallsumdata = 0;
                Soverallcountdata = 0;
                
                %ending area
                Esumdata = zeros(1, lastframe);
                Ecountdata = zeros(1, lastframe);
                Emeandata = NaN(1, lastframe);
                Eoverallsumdata = 0;
                Eoverallcountdata = 0;

                for i=1:numel(objects)
                    for j=1:objects(i).duration
                        if objects(i).time(j) >= timefrom && objects(i).time(j) <= timeuntil && ~invalid(i, j, whichparameter) && (allobjects || wormid == i)
                            switch whichparameter
                                case CONST_DISPLAY_SPEED
                                    addnow = smoothspeed(i, j) * scalingfactor;
                                case CONST_DISPLAY_X
                                    addnow = objects(i).x(j);
                                case CONST_DISPLAY_Y
                                    addnow = objects(i).y(j);
                                case CONST_DISPLAY_LENGTH
                                    addnow = objects(i).length(j) * scalingfactor;
                                case CONST_DISPLAY_WIDTH
                                    addnow = objects(i).width(j) * scalingfactor;
                                case CONST_DISPLAY_AREA
                                    addnow = objects(i).area(j) * scalingfactor^2;
                                case CONST_DISPLAY_PERIMETER
                                    addnow = objects(i).perimeter(j) * scalingfactor;
                                case CONST_DISPLAY_ECCENTRICITY
                                    addnow = objects(i).eccentricity(j);
                                case CONST_DISPLAY_SOLIDITY
                                    addnow = objects(i).solidity(j);
                                case CONST_DISPLAY_ORIENTATION
                                    addnow = objects(i).orientation(j);
                                case CONST_DISPLAY_COMPACTNESS
                                    addnow = objects(i).compactness(j);
                                case CONST_DISPLAY_DIRECTIONCHANGE
                                    addnow = abs(objects(i).directionchange(j)); %When averaging, we take the absolute value, because we want to look at whether there are large reorientations or not (not so much at which direction they tend to go, although I suppose sometimes that might also be interesting)
                                case CONST_DISPLAY_REVERSAL
                                    if objects(i).behaviour(j) == CONST_BEHAVIOUR_REVERSAL
                                        addnow = 1;
                                    elseif objects(i).behaviour(j) ~= CONST_BEHAVIOUR_INVALID && objects(i).behaviour(j) ~= CONST_BEHAVIOUR_UNKNOWN
                                        addnow = 0;
                                    else
                                        addnow = NaN;
                                    end
                                case CONST_DISPLAY_OMEGA
                                    if objects(i).behaviour(j) == CONST_BEHAVIOUR_OMEGA
                                        addnow = 1;
                                    elseif objects(i).behaviour(j) ~= CONST_BEHAVIOUR_INVALID && objects(i).behaviour(j) ~= CONST_BEHAVIOUR_UNKNOWN
                                        addnow = 0;
                                    else
                                        addnow = NaN;
                                    end
                                case CONST_DISPLAY_LEAVING
                                    addnow = NaN;
                                    if objects(i).targetreached(j) == CONST_TARGET_ENDINGAREA
                                        addnow = 1;
                                    elseif objects(i).target(j) == CONST_TARGET_STARTINGAREA
                                        addnow = 0;
                                    end
                                case CONST_DISPLAY_RETURNING
                                    addnow = NaN;
                                    if objects(i).targetreached(j) == CONST_TARGET_STARTINGAREA
                                        addnow = 1;
                                    elseif objects(i).target(j) == CONST_TARGET_ENDINGAREA
                                        addnow = 0;
                                    end
                                case CONST_DISPLAY_NNUMBER
                                    addnow = (objects(i).behaviour(j) ~= CONST_BEHAVIOUR_INVALID);
                            end
                            if ~isnan(addnow)
                                sumdata(objects(i).frame(j)) = sumdata(objects(i).frame(j)) + addnow;
                                countdata(objects(i).frame(j)) = countdata(objects(i).frame(j)) + 1;
                                overallsumdata = overallsumdata + addnow;
                                overallcountdata = overallcountdata + 1;
                                if calculateforSE
                                    if startingarea(round(objects(i).y(j)), round(objects(i).x(j)))
                                        Ssumdata(objects(i).frame(j)) = Ssumdata(objects(i).frame(j)) + addnow;
                                        Scountdata(objects(i).frame(j)) = Scountdata(objects(i).frame(j)) + 1;
                                        Soverallsumdata = Soverallsumdata + addnow;
                                        Soverallcountdata = Soverallcountdata + 1;
                                    end
                                    if endingarea(round(objects(i).y(j)), round(objects(i).x(j)))
                                        Esumdata(objects(i).frame(j)) = Esumdata(objects(i).frame(j)) + addnow;
                                        Ecountdata(objects(i).frame(j)) = Ecountdata(objects(i).frame(j)) + 1;
                                        Eoverallsumdata = Eoverallsumdata + addnow;
                                        Eoverallcountdata = Eoverallcountdata + 1;
                                    end
                                end
                            end
                        end
                    end
                end

                wherewehavedata = countdata>0;
                Swherewehavedata = Scountdata>0;
                Ewherewehavedata = Ecountdata>0;
                if whichparameter ~= CONST_DISPLAY_NNUMBER
                    meandata(wherewehavedata) = sumdata(wherewehavedata) ./ countdata(wherewehavedata);
                    Smeandata(Swherewehavedata) = Ssumdata(Swherewehavedata) ./ Scountdata(Swherewehavedata);
                    Emeandata(Ewherewehavedata) = Esumdata(Ewherewehavedata) ./ Ecountdata(Ewherewehavedata);
                else
                    meandata(wherewehavedata) = sumdata(wherewehavedata);
                    Smeandata(Swherewehavedata) = Ssumdata(Swherewehavedata);
                    Emeandata(Ewherewehavedata) = Esumdata(Ewherewehavedata);
                end
                if overallcountdata > 0
                    overallmeandata = overallsumdata / overallcountdata;
                    byframemeandata = nanmean(meandata);
                else
                    overallmeandata = NaN;
                    byframemeandata = NaN;
                end
                if Soverallcountdata > 0
                    Soverallmeandata = Soverallsumdata / Soverallcountdata;
                    Sbyframemeandata = nanmean(Smeandata);
                else
                    Soverallmeandata = NaN;
                    Sbyframemeandata = NaN;
                end
                if Eoverallcountdata > 0
                    Eoverallmeandata = Eoverallsumdata / Eoverallcountdata;
                    Ebyframemeandata = nanmean(Emeandata);
                else
                    Eoverallmeandata = NaN;
                    Ebyframemeandata = NaN;
                end

                if movingaverage > 1/framerate
                    meandata = movingaveragefilterwithoutnan(meandata, round(movingaverage*framerate)); %just for plotting, not for displaying stats
                end
                
                if ~silent
                    plot(0:1/framerate:lasttime, meandata);

                    if ~isempty(flashed)
                        hold on;
                        scatter(converttotime(find(flashed)), zeros(size(find(flashed))), 5, 'g');
                    end

                    switch whichparameter
                        case CONST_DISPLAY_SPEED
                            averagedwhat = 'speed';
                        case CONST_DISPLAY_X
                            averagedwhat = 'x-coordinate';
                        case CONST_DISPLAY_Y
                            averagedwhat = 'y-coordinate';
                        case CONST_DISPLAY_LENGTH
                            averagedwhat = 'length';
                        case CONST_DISPLAY_WIDTH
                            averagedwhat = 'width';
                        case CONST_DISPLAY_AREA
                            averagedwhat = 'area';
                        case CONST_DISPLAY_PERIMETER
                            averagedwhat = 'perimeter';
                        case CONST_DISPLAY_ECCENTRICITY
                            averagedwhat = 'eccentricity';
                        case CONST_DISPLAY_SOLIDITY
                            averagedwhat = 'solidity';
                        case CONST_DISPLAY_ORIENTATION
                            averagedwhat = 'orientation';
                        case CONST_DISPLAY_COMPACTNESS
                            averagedwhat = 'compactness';
                        case CONST_DISPLAY_DIRECTIONCHANGE
                            averagedwhat = 'direction change';
                        case CONST_DISPLAY_REVERSAL
                            averagedwhat = 'proportion of reversals';
                        case CONST_DISPLAY_OMEGA
                            averagedwhat = 'proportion of omega turns';
                        case CONST_DISPLAY_LEAVING
                            averagedwhat = 'proportion of worms leaving';
                        case CONST_DISPLAY_RETURNING
                            averagedwhat = 'proportion of worms returning';
                        case CONST_DISPLAY_NNUMBER
                            averagedwhat = 'n-number';
                        otherwise
                            averagedwhat = 'value';
                    end

                    if ~(whichparameter == CONST_DISPLAY_LEAVING || whichparameter == CONST_DISPLAY_RETURNING)
                        fprintf('The average %s over the whole movie is:\n %f (when we first average across valid objects at each timepoint, and then average these values across the timepoints), or\n %f (when we just take the overall average value of all the valid datapoints).\n', averagedwhat, byframemeandata, overallmeandata);
                        if calculateforSE
                            fprintf('The average %s within the starting area over the whole movie is:\n %f (when we first average across valid objects at each timepoint, and then average these values across the timepoints), or\n %f (when we just take the overall average value of all the valid datapoints).\n', averagedwhat, Sbyframemeandata, Soverallmeandata);
                            fprintf('The average %s within the ending area over the whole movie is:\n %f (when we first average across valid objects at each timepoint, and then average these values across the timepoints), or\n %f (when we just take the overall average value of all the valid datapoints).\n', averagedwhat, Ebyframemeandata, Eoverallmeandata);
                        end
                    end
                end
                
                if nargout > 0
                    varargout{1} = meandata;
                end

                %{
                if get(handles.exportdisplay, 'Value')
                    exportfile = fopen([selectedfiles{1} '-exported.txt'], 'w');
                    fprintf(exportfile, 'frame number\taverage value\n');
                    for i=1:numel(meandata)
                        fprintf(exportfile, '%d\t%f\n', i, meandata(i));
                    end
                    fclose(exportfile);
                    fprintf('The average displayed values were exported successfully.\n');
                end
                %}
                
            else %individuals

                beingheld = false;

                if longest > 0
                    displayhowmany = min([longest numel(objects)]);

                    validduration = zeros(numel(objects), 1);
                    for i=1:numel(objects)
                        for j=1:objects(i).duration
                            if ~invalid(i, j, whichparameter) && objects(i).time(j) >= timefrom && objects(i).time(j) <= timeuntil
                                validduration(i) = validduration(i) + 1;
                            end
                        end
                    end
                    [sorted, sortindex] = sort(validduration, 'descend');

                else
                    displayhowmany = numel(objects);
                    sortindex = 1:numel(objects);
                end

                for i=1:displayhowmany

                    firstindex = NaN;
                    lastindex = NaN;
                    for j=1:objects(sortindex(i)).duration
                        if isnan(firstindex) && objects(sortindex(i)).time(j) >= timefrom
                            firstindex = j;
                        end
                        if (isnan(lastindex) || objects(sortindex(i)).time(j) > objects(sortindex(i)).time(lastindex)) && objects(sortindex(i)).time(j) <= timeuntil
                            lastindex = j;
                        end
                    end

                    if ~isnan(firstindex) && lastindex > -Inf && ~(displayhowmany == numel(objects) && wormid ~= i && ~allobjects) %If there's something to display

                        switch whichparameter
                            case CONST_DISPLAY_SPEED
                                displaynow = smoothspeed(sortindex(i), firstindex:lastindex) * scalingfactor;
                            case CONST_DISPLAY_X
                                displaynow = objects(sortindex(i)).x(firstindex:lastindex);
                            case CONST_DISPLAY_Y
                                displaynow = objects(sortindex(i)).y(firstindex:lastindex);
                            case CONST_DISPLAY_LENGTH
                                displaynow = objects(sortindex(i)).length(firstindex:lastindex) * scalingfactor;
                            case CONST_DISPLAY_WIDTH
                                displaynow = objects(sortindex(i)).width(firstindex:lastindex) * scalingfactor;
                            case CONST_DISPLAY_AREA
                                displaynow = objects(sortindex(i)).area(firstindex:lastindex) * scalingfactor^2;
                            case CONST_DISPLAY_PERIMETER
                                displaynow = objects(sortindex(i)).perimeter(firstindex:lastindex) * scalingfactor;
                            case CONST_DISPLAY_ECCENTRICITY
                                displaynow = objects(sortindex(i)).eccentricity(firstindex:lastindex);
                            case CONST_DISPLAY_SOLIDITY
                                displaynow = objects(sortindex(i)).solidity(firstindex:lastindex);
                            case CONST_DISPLAY_ORIENTATION
                                displaynow = objects(sortindex(i)).orientation(firstindex:lastindex);
                            case CONST_DISPLAY_COMPACTNESS
                                displaynow = objects(sortindex(i)).compactness(firstindex:lastindex);
                            case CONST_DISPLAY_DIRECTIONCHANGE
                                displaynow = objects(sortindex(i)).directionchange(firstindex:lastindex);
                            case CONST_DISPLAY_REVERSAL
                                displaynowindex = 0;
                                displaynow = NaN(1, lastindex-firstindex+1);
                                for j=firstindex:lastindex
                                    displaynowindex = displaynowindex + 1;
                                    if objects(sortindex(i)).behaviour(j) == CONST_BEHAVIOUR_REVERSAL
                                        displaynow(displaynowindex) = 1;
                                    elseif objects(sortindex(i)).behaviour(j) ~= CONST_BEHAVIOUR_INVALID && objects(sortindex(i)).behaviour(j) ~= CONST_BEHAVIOUR_UNKNOWN
                                        displaynow(displaynowindex) = 0;
                                    else
                                        displaynow(displaynowindex) = NaN;
                                    end
                                end
                                %displaynow = objects(sortindex(i)).behaviour(firstindex:lastindex) == CONST_BEHAVIOUR_REVERSAL;
                            case CONST_DISPLAY_OMEGA
                                displaynowindex = 0;
                                displaynow = NaN(1, lastindex-firstindex+1);
                                for j=firstindex:lastindex
                                    displaynowindex = displaynowindex + 1;
                                    if objects(sortindex(i)).behaviour(j) == CONST_BEHAVIOUR_OMEGA
                                        displaynow(displaynowindex) = 1;
                                    elseif objects(sortindex(i)).behaviour(j) ~= CONST_BEHAVIOUR_INVALID && objects(sortindex(i)).behaviour(j) ~= CONST_BEHAVIOUR_UNKNOWN
                                        displaynow(displaynowindex) = 0;
                                    else
                                        displaynow(displaynowindex) = NaN;
                                    end
                                end
                            case CONST_DISPLAY_LEAVING
                                displaynowindex = 0;
                                displaynow = NaN(1, lastindex-firstindex+1);
                                for j=firstindex:lastindex
                                    displaynowindex = displaynowindex + 1;
                                    if objects(sortindex(i)).targetreached(j) == CONST_TARGET_ENDINGAREA
                                        displaynow(displaynowindex) = 1;
                                    elseif objects(sortindex(i)).target(j) == CONST_TARGET_STARTINGAREA
                                        displaynow(displaynowindex) = 0;
                                    end
                                end
                            case CONST_DISPLAY_RETURNING
                                displaynowindex = 0;
                                displaynow = NaN(1, lastindex-firstindex+1);
                                for j=firstindex:lastindex
                                    displaynowindex = displaynowindex + 1;
                                    if objects(sortindex(i)).targetreached(j) == CONST_TARGET_STARTINGAREA
                                        displaynow(displaynowindex) = 1;
                                    elseif objects(sortindex(i)).target(j) == CONST_TARGET_ENDINGAREA
                                        displaynow(displaynowindex) = 0;
                                    end
                                end
                            case CONST_DISPLAY_NNUMBER
                                displaynow = (objects(sortindex(i)).behaviour(firstindex:lastindex) ~= CONST_BEHAVIOUR_INVALID);
                        end

                        %validity checking
                        if whichparameter ~= CONST_DISPLAY_NNUMBER
                            for j=firstindex:lastindex
                                if invalid(sortindex(i), j, whichparameter)
                                    displaynow(j-firstindex+1) = NaN;
                                end
                            end
                        end
                        
                        %fprintf('%f\n', mean(displaynow(~isnan(displaynow)))); %changeme

                        %Displaying
                        if ~silent
                            if movingaverage > 1/framerate
                                plot(objects(sortindex(i)).time(firstindex):1/framerate:objects(sortindex(i)).time(lastindex), movingaveragefilterwithoutnan(displaynow, movingaverage));
                            else
                                plot(objects(sortindex(i)).time(firstindex):1/framerate:objects(sortindex(i)).time(lastindex), displaynow);
                            end
                            if ~beingheld
                                hold all;
                                beingheld = true;
                            end
                        end
                        
                        if nargout > 0
                            varargout{i} = displaynow;
                        end
                        
                    end
                end
                
                if ~silent
                    if ~isempty(flashed)
                        hold on;
                        scatter(converttotime(find(flashed)), zeros(size(find(flashed))), 5, 'g');
                    end
                end

            end
            
            if ~silent
                hold off;

                xlabel('time (s)');
                if timeuntil > timefrom
                    xlim([timefrom timeuntil]);
                else %if timefrom == timeuntil, Matlab xlim throws an error
                    xlim([timefrom-1 timeuntil+1]);
                end
                %set(gca, 'XTick', floor(timefrom/120)*120:120:ceil(timeuntil/120)*120); %changeme
                switch whichparameter
                    case CONST_DISPLAY_SPEED
                        ylabelnow = 'speed (um/s)';
                        title('Speed');
                    case CONST_DISPLAY_X
                        ylabelnow = 'x coordinate (pixels)';
                        title('x coordinate');
                    case CONST_DISPLAY_Y
                        ylabelnow = 'y coordinate (pixels)';
                        title('y coordinate');
                    case CONST_DISPLAY_LENGTH
                        ylabelnow = 'length (um)';
                        title('Length');
                    case CONST_DISPLAY_WIDTH
                        ylabelnow = 'average width (um)';
                        title('Width');
                    case CONST_DISPLAY_AREA
                        ylabelnow = 'area (um^2)';
                        title('Area');
                    case CONST_DISPLAY_PERIMETER
                        ylabelnow = 'perimeter (um)';
                        title('Perimeter');
                    case CONST_DISPLAY_ECCENTRICITY
                        ylabelnow = 'eccentricity';
                        title('Eccentricity');
                    case CONST_DISPLAY_SOLIDITY
                        ylabelnow = 'solidity';
                        title('Solidity');
                    case CONST_DISPLAY_ORIENTATION
                        ylabelnow = 'orientation';
                        title('Orientation');
                    case CONST_DISPLAY_COMPACTNESS
                        ylabelnow = 'compactness';
                        title('Compactness');
                    case CONST_DISPLAY_DIRECTIONCHANGE
                        ylabelnow = 'direction change (radians)';
                        title('Direction change');
                    case CONST_DISPLAY_REVERSAL
                        if averagedisplay
                            ylabelnow = 'Proportion in reversal';
                        else
                            ylabelnow = 'Reversal state (1 = reversing; 0 = not reversing)';
                        end
                        title('Reversals');
                    case CONST_DISPLAY_OMEGA
                        if averagedisplay
                            ylabelnow = 'Proportion in omega turns';
                        else
                            ylabelnow = 'Omega turn state (1 = performing an omega turn; 0 = not)';
                        end
                        title('Omega turns');
                    case CONST_DISPLAY_LEAVING
                        if averagedisplay
                            ylabelnow = 'Proportion of worms leaving';
                        else
                            ylabelnow = 'Leaving state (1 = entering the ending area; 0 = staying in the starting area)';
                        end
                    case CONST_DISPLAY_RETURNING
                        if averagedisplay
                            ylabelnow = 'Proportion of worms returning';
                        else
                            ylabelnow = 'Returning state (1 = entering the starting area; 0 = staying in the ending area)';
                        end
                    case CONST_DISPLAY_NNUMBER
                        if averagedisplay
                            ylabelnow = 'Valid number of worms';
                        else
                            ylabelnow = 'Validity';
                        end
                end
                ylabel(ylabelnow);
            end
            
            if nargout > 0 && isempty(varargout)
                varargout{1} = [];
            end
            
        else
            if ~silent
                fprintf(2, 'Warning: no objects have been detected, so there is nothing to display.\n');
                questdlg('No objects have been detected, so there is nothing to display.', 'Nothing to display', 'OK', 'OK');
            end
            
            if nargout > 0
                varargout{1} = [];
            end
        end
    end

    function clearadvancedvalidityfigure(hobj, eventdata) %#ok<INUSD>
        %clearing advancedvalidityfigure to prevent the following from occurring:
        %1. User opens advancedvalidityfigure
        %2. User closes advancedvalidityfigure
        %3. User makes a new figure that gets the same ID as advancedvalidityfigure (e.g. figure "2" again)
        %4. User loads analysisdata, which checks that advancedvalidityfigure exists, finds that it does (because a new figure exists with the same ID), and so it deletes the figure
        advancedvalidityfigure = [];
    end

    function clearadvancedrevfigure(hobj, eventdata) %#ok<INUSD>
        %clearing advancedrevfigure to prevent the following from occurring:
        %1. User opens advancedrevfigure
        %2. User closes advancedrevfigure
        %3. User makes a new figure that gets the same ID as advancedrevfigure (e.g. figure "2" again)
        %4. User loads analysisdata, which checks that advancedrevfigure exists, finds that it does (because a new figure exists with the same ID), and so it deletes the figure
        advancedrevfigure = [];
    end

    function clearadvancedomegafigure(hobj, eventdata) %#ok<INUSD>
        %clearing advancedomegafigure to prevent the following from occurring:
        %1. User opens advancedomegafigure
        %2. User closes advancedomegafigure
        %3. User makes a new figure that gets the same ID as advancedomegafigure (e.g. figure "2" again)
        %4. User loads analysisdata, which checks that advancedomegafigure exists, finds that it does (because a new figure exists with the same ID), and so it deletes the figure
        advancedomegafigure = [];
    end

    function validityadvanced(hobj, eventdata) %#ok<INUSD>
        
        advancedvalidityfigure = figure('Name','Advanced validity checking settings','NumberTitle','off', ...
            'Visible','on','Color',get(0,'defaultUicontrolBackgroundColor'), 'Units','Normalized',...
            'DefaultUicontrolUnits','Normalized','Toolbar', 'none', 'MenuBar', 'none', 'DeleteFcn', @clearadvancedvalidityfigure); %clearing advancedvalidityfigure inline (i.e. without referring to a function to do it) does not seem to work
        advancedvaliditypanel = uipanel(advancedvalidityfigure, 'Title', 'Advanced validity checking settings', 'Units','Normalized',...
        'DefaultUicontrolUnits','Normalized', 'Position', [0 0 1 1]);
    
        handles.validspeedtext = uicontrol(advancedvaliditypanel, 'Style','Text','String','Speed (um/s)', 'Position', [0.10 0.95 0.80 0.04]);
        handles.validspeedmin = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(validspeedmin), 'Position', [0.22 0.87 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'setglobal', 'validspeedmin'});
        handles.validspeedmax = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(validspeedmax), 'Position', [0.58 0.87 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'setglobal', 'validspeedmax'});
        handles.validspeeddash = uicontrol(advancedvaliditypanel, 'Style','Text','String','to', 'Position', [0.43 0.87 0.14 0.06]);
        
        handles.validlengthtext = uicontrol(advancedvaliditypanel, 'Style','Text','String','Length (um)', 'Position', [0.10 0.80 0.80 0.04]);
        handles.validlengthmin = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(validlengthmin), 'Position', [0.22 0.72 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'setglobal', 'validlengthmin'});
        handles.validlengthmax = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(validlengthmax), 'Position', [0.58 0.72 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'setglobal', 'validlengthmax'});
        handles.validlengthdash = uicontrol(advancedvaliditypanel, 'Style','Text','String','to', 'Position', [0.43 0.72 0.14 0.06]);
        
        handles.validwidthtext = uicontrol(advancedvaliditypanel, 'Style','Text','String','Width (um)', 'Position', [0.10 0.65 0.80 0.04]);
        handles.validwidthmin = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(validwidthmin), 'Position', [0.22 0.57 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'setglobal', 'validwidthmin'});
        handles.validwidthmax = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(validwidthmax), 'Position', [0.58 0.57 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'setglobal', 'validwidthmax'});
        handles.validwidthdash = uicontrol(advancedvaliditypanel, 'Style','Text','String','to', 'Position', [0.43 0.57 0.14 0.06]);
        
        handles.validareatext = uicontrol(advancedvaliditypanel, 'Style','Text','String','Area (um^2)', 'Position', [0.10 0.50 0.80 0.04]);
        handles.validareamin = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(validareamin), 'Position', [0.22 0.42 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'setglobal', 'validareamin'});
        handles.validareamax = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(validareamax), 'Position', [0.58 0.42 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'setglobal', 'validareamax'});
        handles.validareadash = uicontrol(advancedvaliditypanel, 'Style','Text','String','to', 'Position', [0.43 0.42 0.14 0.06]);
        
        handles.validperimetertext = uicontrol(advancedvaliditypanel, 'Style','Text','String','Perimeter (um)', 'Position', [0.10 0.35 0.80 0.04]);
        handles.validperimetermin = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(validperimetermin), 'Position', [0.22 0.27 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'setglobal', 'validperimetermin'});
        handles.validperimetermax = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(validperimetermax), 'Position', [0.58 0.27 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'setglobal', 'validperimetermax'});
        handles.validperimeterdash = uicontrol(advancedvaliditypanel, 'Style','Text','String','to', 'Position', [0.43 0.27 0.14 0.06]);
        
        handles.valideccentricitytext = uicontrol(advancedvaliditypanel, 'Style','Text','String','Eccentricity', 'Position', [0.10 0.20 0.80 0.04]);
        handles.valideccentricitymin = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(valideccentricitymin), 'Position', [0.22 0.12 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'max', 1, 'setglobal', 'valideccentricitymin'});
        handles.valideccentricitymax = uicontrol(advancedvaliditypanel, 'Style','Edit','String',num2str(valideccentricitymax), 'Position', [0.58 0.12 0.20 0.08], 'Callback', {@setvalue, 'min', 0, 'default', 0, 'max', 1, 'setglobal', 'valideccentricitymax'});
        handles.valideccentricitydash = uicontrol(advancedvaliditypanel, 'Style','Text','String','to', 'Position', [0.43 0.12 0.14 0.06]);
        
    end

    function revadvanced(hobj, eventdata) %#ok<INUSD>
        
        advancedrevfigure = figure('Name','Advanced reversal detection settings','NumberTitle','off', ...
            'Visible','on','Color',get(0,'defaultUicontrolBackgroundColor'), 'Units','Normalized',...
            'DefaultUicontrolUnits','Normalized','Toolbar', 'none', 'MenuBar', 'none', 'DeleteFcn', @clearadvancedrevfigure); %clearing advancedrevfigure inline (i.e. without referring to a function to do it) does not seem to work
        advancedrevpanel = uipanel(advancedrevfigure, 'Title', 'Advanced reversal detection settings', 'Units','Normalized',...
        'DefaultUicontrolUnits','Normalized', 'Position', [0 0 1 1]);
    
        handles.revdisplacementwindowtext = uicontrol(advancedrevpanel, 'Style','Text','String','Displacement window (s)', 'Position', [0.00 0.90 0.50 0.05]);
        handles.revdisplacementwindowtext2 = uicontrol(advancedrevpanel, 'Style','Text','String','(subtract from the current position the coordinates this much time ago to obtain a reliable measure of direction)', 'Position', [0.00 0.80 0.50 0.10]);
        handles.revdisplacementwindow = uicontrol(advancedrevpanel, 'Style','Edit','String',num2str(revdisplacementwindow), 'Position', [0.10 0.70 0.30 0.10], 'Callback', {@setvalue, 'min', '1/framerate', 'max', 'lastframe', 'setglobal', 'revdisplacementwindow', 'default', revdisplacementwindow});
        
        handles.revextrapolatetext = uicontrol(advancedrevpanel, 'Style','Text','String','Maximal extrapolation (s)', 'Position', [0.50 0.90 0.50 0.05]);
        handles.revextrapolatetext2 = uicontrol(advancedrevpanel, 'Style','Text','String','(given a user-specified head-direction at the current time, assume that the head is still in the same direction this much time later)', 'Position', [0.50 0.80 0.50 0.10]);
        handles.revextrapolate = uicontrol(advancedrevpanel, 'Style','Edit','String',num2str(revextrapolate), 'Position', [0.60 0.70 0.30 0.10], 'Callback', {@setvalue, 'min', 0, 'setglobal', 'revextrapolate', 'default', revextrapolate});

        handles.revdurationmaxtext = uicontrol(advancedrevpanel, 'Style','Text','String','Maximal reversal duration (s)', 'Position', [0.00 0.55 0.50 0.05]);
        handles.revdurationmaxtext2 = uicontrol(advancedrevpanel, 'Style','Text','String','(an interval consisting of at least this much time of a worm going in the same direction should be considered forwards movement)', 'Position', [0.00 0.45 0.50 0.10]);
        handles.revdurationmax = uicontrol(advancedrevpanel, 'Style','Edit','String',num2str(revdurationmax), 'Position', [0.10 0.35 0.30 0.10], 'Callback', {@setvalue, 'min', 0, 'setglobal', 'revdurationmax', 'default', revdurationmax});

        handles.revdistancetext = uicontrol(advancedrevpanel, 'Style','Text','String','Maximal dwelling distance (um)', 'Position', [0.50 0.55 0.50 0.05]);
        handles.revdistancetext2 = uicontrol(advancedrevpanel, 'Style','Text','String','(with less than this much distance covered during an interval, the user-specified head-direction should be applicable to the entire interval)', 'Position', [0.50 0.45 0.50 0.10]);
        handles.revdistance = uicontrol(advancedrevpanel, 'Style','Edit','String',num2str(revdistance), 'Position', [0.60 0.35 0.30 0.10], 'Callback', {@setvalue, 'min', 0, 'setglobal', 'revdistance', 'default', revdistance});
        
    end

    function omegaadvanced(hobj, eventdata) %#ok<INUSD>
        
        advancedomegafigure = figure('Name','Advanced reversal detection settings','NumberTitle','off', ...
            'Visible','on','Color',get(0,'defaultUicontrolBackgroundColor'), 'Units','Normalized',...
            'DefaultUicontrolUnits','Normalized','Toolbar', 'none', 'MenuBar', 'none', 'DeleteFcn', @clearadvancedomegafigure); %clearing advancedomegafigure inline (i.e. without referring to a function to do it) does not seem to work
        advancedomegapanel = uipanel(advancedomegafigure, 'Title', 'Advanced reversal detection settings', 'Units','Normalized',...
        'DefaultUicontrolUnits','Normalized', 'Position', [0 0 1 1]);

        handles.omegadurationmintext = uicontrol(advancedomegapanel, 'Style','Text','String','Minimal omega duration (s)', 'Position', [0.00 0.90 0.50 0.05]);
        handles.omegadurationmintext2 = uicontrol(advancedomegapanel, 'Style','Text','String','(if an omega turn would last for less than this much time, it should not be flagged)', 'Position', [0.00 0.80 0.50 0.10]);
        handles.omegadurationmin = uicontrol(advancedomegapanel, 'Style','Edit','String',num2str(omegadurationmin), 'Position', [0.10 0.70 0.30 0.10], 'Callback', {@setvalue, 'min', 0, 'setglobal', 'omegadurationmin', 'default', omegadurationmin});
        
        handles.omegatolerancetext = uicontrol(advancedomegapanel, 'Style','Text','String','Omega interruption tolerance (s)', 'Position', [0.50 0.90 0.50 0.05]);
        handles.omegatolerancetext2 = uicontrol(advancedomegapanel, 'Style','Text','String','(if an omega is interrupted for only at most this much time, treat the whole interval as a single omega turn)', 'Position', [0.50 0.80 0.50 0.10]);
        handles.omegatolerance = uicontrol(advancedomegapanel, 'Style','Edit','String',num2str(omegatolerance), 'Position', [0.60 0.70 0.30 0.10], 'Callback', {@setvalue, 'min', 0, 'setglobal', 'omegatolerance', 'default', omegatolerance});
        
        handles.omegadisplacementmaxtext = uicontrol(advancedomegapanel, 'Style','Text','String','Maximal omega displacement (um)', 'Position', [0.00 0.55 0.50 0.05]);
        handles.omegadisplacementmaxtext2 = uicontrol(advancedomegapanel, 'Style','Text','String','(an overall centroid movement of more than this many micrometers should not be considered a single omega turn)', 'Position', [0.00 0.45 0.50 0.10]);
        handles.omegadisplacementmax = uicontrol(advancedomegapanel, 'Style','Edit','String',num2str(omegadisplacementmax), 'Position', [0.10 0.35 0.30 0.10], 'Callback', {@setvalue, 'min', 0, 'setglobal', 'omegadisplacementmax', 'default', omegadisplacementmax});

        handles.omegaperiareatext = uicontrol(advancedomegapanel, 'Style','Text','String','Omega compactness', 'Position', [0.50 0.55 0.50 0.05]);
        handles.omegaperiareatext2 = uicontrol(advancedomegapanel, 'Style','Text','String','(if compactness falls below this value, treat it as an omega turn)', 'Position', [0.50 0.45 0.50 0.10]);
        handles.omegaperiarea = uicontrol(advancedomegapanel, 'Style','Edit','String',num2str(omegacompactness), 'Position', [0.60 0.35 0.30 0.10], 'Callback', {@setvalue, 'min', 0, 'setglobal', 'omegacompactness', 'default', omegacompactness});
        
        handles.omegasoliditymintext = uicontrol(advancedomegapanel, 'Style','Text','String','Minimal omega solidity', 'Position', [0.00 0.20 0.50 0.05]);
        handles.omegasoliditymintext2 = uicontrol(advancedomegapanel, 'Style','Text','String','(if less than this proportion of the convex hull is filled, other measures cannot indicate an omega)', 'Position', [0.00 0.10 0.50 0.10]);
        handles.omegasoliditymin = uicontrol(advancedomegapanel, 'Style','Edit','String',num2str(omegasoliditymin), 'Position', [0.10 0.00 0.30 0.10], 'Callback', {@setvalue, 'min', 0, 'max', 1, 'setglobal', 'omegasoliditymin', 'default', omegasoliditymin});
        
    end

    function trackobjects(hobj, eventdata) %#ok<INUSD>
        
        questionstring = [];
        if isnan(thresholdspeedmax) || isinf(thresholdspeedmax)
            questionstring = 'No max speed threshold has been specified for tracking. This may result in object IDs jumping across large distances (e.g. when new objects appear and disappear in the same frame). It is strongly recommended to set a max speed threshold, perhaps around 3x the expected mean speed of a fast object (e.g. 600 um/s threshold for C. elegans).';
        elseif scalingfactor == 1
            questionstring = 'The scaling factor does not appear to have been set up. This way all distance measurements will be in pixels rather than micrometers, including the max speed threshold for tracking, and validity check measurements. It is recommended that you set up the scalingfactor as the number of micrometers corresponding to a pixel.';
        elseif ~any(detectionarea(:))
            questionstring = 'No detection area has been specified. This way no objects will be detected or tracked anywhere. You should mark as "detection area" the parts where you want to detect and track the identities of objects.';
        end
        if ~isempty(questionstring)
            if strcmp(questdlg(questionstring,'Warning: speed threshold may be inappropriate','Proceed anyway','Cancel and fix it','Cancel and fix it'),'Cancel and fix it')
                return;
            end
        end
        
        objects = []; %struct('frame', [], 'time', [], 'x', [], 'y', [], 'length', [], 'width', [], 'area', [], 'perimeter', [], 'eccentricity', [], 'speed', [], 'directionchange', [], 'behaviour', [], 'duration', []);
        
        firstobject = true;
        
        waitbarfps = 20; %CHANGEME: should be adjustable somehow
        
        waithandle = waitbar(0,'Thresholding and tracking...','Name','Processing', 'CreateCancelBtn', 'delete(gcbf)');
        
        if ~isnan(thresholdspeedmax) && thresholdspeedmax > 0
            distance2threshold = (thresholdspeedmax/scalingfactor/framerate)^2; %the threshold on (the square of) the centroid-displacements, in terms of pixels per frames
        else
            distance2threshold = Inf;
        end
        
        for i=1:lastframe
            
            if ishandle(waithandle) > 0
                if mod(i, waitbarfps) == 0
                    waitbar(i/lastframe, waithandle);
                end
            else
                break;
            end
            
            %fprintf('By frame %d we have %d objects altogether.\n', i, numel(objects));
            
            originalimage = readframe(i);
            thresholdedimage = thresholdimage(originalimage);
            labelledimage = bwlabel(thresholdedimage);
            
            if verLessThan('matlab', '7.8')
                thresholdedregions = regionprops(labelledimage,'Area'); %#ok<MRPBW>
            else
                thresholdedregions = regionprops(thresholdedimage,'Area');
            end
            
            allregionareas = vertcat(thresholdedregions.Area);
            goodregions = find(allregionareas >= thresholdsizemin/scalingfactor^2 & allregionareas <= thresholdsizemax/scalingfactor^2);
            thresholdedimage = ismember(labelledimage, goodregions); %keeping only the appropriately sized regions
            
            if verLessThan('matlab', '7.8')
                labelledimage = bwlabel(thresholdedimage);
                thresholdedregions = regionprops(labelledimage,'Centroid','Area','MinorAxisLength','MajorAxisLength','Perimeter','Eccentricity','Solidity', 'Orientation'); %#ok<MRPBW>
            else
                thresholdedregions = regionprops(thresholdedimage,'Centroid','Area','MinorAxisLength','MajorAxisLength','Perimeter','Eccentricity','Solidity', 'Orientation');
            end
            
            if i>1 && ~firstobject
                costmatrix = Inf(numel(thresholdedregions), numel(lastregions));
                for j=1:numel(thresholdedregions)
                    for k=1:numel(lastregions)
                        distance2 = (lastregions(k).x-thresholdedregions(j).Centroid(1))^2 + (lastregions(k).y-thresholdedregions(j).Centroid(2))^2;
                        if distance2 <= distance2threshold
                            costmatrix(j, k) = distance2;
                        end
                    end
                end
                
                assignment = assignmentoptimal(costmatrix); %Solving the across-frame assignment problem using the Hungarian algorithm
            else
                assignment = zeros(1, numel(thresholdedregions));
            end
            
            %assert(numel(thresholdedregions) == numel(assignment));

            for j=1:numel(thresholdedregions)
                if assignment(j) ~= 0
                    
                    objects(lastregions(assignment(j)).id).frame(end+1) = i;
                    objects(lastregions(assignment(j)).id).time(end+1) = converttotime(i);
                    objects(lastregions(assignment(j)).id).x(end+1) = thresholdedregions(j).Centroid(1);
                    objects(lastregions(assignment(j)).id).y(end+1) = thresholdedregions(j).Centroid(2);
                    objects(lastregions(assignment(j)).id).length(end+1) = thresholdedregions(j).MajorAxisLength;
                    objects(lastregions(assignment(j)).id).width(end+1) = thresholdedregions(j).MinorAxisLength;
                    objects(lastregions(assignment(j)).id).area(end+1) = thresholdedregions(j).Area;
                    objects(lastregions(assignment(j)).id).perimeter(end+1) = thresholdedregions(j).Perimeter;
                    objects(lastregions(assignment(j)).id).eccentricity(end+1) = thresholdedregions(j).Eccentricity;
                    objects(lastregions(assignment(j)).id).solidity(end+1) = thresholdedregions(j).Solidity;
                    objects(lastregions(assignment(j)).id).orientation(end+1) = thresholdedregions(j).Orientation;
                    objects(lastregions(assignment(j)).id).compactness(end+1) = thresholdedregions(j).Perimeter.^2./thresholdedregions(j).Area;
                    objects(lastregions(assignment(j)).id).speed(end+1) = realsqrt(costmatrix(j, assignment(j))) * framerate; %realsqrt of the costmatrix gives the instantaneous displacement across frames; multiplying it by the framerate is equivalent to dividing by the time-difference between successive frames
                    objects(lastregions(assignment(j)).id).behaviour(end+1) = CONST_BEHAVIOUR_UNKNOWN;
                    objects(lastregions(assignment(j)).id).target(end+1) = CONST_TARGET_NOMANSLAND;
                    objects(lastregions(assignment(j)).id).targetreached(end+1) = CONST_TARGET_NOMANSLAND;
                    objects(lastregions(assignment(j)).id).duration = objects(lastregions(assignment(j)).id).duration + 1;
                    thresholdedregions(j).id = lastregions(assignment(j)).id;
                    
                else
                    
                    if firstobject
                        objects(1).frame(1) = i;
                        firstobject = false;
                    else
                        objects(end+1).frame(1) = i; %#ok<AGROW>
                    end
                    
                    objects(end).time(1) = converttotime(i);
                    objects(end).x(1) = thresholdedregions(j).Centroid(1);
                    objects(end).y(1) = thresholdedregions(j).Centroid(2);
                    objects(end).length(1) = thresholdedregions(j).MajorAxisLength;
                    objects(end).width(1) = thresholdedregions(j).MinorAxisLength;
                    objects(end).area(1) = thresholdedregions(j).Area;
                    objects(end).perimeter(1) = thresholdedregions(j).Perimeter;
                    objects(end).eccentricity(1) = thresholdedregions(j).Eccentricity;
                    objects(end).solidity(1) = thresholdedregions(j).Solidity;
                    objects(end).orientation(1) = thresholdedregions(j).Orientation;
                    objects(end).compactness(1) = thresholdedregions(j).Perimeter.^2./thresholdedregions(j).Area;
                    objects(end).speed(1) = NaN;
                    objects(end).behaviour(1) = CONST_BEHAVIOUR_UNKNOWN;
                    objects(end).target(1) = CONST_TARGET_NOMANSLAND;
                    objects(end).targetreached(1) = CONST_TARGET_NOMANSLAND;
                    objects(end).duration = 1;
                    thresholdedregions(j).id = numel(objects);
                    
                end
            end
            
            lastregions = struct('x', [], 'y', [], 'id', []);
            for j=1:numel(thresholdedregions)
                lastregions(j).x = thresholdedregions(j).Centroid(1);
                lastregions(j).y = thresholdedregions(j).Centroid(2);
                lastregions(j).id = thresholdedregions(j).id;
            end
            
        end
        
        if ishandle(waithandle)
            close(waithandle);
        end
        
        for i=1:numel(objects)
            objects(i).directionchange = NaN(1, objects(i).duration);
            lastdirection = NaN;
            for j=2:objects(i).duration
                currentdirection = getabsoluteangle(objects(i).x(j-1), objects(i).y(j-1), objects(i).x(j), objects(i).y(j));
                objects(i).directionchange(j) = angledifference(lastdirection, currentdirection);
                lastdirection = currentdirection;
            end
        end
        
        timefrom = 0;
        timeuntil = lasttime;
        set(handles.timefrom, 'String', num2str(timefrom));
        set(handles.timeuntil, 'String', num2str(timeuntil));
        
        if isnan(wormshowframe)
            wormshowframe = 1;
        end
        
        %flashed = false(1, lastframe);
        
        set(handles.wormshowframeslider, 'Value', wormshowframe, 'Min',1,'Max',lastframe, 'SliderStep',[1/(lastframe-1) 10/(lastframe-1)]);
        set(handles.wormshowsettime, 'String',num2str(converttotime(wormshowframe)));
        set(handles.wormshowsetframe, 'String',num2str(wormshowframe));
        
        set(handles.scalingfactor, 'String', num2str(scalingfactor));
        
        recalculatemeanperimeter;
        wormshow;
        
    end

    function thresholded = thresholdimage (imagetothreshold)
        
        if numel(size(imagetothreshold)) == 3 && size(imagetothreshold, 3) == 3
            imagetothreshold = rgb2gray(imagetothreshold);
        end
        
        if ~any(detectionarea)
            thresholded = false(size(imagetothreshold));
            return
        end
        
        %CHANGEME
        %if exist('thresholdingfilter', 'var') == 1
            %imagetothreshold = imfilter(imagetothreshold, thresholdingfilter);
        %end
        %imagetothreshold = denoise(double(imagetothreshold), thresholdingfilter, 1, [0 3.6 0 1 5 0]); %passing a uint8 (instead of double) 2D image to denoise consistently caused segfaults
        %imagetothreshold = medfilt2(imagetothreshold, [3 3]);
        %gaussianfilter = fspecial('gaussian',[3,3],0.5); %Gaussian filter to help find continuous areas
        %imagetothreshold = imfilter(imagetothreshold, gaussianfilter);
        
        thresholded = imagetothreshold < thresholdintensity; %im2bw has trouble with floating-point intensity values, so we'll just threshold directly
        thresholded(~detectionarea) = false;
        
        %disklike = strel('disk', 1, 4); %structuring element used for erosion and dilation ([0 1 0; 1 1 1; 0 1 0])
        thresholded = imerode(imdilate(thresholded, disklike), disklike); 
        
    end

    function readmovie(hobj, eventdata) %#ok<INUSD>
        
        if isempty(selectedfiles)
            questdlg('You must navigate to a folder that contains movie files, and select at least one of them to be read', 'No movie selected', 'OK', 'OK');
            return;
        end
        
        set(handles.read, 'String', 'Reading movie...');
        drawnow;
        
        lastframe = NaN;
        lasttime = NaN;
        framerate = NaN;
        lasttime = -1;
        wormshowframe = 1;
        objects = [];
        
        %clearing cache
        cachedframe = [];
        cachedindex = NaN;
        moviecache = struct('data', []);
        
        moviereaderobjects = struct([]);
        closeqtobjects;
        closetiffobjects;
        avireadworks = false;
        
        movieindicator = []; %This way if the movie doesn't cover the whole range of frames, we'll get NaN as the return value when we try to access the frame for which there's no movie
        frameindicator = []; %This way if the movie doesn't cover the whole range of frames, we'll get NaN as the return value when we try to access the frame for which there's no movie
        numberofchannels = 1;
        readwhichchannel = 1;
        totalduration = NaN(1, numel(selectedfiles));
        nf = NaN(1, numel(selectedfiles)); %number of frames
        
        readerfailuredisplayed = false(1, numel(selectedfiles));
        
        flashed = [];
        flashintensities = []; %#ok<NASGU>
        flashx = NaN;
        flashy = NaN;
        
        gradnormmatrix = [];
        gradnorm = false;
        timenorm = false;
        set(handles.gradnorm, 'Value', gradnorm);
        set(handles.timenorm, 'Value', timenorm);
        
        for i=1:numel(selectedfiles)
            
            currentfullfile = fullfile(directory,selectedfiles{i}); %filename of the movie we're currently reading, including full path

            autoloaded = []; %clearing it so that we know if it is empty, it means that no framerate data could be autoloaded for this particular movie
            if get(handles.trytoloadfps, 'Value')
                if (exist([selectedfiles{i} '-framerate.mat'], 'file') ~= 0) %If framerate file exists
                    try
                        autoloaded = load([selectedfiles{i} '-framerate.mat'], 'goodframe', 'framerate'); %goodframe means last valid frame in the movie ("badframe" (later) means the first invalid frame number (i.e. number of frames + 1))
                        nf(i) = autoloaded.goodframe;
                        framerate = autoloaded.framerate;
                    catch %#ok<CTCH>
                        fprintf(2, 'Warning: could not read the framerate or the valid frame number from the framerate savefile. Rechecking these values for the movie %s ...\n', selectedfiles{i});
                    end
                end
            end
            
            currentframerate = [];
            currentnumberofframes = 0;
            successfullyread = false;
            
            if strcmpi(currentfullfile(end-3:end), '.nd2')
                if ~successfullyread
                    try
                        bfreaders(end+1).server = bfGetReader(currentfullfile); %#ok<AGROW>
                        bfreaders(end).filename = selectedfiles{i};
                        nf(i) = bfreaders(end).server.getSizeT;
                        moviewidth = bfreaders(end).server.getSizeX;
                        movieheight = bfreaders(end).server.getSizeY;
                        numberofchannels = bfreaders(end).server.getSizeC;
                        currentnumberofframes = nf;
                        currentframerate = NaN;
                        while isempty(currentframerate) || isnan(currentframerate)
                            answerstring = inputdlg('Specify frame rate (FPS):', 'Unknown frame rate', 1, {''}, 'on');
                            currentframerate = str2double(answerstring);
                            if isempty(answerstring) %the user clicked cancel
                                error('Canceled frame rate specification');
                            end
                        end
                        framerate = currentframerate;
                        totalduration(i) = nf(i)/currentframerate;
                        if numberofchannels > 1
                            readwhichchannel = NaN;
                            while isempty(readwhichchannel) || isnan(readwhichchannel)
                                answerstring = inputdlg(sprintf('There appear to be %d channels in this movie. Specify which channel to read', numberofchannels), 'Channel selection', 1, {'1'}, 'on');
                                readwhichchannel = str2double(answerstring);
                                if isempty(answerstring) %the user clicked cancel
                                    error('Canceled channel selection');
                                end
                            end
                        end
                        successfullyread = true;
                    catch err
                        try
                            bfreaders(end).close;
                        catch
                        end
                        bfreaders = bfreaders(1:end-1);
                        numberofchannels = 1;
                        readwhichchannel = 1;
                        fprintf('Opening the movie %s using bfreader failed.\n', selectedfiles{i});
                        fprintf('%s\n', err.message);
                        fprintf('Attempting to open the movie using another method...\n');
                    end
                end
            end
            
            if strcmpi(currentfullfile(end-3:end), '.tif') || strcmpi(currentfullfile(end-4:end), '.tiff')
                if ~tiffserveravailable
                    fprintf('Warning: TIFFServer.jar was not found in the Matlab paths. This will probably result in the tiff file not being read correctly. Attempting to proceed anyway for now, but ideally, make sure that TIFFServer.jar is available.\n');
                else
                    if ~successfullyread
                        try
                            tiffservers(end+1).server = util.TIFFServer; %#ok<AGROW> %having an array of objects causes problems because by declaring it at the start of the program (to give it a greater scope) produces an array of doubles, which is incompatible with these objects. so instead we'll declare a structure, each element of which can have an object
                            tiffservers(end).server.open(currentfullfile);
                            tiffservers(end).filename = selectedfiles{i};
                            currentframerate = NaN; %could only try to get frame rate from custom tiff tags, but we don't know where to look
                            currentnumberofframes = tiffservers(end).server.getImageCount();
                            nf(i) = currentnumberofframes; %Robin's TIFFServer supposedly always returns the correct number of frames
                            %we'll delay setting totalduration until the user confirms the framerate, because if user changes the framerate, that would make the apparent totalduration different (because what we know for sure is the number of frames, not the duration in seconds
                            moviesize = double(tiffservers(end).server.getSize());
                            moviewidth = moviesize(2);
                            movieheight = moviesize(1);
                            successfullyread = true;
                            fprintf('Movie %s opened successfully using TIFFServer.\n', selectedfiles{i});
                        catch, err = lasterror; %#ok<CTCH,LERR> %catch err would be nicer, but that doesn't work on older versions of Matlab
                            if ~isempty(tiffservers) && isfield(tiffservers(end), 'server') && (~isfield(tiffservers(end), 'filename') || strcmp(tiffservers(end).filename, selectedfiles{i})) %if we've managed to create the TIFFServer for this file, but still had an error,
                                try %try to close the stream, but don't worry if closing fails (because closing may fail because opening failed in the first place)
                                    tiffservers(end).server.close;
                                catch %#ok<CTCH>
                                end
                                tiffservers = tiffservers(1:end-1); %we'll remove this TIFFServer instance that produced the error
                                fprintf('Opening the movie %s using TIFFServer failed.\n', selectedfiles{i});
                                fprintf('%s\n', err.message);
                                fprintf('Attempting to open the movie using another method...\n');
                            end
                        end
                    end
                end
            end
            
            if ~(ispc && strcmpi(currentfullfile(end-3:end), '.mov')) %reading of quicktime movies is not supported on Windows, and in my experience can sometimes cause the wrong frames to be displayed (when not all frames are cached, which we cannot ensure), so we'll fall back to other options, probably mmread
                if ~successfullyread
                    try
                        moviereaderobjects(end+1).reader = VideoReader(currentfullfile); %#ok<AGROW> %having an array of objects causes problems because by declaring it at the start of the program (to give it a greater scope) produces an array of doubles, which is incompatible with these objects. so instead we'll declare a structure, each element of which can have an object
                        totalduration(i) = get(moviereaderobjects(end).reader, 'Duration');
                        currentframerate = get(moviereaderobjects(end).reader, 'FrameRate');
                        currentnumberofframes = get(moviereaderobjects(end).reader, 'NumberOfFrames');
                        moviewidth = get(moviereaderobjects(end).reader, 'Width');
                        movieheight = get(moviereaderobjects(end).reader, 'Height');
                        successfullyread = true;
                        fprintf('Movie %s opened successfully using VideoReader.\n', selectedfiles{i});
                    catch %#ok<CTCH>
                        if ~isempty(moviereaderobjects) && isfield(moviereaderobjects(end), 'reader') && strcmp(get(moviereaderobjects(end).reader, 'Name'), selectedfiles{i}) %if we've managed to create the moviereaderobject for this file, but still had an error,
                            moviereaderobjects = moviereaderobjects(1:end-1); %we'll remove this moviereaderobject that produced an error
                        end
                    end
                end

                if ~successfullyread
                    try
                        lastwarn('');
                        warning('off', 'MATLAB:mmreader:unknownNumFrames'); %we'll get the number of frames ourselves anyway, so this warning is not really relevant
                        moviereaderobjects(end+1).reader = mmreader(currentfullfile); %#ok<AGROW>
                        warning('on', 'MATLAB:mmreader:unknownNumFrames');
                        if ~isempty(lastwarn) && ~cachemovie %mmreader doesn't understand the number of frames, so the wrong frames may be displayed when we try to read single frames using it, but if we're caching the whole movie at once with mmreader, then apparently it's fine even if it doesn't understand the number of frames
                            error('MATLAB:mmreader:unknownNumFrames', lastwarn);
                        end
                        totalduration(i) = get(moviereaderobjects(end).reader, 'Duration');
                        currentframerate = get(moviereaderobjects(end).reader, 'FrameRate');
                        currentnumberofframes = get(moviereaderobjects(end).reader, 'NumberOfFrames');
                        moviewidth = get(moviereaderobjects(end).reader, 'Width');
                        movieheight = get(moviereaderobjects(end).reader, 'Height');
                        successfullyread = true;
                        fprintf('Movie %s opened successfully using mmreader.\n', selectedfiles{i});
                    catch %#ok<CTCH>
                        if ~isempty(moviereaderobjects) && isfield(moviereaderobjects(end), 'reader') && strcmp(get(moviereaderobjects(end).reader, 'Name'), selectedfiles{i}) %if we've managed to create the moviereaderobject for this file, but still had an error,
                            moviereaderobjects = moviereaderobjects(1:end-1); %we'll remove this moviereaderobject that produced an error
                        end
                    end
                end
            end
            
            triedaviread = false;
            triedmmread = false;
            triedqtreader = false;
            delayforqtreader = false;
            if strcmpi(currentfullfile(end-3:end), '.mov') %if the current file is a mov, we'll try Robin's QTFrameServer first before the other options, otherwise (for non-movs) it's the last option
                delayforqtreader = true;
            end
            
            while ~ (successfullyread || (triedaviread && triedmmread && triedqtreader))
                
                clear video;
                if ~successfullyread && ~delayforqtreader && ~triedaviread
                    try
                        triedaviread = true;
                        movieinfo = mmfileinfo(currentfullfile);
                        totalduration(i) = movieinfo.Duration;
                        currentframerate = NaN;
                        currentnumberofframes = NaN;
                        moviewidth = movieinfo.Video.Width;
                        movieheight = movieinfo.Video.Height;
                        video = aviread(currentfullfile, 1); %both attempting to actually read a frame to test if aviread works, and also getting the frame data that could be used later to determine the range of intensity values pixels can take
                        successfullyread = true;
                        avireadworks = true;
                        fprintf('Movie %s opened successfully using aviread.\n', selectedfiles{i});
                    catch %#ok<CTCH>
                        clear video;
                        avireadworks = false;
                    end
                end

                if ~successfullyread && ~delayforqtreader && ~triedmmread
                    try
                        triedmmread = true;                       
                        [video, audio] = mmread(currentfullfile, 1); %#ok<NASGU>
                        totalduration(i) = video.totalDuration;
                        currentframerate = video.rate;
                        currentnumberofframes = video.nrFramesTotal;
                        moviewidth = video.width;
                        movieheight = video.height;
                        successfullyread = true;
                        fprintf('Movie %s opened successfully using mmread.\n', selectedfiles{i});
                    catch %#ok<CTCH>
                        clear video;
                    end
                end

                delayforqtreader = false;
                if ~successfullyread && qtserveravailable && ~triedqtreader
                    try
                        triedqtreader = true;
                        qtreaders(end+1).server = util.QTFrameServer(currentfullfile); %#ok<AGROW> %having an array of objects causes problems because by declaring it at the start of the program (to give it a greater scope) produces an array of doubles, which is incompatible with these objects. so instead we'll declare a structure, each element of which can have an object
                        qtreaders(end).filename = selectedfiles{i};
                        currentframerate = qtreaders(end).server.getFrameRate();
                        currentnumberofframes = qtreaders(end).server.getLength();
                        nf(i) = currentnumberofframes; %Robin's QTFrameServer supposedly always returns the correct number of frames
                        %we'll delay setting totalduration until the user confirms the framerate, because if user changes the framerate, that would make the apparent totalduration different (because what we know for sure is the number of frames, not the duration in seconds
                        moviesize = double(qtreaders(end).server.getSize());
                        moviewidth = moviesize(2);
                        movieheight = moviesize(1);
                        successfullyread = true;
                        fprintf('Movie %s opened successfully using QTFrameServer.\n', selectedfiles{i});
                    catch %#ok<CTCH>
                        if ~isempty(qtreaders) && isfield(qtreaders(end), 'server') && (~isfield(qtreaders(end), 'filename') || strcmp(qtreaders(end).filename, selectedfiles{i})) %if we've managed to create the QTFrameServer for this file, but still had an error,
                            try %try to close the stream, but don't worry if closing fails (because closing may fail because opening failed in the first place)
                                qtreaders(end).server.close;
                            catch %#ok<CTCH>
                            end
                            qtreaders = qtreaders(1:end-1); %we'll remove this QTFrameServer instance that produced the error
                        end
                    end
                end
                
            end
            
            if ~successfullyread && triedaviread && triedmmread && triedqtreader
                error('Could not read the movie by any available method.');
            end
            
            %we only need to get the maximal pixel value and the frame size once
            if i==1
                if exist('video', 'var') == 1
                    if isfield(video, 'frames')
                        firstframe = video.frames(1).cdata;
                    else
                        firstframe = video.cdata;
                    end
                else
                    if ~isempty(qtreaders) && isfield(qtreaders(end), 'server') && strcmp(qtreaders(end).filename, selectedfiles{i})
                        firstframe = uint8(qtreaders(end).server.getBW(1));
                    elseif ~isempty(tiffservers) && isfield(tiffservers(end), 'server') && strcmp(tiffservers(end).filename, selectedfiles{i})
                        firstframe = tiffservers(end).server.getImage(1);
                        if ~strcmpi(class(firstframe), 'double') && ~strcmpi(class(firstframe), 'single') && intmax(class(firstframe)) > intmax('uint16')
                            firstframe = uint16(firstframe);
                        end
                    elseif ~isempty(bfreaders) && isfield(bfreaders(end), 'server') && strcmp(bfreaders(end).filename, selectedfiles{i})
                        firstframe = bfGetPlane(bfreaders(end).server, readwhichchannel);
                    else
                        firstframe = read(moviereaderobjects(end).reader, 1);
                    end
                end
                if strcmpi(class(firstframe), 'double') || strcmpi(class(firstframe), 'single')
                    pixelmax = realmax(class(firstframe));
                elseif ~isempty(strfind(class(firstframe), 'int'))
                    pixelmax = intmax(class(firstframe));
                else
                    fprintf(2, 'Warning: cannot determine the class of the image data; assuming uint8...\n');
                    pixelmax = 255;
                end
                
                brightestpixel = max(firstframe(:));
                if brightestpixel > pixelmax
                    fprintf(2, 'Warning: a pixel intensity (%f) was higher than the detected maximum (%d). Adjusting maximal pixel intensity to ', brightestpixel, pixelmax);
                    pixelmax = 2^ceil(log2( brightestpixel ))-1; %the next power of 2 above it
                    fprintf(2, '%d .\n', pixelmax);
                end
                
                pixelmax = double(pixelmax); %Annoyingly, if pixelmax is an integer (which is possible if using the return value from one of the builtin functions), then thresholdintensity/pixelmax threshold value would also be integer, meaning either 0 or 1
                
                detectionarea = false(movieheight, moviewidth);
                measurementarea = false(movieheight, moviewidth);
                startingarea = false(movieheight, moviewidth);
                endingarea = false(movieheight, moviewidth);
                [meshx, meshy] = meshgrid(1:moviewidth,1:movieheight);
            end
            
        end
        
        cancelling = false;
        
        if isempty(framerate) || isnan(framerate)
            %Asking for user confirmation of the frame rate
            userrate = currentframerate;
            enteringfirst = true;
            while enteringfirst || isnan(framerate)
                enteringfirst = false;
                if isnan(userrate)
                    userratestring = '';
                else
                    userratestring = num2str(userrate);
                end
                userrate = inputdlg('Frame rate (FPS):', 'Enter the frame rate', 1, {userratestring}, 'on');
                userrate = str2double(userrate);
                if isempty(userrate) %the user clicked cancel
                    cancelling = true;
                    break;
                elseif userrate > 0
                    framerate = userrate;
                end
            end
        end
        
        for i=1:numel(selectedfiles)
            if ~checknf && ~isempty(currentframerate) && ~isnan(currentframerate) %if we don't want to have to check the number of frames, and the framerate value exists
                framerate = currentframerate;
                if currentnumberofframes > 0
                    nf(i) = currentnumberofframes;
                else
                    nf(i) = round(totalduration(i)*framerate);
                end
            end

            %If, for example, QTFrameServer or TIFFServer is used for reading, we may not get totalduration(i) but do get currentnumberofframes and framerate
            if (isempty(totalduration(i)) || isnan(totalduration(i)))
                totalduration(i) = currentnumberofframes / framerate; %totalduration is only used for guessing the real number of frames, so it's not a big issue if it's not always perfectly accurate
            end
        end

        if any(isnan(nf(:))) && ~cancelling %if there are movies with still unknown number of frames (and not because the user cancelled), we'll tell the user that we're checking the number of frames
            waitfigure = figure('Name','Reading...','NumberTitle','off', ...
                'Visible','on','Color',get(0,'defaultUicontrolBackgroundColor'), 'Units','Normalized',...
                'DefaultUicontrolUnits','Normalized','Toolbar', 'none', 'MenuBar', 'none');
            waitpanel = uipanel(waitfigure,'Units','Normalized',...
                'DefaultUicontrolUnits','Normalized','Position',[0.00 0.00 1.00 1.00]);
            waittext = uicontrol(waitpanel,'Style','Text','String',{'Verifying the number of frames in the movie.', 'Please wait...'},'HorizontalAlignment','center','Fontsize', 20,'Position',[0.00 0.70 1.00 0.30]);
            waitnote = uicontrol(waitpanel,'Style','Text','String','','HorizontalAlignment','center','Fontsize', 12,'Position',[0.00 0.40 1.00 0.20]);
            drawnow;
        else
            waitfigure = NaN;
        end
        
        %verifying the number of frames that are in the movie (bah, but necessary for the stupid quicktime mov files where neither mmreader nor mmread knows the actual number for sure!)
        if ~cancelling
            for i=1:numel(selectedfiles)
                
                if isnan(nf(i))
                    for j=1:numel(moviereaderobjects)
                        if strcmp(get(moviereaderobjects(j).reader, 'Name'), selectedfiles{i})
                            currentnumberofframes = get(moviereaderobjects(j).reader, 'NumberOfFrames');
                            if isempty(currentnumberofframes) || isnan(currentnumberofframes) || currentnumberofframes == 0 %if the reader didn't know the number of frames in the movie, we'll try one more thing...
                                try
                                    read(moviereaderobjects(j).reader, Inf); %forcing a read of the last frame, which will hopefully make the movie reader realize the number of frames in the movie
                                    currentnumberofframes = get(moviereaderobjects(j).reader, 'NumberOfFrames'); %perhaps the movie reader will now know the actual number of frames
                                catch %#ok<CTCH>
                                    currentnumberofframes = NaN;
                                end
                            end
                            if isempty(currentnumberofframes) || isnan(currentnumberofframes) || currentnumberofframes == 0 %if we still don't have the number of frames in the movie, then we're forced to use other options to check it (because mmreader for some weird reason with certain quicktime movies can return the last frame of the movie without an error when asked for a frame beyond the last frame)
                                fprintf(2, 'Warning: %s could not figure out the number of frames in the movie %s. Trying to check it with other movie readers...\n', get(moviereaderobjects(j).reader, 'Type'), selectedfiles{i});
                            else %if currentnumberofframes is an actual good value,
                                nf(i) = currentnumberofframes; %then we'll accept that as the number of frames and proceed to the next moive
                            end
                            break;
                        end
                    end
                end
                
                if isnan(nf(i))
                    nf(i) = round(totalduration(i)*framerate); %a first guess for the number of frames in the movie
                    
                    goodframe = NaN;
                    badframe = NaN;
                    nextframetocheck = nf(i); %we will seek forwards from this frame in case this frame exists ("good"), or in the reverse direction in case this frame didn''t exist ("bad") in order to find the last frame definitively
                    
                    howfaroff = -1;
                    
                    while isnan(goodframe) || isnan(badframe)
                        
                        set(waittext, 'String',{'Verifying the number of frames in the movie...', sprintf('Checking frame %d...', nextframetocheck)});
                        set(waitnote, 'String', sprintf('If %d is unrealistically small or large compared to the approximate number of frames in the movie "%s", you might want to cancel by closing this window, and to make sure to enter the frame rate correctly in the previous step.', nextframetocheck, char(selectedfiles{i})));
                        drawnow;
                        
                        howfaroff = howfaroff + 1;
                        
                        try
                            lastwarn(''); %clearing lastwarn so that in the next step if lastwarn is set, we know it's a new warning from the movie reader
                            warningstatenormal = warning('query', 'all'); %storing the current (normal) warning state (i.e. which warnings to display)
                            warning('off','all'); %telling Matlab not to display the potentially coming warning (when reading beyond the last frame) because it's excepted and normal. Lastwarn, however, will still be updated (which is what we want).
                            if avireadworks
                                frametobediscarded = aviread(fullfile(directory,selectedfiles{i}), nextframetocheck); %#ok<NASGU>
                            else
                                %warning('off','mmread:general'); 
                                mmread(fullfile(directory,selectedfiles{i}), nextframetocheck);
                                %warning('on', 'mmread:general'); 
                            end
                            warning(warningstatenormal); %restoring the normal display of warnings because we don't expect any more
                            if ~isempty(lastwarn) %with newer versions of Matlab, when mmread tries to read a frame that doesn't exist, we only get a warning, so we force it to throw it as an error instead to make the behaviour consistent across versions (since we determine that we reached the last frame by the error that's thrown when we try to read beyond it)
                                error(lastwarn);
                            end
                            managedtoread = true;
                        catch %#ok<CTCH>
                            managedtoread = false;
                        end
                        
                        if ~managedtoread
                            badframe = nextframetocheck;
                        else
                            goodframe = nextframetocheck;
                        end
                        
                        if ~isnan(goodframe) && isnan(badframe)
                            nextframetocheck = nextframetocheck + 1;
                        elseif ~isnan(badframe) && isnan(goodframe)
                            nextframetocheck = nextframetocheck - 1;
                        end
                        
                        if ~ishandle(waitfigure)
                            cancelling = true;
                            break;
                        end
                        
                    end

                    if cancelling
                        break;
                    end
                    
                    assert(goodframe+1==badframe, 'Error: could not find the last frame of the movie.\n');
                    
                    nf(i) = goodframe;
                    
                end

                movieindicator(end+1:end+nf(i)) = i;
                frameindicator(end+1:end+nf(i)) = readwhichchannel:numberofchannels:nf(i)*numberofchannels;
                moviefiles(i) = selectedfiles(i);
                
                goodframe = nf(i);
                if isempty(autoloaded) || (framerate ~= autoloaded.framerate || goodframe ~= autoloaded.goodframe) %if nothing was autoloaded, or if the framerate or valid frame number changed from the one that was autoloaded, save the framerate and the valid frame number
                    save([selectedfiles{i} '-framerate.mat'], 'goodframe', 'framerate');
                end
            end
        end
        
        if ~cancelling %here we need to check again whether we're cancelling because the user could have clicked cancel during frame number verification
            lastframe = sum(nf(:));
            lasttime = (lastframe-1)/framerate;
            timefrom = 0;
            timeuntil = lasttime;
            set(handles.timefrom, 'String', num2str(timefrom));
            set(handles.timeuntil, 'String', num2str(timeuntil));

            if isnan(wormshowframe)
                wormshowframe = 1;
            end
        
            set(handles.wormshowframeslider, 'Value', wormshowframe, 'Min',1,'Max',lastframe, 'SliderStep',[1/(lastframe-1) 10/(lastframe-1)]);
            set(handles.wormshowsettime, 'String',num2str(converttotime(wormshowframe)));
            set(handles.wormshowsetframe, 'String',num2str(wormshowframe));
            
            if cachemovie
                if ~isempty(tiffservers) && isfield(tiffservers(end), 'server') && strcmp(tiffservers(end).filename, selectedfiles{i})
                    fprintf('Movie %s appears to be a tiff stack, caching of which would result in no benefit. Skipping the caching step...\n', selectedfiles{i});
                else
                    fprintf('Caching movie...\n');
                    set(handles.read, 'String', 'Caching movie...');
                    drawnow;
                    errormessage = [];
                    moviecache = struct('data', []);
                    whichmoviecached = NaN;
                    for i=1:lastframe
                        try

                            if movieindicator(i) ~= whichmoviecached %we need to actually read the movie

                                clear videocachedO videocachedM audio %freeing space

                                successfullyread = false;

                                currentreaderobject = 0;
                                for j=1:numel(moviereaderobjects) %trying to see if we've already set up a movie reader object for this file
                                    if strcmp(moviefiles{movieindicator(i)}, get(moviereaderobjects(j).reader, 'Name'))
                                        currentreaderobject = j;
                                        break;
                                    end
                                end
                                if currentreaderobject ~= 0 %if we've managed to find a movie reader object
                                    try %mmreader can sometimes be overeager in throwing out-of-memory errors (maybe because sometimes it doesn't recognise how many actual frames are in the movie? or because it tries to reserve a continuous contiguous block of memory?), so we'll double check the available memory ourselves
                                        videocachedO = read(moviereaderobjects(currentreaderobject).reader, [1 nf(movieindicator(i))]);
                                        successfullyread = true;
                                    catch, readererror = lasterror; %#ok<CTCH,LERR> %catch readererror would be nicer, but that doesn't work on older versions of Matlab
                                        if ~isempty(strfind(readererror.identifier, 'notEnoughMemory'))
                                            mem = memory;
                                            if exist('firstframe', 'var') ~= 1
                                                firstframe = read(moviereaderobjects(currentreaderobject).reader, 1); %#ok<NASGU>
                                            end
                                            firstframedetails = whos('firstframe');
                                            availablememory = mem.MemAvailableAllArrays; %apparently, reading the entire movie and storing the results not in a single high-dimensional array, but in a vector of structures (representing the frames through time) containing one array each (representing the contents of the frames), the way mmread does, the data structure doesn't count as a single array so we can use all available memory instead of the largest contiguous block
                                            neededmemory = nf(movieindicator(i))*firstframedetails.bytes;
                                            if neededmemory > availablememory %we really don't have enough memory, so let the user know that the movie cannot be cached
                                                rethrow(readererror);
                                            else %we may still be able to read it with other options
                                            end
                                        else %not a memory-related error, so let's try falling back to other options
                                        end
                                    end
                                end

                                if ~successfullyread && qtserveravailable
                                    currentqtreaderobject = 0;
                                    for j=1:numel(qtreaders)
                                        if strcmp(moviefiles{movieindicator(i)}, qtreaders(j).filename)
                                            currentqtreaderobject = j;
                                            break;
                                        end
                                    end
                                    if currentqtreaderobject ~= 0
                                        %videocachedM(1:nf(movieindicator(i))) = struct('cdata', uint8(NaN(movieheight, moviewidth))); %this does not actually improve speed at all
                                        for j=1:nf(movieindicator(i))
                                            videocachedM(j).cdata = uint8(qtreaders(currentqtreaderobject).server.getBW(j)); %#ok<AGROW>
                                        end
                                        successfullyread = true;
                                    end
                                end

                                if ~successfullyread && avireadworks %otherwise fall back to aviread, if available
                                    videocachedM = aviread((fullfile(directory,moviefiles{movieindicator(i)})));
                                    successfullyread = true;
                                end

                                if ~successfullyread %otherwise fall back to mmread as a last resort
                                    [videocachedM, audio] = mmread(fullfile(directory,moviefiles{movieindicator(i)}), 1:nf(movieindicator(i))); %#ok<NASGU>
                                end
                                whichmoviecached = movieindicator(i);
                            end

                            if exist('videocachedO', 'var') == 1
                                if numel(size(videocachedO)) >= 3 && size(videocachedO, 3) == 3
                                    moviecache(i).data = rgb2gray(videocachedO(:, :, :, frameindicator(i)));
                                else
                                    moviecache(i).data = videocachedO(:, :, frameindicator(i));
                                end
                            elseif exist('videocachedM', 'var') == 1
                                if isfield(videocachedM, 'frames')
                                    if numel(size(videocachedM.frames(frameindicator(i)).cdata)) >= 3 && size(videocachedM.frames(frameindicator(i)).cdata, 3) == 3
                                        moviecache(i).data = rgb2gray(videocachedM.frames(frameindicator(i)).cdata);
                                    else
                                        moviecache(i).data = videocachedM.frames(frameindicator(i)).cdata;
                                    end
                                else
                                    if numel(size(videocachedM(frameindicator(i)).cdata)) >= 3 && size(videocachedM(frameindicator(i)).cdata, 3) == 3
                                        moviecache(i).data = rgb2gray(videocachedM(frameindicator(i)).cdata);
                                    else
                                        moviecache(i).data = videocachedM(frameindicator(i)).cdata;
                                    end
                                end
                            else
                                error('Error: could not find frame to be cached.');
                            end

                        catch, cachingerror = lasterror; %#ok<CTCH,LERR> %catch cachingerror would be nicer, but that doesn't work on older versions of Matlab
                            clear videocachedO videocachedM audio
                            moviecache = struct('data', []);
                            errormessage = 'Warning: could not cache movie';
                            if ~isempty(strfind(cachingerror.identifier, 'nomem')) || ~isempty(strfind(cachingerror.identifier, 'notEnoughMemory'))
                                errormessage = [errormessage ' because there does not appear to be enough memory available for this program']; %#ok<AGROW>
                            end
                            errormessage = [errormessage '. You can still analyse the movie without caching it.']; %#ok<AGROW>
                            cachemovie = false;
                            set(handles.cachemovie, 'Value', cachemovie);
                            fprintf(2, '%s\n', cachingerror.message);
                            questdlg(errormessage, 'Unable to cache movie', 'OK', 'OK');

                            %checking to see if mmreaders know the number of frames in the movies. If not, they should be removed, because they might return the wrong frames.
                            moviereaderobjectsgood = true(1, numel(moviereaderobjects));
                            for j=1:numel(moviereaderobjects) 
                                if strcmpi(get(moviereaderobjects(j).reader, 'Type'), 'mmreader')
                                    currentnumberofframes = get(moviereaderobjects(j).reader, 'NumberOfFrames');
                                    if isempty(currentnumberofframes) || isnan(currentnumberofframes)
                                        moviereaderobjectsgood(j) = false;
                                    end
                                end
                            end
                            moviereaderobjects = moviereaderobjects(moviereaderobjectsgood);

                            break;
                        end

                    end
                    if isempty(errormessage)
                        fprintf('Movie cached successfully.\n');
                    end
                end
            end
            
            if ishandle(waitfigure)
                delete(waitfigure);
            end
            
        else %if the user cancelled the reading, then we need to clear the currently semi-loaded movies
            framerate = NaN;
            scalingfactor = 1;
            lastframe = NaN;
            lasttime = NaN;
            wormshowframe = 1;
            objects = [];
            movieindicator = []; %This way if the movie doesn't cover the whole range of frames, we'll get NaN as the return value when we try to access the frame for which there's no movie
            frameindicator = []; %This way if the movie doesn't cover the whole range of frames, we'll get NaN as the return value when we try to access the frame for which there's no movie
        end

        clear videocachedO videocachedM audio;

        set(handles.read, 'String', 'Read movie');
        
        wormshow;
    end
    
    function getobject (hobj, eventdata) %#ok<INUSD>
        [x, y] = zinput('crosshair');
        
        closestid = NaN;
        closestdistance = Inf;
        for i=1:numel(objects)
            frameindex = find(objects(i).frame==wormshowframe); %the object's index of the frame we want to look at
            if ~isempty(frameindex)
                currentdistance = realsqrt( (objects(i).x(frameindex) - x)^2 + (objects(i).y(frameindex) - y)^2 );
                if currentdistance < closestdistance
                    closestid = i;
                    closestdistance = currentdistance;
                end
            end
        end
        
        if ~isnan(closestid)
            wormid = closestid;
            set(handles.wormid, 'String', num2str(wormid));
            allobjects = false;
            set(handles.allobjects, 'Value', allobjects);
        end
    end

    %{
    function setwormid (hobj, eventdata) 
        
        changeinto = str2double(get(handles.setid, 'String'));
        
        if timefrom < objects(wormid).time(1)
            currentframefrom = 1;
        elseif timefrom > objects(wormid).time(end)
            currentframefrom = NaN;
        else
            currentframefrom = find(objects(wormid).time==timefrom);
        end
        if timeuntil > objects(wormid).time(end)
            currentframeuntil = numel(objects(wormid).time);
        elseif timeuntil < objects(wormid).time(1)
            currentframeuntil = NaN;
        else
            currentframeuntil = find(objects(wormid).time==timeuntil);
        end
        
        if ~isnan(changeinto) && changeinto ~= 0 && ~isnan(wormid) && wormid ~= 0 && ~isempty(currentframefrom) && ~isnan(currentframefrom) && ~isempty(currentframeuntil) && ~isnan(currentframeuntil)
            
            reachframe = [];
            
            if objects(changeinto).frame(end) < objects(wormid).frame(currentframeuntil) %changeinto followed by wormid
                reachframe(end+1) = objects(wormid).frame(currentframeuntil);
            end
            if objects(changeinto).frame(1) > objects(wormid).frame(currentframefrom)
                reachframe(end+1) = objects(wormid).frame(currentframefrom);
            end
            
            while ~isempty(reachframe)
                if reachframe(1) < objects(changeinto).frame(1)
                    framestoadd = objects(changeinto).frame(1)-reachframe(1);
                    objects(changeinto).frame = [reachframe(1):objects(changeinto).frame(1)-1, objects(changeinto).frame];
                    objects(changeinto).time = [converttotime(reachframe(1)):1/framerate:objects(changeinto).time(1)-1/framerate, objects(changeinto).time];
                    objects(changeinto).x = [NaN(1, framestoadd), objects(changeinto).x];
                    objects(changeinto).y = [NaN(1, framestoadd), objects(changeinto).y];
                    objects(changeinto).length = [NaN(1, framestoadd), objects(changeinto).length];
                    objects(changeinto).width = [NaN(1, framestoadd), objects(changeinto).width];
                    objects(changeinto).area = [NaN(1, framestoadd), objects(changeinto).area];
                    objects(changeinto).perimeter = [NaN(1, framestoadd), objects(changeinto).perimeter];
                    objects(changeinto).speed = [NaN(1, framestoadd), objects(changeinto).speed];
                    objects(changeinto).directionchange = [NaN(1, framestoadd), objects(changeinto).directionchange];
                    objects(changeinto).behaviour = [ones(1, framestoadd)*CONST_BEHAVIOUR_INVALID, objects(changeinto).behaviour];
                    reachframe = reachframe(2:end);
                elseif reachframe(1) > objects(changeinto).frame(end)
                    framestoadd = reachframe(1)-objects(changeinto).frame(end);
                    objects(changeinto).frame = [objects(changeinto).frame, objects(changeinto).frame(end)+1:reachframe(1)];
                    objects(changeinto).time = [objects(changeinto).time, objects(changeinto).time(end)+1/framerate:1/framerate:converttotime(reachframe(1))];
                    objects(changeinto).x = [objects(changeinto).x, NaN(1, framestoadd)];
                    objects(changeinto).y = [objects(changeinto).y, NaN(1, framestoadd)];
                    objects(changeinto).length = [objects(changeinto).length, NaN(1, framestoadd)];
                    objects(changeinto).width = [objects(changeinto).width, NaN(1, framestoadd)];
                    objects(changeinto).area = [objects(changeinto).area, NaN(1, framestoadd)];
                    objects(changeinto).perimeter = [objects(changeinto).perimeter, NaN(1, framestoadd)];
                    objects(changeinto).speed = [objects(changeinto).speed, NaN(1, framestoadd)];
                    objects(changeinto).directionchange = [objects(changeinto).directionchange, NaN(1, framestoadd)];
                    objects(changeinto).behaviour = [objects(changeinto).behaviour, ones(1, framestoadd)*CONST_BEHAVIOUR_INVALID];
                    reachframe = reachframe(2:end);
                end
            end
            
            framestodelete = [];
            
            for j=currentframefrom:currentframeuntil
                if ~isnan(objects(wormid).x(j)) && ~isnan(objects(wormid).y(j)) %if there is something to merge
                    wheretoput = find(objects(changeinto).frame == objects(wormid).frame(j), 1);
                    if isnan(objects(changeinto).x(wheretoput)) && isnan(objects(changeinto).y(wheretoput)) %if what we're overwriting is nothing
                        objects(changeinto).x(wheretoput) = objects(wormid).x(j);
                        objects(changeinto).y(wheretoput) = objects(wormid).y(j);
                        objects(changeinto).length(wheretoput) = objects(wormid).length(j);
                        objects(changeinto).width(wheretoput) = objects(wormid).width(j);
                        objects(changeinto).area(wheretoput) = objects(wormid).area(j);
                        objects(changeinto).perimeter(wheretoput) = objects(wormid).perimeter(j);
                        objects(changeinto).eccentricity(wheretoput) = objects(wormid).eccentricity(j);
                        objects(changeinto).speed(wheretoput) = objects(wormid).speed(j);
                        objects(changeinto).directionchange(wheretoput) = objects(wormid).directionchange(j);
                        objects(changeinto).behaviour(wheretoput) = objects(wormid).behaviour(j);
                        framestodelete(end+1) = j; %#ok<AGROW>
                    else
                        fprintf(2, 'Warning: worm %d already exists in frame %d.\n', changeinto, objects(changeinto).frame(wheretoput));
                    end
                end
            end
            objects(changeinto).duration = numel(objects(changeinto).frame);
            
            indicestokeep = ~ismember(objects(wormid).frame, objects(wormid).frame(framestodelete));
            
            oldwormid = wormid;
            
            deleteobject(hobj, eventdata, indicestokeep);

            if ~any(indicestokeep) && oldwormid < changeinto %if the object wormid has been deleted, and its ID had been lower than that of the one it was merged into, the newly mergedinto will have an ID 1 lower than it used to (because IDs are downshifted 1 because of the deleted ID)
                set(handles.setid, 'String', num2str(changeinto-1));
            end
                        
        end
        
        %wormshow already occurs via deleteobject
        
    end
    %}

    function setallobjects (hobj, eventdata) %#ok<INUSD>
        
        allobjects = get(handles.allobjects, 'Value');
        if allobjects
            wormid = NaN;
            set(handles.wormid, 'String', '-');
        end
    
    end

    function smoothedspeeds = smoothspeed(objectindex, frameindices)
        
        if speedsmoothing <= 1 && numel(frameindices) == 1
            if invalid(objectindex, frameindices, CONST_DISPLAY_SPEED) || frameindices == 1
                smoothedspeeds = NaN;
            else
                smoothedspeeds = hypot(objects(objectindex).x(frameindices)-objects(objectindex).x(frameindices-1), objects(objectindex).y(frameindices)-objects(objectindex).y(frameindices-1))*framerate;
            end
        else
        
            smoothedspeeds = NaN(numel(frameindices), 1);
            lookleft = ceil(speedsmoothing / 2);
            lookright = speedsmoothing - lookleft;

            for i=1:numel(frameindices) %going through the indices, which makes i the index of the index (necessary for the general case because we might get nonconsecutive frameindices as the argument)
                lookfromindex = frameindices(i)-lookleft;
                lookuntilindex = frameindices(i)+lookright;
                if lookfromindex >= 1 && lookuntilindex <= objects(objectindex).duration %bounds check
                    %validity check for all of the frames within the interval (because the identity can switch from one object to another with an intermediate frame where the two are merged and invalid - and in this scenario with a speedsmoothing of 2 it looks like there was a high speed when the coordinates switched from one valid object in a frame to another valid object in (frame+2))
                    allvalid = true;
                    for j=lookfromindex:lookuntilindex
                        if invalid(objectindex, j, CONST_DISPLAY_X)
                                allvalid = false;
                            break;
                        end
                    end
                    if allvalid
                        smoothedspeeds(i) = hypot(objects(objectindex).x(lookuntilindex)-objects(objectindex).x(lookfromindex), objects(objectindex).y(lookuntilindex)-objects(objectindex).y(lookfromindex))/(speedsmoothing/framerate);
                    end
                end
            end
        end
        
    end

    % Update file list upon entry of a new directory
    function updatefilelist(hobj,eventdata) %#ok<INUSD>
        directory = get(handles.folder,'String');
        
        moviefileextensions = {'mpg', 'avi', 'wmv', 'asf', 'mpeg', 'mp4', 'mov', 'm4v', 'tif', 'tiff', 'nd2'};
        
        files = {};
        
        for i=1:numel(moviefileextensions);
            currentmoviefiles = dir(fullfile(directory, ['*.' moviefileextensions{i}]));
            files(end+1:end+numel(currentmoviefiles)) = {currentmoviefiles.name};
        end
        
        if isempty(files)
            set(handles.files,'String','');
        else
            set(handles.files,'String',files);
            set(handles.files,'Value',1);
        end
        selectfile;
    end

    % Select a new directory graphically
    function browse(hobj,eventdata)
        newdirectory = uigetdir(directory,'Select data folder');
        if newdirectory ~= 0
            directory = newdirectory;
            set(handles.folder,'String',directory);
            updatefilelist(hobj,eventdata);
        end
    end

    function selectfile(hobj, eventdata) %#ok<INUSD>
        allstrings = get(handles.files,'String');
        if ~isempty(allstrings)
            selectedfiles = allstrings(get(handles.files,'Value'));
        else
            selectedfiles = [];
        end
    end

    function deleteobject (hobj, eventdata, indicestokeep)  %#ok<INUSL>
        if exist('indicestokeep', 'var') ~= 1
            indicestokeep = [];
        end
        
        if ~isnan(wormid) || allobjects
            if allobjects
                objects = []; %struct('frame', [], 'time', [], 'x', [], 'y', [], 'length', [], 'width', [], 'area', [], 'perimeter', [], 'eccentricity', [], 'speed', [], 'directionchange', [], 'behaviour', [], 'duration', []);
                wormid = NaN; set(handles.wormid, 'String', num2str(wormid));
            else
                if isempty(indicestokeep)
                    timepointstodelete = timefrom:1/framerate:timeuntil;
                    indicestokeep = ~ismember(objects(wormid).time, timepointstodelete);
                end
                
                firstrealtokeepindex = find(~isnan(objects(wormid).x) & indicestokeep, 1, 'first');
                lastrealtokeepindex = find(~isnan(objects(wormid).x) & indicestokeep, 1, 'last');

                indicestokeep(1:firstrealtokeepindex-1) = false;
                indicestokeep(lastrealtokeepindex+1:end) = false;
                
                if any(indicestokeep)
                    objects(wormid).x(~indicestokeep) = NaN;
                    objects(wormid).y(~indicestokeep) = NaN;
                    objects(wormid).length(~indicestokeep) = NaN;
                    objects(wormid).width(~indicestokeep) = NaN;
                    objects(wormid).area(~indicestokeep) = NaN;
                    objects(wormid).perimeter(~indicestokeep) = NaN;
                    objects(wormid).eccentricity(~indicestokeep) = NaN;
                    objects(wormid).solidity(~indicestokeep) = NaN;
                    objects(wormid).compactness(~indicestokeep) = NaN;
                    objects(wormid).speed(~indicestokeep) = NaN;
                    objects(wormid).directionchange(~indicestokeep) = NaN;
                    objects(wormid).behaviour(~indicestokeep) = CONST_BEHAVIOUR_INVALID;

                    objects(wormid).frame = objects(wormid).frame(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).time = objects(wormid).time(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).x = objects(wormid).x(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).y = objects(wormid).y(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).length = objects(wormid).length(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).width = objects(wormid).width(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).area = objects(wormid).area(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).perimeter = objects(wormid).perimeter(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).eccentricity = objects(wormid).eccentricity(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).solidity = objects(wormid).solidity(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).compactness = objects(wormid).compactness(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).speed = objects(wormid).speed(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).directionchange = objects(wormid).directionchange(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).behaviour = objects(wormid).behaviour(firstrealtokeepindex:lastrealtokeepindex);
                    objects(wormid).duration = numel(objects(wormid).frame);
                else
                    for i=wormid:numel(objects)-1
                        objects(i) = objects(i+1);
                    end
                    objects = objects(1:end-1);
                    wormid = NaN; set(handles.wormid, 'String', num2str(wormid));
                end
                
            end
        else
            fprintf(2, 'Warning: no object is selected so we don''t know what to delete.\n');
        end
        recalculatemeanperimeter;
        wormshow;
    end

    function validdurationcheck (hobj, eventdata) %#ok<INUSD>
        i=1;
        while i<=numel(objects) %I want to be able to move the index one step earlier in certain cases, and a for is less flexible in that respect
            %if floor(i/25) == i/25
            %    fprintf('%d\n', i);
            %end
            if objects(i).duration < round(validdurationminimum*framerate)
                if get(handles.validdurationcheckstyle, 'Value') == 1 %mark as invalid
                    objects(i).behaviour = ones(1, objects(i).duration) * CONST_BEHAVIOUR_INVALID;
                elseif get(handles.validdurationcheckstyle, 'Value') == 2 %delete
                    objects(i) = [];
                    i = i - 1;
                end
            end
            i = i + 1;
        end
        recalculatemeanperimeter;
        wormshow;
    end
    
    function validitycheck (hobj, eventdata) %#ok<INUSD>
        
        questionstring = [];
        
        if scalingfactor == 1
            questionstring = 'The scaling factor does not appear to have been set up. This way all distance measurements will be in pixels rather than micrometers, including validity check thresholds. It is recommended that you set up the scalingfactor as the number of micrometers corresponding to a pixel.';
        elseif ~any(measurementarea(:))
            questionstring = 'No valid area has been specified. This way all objects everywhere will be flagged invalid. It is recommended that you mark as valid the area from which you wish to measure.';
        end
        if ~isempty(questionstring)
            if strcmp(questdlg(questionstring,'Warning: speed threshold may be inappropriate','Proceed anyway','Cancel and fix it','Cancel and fix it'),'Cancel and fix it')
                return;
            end
        end
        
        for i=1:numel(objects)
            for j=1:objects(i).duration
                if objects(i).time(j) < timefrom || objects(i).time(j) > timeuntil
                    continue
                end
                if invaliditycheckframe(i, j)
                    objects(i).behaviour(j) = CONST_BEHAVIOUR_INVALID;
                elseif objects(i).behaviour(j) == CONST_BEHAVIOUR_INVALID
                    objects(i).behaviour(j) = CONST_BEHAVIOUR_UNKNOWN;
                end
            end
        end
        recalculatemeanperimeter;
        wormshow;
    end

    function isitinvalid = invalid (objectindex, frameindex, varargin) %validity checking the specified frame, and (if exists) the frame before. If neither frames are invalid, the checked frame is deemed acceptable
        
        if nargin >= 3
            parameter = varargin{1};
        else
            parameter = CONST_DISPLAY_X;
        end
        
        isitinvalid = false;
        
        if objects(objectindex).behaviour(frameindex) == CONST_BEHAVIOUR_INVALID || (parameter == CONST_DISPLAY_SPEED && frameindex>1 && objects(objectindex).behaviour(frameindex-1) == CONST_BEHAVIOUR_INVALID) %only check for the previous frame if what we're looking at (the parameter) is speed ( == 1)
            isitinvalid = true;
        end
        
    end

    function isitinvalid = invaliditycheckframe (objectindex, frameindex)
        
        isitinvalid = false;
        
        if ~measurementarea(round(objects(objectindex).y(frameindex)), round(objects(objectindex).x(frameindex))) ...
        || (validspeedmin > 0 && objects(objectindex).speed(frameindex) < validspeedmin/scalingfactor) ...
        || (validspeedmax > 0 && objects(objectindex).speed(frameindex) > validspeedmax/scalingfactor) ...
        || (validlengthmin > 0 && objects(objectindex).length(frameindex) < validlengthmin/scalingfactor) ...
        || (validlengthmax > 0 && objects(objectindex).length(frameindex) > validlengthmax/scalingfactor) ...
        || (validwidthmin > 0 && objects(objectindex).width(frameindex) < validwidthmin/scalingfactor) ...
        || (validwidthmax > 0 && objects(objectindex).width(frameindex) > validwidthmax/scalingfactor) ...
        || (validareamin > 0 && objects(objectindex).area(frameindex) < validareamin/scalingfactor/scalingfactor) ...
        || (validareamax > 0 && objects(objectindex).area(frameindex) > validareamax/scalingfactor/scalingfactor) ...
        || (validperimetermin > 0 && objects(objectindex).perimeter(frameindex) < validperimetermin/scalingfactor) ...
        || (validperimetermax > 0 && objects(objectindex).perimeter(frameindex) > validperimetermax/scalingfactor) ...
        || (valideccentricitymin > 0 && objects(objectindex).eccentricity(frameindex) < valideccentricitymin) ...
        || (valideccentricitymax > 0 && objects(objectindex).eccentricity(frameindex) > valideccentricitymax)
                isitinvalid = true;
        end
        
    end

    function targetcheck (hobj, eventdata) %#ok<INUSD>
        for i=1:numel(objects)
            objects(i).target = ones(1, objects(i).duration) * CONST_TARGET_NOMANSLAND;
            objects(i).targetreached = ones(1, objects(i).duration) * CONST_TARGET_NOMANSLAND;
            lastbase = CONST_TARGET_NOMANSLAND;
            for j=1:objects(i).duration
                if objects(i).behaviour(j) == CONST_BEHAVIOUR_INVALID
                    objects(i).target(j) = CONST_TARGET_INVALID;
                elseif endingarea(round(objects(i).y(j)), round(objects(i).x(j)))
                    objects(i).target(j) = CONST_TARGET_ENDINGAREA;
                elseif startingarea(round(objects(i).y(j)), round(objects(i).x(j)))
                    objects(i).target(j) = CONST_TARGET_STARTINGAREA;
                end
                if lastbase == CONST_TARGET_STARTINGAREA && objects(i).target(j) == CONST_TARGET_ENDINGAREA
                    objects(i).targetreached(j) = CONST_TARGET_ENDINGAREA;
                elseif lastbase == CONST_TARGET_ENDINGAREA && objects(i).target(j) == CONST_TARGET_STARTINGAREA
                    objects(i).targetreached(j) = CONST_TARGET_STARTINGAREA;
                end
                if objects(i).target == CONST_TARGET_INVALID
                    lastbase = CONST_TARGET_NOMANSLAND;
                elseif objects(i).target(j) == CONST_TARGET_ENDINGAREA
                    lastbase = CONST_TARGET_ENDINGAREA;
                elseif objects(i).target(j) == CONST_TARGET_STARTINGAREA
                    lastbase = CONST_TARGET_STARTINGAREA;
                end
            end
            %relabelling target area disregarding invalidity (so as to be able to estimate the number of worms based on area)
            %should come after the calculation of targetreached because that needs to consider validity
            for j=1:objects(i).duration
                if endingarea(round(objects(i).y(j)), round(objects(i).x(j)))
                    objects(i).target(j) = CONST_TARGET_ENDINGAREA;
                elseif startingarea(round(objects(i).y(j)), round(objects(i).x(j)))
                    objects(i).target(j) = CONST_TARGET_STARTINGAREA;
                end
            end
        end
    end
    
    function recalculatemeanperimeter
        if ~isempty(objects)
            meanindividualperimeter = NaN(numel(objects), 1);
            for i=1:numel(objects)
                whichindicesareok = ~isnan(objects(i).perimeter) & objects(i).behaviour ~= CONST_BEHAVIOUR_INVALID;
                if any(whichindicesareok)
                    meanindividualperimeter(i) = mean(objects(i).perimeter(whichindicesareok));
                else
                    meanindividualperimeter(i) = NaN;
                end
            end
            if any(~isnan(meanindividualperimeter))
                meanperimeter = mean(meanindividualperimeter(~isnan(meanindividualperimeter)));
            else
                meanperimeter = NaN;
            end
        else
            meanperimeter = NaN;
        end
    end
    
    function loadsettings(hobj, eventdata) %#ok<INUSD>
        if (exist([mfilename '-options.mat'], 'file') ~= 0)
            settingsdata = load([mfilename '-options.mat']);
            if isfield(settingsdata, 'directory')
                directory = settingsdata.directory;
            end
            if isfield(settingsdata, 'figureposition')
                set(handles.fig, 'OuterPosition', settingsdata.figureposition);
            end
            if isfield(settingsdata, 'directory')
                set(handles.folder,'String', settingsdata.directory);
            end
        %else
            %set(handles.fig, 'OuterPosition', get(0, 'Screensize')); %this doesn't seem to work in practice for some weird reason
        end
    end
    function savesettings(hobj,eventdata) %#ok<INUSD>
        closeqtobjects;
        closetiffobjects;
        settingsdata = struct;
        settingsdata.figureposition = get(handles.fig, 'OuterPosition');
        settingsdata.directory = get(handles.folder,'String');
        if ~isempty(settingsdata.figureposition)
            save([mfilename '-options.mat'], '-struct', 'settingsdata');
        end
        warning(oldwarningstate); %restore warning states as they were before zentracker was started
    end
    
    function returnvalue = bound(value, minvalues, maxvalues)
		if numel(value) > 1
			fprintf(2, 'the value argument to the bound function bound must be a scalar.\n');
		end
		realmaxvalue = min(maxvalues(:));
		realminvalue = max(minvalues(:));
		if realmaxvalue < realminvalue
			fprintf(2, 'the lowest upper bound argument passed to the bound function should be greater than the highest lower bound.\n');
		end
		tempreturnvalue = value;
		if value > realmaxvalue
			tempreturnvalue = realmaxvalue;
		elseif value < realminvalue
			tempreturnvalue = realminvalue;
		end
		returnvalue = tempreturnvalue;
    end

    
    %This is the main display updating function
    function wormshow (wheretoshow, enforcesimpledisplay, frametoshow)

        if exist('wheretoshow', 'var') ~= 1
            wheretoshow = handles.img;
        end
        if exist('enforcesimpledisplay', 'var') ~= 1
            enforcesimpledisplay = false;
        end
        if exist('frametoshow', 'var') ~= 1
            frametoshow = wormshowframe;
        end
        
        if isempty(movieindicator) || all(isnan(movieindicator)) || isempty(frameindicator) || all(isnan(frameindicator)) || isnan(frametoshow) %if no frame can be displayed, don't attempt to
            enforcesimpledisplay = true;
        end
        
        if wheretoshow == handles.img
            set(handles.fig, 'CurrentAxes', wheretoshow);
        else
            axes(wheretoshow);
        end
        
        set(wheretoshow,'NextPlot','replace');
        
        if ~enforcesimpledisplay
        
            if thresholdeddisplay || detectionareadisplay || measurementareadisplay || targetareadisplay
                
                originalimage = readframe(frametoshow);
                
                if numel(size(originalimage)) == 3 && size(originalimage, 3) == 3
                    originalrgbimage = originalimage;
                else
                    originalrgbimage = repmat(originalimage, [1 1 3]);
                end
                
                %floating-point-based RGB images have a range from 0 to 1, so we need to normalize
                if strcmpi(class(originalrgbimage), 'single') || strcmpi(class(originalrgbimage), 'double')
                    originalrgbimage = originalrgbimage ./ max(originalrgbimage(:));
                end
                
                superimposedimage = originalrgbimage;
                
                if detectionareadisplay
                    whattoclear = repmat(~detectionarea, [1 1 3]); %we start by flagging to all colours for removal in non-thresholding areas
                    whattoclear(:, :, 1) = false; 
                    whattoclear(:, :, 2) = false; 
                    superimposedimage(whattoclear) = 0.0;
                end
                if measurementareadisplay
                    whattoclear = repmat(measurementarea, [1 1 3]); %we start by flagging to all colours for removal in valid areas
                    whattoclear(:, :, 2) = false;
                    whattoclear(:, :, 3) = false;
                    superimposedimage(whattoclear) = 0.0;
                end
                if thresholdeddisplay
                    thresholdedimage = thresholdimage(originalimage);
%                    thresholdedimage = bwlabel(thresholdedimage);
                    thresholdedimageRGB = repmat(thresholdedimage, [1 1 3]);
                    thresholdedimagegreen = thresholdedimageRGB; %first we take everything, and then we remove all colours but green
                    %keeping only the green indices
                    thresholdedimagegreen(:, :, 1) = 0.0;
                    thresholdedimagegreen(:, :, 3) = 0.0;
                    thresholdedimageredblue = thresholdedimageRGB; %first we take everything, and then we remove green
                    thresholdedimageredblue(:, :, 2) = 0.0; %zeroing the green indices to keep only the red and blue ones
                    if strcmpi(class(originalrgbimage), 'single') || strcmpi(class(originalrgbimage), 'double')
                        superimposedimage(thresholdedimagegreen==1) = 1.0;
                    else
                        superimposedimage(thresholdedimagegreen==1) = pixelmax;
                    end
                    superimposedimage(thresholdedimageredblue==1) = 0.0;
                end
                if targetareadisplay
                    whattoadjust = repmat(startingarea, [1 1 3]);
                    superimposedimage(whattoadjust) = superimposedimage(whattoadjust) .* 1.2; %lightening the part inside the starting area a bit
                    whattoadjust = repmat(endingarea, [1 1 3]);
                    superimposedimage(whattoadjust) = superimposedimage(whattoadjust) .* 0.8; %darkening the part inside the ending area a bit
                end

                set(handles.img,'NextPlot','replace');
                if numel(size(superimposedimage)) >= 3 && size(superimposedimage, 3) == 3 && min(superimposedimage(:)) == max(superimposedimage(:)) %a completely black RGB image cannot be autoscaled
                    imshow(superimposedimage);
                else
                    imshow(superimposedimage, []);
                end
                
                if thresholdeddisplay
                    hold on;
                    if verLessThan('matlab', '7.8')
                        thresholdedimage = bwlabel(thresholdedimage);
                    end
                    thresholdedregions = regionprops(thresholdedimage,'Centroid','Area'); %get centroid and area size for each region of interest
                    thresholdedregions = thresholdedregions(vertcat(thresholdedregions.Area) >= thresholdsizemin/scalingfactor^2); % only consider it if it's larger than the minimum size
                    thresholdedregions = thresholdedregions(vertcat(thresholdedregions.Area) <= thresholdsizemax/scalingfactor^2); % and smaller than the maximum size
                    for i=1:numel(thresholdedregions)
                        radius = realsqrt(thresholdedregions(i).Area)*4.0/pi();
                        plot(radius*circlepointsx+thresholdedregions(i).Centroid(1), radius*circlepointsy+thresholdedregions(i).Centroid(2), '-', 'MarkerSize', 1, 'Color', 'r');
                    end
                end

                hold all;
            else
                imshow(readframe(frametoshow), []);
                hold all;
            end
        else
            scatter([],[]);
            hold all;
        end
        
        if identitydisplay
            for i=1:numel(objects);
                frameindex = find(objects(i).frame==frametoshow); %the index of the frame within the object where the time corresponds to the one we want to look at
                if ~isempty(frameindex)
                    switch objects(i).behaviour(frameindex)
                        case CONST_BEHAVIOUR_UNKNOWN
                            objectcolor = 'b';
                        case CONST_BEHAVIOUR_FORWARDS
                            objectcolor = 'w';
                        case CONST_BEHAVIOUR_REVERSAL
                            objectcolor = 'k';
                        case CONST_BEHAVIOUR_OMEGA
                            objectcolor = 'm';
                        case CONST_BEHAVIOUR_INVALID
                            objectcolor = 'r';
                        otherwise %by default things are blue
                            objectcolor = 'b';
                            fprintf(2, 'the behaviour of worm %d at objectframeindex %d is unspecified.\n', i, frameindex);
                    end

                    if ~isnan(objects(i).perimeter(frameindex))
                        objectsize = min([max([realsqrt(objects(i).perimeter(frameindex))/realsqrt(meanperimeter)*averagetextsize minimumtextsize]) maximumtextsize]); %we scale the text size according to the square root of the ratio of the object's perimeter to the average perimeter (unless that would be a value smaller than minimumtextsize)
                    else
                        objectsize = averagetextsize;
                    end

                    text(objects(i).x(frameindex),objects(i).y(frameindex),num2str(i),'Margin',0.001,'Parent',wheretoshow,'FontSize',objectsize,'color',objectcolor,'Interpreter','none');
                    
                end
            end
        end
        
    end

    function setscaling(hobj, eventdata) %#ok<INUSD>
        
        scalingcrosshairradius = 15;
        
        [x(1), y(1), clicktype] = zinput('crosshair', 'radius', scalingcrosshairradius, 'colour', 'b');
        if ~strcmpi(clicktype, 'normal')
            wormshow;
            return;
        end
        line([x(1)-scalingcrosshairradius x(1)+scalingcrosshairradius], [y(1) y(1)], 'color', 'b');
        line([x(1) x(1)], [y(1)-scalingcrosshairradius y(1)+scalingcrosshairradius], 'color', 'b');
        [x(2), y(2), clicktype] = zinput('crosshair', 'radius', scalingcrosshairradius, 'colour', 'r');
        if ~strcmpi(clicktype, 'normal')
            wormshow;
            return;
        end
        line([x(2)-scalingcrosshairradius x(2)+scalingcrosshairradius], [y(2) y(2)], 'color', 'r');
        line([x(2) x(2)], [y(2)-scalingcrosshairradius y(2)+scalingcrosshairradius], 'color', 'r');
        
        pixeldistance = realsqrt( (x(2)-x(1))^2 + (y(2)-y(1))^2 );
        
        micrometers = inputdlg(sprintf('Distance in pixels: %f .\nDistance in micrometers using the current scaling factor (%.1f): %.0f .\nEnter the actual distance in micrometers to adjust the scaling factor:', pixeldistance, scalingfactor, pixeldistance*scalingfactor));
        
        if ~isempty(micrometers) %if the user did not cancel
            micrometers = str2double(char(micrometers));
            previousscalingfactor = scalingfactor;
            scalingfactor = micrometers/pixeldistance;
            if isnan(scalingfactor)
                if ~isnan(previousscalingfactor)
                    fprintf(2, 'Warning: the new scaling factor is not interpretable (%f). Continuing to use the previous scaling factor (%f).\n', scalingfactor, previousscalingfactor);
                    scalingfactor = previousscalingfactor;
                else
                    fprintf(2, 'Warning: the new scaling factor is not interpretable (%f). Resetting the scaling factor to 1.\n', scalingfactor);
                    scalingfactor = 1;
                end
            end
            set(handles.scalingfactor, 'String', num2str(scalingfactor));
        end
        
        wormshow;
    end
    
    function markarea(hobj, eventdata, whattomark) %#ok<INUSL>
        
        if strcmpi(whattomark, 'threshold') 
            whichstyle = get(handles.detectionwhere, 'Value');
            markas = get(handles.detectionwhat, 'Value') == 1;
            markradius = detectionradius/scalingfactor; %converting to pixels
        elseif strcmpi(whattomark, 'measurementlike')
            if get(handles.measurementwhat, 'Value') <= 2
                whattomark = 'valid';
            elseif get(handles.measurementwhat, 'Value') <= 4
                whattomark = 'starting';
            elseif get(handles.measurementwhat, 'Value') <= 6
                whattomark = 'ending';
            end
            whichstyle = get(handles.measurementwhere, 'Value');
            markas = get(handles.measurementwhat, 'Value') == 1 || get(handles.measurementwhat, 'Value') == 3 || get(handles.measurementwhat, 'Value') == 5;
            markradius = measurementradius/scalingfactor; %converting to pixels
        else
            fprintf(2, 'Warning: we do not know what area to mark.\n');
        end
        
        markradius = round(markradius);
        movieradius = max([movieheight, moviewidth])/2;
        
        if (whichstyle == CONST_AREA_SQUARE || whichstyle == CONST_AREA_CIRCLE) && markradius >= movieradius
            if strcmp(questdlg(sprintf('Warning: the radius of the "paintbrush" used for marking areas (%.0f pixels) is set up to be larger than the radius of the movie (%.0f pixels). Make sure that the scaling factor is set up correctly. Otherwise, do you just want to mark the entire movie area?', markradius, movieradius),'Warning: radius is larger than the movie','Mark everywhere','Cancel','Cancel'),'Cancel')
                return;
            else
                whichstyle = CONST_AREA_EVERYWHERE;
                if strcmpi(whattomark, 'threshold')
                    set(handles.detectionwhere, 'Value', whichstyle);
                elseif strcmpi(whattomark, 'valid') || strcmpi(whattomark, 'starting')
                    set(handles.measurementwhere, 'Value', whichstyle);
                end
            end
        end
        
        switch whichstyle
            case CONST_AREA_EVERYWHERE
                if strcmpi(whattomark, 'threshold')
                    detectionarea = logical(ones(movieheight, moviewidth).*markas);
                elseif strcmpi(whattomark, 'valid')
                    measurementarea = logical(ones(movieheight, moviewidth).*markas);
                elseif strcmpi(whattomark, 'starting')
                    startingarea = logical(ones(movieheight, moviewidth).*markas);
                elseif strcmpi(whattomark, 'ending')
                    endingarea = logical(ones(movieheight, moviewidth).*markas);
                end
                wormshow;
            case CONST_AREA_RECTANGLE
                x = NaN(4,1);
                y = NaN(4,1);
                for i=1:4
                    [x(i), y(i), clicktype] = zinput('axes', 'Colour', 'r');
                    if strcmpi(clicktype, 'alt') %right click cancels
                        return;
                    end
                end
                [x, ix] = sort(x); %#ok<NASGU>
                [y, iy] = sort(y); %#ok<NASGU>
                xmin = round(x(2));
                xmax = round(x(3));
                ymin = round(y(2));
                ymax = round(y(3));
                if strcmpi(whattomark, 'threshold')
                    detectionarea(ymin:ymax, xmin:xmax) = markas;
                elseif strcmpi(whattomark, 'valid')
                    measurementarea(ymin:ymax, xmin:xmax) = markas;
                elseif strcmpi(whattomark, 'starting')
                    startingarea(ymin:ymax, xmin:xmax) = markas;
                elseif strcmpi(whattomark, 'ending')
                    endingarea(ymin:ymax, xmin:xmax) = markas;
                end
                wormshow;
            case CONST_AREA_SQUARE
                clicktype = 'nothing yet';
                while ~strcmpi(clicktype, 'alt') && ~strcmpi(clicktype, 'extend')
                    [x y clicktype] = zinput('Square', 'Radius', markradius);
                    if strcmpi(clicktype, 'normal')
                        x = round(x);
                        y = round(y);
                        xmin = max([x-markradius 1]);
                        xmax = min([x+markradius moviewidth]);
                        ymin = max([y-markradius 1]);
                        ymax = min([y+markradius movieheight]);
                        if strcmpi(whattomark, 'threshold')
                            detectionarea(ymin:ymax, xmin:xmax) = markas;
                        elseif strcmpi(whattomark, 'valid')
                            measurementarea(ymin:ymax, xmin:xmax) = markas;
                        elseif strcmpi(whattomark, 'starting')
                            startingarea(ymin:ymax, xmin:xmax) = markas;
                        elseif strcmpi(whattomark, 'ending')
                            endingarea(ymin:ymax, xmin:xmax) = markas;
                        end
                        wormshow;
                    end
                end
            case CONST_AREA_CIRCLE
                clicktype = 'nothing yet';
                while ~strcmpi(clicktype, 'alt') && ~strcmpi(clicktype, 'extend')
                    [x y clicktype] = zinput('Circle', 'XRadius', markradius, 'YRadius', markradius);
                    if strcmpi(clicktype, 'normal')
                        distance = realsqrt((meshx-x).^2+(meshy-y).^2);
                        withindistance = distance < markradius; %matrix of true values around the clicked coordinates with a radius of markradius
                        if strcmpi(whattomark, 'threshold')
                            detectionarea(withindistance) = markas;
                        elseif strcmpi(whattomark, 'valid')
                            measurementarea(withindistance) = markas;
                        elseif strcmpi(whattomark, 'starting')
                            startingarea(withindistance) = markas;
                        elseif strcmpi(whattomark, 'ending')
                            endingarea(withindistance) = markas;
                        end
                        wormshow;
                    end
                end
            case CONST_AREA_POLYGON
                clicktype = 'nothing yet';
                verticesx = [];
                verticesy = [];
                while ~strcmpi(clicktype, 'alt') && ~strcmpi(clicktype, 'extend')
                    if ~isempty(verticesx) && ~isempty(verticesy)
                        scatter(verticesx(end), verticesy(end), [], 'm');
                        if numel(verticesx) == 1
                            plot(verticesx(end), verticesy(end), '-m.');
                        elseif numel(verticesx) > 1
                            plot([verticesx(end-1) verticesx(end)], [verticesy(end-1) verticesy(end)], '-m.');
                        end
                    end
                    [x y clicktype] = zinput('Crosshair', 'radius', 10);
                    if strcmpi(clicktype, 'normal')
                        verticesx(end+1) = x; %#ok<AGROW>
                        verticesy(end+1) = y; %#ok<AGROW>
                    end
                end
                if strcmpi(clicktype, 'alt') %'alt' (right click) exits and APPLIES the changes; use 'extend' (middle click) to leave without any changes
                    if numel(verticesx) > 1 && numel(verticesy) > 1 %we
                        areatochange = inpolygon(meshx, meshy, verticesx, verticesy);
                        if strcmpi(whattomark, 'threshold')
                            detectionarea(areatochange) = markas;
                        elseif strcmpi(whattomark, 'valid')
                            measurementarea(areatochange) = markas;
                        elseif strcmpi(whattomark, 'starting')
                            startingarea(areatochange) = markas;
                        elseif strcmpi(whattomark, 'ending')
                            endingarea(areatochange) = markas;
                        end
                    end
                end
                wormshow;
        end
        
    end

    function setgradnorm(hobj, eventdata) %#ok<INUSD>
        
        gradnorm = get(handles.gradnorm, 'Value');
        
        %clearing the current frame's cache to make sure that newly displayed frames have the right normalization
        cachedindex = NaN;
        cachedframe = [];
        
        if gradnorm
            
            waithandle = waitbar(0,'Calculating background intensity gradient...','Name','Processing', 'CreateCancelBtn', 'delete(gcbf)');
        
            toaverage = NaN(movieheight, moviewidth, 10);
            whichindex = 0;
            for i=0:9
                
                if ishandle(waithandle)
                    waitbar(i/10, waithandle);
                else
                    break;
                end
                
                whichindex = whichindex + 1;
                whichframe = round(i/10*lastframe);
                if whichframe <= 2 %never use the first frame as a reference, because e.g. it might have a different exposure time or can be otherwise unusual
                    whichframe = 2;
                end
                if whichframe >= lastframe-1 %never use the last frame as a reference, because e.g. it might have a different exposure time or can be otherwise unusual
                    whichframe = lastframe-1;
                end
                currentframe = readframe(whichframe, false); %reading the raw frame without normalization
                toaverage(:, :, whichindex) = currentframe;
            end
            
            if ~ishandle(waithandle) %cancelled
                gradnorm = false;
                set(handles.gradnorm, 'Value', gradnorm);
                wormshow;
                return;
            else
                waitbar(1.0, waithandle);
            end
            
            averageintensity = median(toaverage, 3);

            filtersigma = round(min([movieheight, moviewidth])/20);

            gf = fspecial('gaussian', [filtersigma*4+1, filtersigma*4+1], filtersigma);
            lowpassed = imfilter(averageintensity, gf);
            
            gradnormmatrix = lowpassed./mean(lowpassed(:));
            
            if ishandle(waithandle)
                delete(waithandle);
            end
            
        else
            
            gradnormmatrix = [];
            
        end
        
        wormshow;
        
    end

    function settimenorm(hobj, eventdata) %#ok<INUSD>
        timenorm = get(handles.timenorm, 'Value');
        cachedindex = NaN;
        cachedframe = [];
        wormshow;
    end

    function setdarkfield(hobj, eventdata) %#ok<INUSD>
        darkfield = get(handles.darkfield, 'Value');
        cachedindex = NaN;
        cachedframe = [];
        wormshow;
    end
    
    function setframeslider(hobj, eventdata) %#ok<INUSD>
        wormshowframe = round(get(handles.wormshowframeslider, 'Value')); %we need to round() it because by dragging the slider bar, the user could set it to an intermediate (non-integer) value
        set(handles.wormshowsettime,'String',num2str(converttotime(wormshowframe)));
        set(handles.wormshowsetframe,'String',num2str(wormshowframe));
        wormshow;
    end

    function moveslider (hobj, eventdata, howmuch) %#ok<INUSL>
        wormshowframe = round(get(handles.wormshowframeslider, 'Value'));
        wormshowframe = wormshowframe + howmuch;
        if wormshowframe < 1
            wormshowframe = 1;
        elseif wormshowframe > lastframe
            wormshowframe = lastframe;
        end
        set(handles.wormshowframeslider, 'Value', wormshowframe);
        setframeslider;
    end
    
    function settime(hobj, eventdata) %#ok<INUSD>
        timenumber = round(str2double(get(handles.wormshowsettime,'String'))*framerate)/framerate;
        if ~isnan(timenumber)
            wormshowframe = converttoframe(timenumber);
        end
        wormshowframe = bound(wormshowframe, 1, lastframe);
        set(handles.wormshowframeslider,'Value', wormshowframe); %Moves slider
        setframeslider;
    end

    function setframe(hobj, evetdata) %#ok<INUSD>
        framenumber = round(str2double(get(handles.wormshowsetframe,'String')));
        if ~isnan(framenumber)
            wormshowframe = framenumber;
        end
        wormshowframe = bound(wormshowframe, 1, lastframe);
        set(handles.wormshowframeslider,'Value', wormshowframe); %Moves slider
        setframeslider;
    end

    function settimefromcurrent (hobj, eventdata) %#ok<INUSD>
        timefrom = converttotime(wormshowframe);
        set(handles.timefrom, 'String', num2str(timefrom));
    end

    function settimeuntilcurrent (hobj, eventdata) %#ok<INUSD>
        timeuntil = converttotime(wormshowframe);
        set(handles.timeuntil, 'String', num2str(timeuntil));
    end

    function setvalue (hobj, eventdata, varargin) %#ok<INUSL>
        
        %parsing input arguments
        inputindex=1;
        while (inputindex<=numel(varargin))
            if strcmpi(varargin{inputindex}, 'min') == 1 || strcmpi(varargin{inputindex}, 'minvalue') == 1
                minvalue = varargin{inputindex+1};
                if ischar(minvalue)
                    minvalue = eval(minvalue);
                end
                inputindex=inputindex+2;
            elseif strcmpi(varargin{inputindex}, 'max') == 1 || strcmpi(varargin{inputindex}, 'maxvalue') == 1
                maxvalue = varargin{inputindex+1};
                if ischar(maxvalue)
                    maxvalue = eval(maxvalue);
                end
                inputindex=inputindex+2;
            elseif strcmpi(varargin{inputindex}, 'round') == 1 || strcmpi(varargin{inputindex}, 'rounding') == 1
                rounding = varargin{inputindex+1};
                if ischar(rounding)
                    rounding = eval(rounding);
                end
                inputindex=inputindex+2;
            elseif strcmpi(varargin{inputindex}, 'default') == 1
                default = varargin{inputindex+1};
                inputindex=inputindex+2;
            elseif strcmpi(varargin{inputindex}, 'set') == 1 || strcmpi(varargin{inputindex}, 'setglobal') == 1
                setglobal = varargin{inputindex+1};
                inputindex=inputindex+2;
            elseif strcmpi(varargin{inputindex}, 'logical') == 1 || strcmpi(varargin{inputindex}, 'logic') == 1
                logic = true;
                inputindex=inputindex+1;
            elseif strcmpi(varargin{inputindex}, 'show') == 1 || strcmpi(varargin{inputindex}, 'showit') == 1
                showit = true;
                inputindex=inputindex+1;
            end
        end
        
        if exist('default', 'var') ~= 1
            default = '-';
        end
        if exist('logic', 'var') ~= 1
            logic = false;
        end
        if exist('showit', 'var') ~= 1
            showit = false;
        end
        
        if ~logic
            tempnumber = str2double(get(hobj, 'String'));
        else
            tempnumber = get(hobj, 'Value');
        end
        
        if exist('rounding', 'var') == 1
            tempnumber = round(tempnumber * rounding)/rounding;
        end
        if exist('minvalue', 'var') == 1 && tempnumber < minvalue
            tempnumber = minvalue;
        end
        if exist('maxvalue', 'var') == 1 && tempnumber > maxvalue
            tempnumber = maxvalue;
        end
        
        if ~logic
            if ~isnan(tempnumber)
                set(hobj, 'String', num2str(tempnumber))
            else
                set(hobj, 'String', default);
            end
        end
        
        if exist('setglobal', 'var') == 1
            if isnan(tempnumber) && strcmpi(class(default), 'double')
                eval([setglobal '= default;']);
            else
                eval([setglobal '= tempnumber;']);
            end
        end
        
        if showit
            wormshow;
        end
        
    end
    
    function cdata = readframe(whichframe, cannormalize) %reads the from the appropriate frame of the appropriate movie
        if exist('cannormalize', 'var') ~= 1
            cannormalize = true;
        end
        if whichframe ~= cachedindex %what's requested isn't already the currently cached frame, we'll need to get it
            if isstruct(moviecache) && numel(moviecache) >= whichframe && isfield(moviecache, 'data') && ~isempty(moviecache(whichframe).data) %if we have the entire movie cached, then we just grab the frame
                currentframe = moviecache(whichframe).data;
            else %otherwise we'll need to actually read it from a file
                successfullyread = false;
                if ~isempty(bfreaders)
                    bfi = strcmp({bfreaders.filename}, moviefiles{movieindicator(whichframe)});
                    bfi = find(bfi, 1, 'last');
                    try
                        currentframe = bfGetPlane(bfreaders(bfi).server, frameindicator(whichframe));
                        successfullyread = true;
                    catch
                        if ~readerfailuredisplayed(movieindicator(whichframe))
                            readerfailuredisplayed(movieindicator(whichframe)) = true;
                            fprintf(2, 'Warning: %s could not be read using bfreader. This is unexpected because the movie was opened successfully using this method earlier.\n', selectedfiles{movieindicator(whichframe)});
                            error('Unable to read frame %d using BioFormats', whichframe);
                        end
                    end
                end
                if ~isempty(tiffservers)
                    currenttiffobject = 0;
                    for i=1:numel(tiffservers)
                        if strcmp(moviefiles{movieindicator(whichframe)}, tiffservers(i).filename)
                            currenttiffobject = i;
                            break;
                        end
                    end
                    if currenttiffobject ~= 0
                        try
                            currentframe = tiffservers(currenttiffobject).server.getImage(frameindicator(whichframe));
                            successfullyread = true;
                        catch %#ok<CTCH>
                            if ~readerfailuredisplayed(movieindicator(whichframe))
                                readerfailuredisplayed(movieindicator(whichframe)) = true;
                                fprintf(2, 'Warning: %s could not be read using TIFFServer. This is unexpected because the movie was opened successfully using this method earlier. Trying fallback options...\n', selectedfiles{movieindicator(whichframe)});
                            end
                        end
                    end
                end
                if ~isempty(qtreaders)
                    currentqtobject = 0;
                    for i=1:numel(qtreaders)
                        if strcmp(moviefiles{movieindicator(whichframe)}, qtreaders(i).filename)
                            currentqtobject = i;
                            break;
                        end
                    end
                    if currentqtobject ~= 0
                        try
                            currentframe = uint8(qtreaders(currentqtobject).server.getBW(frameindicator(whichframe)));
                            successfullyread = true;
                        catch %#ok<CTCH>
                            if ~readerfailuredisplayed(movieindicator(whichframe))
                                readerfailuredisplayed(movieindicator(whichframe)) = true;
                                fprintf(2, 'Warning: %s could not be read using QTFrameServer. This is unexpected because the movie was opened successfully using this method earlier. Trying fallback options...\n', selectedfiles{movieindicator(whichframe)});
                            end
                        end
                    end
                end
                if ~isempty(moviereaderobjects) %only try to read with the newer method (VideoReader or mmreader objects) if we've already managed to open the file with this method
                    currentreaderobject = 0;
                    for i=1:numel(moviereaderobjects) %trying to see if we've already set up a movie reader object for this file
                        if strcmp(moviefiles{movieindicator(whichframe)}, get(moviereaderobjects(i).reader, 'Name'))
                            currentreaderobject = i;
                            break;
                        end
                    end
                    if currentreaderobject ~= 0 %if we've managed to find sort of movie reader object, then read the video
                        try
                            currentframe = read(moviereaderobjects(currentreaderobject).reader, frameindicator(whichframe));
                            successfullyread = true;
                        catch %#ok<CTCH>
                            if ~readerfailuredisplayed(movieindicator(whichframe))
                                readerfailuredisplayed(movieindicator(whichframe)) = true;
                                fprintf(2, 'Warning: %s could not be read using a reader object. This is unexpected because the movie was opened successfully using this method earlier. Trying fallback options...\n', selectedfiles{movieindicator(whichframe)});
                            end
                        end
                    end
                end
                if ~successfullyread && avireadworks %if we haven't managed to read the frame yet, fall back to aviread, if possible
                    video = aviread(fullfile(directory,moviefiles{movieindicator(whichframe)}), frameindicator(whichframe));
                    currentframe = video.cdata;
                    successfullyread = true;
                end
                if ~successfullyread %if we still haven't managed to read the frame, fall back to mmread
                    [video, audio] = mmread(fullfile(directory,moviefiles{movieindicator(whichframe)}), frameindicator(whichframe)); %#ok<NASGU>
                    currentframe = video.frames(1).cdata;
                end
            end
            
            %Converting RGB values to grayscale
            if numel(size(currentframe)) >= 3 && size(currentframe, 3) == 3
                currentframe = rgb2gray(currentframe);
            end
            %Matlab cannot display uint32 or int32 class RGB images (and we will eventually make RGB images based on these data), so we'll have to convert them
            if strcmp(class(currentframe), 'uint32') || strcmp(class(currentframe), 'int32')
                currentframe = uint16(currentframe);
            end
            
            if darkfield
                currentframe = pixelmax - currentframe;
            end
            
            cachedframe = currentframe;
            if cannormalize && gradnorm && ~isempty(gradnormmatrix) && ~any(isnan(gradnormmatrix(:)))
                %cachedframe = double(cachedframe)./gradnormmatrix;
                imageclass = class(cachedframe); %preserving original image class
                if cannormalize && timenorm %if we're going to do time-normalization anyway (which will result in double class images), don't needlessly truncate the dynamic range by casting the matrix as anything other than double
                    imageclass = 'double';
                end
                cachedframe = cast(double(cachedframe)./gradnormmatrix, imageclass);
            end
            if cannormalize && timenorm
                
                cachedframe = double(cachedframe);
                
                if any(detectionarea(:))
                    pixelstouse = cachedframe(detectionarea);
                else
                    pixelstouse = cachedframe(:);
                end
                
                %cachedframe = double(cachedframe)./timenormvector(whichframe);
                
                cachedframe = cachedframe-mean(pixelstouse);
                cachedframe = cachedframe/std(pixelstouse)*(1/20);
                cachedframe = cachedframe+0.5;
                
                cachedframe(cachedframe < 0.0) = 0.0;
                cachedframe(cachedframe > 1.0) = 1.0;
                
                cachedframe = cachedframe * pixelmax;
            end
            cachedindex = whichframe;
        end
        cdata = cachedframe;
    end
    
    function returninframe = converttoframe (time)
        %converting time in seconds to frame
        %rounding errors could occur with the weird (integer+epsilon) framerates that can sometimes be read from quicktime movies,
        %so we round() here just to make sure that the frame number we settle on is definitely an integer
        returninframe = round(time * framerate + 1); 
    end

    function returnintime = converttotime (frame)
        returnintime = (frame-1)/framerate;
    end
    
    %{
    function dotindex = findthelastdot (stringtosearch)
        dotindex = NaN;
        for i=numel(stringtosearch):-1:1
            if strcmp(stringtosearch(i), '.')
                dotindex = i;
                break;
            end
        end
    end
    %}
    
    function setbehaviour (hobj, eventdata) %#ok<INUSD>
        
        if ~ (timefrom <= timeuntil)
            questdlg(sprintf('Where to start changing the behaviour has to be smaller than where to end changing the behaviour of worm number %d.\nCurrent start time: %.2f.\nCurrent end time: %.2f.', wormid, timefrom, timeuntil), 'Unable to apply changes', 'OK', 'OK');
        else
            if allobjects
                startid = 1;
                endid = numel(objects);
            else
                startid = wormid;
                endid = wormid;
            end
            settingbehaviourto = get(handles.behaviour, 'Value')-1; %The -1 is needed because with the definitions we start from 0, whereas with the enumeration of the popupbox we start at 1
            for currentid = startid:endid
                if timefrom < objects(currentid).time(1)
                    startindex = 1;
                else
                    startindex = find(objects(currentid).time==timefrom, 1);
                end
                if timeuntil > objects(currentid).time(end)
                    endindex = objects(currentid).duration;
                else
                    endindex = find(objects(currentid).time==timeuntil, 1);
                end
                for i=startindex:endindex
                    objects(currentid).behaviour(i) = settingbehaviourto;
                end
            end
            recalculatemeanperimeter; %invalid frames could have been set valid, or valid frames invalid, so we need to recheck
            wormshow;
        end
    end

    function detectlightflash (hobj, eventdata) %#ok<INUSD>
        
        waithandle = waitbar(0,'Detecting a sudden increase in overall brightness','Name','Processing', 'CreateCancelBtn', 'delete(gcbf)');
        
        startfrom = 1;
        previousaverage = 0;
        for i=startfrom:lastframe
            
            if ishandle(waithandle) > 0
                if mod(i, waitbarfps) == 0
                    waitbar(i/lastframe, waithandle);
                end
            else
                break;
            end

            currentframe = readframe(i, false);
            if numel(size(currentframe)) >= 3 && size(currentframe, 3) > 1
                currentframe = rgb2gray(currentframe);
            end
            currentaverage = mean(currentframe(:));
            if i>startfrom && currentaverage/previousaverage > 1.5
                flashindices = i;
                break;
            end
            previousaverage = currentaverage;
        end
        
        if ishandle(waithandle)
            close(waithandle);
        end
        
    end
    
    function setflasharea (hobj,eventdata)  %#ok<INUSD>
        
        flashradius = 10;
        
        [flashx flashy] = zinput('circle', 'colour', 'r', 'XRadius', flashradius, 'YRadius', flashradius); 
        
        
        flashintensity = zeros(1, lastframe);
        
        distance = realsqrt((meshx-flashx).^2+(meshy-flashy).^2);
        withindistance = distance <= flashradius; %matrix of 1s around clicked coordinates with radius flashradius, which should be considered
        
        for i=1:lastframe
            currentframe = readframe(i);
            if numel(size(currentframe)) >= 3 && size(currentframe, 3) > 1
                currentframe = rgb2gray(currentframe);
            end
            pixelstouse = currentframe(withindistance);
            flashintensity(i) = mean(pixelstouse(:));
        end
        
        flashfigure = figure('Name', 'Set flash threshold', 'NumberTitle','off', 'Units','Normalized','DefaultUicontrolUnits','Normalized'); %#ok<NASGU>
        plot(flashintensity);
        
        [thresholdx thresholdy clicktype] = zinput('horizontal', 'colour', 'r');
        
        if ~strcmpi(clicktype, 'alt')
            flashed = flashintensity > thresholdy;
            flashindices = strfind(flashed, [false true]) + 1; %the indices of the flash coming on
            flashed = false(1, numel(flashed));
            flashed(flashindices) = true;
        end
        
        %{
        o2at21 = zeros(size(flashed, 1), size(flashed, 2));
        timedelayframes = 6; %there is a 1.5 s ( == 3 frames usually) delay between the light switch and the change in O2 (CHANGEME CHANGEME)
        upframe = NaN;
        upframes = [];
        downframes = [];
        
        for i=1:numel(flashed)
            if flashed(i)
                if isnan(upframe) %if switching up
                    upframe = i;
                    upframes(end+1) = i+timedelayframes; %#ok<AGROW>
                else %if switching down
                    downframes(end+1) = i+timedelayframes; %#ok<AGROW>
                    o2at21(upframe+timedelayframes:i+timedelayframes) = true(1, i-upframe+1);
                    upframe = NaN;
                end
            end
        end
        
        if numel(upframes) ~= numel(downframes)
            fprintf(2, 'Warning: there is not an equal number of upsteps and downsteps. This could cause problems.\n');
        end
        %}
        
    end

    function angleinradians = getabsoluteangle(xold, yold, xnew, ynew)
        angleinradians = atan2(ynew-yold, xnew-xold);
    end

    %{
    function distance = getabsolutedistance(xold, xnew, yold, ynew)
        distance = realsqrt((xnew-xold)^2+(ynew-yold)^2);
    end
    %}
    
    %gives the (signed) change in (shorter) angle between anglenew and angleold (in radians)
    function difference = angledifference(angleold, anglenew) 
        difference = anglenew - angleold;
        %checking if moving one of the angles by a full circle would bring the two closer in terms of absolute angle difference. If so, we'll use that (signed) value. This is to work around the issue of pi-epsilon being very near to -pi+epsilon (but not in terms of naive angle difference).
        difference2 = (anglenew + 2*pi) - angleold;
        difference3 = anglenew - (angleold + 2*pi);
        if abs(difference2) < abs(difference)
            difference = difference2;
        end
        if abs(difference3) < abs(difference)
            difference = difference3;
        end
    end

    function datafilename = determinedatafilename (hobj, eventdata) %#ok<INUSD>
        if numel(selectedfiles) == 1
            datafilename = char(selectedfiles);
        else
            shortestnamelength = Inf;
            for i=1:numel(selectedfiles)
                currentlength = numel(selectedfiles{i});
                if currentlength < shortestnamelength
                    shortestnamelength = currentlength;
                end
            end
            howmanychars = shortestnamelength;
            referencefilename = char(selectedfiles(1));
            datafilename = [];
            while howmanychars>0
                goodnamesofar = true;
                for i=2:numel(selectedfiles)
                    currentfilename = char(selectedfiles(i));
                    if ~strcmp(referencefilename(1:howmanychars), currentfilename(1:howmanychars))
                        goodnamesofar = false;
                        break;
                    end
                end
                if goodnamesofar
                    datafilename = referencefilename(1:howmanychars);
                    break;
                else
                    howmanychars = howmanychars - 1;
                end
            end
        end
        
        if isempty(datafilename)
            datafilename = inputdlg('Analysis data filename:', 'Manually enter analysis data file name', 1, {char(selectedfiles(1))}, 'on');
        end
        
    end

    function saveanalysis (hobj, eventdata) %#ok<INUSD>
        
        basefilename = determinedatafilename;
        
        if ~isempty(basefilename)
            
            savefilename = [basefilename savefilesuffix];
            
            if exist(savefilename, 'file') ~= 0
                if ~strcmp(questdlg('Analysis data already exists for this file. Overwrite it?','Data already exists','Cancel','Overwrite','Overwrite'),'Overwrite')
                    return;
                end
            end    
            
            saveversion = version; %#ok<SETNU>

            for i=1:numel(trytoload)
                eval(['ztdata.' char(trytoload(i)) '=' char(trytoload(i)) ';']);
            end
            for i=1:numel(trytosetvalue)
                eval(['ztdata.' char(trytosetvalue(i)) '= get(handles.' char(trytosetvalue(i)) ', ''Value'');']);
            end
            for i=1:numel(saveonly)
                eval(['ztdata.' char(saveonly(i)) '=' char(saveonly(i)) ';']);
            end

            save(savefilename, '-struct', 'ztdata');

            fprintf('Analysis data saved successfully as %s .\n', savefilename);
            questdlg(sprintf('Analysis data saved successfully as %s .', savefilename), 'Data saved', 'OK', 'OK');
        else
            fprintf('Analysis data was not saved.\n');
            questdlg(sprintf('Warning: analysis data could not be saved.'), 'Data not saved', 'OK', 'OK');
        end
        
    end

    function loadanalysis (hobj, eventdata) %#ok<INUSD>
        
        filenametoload = [];
        
        basefilename = determinedatafilename;
        
        if ~isempty(basefilename)
            filenamecheck = [basefilename savefilesuffix];
            if exist(filenamecheck, 'file') == 2
                filenametoload = filenamecheck;
            else
                filenamecheckprevious = [basefilename savefilesuffixprevious];
                if exist(filenamecheckprevious, 'file') == 2
                    filenametoload = filenamecheckprevious;
                end
            end
        end
        
        if ~isempty(filenametoload)
            
            %close advanced validity checking window (if open) when we load analysis
            if ishandle(advancedvalidityfigure)
                delete(advancedvalidityfigure);
            end
            %close advanced reversal detection window (if open) when we load analysis
            if ishandle(advancedrevfigure)
                delete(advancedrevfigure);
            end
            %close advanced omega detection window (if open) when we load analysis
            if ishandle(advancedomegafigure)
                delete(advancedomegafigure);
            end
            
            ztdata = load(filenametoload);
            
            allloadedsofar = true;
            for i=1:numel(trytoload)
                if isfield(ztdata, trytoload(i))
                    eval([char(trytoload(i)) '= ztdata.' char(trytoload(i)) ';']);
                else
                    if allloadedsofar
                        fprintf('Data to be loaded does not contain values for the following variables: ''%s''', char(trytoload(i)));
                        allloadedsofar = false;
                    else
                        fprintf(', ''%s''', char(trytoload(i)));
                    end
                end
            end
            if ~allloadedsofar %if there was at least one thing that we couldn't load
                fprintf('\n');
            end

            for i=1:numel(trytosetstring)
                eval(['set(handles.' char(trytosetstring(i)) ', ''String'', num2str(' char(trytosetstring(i)) '));']);
            end
            
            allsetsofar = true;
            for i=1:numel(trytosetvalue)
                if isfield(ztdata, trytosetvalue(i))
                    eval(['set(handles.' char(trytosetvalue(i)) ', ''Value'', ztdata.' char(trytosetvalue(i)) ');']);
                else
                    if allsetsofar
                        fprintf('Data to be loaded does not contain values for the following GUI parameters: ''%s''', char(trytosetvalue(i)));
                        allsetsofar = false;
                    else
                        fprintf(', ''%s''', char(trytosetvalue(i)));
                    end
                end
            end
            if ~allsetsofar %if there was at least one thing that we couldn't load
                fprintf('\n');
            end

            %Renaming, combining or otherwise modifying the values for the sake of backwards compatibility
            converted = false;
            if numel(objects) > 0
                if ~isfield(objects, 'behaviour')
                    for i=1:numel(objects)
                        objects(i).behaviour = ones(size(objects(i).time)) * CONST_BEHAVIOUR_UNKNOWN;
                    end
                    converted = true;
                    fprintf('In the absence of behaviour data, initialized behaviour of all objects as unknown.\n');
                end
                if isfield(objects, 'rev')
                    for i=1:numel(objects)
                        objects(i).behaviour = objects(i).rev * CONST_BEHAVIOUR_REVERSAL;
                    end
                    objects = rmfield(objects, 'rev');
                    converted = true;
                    fprintf('Converted reversal data.\n');
                end
                if isfield(objects, 'invalid')
                    for i=1:numel(objects)
                        objects(i).behaviour(objects(i).invalid) = CONST_BEHAVIOUR_INVALID;
                    end
                    objects = rmfield(objects, 'invalid');
                    converted = true;
                    fprintf('Converted invalid object flags.\n');
                end
                if ~isfield(objects, 'eccentricity')
                    for i=1:numel(objects)
                        objects(i).eccentricity = NaN(1, objects(i).duration);
                    end
                    converted = true;
                    fprintf('Initialized eccentricity measures as NaNs.\n');
                end
                if ~isfield(objects, 'solidity')
                    for i=1:numel(objects)
                        objects(i).solidity = NaN(1, objects(i).duration);
                    end
                    converted = true;
                    fprintf('Initialized solidity measures as NaNs.\n');
                end
                if ~isfield(objects, 'orientation')
                    for i=1:numel(objects)
                        objects(i).orientation = NaN(1, objects(i).duration);
                    end
                    converted = true;
                    fprintf('Initialized orientation measures as NaNs.\n');
                end
                if ~isfield(objects, 'compactness')
                    for i=1:numel(objects)
                        objects(i).compactness = objects(i).perimeter.^2./objects(i).area;
                    end
                    converted = true;
                    fprintf('Derived compactness measures from the perimeter and area data for all objects.\n');
                end
                if ~isfield(objects, 'frame')
                    for i=1:numel(objects)
                        objects(i).frame = converttoframe(objects(i).time);
                    end
                    converted = true;
                    fprintf('Derived frame data from the time data for all objects.\n');
                end
                if ~isfield(objects, 'target')
                    for i=1:numel(objects)
                        objects(i).target(1:objects(i).duration) = CONST_TARGET_NOMANSLAND;
                    end
                    converted = true;
                    fprintf('Worm positions initialized as not located within any target area at any time.\n');
                end
                if ~isfield(objects, 'targetreached')
                    for i=1:numel(objects)
                        objects(i).targetreached(1:objects(i).duration) = CONST_TARGET_NOMANSLAND;
                    end
                    converted = true;
                    fprintf('Worm positions initialized as having not entered any target area at any time.\n');
                end
                foundoldstyleinvalid = false;
                foundunknownbehaviour = false;
                foundoldstyleeccentricity = false;
                for i=1:numel(objects)
                    oldstyleinvalidwhere = objects(i).behaviour == 7;
                    objects(i).behaviour(oldstyleinvalidwhere) = CONST_BEHAVIOUR_INVALID;
                    if any(oldstyleinvalidwhere)
                        foundoldstyleinvalid = true;
                    end
                    unknownbehaviourwhere = objects(i).behaviour > CONST_BEHAVIOUR_INVALID;
                    objects(i).behaviour(unknownbehaviourwhere) = CONST_BEHAVIOUR_UNKNOWN;
                    if any(unknownbehaviourwhere)
                        foundunknownbehaviour = true;
                    end
                    if any(objects(i).eccentricity > 1)
                        foundoldstyleeccentricity = true; %if any object has old-style eccentricity, we will convert all objects
                    end
                end
                if foundoldstyleeccentricity
                    converted = true;
                    for i=1:numel(objects)
                        objects(i).eccentricity = 1-(objects(i).eccentricity/100);
                    end
                    fprintf('Converted old-style eccentricity values to new style.\n');
                end
                if foundoldstyleinvalid
                    converted = true;
                    fprintf('Converted old-style flags of invalid behaviour to new style.\n');
                end
                if foundunknownbehaviour
                    converted = true;
                    fprintf('Uninterpretable behaviour values in the analysis savefile have been initialized as unknown.\n');
                end
            end
            if omegaeccentricity > 1
                omegaeccentricity = 1-(omegaeccentricity/100);
                set(handles.omegaeccentricity, 'String', num2str(omegaeccentricity));
                converted = true;
                fprintf('Converted old-style omega eccentricity threshold to new style.\n');
            end
            if ~isfield(ztdata, 'detectionarea')
                detectionarea = false(movieheight, moviewidth);
                if isfield(ztdata, 'thresholdxmin') && isfield(ztdata, 'thresholdxmax') && isfield(ztdata, 'thresholdymin') && isfield(ztdata, 'thresholdymax')
                    detectionarea(round(ztdata.thresholdymin):round(ztdata.thresholdymax), round(ztdata.thresholdxmin):round(ztdata.thresholdxmax)) = true;
                    converted = true;
                    fprintf('Converted old-style detection area definition.\n');
                elseif isfield(ztdata, 'thresholdingarea')
                    detectionarea = ztdata.thresholdingarea;
                    converted = true;
                    fprintf('Converted detection area.\n');
                end
            end
            if ~isfield(ztdata, 'measurementarea')
                measurementarea = false(movieheight, moviewidth);
                if isfield(ztdata, 'validxmin') && isfield(ztdata, 'validxmax') && isfield(ztdata, 'validymin') && isfield(ztdata, 'validymax')
                    measurementarea(round(ztdata.validymin):round(ztdata.validymax), round(ztdata.validxmin):round(ztdata.validxmax)) = true;
                    converted = true;
                    fprintf('Converted old-style measurement area definition.\n');
                elseif isfield(ztdata, 'validarea')
                    measurementarea = ztdata.validarea;
                    converted = true;
                    fprintf('Converted measurement area.\n');
                end
            end
            if ~isfield(ztdata, 'startingarea')
                startingarea = false(movieheight, moviewidth);
                fprintf('Initialized starting area as nothing.\n');
            end
            if ~isfield(ztdata, 'endingarea')
                endingarea = false(movieheight, moviewidth);
                fprintf('Initialized ending area as nothing.\n');
            end
            if ~isfield(ztdata, 'revdisplayduration') && isfield(ztdata, 'revframestoshow')
                revdisplayduration = ztdata.revframestoshow  / framerate;
                converted = true;
                fprintf('Converted manual reversal detection movie display duration.\n');
            end
            if ~isfield(ztdata, 'valideccentricitymin') && isfield(ztdata, 'validroundnessmin')
                valideccentricitymin = ztdata.validroundnessmin;
                converted = true;
                fprintf('Converted minimal eccentricity values.\n');
            end
            if ~isfield(ztdata, 'valideccentricitymax') && isfield(ztdata, 'validroundnessmax')
                valideccentricitymax = ztdata.validroundnessmax;
                converted = true;
                fprintf('Converted maximal eccentricity values.\n');
            end
            if ~isfield(ztdata, 'thresholdsizemin') && isfield(ztdata, 'thresholdsize')
                thresholdsizemin = ztdata.thresholdsize;
                set(handles.thresholdsizemin, 'String', num2str(thresholdsizemin));
                converted = true;
                fprintf('Converted minimal object size.\n');
            end
            if ~isfield(ztdata, 'thresholdintensity') && isfield(ztdata, 'thresholdlevel')
                thresholdintensity = ztdata.thresholdlevel;
                set(handles.thresholdintensity, 'String', num2str(thresholdintensity));
                converted = true;
                fprintf('Converted threshold intensity.\n');
            end
            if ~isfield(ztdata, 'detectionradius') && isfield(ztdata, 'thresholdradius')
                detectionradius = ztdata.thresholdradius;
                set(handles.detectionradius, 'String', num2str(detectionradius));
                converted = true;
                fprintf('Converted detection radius.\n');
            end
            if ~isfield(ztdata, 'measurementradius') && isfield(ztdata, 'validradius')
                measurementradius = ztdata.validradius;
                set(handles.measurementradius, 'String', num2str(measurementradius));
                converted = true;
                fprintf('Converted measurement radius.\n');
            end
            if ~isfield(ztdata, 'scalingfactor') || ztdata.scalingfactor <= 0
                scalingfactor = 1; %in previous versions it was possible to set the scaling factor to zero (or rather, to not set it and hence have it at zero). the new way of dealing with it (which should be more user-friendly in principle) is to have a default scaling factor of 1 (meaning that the units will be in pixels)
                set(handles.scalingfactor, 'String', num2str(scalingfactor));
                converted = true;
                fprintf('In the absence of relevant data, scaling initialized factor as 1.\n');
            end
            if ~isfield(ztdata, 'thresholdspeedmax')
                thresholdspeedmax = 30 * scalingfactor; %in early versions there was a hard-coded speed limit of 30 pixels per frame. Now we need to convert it into pixels
                set(handles.thresholdspeedmax, 'String', num2str(thresholdspeedmax));
                converted = true;
                fprintf('Converted presumed old-style hardcoded maximum speed value to 30*scalingfactor (%f).\n', thresholdspeedmax);
            end
            if ~isfield(ztdata, 'detectionareadisplay') && isfield(ztdata, 'unthresholdableareadisplay')
                detectionareadisplay = ztdata.unthresholdableareadisplay;
                set(handles.detectionareadisplay, 'Value', detectionareadisplay);
                converted = true;
                fprintf('Converted detection area display flag.\n');
            end
            if ~isfield(ztdata, 'measurementareadisplay') && isfield(ztdata, 'validareadisplay')
                measurementareadisplay = ztdata.validareadisplay;
                set(handles.measurementareadisplay, 'Value', measurementareadisplay);
                converted = true;
                fprintf('Converted measurement area display flag.\n');
            end
            if ~isfield(ztdata, 'detectionwhat') && isfield(ztdata, 'thresholdwhat')
                detectionwhat = ztdata.thresholdwhat;
                set(handles.detectionwhat, 'Value', detectionwhat);
                converted = true;
                fprintf('Converted detection area add or remove flag.\n');
            end
            if ~isfield(ztdata, 'detectionwhere') && isfield(ztdata, 'thresholdwhere')
                detectionwhere = ztdata.thresholdwhere;
                set(handles.detectionwhere, 'Value', detectionwhere);
                converted = true;
                fprintf('Converted detection area specification style.\n');
            end
            if ~isfield(ztdata, 'measurementwhat') && isfield(ztdata, 'validwhat')
                measurementwhat = ztdata.validwhat;
                set(handles.measurementwhat, 'Value', measurementwhat);
                converted = true;
                fprintf('Converted measurement area add or remove flag.\n');
            end
            if ~isfield(ztdata, 'measurementwhere') && isfield(ztdata, 'validwhere')
                measurementwhere = ztdata.validwhere;
                set(handles.measurementwhere, 'Value', measurementwhere);
                converted = true;
                fprintf('Converted measurement area specification style.\n');
            end
            if ~isfield(ztdata, 'wormshowframeslider') && (isfield(ztdata, 'wormshow') && isfield(ztdata.wormshow, 'frameslider')) %isfield is weird in the sense that is we have a.b.c , 'b.c' is not a field of a, so we have to do it step by step (and this is why I no longer use handles.wormshow.blahblah)
                set(handles.wormshowframeslider, 'Value', ztdata.wormshow.frameslider);
                converted = true;
                fprintf('Converted current frame counter.\n');
            end
            if ~isfield(ztdata, 'revangle') && isfield(ztdata, 'revcriticalangle')
                revangle = ztdata.revcriticalangle;
                set(handles.revangle, 'String', num2str(revangle));
                converted = true;
                fprintf('Converted critical reversal angle.\n');
            end
            if isfield(ztdata, 'saveversion') && strcmpi(earlierversion(ztdata.saveversion, '2.7.3'), 'earlier')
                if ~isnan(detectionradius) && ~isnan(scalingfactor) && (isfield(ztdata, 'detectionradius') || isfield(ztdata, 'thresholdradius')) %only convert it if it was loaded from the analysis data, not if it just kept the current value
                    detectionradius = round(detectionradius * scalingfactor); %detectionradius can be a non-integer; only rounding to avoid excessive precision for larger numbers
                    set(handles.detectionradius, 'String', num2str(detectionradius));
                    converted = true;
                    fprintf('Converted detection area marking radius from pixels to micrometers.\n');
                end
                if ~isnan(measurementradius) && ~isnan(scalingfactor) && (isfield(ztdata, 'measurementradius') || isfield(ztdata, 'validradius')) %only convert it if it was loaded from the analysis data, not if it just kept the current value
                    measurementradius = round(measurementradius * scalingfactor); %measurementradius can be a non-integer; only rounding to avoid excessive precision for larger numbers
                    set(handles.measurementradius, 'String', num2str(measurementradius));
                    converted = true;
                    fprintf('Converted measurement area marking radius from pixels to micrometers.\n');
                end
                if ~isnan(validdurationminimum) && isfield(ztdata, 'validdurationminimum') %only convert it if it was loaded from the analysis data, not if it just kept the current value
                    validdurationminimum = validdurationminimum/framerate;
                    set(handles.validdurationminimum, 'String', num2str(validdurationminimum));
                    converted = true;
                    fprintf('Converted measurement area marking radius from frames to seconds.\n');
                end
                if ~isnan(thresholdsizemin) && ~isnan(scalingfactor) && (isfield(ztdata, 'thresholdsizemin') || isfield(ztdata, 'thresholdsize')) %only convert it if it was loaded from the analysis data, not if it just kept the current value
                    thresholdsizemin = round(thresholdsizemin * scalingfactor^2); %thresholdsizemin can be a non-integer; only rounding to avoid excessive precision for larger numbers
                    set(handles.thresholdsizemin, 'String', num2str(thresholdsizemin));
                    converted = true;
                    fprintf('Converted object detection minimum size from pixels to um^2.\n');
                end
                if ~isnan(thresholdsizemax) && ~isnan(scalingfactor) && isfield(ztdata, 'thresholdsizemax') %only convert it if it was loaded from the analysis data, not if it just kept the current value
                    thresholdsizemax = round(thresholdsizemax * scalingfactor^2); %thresholdsizemax can be a non-integer; only rounding to avoid excessive precision for larger numbers
                    set(handles.thresholdsizemax, 'String', num2str(thresholdsizemax));
                    converted = true;
                    fprintf('Converted object detection maximum size from pixels to um^2.\n');
                end
                if ~isnan(revdisplacementwindow) && isfield(ztdata, 'revdisplacementwindow') %only convert it if it was loaded from the analysis data, not if it just kept the current value
                    revdisplacementwindow = revdisplacementwindow/framerate;
                    converted = true;
                    fprintf('Converted reversal detection displacement window from frames to seconds.\n');
                end
                if ~isnan(revextrapolate) && isfield(ztdata, 'revextrapolate') %only convert it if it was loaded from the analysis data, not if it just kept the current value
                    revextrapolate = revextrapolate/framerate;
                    converted = true;
                    fprintf('Converted reversal detection maximal extrapolation time from frames to seconds.\n');
                end
                if ~isnan(revdurationmax) && isfield(ztdata, 'revdurationmax') %only convert it if it was loaded from the analysis data, not if it just kept the current value
                    revdurationmax = revdurationmax/framerate;
                    converted = true;
                    fprintf('Converted maximal reversal duration from frames to seconds.\n');
                end
                if ~isnan(omegadurationmin) && isfield(ztdata, 'omegadurationmin') %only convert it if it was loaded from the analysis data, not if it just kept the current value
                    omegadurationmin = omegadurationmin/framerate;
                    converted = true;
                    fprintf('Converted minimal omega duration from frames to seconds.\n'); 
                end
                if ~isnan(omegatolerance) && isfield(ztdata, 'omegatolerance') %only convert it if it was loaded from the analysis data, not if it just kept the current value
                    omegatolerance = omegatolerance/framerate;
                    converted = true;
                    fprintf('Converted omega interruption tolerance from frames to seconds.\n');
                end
                
                somethingnonstandard = false;
                nonstandardmessage = 'Warning: the loaded values for the following behaviour detection parameters appear to be nonstandard: ';

                if revdisplacementwindow ~= revdisplacementwindowdefault
                    somethingnonstandard = true;
                    nonstandardmessage = [nonstandardmessage sprintf('reversal displacement window (%f loaded vs %f default), ', revdisplacementwindow, revdisplacementwindowdefault)];
                end
                if revextrapolate ~= revextrapolatedefault
                    somethingnonstandard = true;
                    nonstandardmessage = [nonstandardmessage sprintf('reversal detection maximal extrapolation time (%f loaded vs %f default), ', revextrapolate, revextrapolatedefault)];
                end
                if revdurationmax ~= revdurationmaxdefault
                    somethingnonstandard = true;
                    nonstandardmessage = [nonstandardmessage sprintf('maximal reversal duration (%f loaded vs %f default), ', revdurationmax, revdurationmaxdefault)];
                end
                if omegadurationmin ~= omegadurationmindefault
                    somethingnonstandard = true;
                    nonstandardmessage = [nonstandardmessage sprintf('minimal omega duration (%f loaded vs %f default), ', omegadurationmin, omegadurationmindefault)];
                end
                if omegatolerance ~= omegatolerancedefault
                    somethingnonstandard = true;
                    nonstandardmessage = [nonstandardmessage sprintf('omega interruption tolerance (%f loaded vs %f default), ', omegatolerance, omegatolerancedefault)];
                end

                if somethingnonstandard
                    nonstandardmessage = [nonstandardmessage(1:end-2) '. Do you wish to reset these parameters to their standard values (recommended)?'];
                    if strcmp(questdlg(nonstandardmessage,'Warning: some behaviour detection parameters are nonstandard','Use standard values','Keep the current values','Use standard values'),'Use standard values')
                        revdisplacementwindow = revdisplacementwindowdefault;
                        revextrapolate = revextrapolatedefault;
                        revdurationmax = revdurationmaxdefault;
                        omegadurationmin = omegadurationmindefault;
                        omegatolerance = omegatolerancedefault;
                        converted = true;
                        fprintf('Reset some advanced behaviour detection parameters to their default values.\n');
                    end
                end
                
            end
            
            if converted
                fprintf('Converted some old-format analysis data fields to the new format (see above). It is recommended to double-check that all values make sense.\n');
            end
            
            cachedindex = NaN; %clear cached frame because normalization parameters may have changed
            recalculatemeanperimeter; %older versions had wrong values, so we just recalculate the mean perimeter all the time (TODO: should only call it if we detect that the version is older than '2.5.3pre2'.
            setframeslider %setting the time and frame boxes to the right value, and also calling wormshow

            fprintf('Analysis data loaded successfully from %s .\n', filenametoload);
            
        else
            fprintf(2, 'Warning: could not find analysis save file.\n');
            questdlg(sprintf('Warning: could not find analysis save file.'), 'Data not loaded', 'OK', 'OK');
        end
        
    end
    
    function correctedangles = checkangleoverflow(angles)
        correctedangles = angles;
        correctedangles(correctedangles>pi) = correctedangles(correctedangles>pi) - 2*pi;
        correctedangles(correctedangles<-pi) = correctedangles(correctedangles<-pi) + 2*pi;
    end

    function yesinvalid = anyinvalid
        yesinvalid = false;
        for i=1:numel(objects)
            if any(objects(i).behaviour == CONST_BEHAVIOUR_INVALID)
                yesinvalid = true;
                break;
            end
        end
    end

    function exportastxt(hobj, eventdata)
        
        %warning the user when trying to export results without having performed validity checking first
        if ~anyinvalid
            if strcmp(questdlg('Warning: a lack of invalid objects indicates that the validity-checking step may have been skipped. Exporting the data without excluding invalid objects such as merged worms or dirt will produce inaccurate results. Use the "check validity" button before exporting to automatically exclude such objects from the averages.','Warning: validity checking may have been skipped','Proceed anyway','Cancel and fix it','Cancel and fix it'),'Cancel and fix it')
                return;
            end
        end
        
        waithandle = [];
        
        if numel(selectedfiles) > 0
            try
                waithandle = waitbar(0,'Exporting data as plaintext...','Name','Processing', 'CreateCancelBtn', 'delete(gcbf)');
                dots = strfind(selectedfiles{1}, '.');
                if isempty(dots)
                    lastvalidchar = numel(selectedfiles{1}); %if we didn't find any dots in the full filename, then we'll just use the whole filename
                else
                    lastvalidchar = dots(end)-1;
                end
                exportfilename = [selectedfiles{1}(1:lastvalidchar) '-exported.txt'];
                
                for i=1:14
                    switch i
                        case 1
                            averagespeed = plotit(hobj, eventdata, CONST_DISPLAY_SPEED, true, true);
                        case 2
                            averagex = plotit(hobj, eventdata, CONST_DISPLAY_X, true, true);
                        case 3
                            averagey = plotit(hobj, eventdata, CONST_DISPLAY_Y, true, true);
                        case 4
                            averagelength = plotit(hobj, eventdata, CONST_DISPLAY_LENGTH, true, true);
                        case 5
                            averagewidth = plotit(hobj, eventdata, CONST_DISPLAY_WIDTH, true, true);
                        case 6
                            averagearea = plotit(hobj, eventdata, CONST_DISPLAY_AREA, true, true);
                        case 7
                            averageperimeter = plotit(hobj, eventdata, CONST_DISPLAY_PERIMETER, true, true);
                        case 8
                            averageeccentricity = plotit(hobj, eventdata, CONST_DISPLAY_ECCENTRICITY, true, true);
                        case 9
                            averagesolidity = plotit(hobj, eventdata, CONST_DISPLAY_SOLIDITY, true, true);
                        case 10
                            averagecompactness = plotit(hobj, eventdata, CONST_DISPLAY_COMPACTNESS, true, true);
                        case 11
                            averagedirectionchange = plotit(hobj, eventdata, CONST_DISPLAY_DIRECTIONCHANGE, true, true);
                        case 12
                            averagereversal = plotit(hobj, eventdata, CONST_DISPLAY_REVERSAL, true, true);
                        case 13
                            averageomega = plotit(hobj, eventdata, CONST_DISPLAY_OMEGA, true, true);
                        case 14
                            averagen = plotit(hobj, eventdata, CONST_DISPLAY_NNUMBER, true, true);
                    end
                            
                    if ishandle(waithandle)
                        waitbar(i*0.05,waithandle);
                        drawnow;
                    else %user canceled
                        %exportfile not yet opened, so we don't even have to worry about closing it
                        fprintf('Data exporting has been cancelled by the user before the output file could have been modified.\n');
                        return;
                    end
                end
                
                if isempty(averagen)
                    if ishandle(waithandle)
                        close(waithandle)
                    end
                    questdlg('Could not export analysis results, because apparently there is no analysis data available for this movie. Try analysing the movie first.', 'Could not export as txt', 'OK', 'OK');
                    return;
                else
                    exportfile = fopen(exportfilename, 'w');
                    fprintf(exportfile, 'Frame\tTime\tN\tSpeed\tProportion reversing\tProportion in omegas\tX-coordinate\tY-coordinate\tLength\tWidth\tArea\tPerimeter\tEccentricity\tSolidity\tCompactness\tDirection change\n');
                    for i=1:lastframe
                        if ishandle(waithandle)
                            if mod(i, waitbarfps) == 0
                                waitbar(0.70+0.30*(i/lastframe),waithandle);
                                drawnow;
                            end
                        else %user canceled
                            error('Exportastxt:userCancelled', 'Data exporting has been cancelled by the user');
                        end
                        fprintf(exportfile,'%d\t', i); %Frame
                        fprintf(exportfile,'%f\t', (i-1)/framerate); %Time
                        fprintf(exportfile,'%d\t', averagen(i)); %N
                        fprintf(exportfile,'%f\t', averagespeed(i)); %Speed
                        fprintf(exportfile,'%f\t', averagereversal(i)); %tProportion reversing
                        fprintf(exportfile,'%f\t', averageomega(i)); %tProportion in omegas
                        fprintf(exportfile,'%f\t', averagex(i)); %X-coordinate
                        fprintf(exportfile,'%f\t', averagey(i)); %Y-coordinate
                        fprintf(exportfile,'%f\t', averagelength(i)); %Length
                        fprintf(exportfile,'%f\t', averagewidth(i)); %Width
                        fprintf(exportfile,'%f\t', averagearea(i)); %Area
                        fprintf(exportfile,'%f\t', averageperimeter(i)); %Perimeter
                        fprintf(exportfile,'%f\t', averageeccentricity(i)); %Eccentricity
                        fprintf(exportfile,'%f\t', averagesolidity(i)); %Solidity
                        fprintf(exportfile,'%f\t', averagecompactness(i)); %Compactness
                        fprintf(exportfile,'%f\t', averagedirectionchange(i)); %Direction change
                        fprintf(exportfile, '\n');
                    end
                    fclose(exportfile);
                end
            catch, err = lasterror; %#ok<LERR,CTCH> %catch err would be nicer, but that doesn't work on older versions of Matlab 
                fprintf('Data exporting has been cancelled.');
                try
                    fclose(exportfile);
                    fprintf(' The unfinished output file has been closed successfully.');
                catch %#ok<CTCH>
                    fprintf(' The unfinished output file could not be closed.');
                end
                try
                    delete(exportfilename);
                    fprintf(' The unfinished output file %s has been deleted successfully.', exportfilename);
                catch %#ok<CTCH>
                    fprintf(' The unfinished output file %s could not be deleted.', exportfilename);
                end
                fprintf('\n');
                if ~strcmp(err.identifier, 'Exportastxt:userCancelled')
                    fprintf(2, 'Warning: there was an unexpected error while trying to export the analysis data as a txt file.\n');
                    fprintf(2, '%s\n', err.message);
                    questdlg('Failed to export the analysis data due to an unexpected error.', 'Could not export as txt', 'OK', 'OK');
                end
                if ishandle(waithandle)
                    close(waithandle)
                end
                return;
            end
        end
        if ishandle(waithandle)
            close(waithandle);
            fprintf('Results successfully exported as %s .\n', exportfilename);
        end
        
    end
    
    %{
    function [textreturn] = datacursorupdate(hobj,eventdata) %#ok<INUSL>
        pos = get(eventdata,'Position');
        x = pos(1);
        y = pos(2);
        objectids = {};
        
        for i=1:numel(objects)
            for j=1:objects(i).duration
                if ~invalid(i, j, whichparameter)
                    switch whichparameter
                        case CONST_DISPLAY_SPEED
                            comparenow = smoothspeed(i, j);
                        case CONST_DISPLAY_X
                            comparenow = objects(i).x(j);
                        case CONST_DISPLAY_Y
                            comparenow = objects(i).y(j);
                        case CONST_DISPLAY_LENGTH
                            comparenow = objects(i).length(j);
                        case CONST_DISPLAY_WIDTH
                            comparenow = objects(i).avgwid(j);
                        case CONST_DISPLAY_AREA
                            comparenow = objects(i).area(j);
                        case CONST_DISPLAY_PERIMETER
                            comparenow = objects(i).perimeter(j);
                        case CONST_DISPLAY_ECCENTRICITY
                            comparenow = objects(i).eccentricity(j);
                        case CONST_DISPLAY_DIRECTIONCHANGE
                            comparenow = objects(i).directionchange(j);
                    end
                    if objects(i).time(j) == x && comparenow == y
                        objectids{numel(objectids)+1} = num2str(i); %#ok<AGROW>
                    end
                end
            end
        end
        
        idstring = '';
        for i=1:numel(objectids)
            idstring = [idstring char(objectids{i})]; %#ok<AGROW>
            if i<numel(objectids)
                idstring = [idstring ';']; %#ok<AGROW>
            end
        end
        
        if ~isempty(idstring)
            if numel(objectids) > 1
                idstring = ['IDs: ', idstring];
            else
                idstring = ['ID: ', idstring];
            end
            textreturn = {['Value: ',num2str(y)],...
                          ['Time: ',num2str(x)],...
                          ['Frame: ',num2str(converttoframe(x))],...
                          idstring};
        else
            textreturn = {['Value: ',num2str(y)],...
                          ['Time: ',num2str(x)],...
                          ['Frame: ',num2str(converttoframe(x))]};
        end
    end
    %}

    function autodetectreversals (hobj, eventdata) %#ok<INUSD>
        
        %making sure that time-consuming manual reversal detection don't get accidentally overwritten by fast automatic reversal detection, unless the user insists
        foundexistingrevdet = false;
        foundunknown = false;
        for i=1:numel(objects)
            if any(objects(i).behaviour == CONST_BEHAVIOUR_REVERSAL | objects(i).behaviour == CONST_BEHAVIOUR_FORWARDS | objects(i).behaviour == CONST_BEHAVIOUR_OMEGA)
                foundexistingrevdet = true;
            end
            if any(objects(i).behaviour == CONST_BEHAVIOUR_UNKNOWN)
                foundunknown = true;
            end
            if foundexistingrevdet && foundunknown
                break;
            end
        end
        if foundexistingrevdet
            questionstring = 'Warning: the movie seems to be already ';
            if foundunknown
                questionstring = [questionstring 'partially'];
            else
                questionstring = [questionstring 'fully'];
            end
            questionstring = [questionstring ' processed in terms of reversal detection. Attempting to autodetect reversals now will overwrite the flags of previously detected behaviours.'];
            if strcmp(questdlg(questionstring, 'Warning: previously detected behavioural flags may be overwritten','Proceed and redetect','Cancel','Proceed and redetect'),'Cancel')
                return;
            end
        end
        if detectomegas
            foundvalidsolidity = false;
            for i=1:numel(objects)
                if any(~isnan(objects(i).solidity))
                    foundvalidsolidity = true;
                    break;
                end
            end
            if ~foundvalidsolidity
                if omegaeccentricity <= 0.80
                    if strcmp(questdlg('Warning: the solidity measure is not available. This is probably because you loaded an analysis savefile generated by an earlier version. You may proceed, but omega detection will be less accurate without the solidity measure. Alternatively, by retracking the objects, the solidity measure will become available, allowing more accurate omega detection.', 'Warning: omega detection may be inaccurate','Proceed','Cancel','Proceed'),'Cancel')
                        return;
                    end
                else
                    whichchoice = questdlg(sprintf('Warning: the solidity measure is not available. This is probably because you loaded an analysis savefile generated by an earlier version. You may proceed, but omega detection will be less accurate without the solidity measure. Alternatively, by retracking the objects, the solidity measure will become available, allowing more accurate omega detection. Note that without a solidity measure, a high eccentricity threshold can result in an increased rate of false positives. Your current eccentricity threshold is %g. It is recommended to decrease it to at most 0.80.', omegaeccentricity), 'Warning: omega detection may be inaccurate','Proceed with the current settings','Decrease threshold to 0.80 and proceed','Cancel','Proceed with the current settings');
                    if strcmp(whichchoice, 'Decrease threshold to 0.80 and proceed')
                        omegaeccentricity = 0.80;
                        set(handles.omegaeccentricity, 'String', num2str(omegaeccentricity));
                    elseif strcmp(whichchoice, 'Cancel')
                        return;
                    end
                end
            end
        end
        
        if ~anyinvalid
            if strcmp(questdlg('Warning: a lack of invalid objects indicates that the validity-checking step may have been skipped. Trying to auto-detect the behaviour without first excluding invalid objects such as merged worms or dirt will produce inaccurate results. Use the "check validity" button to automatically exclude such objects.','Warning: validity checking may have been skipped','Proceed anyway','Cancel and fix it','Cancel and fix it'),'Cancel and fix it')
                return;
            end
        end
        
        CONST_REVDET_NORMAL = 1;
        CONST_REVDET_TURN = 2;
        CONST_REVDET_OMEGA = 3;
        CONST_REVDET_INVALID = 4;
        
        CONST_OMEGADET_ECCENTRIC = 1; %eccentricity measure indicates an omega turn
        CONST_OMEGADET_COMPACT = 2; %compactness measure indicates self-touching
        CONST_OMEGADET_TOLERATED = 3; %frame considered an omega thanks to neighbouring frames
        CONST_OMEGADET_NOT = 4; %not an omega turn
        CONST_OMEGADET_DEFINITELY = 5; %we have decided to definitely consider it an omega turn
        
        minrevangle = (180-revangle)/180*pi;
        
        decisionfromcancellings = 0;
        decisionfromrevframes = 0;
        omegaframes = 0;
        revdisplacementwindowframes = max([ceil(revdisplacementwindow*framerate), 1]);

        for i=1:numel(objects)
            %clearing previously detected behaviours (except invalid frames)
            objects(i).behaviour(objects(i).behaviour ~= CONST_BEHAVIOUR_INVALID) = CONST_BEHAVIOUR_UNKNOWN;
            
            %calculating movement vectors
            dx = [NaN(1, revdisplacementwindowframes) objects(i).x(1+revdisplacementwindowframes:end)-objects(i).x(1:end-revdisplacementwindowframes)];
            dy = [NaN(1, revdisplacementwindowframes) objects(i).y(1+revdisplacementwindowframes:end)-objects(i).y(1:end-revdisplacementwindowframes)];
            directions = atan2(dy,dx);
            
            % computing angle differences between successive coordinate-displacements
            deltaangles = NaN(size(directions));
            deltaangles(2:end) = directions(2:end) - directions(1:end-1);
            %the delta angle between the zeroth and the first directions is assumed to be zero
            deltaangles(find(~isnan(deltaangles), 1)-1) = 0;
            
            %we always take the smallest angle for each turn so transform angle
            %differences greater than pi to their smaller negative equivalent and
            %values less than -pi to their smaller positive equivalent
            deltaangles = checkangleoverflow(deltaangles);
            
            
            %first we detect omega-turns
            if detectomegas
                validframes = objects(i).behaviour ~= CONST_BEHAVIOUR_INVALID;
                currentomegas = ones(1, objects(i).duration)*CONST_OMEGADET_NOT;
                currentomegas(validframes & objects(i).eccentricity <= omegaeccentricity) = CONST_OMEGADET_ECCENTRIC;
                currentomegas(validframes & objects(i).compactness <= omegacompactness) = CONST_OMEGADET_COMPACT;
                
                currentomegas(objects(i).solidity < omegasoliditymin) = CONST_OMEGADET_NOT; %exclude those with low solidity, even if they would normally be considered omegas
                
                %omega tolerance
                lastomega = NaN;
                foundnon = false;
                for j=1:objects(i).duration
                    if currentomegas(j) ~= CONST_OMEGADET_NOT
                        if foundnon && ~isnan(lastomega) && j-lastomega-1 <= round(omegatolerance*framerate)
                            currentomegas(lastomega+1:j-1) = CONST_OMEGADET_TOLERATED;
                        end
                        lastomega = j;
                        foundnon = false;
                    else %~currentomegas
                        if validframes(j)
                            foundnon = true;
                        else %~validframe
                            lastomega = NaN;
                            foundnon = false;
                        end
                    end
                end
                                
                somethingchanged = true; %in each iteration, we'll accept at most one validstationaryomegas interval per currentomegas interval. this indicates whether we managed to find any acceptable validstationaryomegas. if not, that means we've exhausted the currentomegas
                
                while somethingchanged
                    
                    somethingchanged = false;
                
                    %min omega duration check
                    omegastarts = strfind(currentomegas~=CONST_OMEGADET_NOT & currentomegas~=CONST_OMEGADET_DEFINITELY, [false true])+1;
                    if currentomegas(1) ~= CONST_OMEGADET_NOT && currentomegas(1) ~= CONST_OMEGADET_DEFINITELY
                        omegastarts = [1 omegastarts]; %#ok<AGROW>
                    end
                    omegaends = strfind(currentomegas~=CONST_OMEGADET_NOT & currentomegas~=CONST_OMEGADET_DEFINITELY, [true, false]);
                    if currentomegas(end) ~= CONST_OMEGADET_NOT && currentomegas(end) ~= CONST_OMEGADET_DEFINITELY
                        omegaends = [omegaends numel(currentomegas)]; %#ok<AGROW>
                    end
                    omegadurations = omegaends - omegastarts + 1;
                    for j=1:numel(omegadurations)
                        if omegadurations(j) < round(omegadurationmin*framerate)
                            currentomegas(omegastarts(j):omegaends(j)) = CONST_OMEGADET_NOT;
                            omegadurations(j) = 0;
                        end
                    end

                    %greedy algorithm for finding, for each omega-flagged-interval, the longest continuous stretch of omega-flagged frames where the overall displacement is below the maximum omega movement distance allowed
                    for j=1:numel(omegadurations)
                        if omegadurations(j) == 0
                            continue;
                        end
                        
                        if hypot(objects(i).x(omegaends(j))-objects(i).x(omegastarts(j)), objects(i).y(omegaends(j))-objects(i).y(omegastarts(j))) * scalingfactor <= omegadisplacementmax %if the overall displacement over the entire interval is still within limits, we don't have to worry about calculating distances for each pair of points
                            currentomegas(omegastarts(j):omegaends(j)) = CONST_OMEGADET_DEFINITELY;
                            somethingchanged = true;
                        else
                            if license('checkout', 'Statistics_Toolbox') || license('test', 'Statistics_Toolbox') %if we're already using the statistics toolbox, or if we could use it
                                distancematrix = squareform(pdist([objects(i).x(omegastarts(j):omegaends(j))' objects(i).y(omegastarts(j):omegaends(j))'], 'euclidean')) * scalingfactor;
                            else %without the statistics toolbox, use a naive bruteforce approach
                                for k=omegastarts(j):omegaends(j)
                                    for m=omegastarts(j):omegaends(j)
                                        distancematrix(k-omegastarts(j)+1, m-omegastarts(j)+1) = hypot(objects(i).x(k)-objects(i).x(m), objects(i).y(k)-objects(i).y(m)) * scalingfactor;
                                    end
                                end
                            end
                            
                            %somewhat vectorised way of getting a distance matrix of time elapsed between the datapoints
                            timematrix = NaN(size(distancematrix));
                            timevector = 0:size(distancematrix, 2)-1;
                            for k=1:size(distancematrix, 1)
                                timematrix(k, :) = timevector;
                                timevector = [k timevector(1:end-1)];
                            end
                            
                            while max(timematrix(:)) > 0
                                longesttimeindices = find(timematrix == max(timematrix(:)));
                                [longesttimefrom, longesttimeuntil] = ind2sub(size(timematrix), longesttimeindices);
                                
                                whichonesaremirrored = longesttimefrom > longesttimeuntil;
                                longesttimefrom(whichonesaremirrored) = [];
                                longesttimeuntil(whichonesaremirrored) = [];
                                
                                smallestdistance = Inf;
                                smallestdistancewhich = NaN;
                                for k=1:numel(longesttimefrom)
                                    if distancematrix(longesttimefrom(k), longesttimeuntil(k)) < smallestdistance
                                        smallestdistance = distancematrix(longesttimefrom(k), longesttimeuntil(k));
                                        smallestdistancewhich = k;
                                    end
                                end
                                
                                if smallestdistance <= omegadisplacementmax
                                    beststationaryomegafrom = omegastarts(j)+longesttimefrom(smallestdistancewhich)-1;
                                    beststationaryomegauntil = omegastarts(j)+longesttimeuntil(smallestdistancewhich)-1;
                                    currentomegas(beststationaryomegafrom:beststationaryomegauntil) = CONST_OMEGADET_DEFINITELY;
                                    somethingchanged = true;
                                    break;
                                end
                                
                                timematrix(longesttimeindices) = 0;
                            end
                            
                        end
                        
                    end
                end
                
                omegaframes = omegaframes + sum(currentomegas == CONST_OMEGADET_DEFINITELY);
                objects(i).behaviour(currentomegas == CONST_OMEGADET_DEFINITELY) = CONST_BEHAVIOUR_OMEGA;
            end
            
            
            %for reversal detection, first we just flag the frames where large orientation-changes occur
            reversalflags = ones(size(objects(i).behaviour)).*CONST_REVDET_NORMAL;
            for j=2:objects(i).duration
                if abs(deltaangles(j))>=minrevangle || (abs(deltaangles(j))<minrevangle && abs(deltaangles(j-1))<minrevangle && abs(deltaangles(j)+deltaangles(j-1))>minrevangle)
                    reversalflags(j) = CONST_REVDET_TURN;
                end
            end
            reversalflags(objects(i).behaviour == CONST_BEHAVIOUR_INVALID) = CONST_REVDET_INVALID;
            
            reversalflags(objects(i).behaviour == CONST_BEHAVIOUR_OMEGA) = CONST_REVDET_OMEGA;
            
            %then we check for each "track" (sequences of frames containing no invalid behaviours for a particular worm) if it makes more sense (fewer overall reversal frames) for the track to have started with the worm already reversing, or if it was moving forwards
            trackfrom = NaN;
            reversalfromF = NaN; %assuming the track starts with the worm moving forwards
            reversalfromR = 1; %assuming the track starts with the worm moving backwards. as here this is the first frame in which this object exists, no need to worry about previous omega frames for now
            reversalcancellingsF = 0;
            reversalcancellingsR = 0;
            newtrackF = objects(i).behaviour;
            newtrackR = objects(i).behaviour;
            j = 1;
            while j<=numel(reversalflags)
                
                if ~isnan(trackfrom) %already in a track
                    endthetrack = false;
                    
                    if reversalflags(j) == CONST_REVDET_TURN
                        if isnan(reversalfromF) %starting a reversal
                            reversalfromF = j;
                            if j>1 && reversalflags(j-1) == CONST_REVDET_OMEGA %if the track would start with a reversal immediately after an omega, penalize the assumption that led to this
                                reversalcancellingsF = reversalcancellingsF + 1;
                            end
                        else %was already doing a reversal, now resuming forwards movement
                            newtrackF(reversalfromF:j-1) = CONST_BEHAVIOUR_REVERSAL;
                            reversalfromF = NaN;
                        end
                        if isnan(reversalfromR) %starting a reversal
                            reversalfromR = j;
                            if j>1 && reversalflags(j-1) == CONST_REVDET_OMEGA %if the track would start with a reversal immediately after an omega, penalize the assumption that led to this
                                reversalcancellingsR = reversalcancellingsR + 1;
                            end
                        else %was already doing a reversal, now resuming forwards movement
                            newtrackR(reversalfromR:j-1) = CONST_BEHAVIOUR_REVERSAL;
                            reversalfromR = NaN;
                        end
                    elseif reversalflags(j) == CONST_REVDET_NORMAL
                        %if the reversal would continue beyond the maximum duration threshold, cancel the reversal, and add a penality point to the
                        %initial worm-direction assumption that produced this cancellation
                        if ~isnan(reversalfromF) && j-reversalfromF > round(revdurationmax*framerate)
                            reversalcancellingsF = reversalcancellingsF + 1;
                            reversalfromF = NaN;
                        end
                        if ~isnan(reversalfromR) && j-reversalfromR > round(revdurationmax*framerate)
                            reversalcancellingsR = reversalcancellingsR + 1;
                            reversalfromR = NaN;
                        end
                    elseif reversalflags(j) == CONST_REVDET_INVALID || reversalflags(j) == CONST_REVDET_OMEGA %reached the end of the track
                        lastvalid = j-1;
                        endthetrack = true;
                    else
                        fprintf(2, 'Warning: unexpected reversal detection token for object %d at frame %d. Proceeding by assuming it is invalid.\n', i, objects(i).frame(j));
                        lastvalid = j-1;
                        endthetrack = true;
                    end
                    if j == numel(reversalflags) && reversalflags(j) ~= CONST_REVDET_INVALID
                        lastvalid = j;
                        endthetrack = true;
                    end
                    
                    if endthetrack
                        %if it was doing a reversal when it got interrupted by an invalid frame we'll just flag it as long as we can
                        if ~isnan(reversalfromF)
                            newtrackF(reversalfromF:lastvalid) = CONST_BEHAVIOUR_REVERSAL;
                        end
                        if ~isnan(reversalfromR)
                            newtrackR(reversalfromR:lastvalid) = CONST_BEHAVIOUR_REVERSAL;
                        end
                        %frames not flagged as either reversal or invalid are presumed to be forwards movement
                        newtrackF(newtrackF==CONST_BEHAVIOUR_UNKNOWN) = CONST_BEHAVIOUR_FORWARDS;
                        newtrackR(newtrackR==CONST_BEHAVIOUR_UNKNOWN) = CONST_BEHAVIOUR_FORWARDS;
                        %check which assumption generated fewer cancelled reversals, and secondarily, which assumption generated fewer reversal frames.
                        %use the assumption that wins
                        if reversalcancellingsF < reversalcancellingsR
                            useF = true;
                            decisionfromcancellings = decisionfromcancellings + 1;
                        elseif reversalcancellingsR < reversalcancellingsF
                            useF = false;
                            decisionfromcancellings = decisionfromcancellings + 1;
                        else
                            decisionfromrevframes = decisionfromrevframes + 1;
                            revframesFsum = sum(newtrackF(trackfrom:lastvalid) == CONST_BEHAVIOUR_REVERSAL);
                            revframesRsum = sum(newtrackR(trackfrom:lastvalid) == CONST_BEHAVIOUR_REVERSAL);
                            if revframesFsum <= revframesRsum
                                useF = true;
                            else
                                useF = false;
                            end
                        end
                        if useF
                            objects(i).behaviour(trackfrom:lastvalid) = newtrackF(trackfrom:lastvalid);
                        else
                            objects(i).behaviour(trackfrom:lastvalid) = newtrackR(trackfrom:lastvalid);
                        end
                        trackfrom = NaN;
                    end
                    j = j + 1;
                else %not in a track
                    if reversalflags(j) == CONST_REVDET_INVALID || reversalflags(j) == CONST_REVDET_OMEGA
                        j = j + 1;
                    else %not invalid or omega, so we should check it again, without incrementing j
                        trackfrom = j;
                        reversalcancellingsF = 0;
                        reversalcancellingsR = 0;
                        reversalfromF = NaN;
                        reversalfromR = j;
                        if j>1 && reversalflags(j-1) == CONST_REVDET_OMEGA %if the track would start with a reversal immediately after an omega, penalize the assumption that led to this
                            reversalcancellingsR = reversalcancellingsR + 1;
                        end
                    end
                end
            end
            
        end
        
        fprintf('Automatic reversal detection finished successfully. Worm direction was decided based on max reversal duration violations %d times (%.0f%%).', decisionfromcancellings, decisionfromcancellings/(decisionfromcancellings+decisionfromrevframes)*100.0);
        if detectomegas
            fprintf(' %d frames have been flagged as omega turns.\n', omegaframes);
        else
            fprintf('\n');
        end
        
        wormshow;
    end

    function manualdetectreversals (hobj, eventdata) %#ok<INUSD>
        
        samedirectionmax = revangle/180*pi;
        reversedirectionmin = (180-revangle)/180*pi;
        
        uncertaincount = 0;
        revdisplacementwindowframes = max([ceil(revdisplacementwindow*framerate), 1]);
        revextrapolateframes = round(revextrapolate*framerate);
        
        for i=1:numel(objects)
            
            %if there are no unknowns for this worm, skip it.
            if sum(objects(i).behaviour == CONST_BEHAVIOUR_UNKNOWN) == 0
                continue;
            end
            
            %clearing reversal-related flags from the objects' behaviour because we don't want to superimpose the newly detected reversals on the already detected ones,
            %but instead re-detect the reversals. importantly, we're not setting invalid frames to unknown because obviously we need the invalid flags
            %to know where tracks start and end
            %objects(i).behaviour(objects(i).behaviour ~= CONST_BEHAVIOUR_INVALID) = CONST_BEHAVIOUR_UNKNOWN;
            
            % calculate coordinate-displacements
            dx = [NaN(1, revdisplacementwindowframes) objects(i).x(1+revdisplacementwindowframes:end)-objects(i).x(1:end-revdisplacementwindowframes)];
            dy = [NaN(1, revdisplacementwindowframes) objects(i).y(1+revdisplacementwindowframes:end)-objects(i).y(1:end-revdisplacementwindowframes)];
            
            % distances = hypot(dx,dy);
            
            directions = atan2(dy,dx);
            
            deltaangles = NaN(size(directions));
            deltaangles(2:end) = directions(2:end) - directions(1:end-1);
            %the delta angle between the zeroth and the first directions is assumed to be zero
            deltaangles(find(~isnan(deltaangles), 1)-1) = 0;
            
            %we always take the smallest angle for each turn so transform angle
            %differences greater than pi to their smaller negative equivalent and
            %values less than -pi to their smaller positive equivalent
            deltaangles = checkangleoverflow(deltaangles);
            
            consistentheadsfrom = NaN;
            consistentheads = false(1, numel(deltaangles));
            consistentheadsn = 0;
            for j=1:numel(deltaangles)
                if isnan(consistentheadsfrom) %currently not in a consistent headdirection interval
                    if (abs(deltaangles(j)) <= samedirectionmax || abs(deltaangles(j)) >= reversedirectionmin) && objects(i).behaviour(j) ~= CONST_BEHAVIOUR_INVALID %starting consistent headdirection interval
                        consistentheadsfrom = j;
                    end
                else %currently in a consistent headdirection interval
                    if (abs(deltaangles(j)) > samedirectionmax && abs(deltaangles(j)) < reversedirectionmin) || objects(i).behaviour(j) == CONST_BEHAVIOUR_INVALID %ending consistent headdirection interval
                        consistentheads(consistentheadsfrom:j-1) = true;
                        consistentheadsfrom = NaN;
                        consistentheadsn = consistentheadsn + 1;
                    end
                end
            end
            if ~isnan(consistentheadsfrom) %if the loop ended with a consistent headdirection interval still not closed, we end it now
                consistentheads(consistentheadsfrom:end) = true;
            end
            
            objectframeindex = 1;
            while ~isnan(objectframeindex) && objectframeindex <= objects(i).duration %going through the object
                
                if objects(i).time(objectframeindex) < timefrom || objects(i).time(objectframeindex) > timeuntil
                    objectframeindex = objectframeindex+1;
                    continue;
                end
                
                [trackfrom trackuntil] = findinterval(objects(i).behaviour, '# == CONST_BEHAVIOUR_UNKNOWN', 'first', objectframeindex, objects(i).duration);
                
                if ~isnan(trackfrom) && ~isnan(trackuntil)
                    
                    if trackuntil-trackfrom == 0 && (trackfrom == 1 || objects(i).behaviour(trackfrom-1) == CONST_BEHAVIOUR_INVALID) && (trackuntil == objects(i).duration || objects(i).behaviour(trackuntil+1) == CONST_BEHAVIOUR_INVALID) %if the track consists of a single frame of valid worm "behaviour" sandwiched between two invalid frames, then don't even bother
                        objects(i).behaviour(trackfrom:trackuntil) = CONST_BEHAVIOUR_INVALID;
                    elseif sum(~isnan(directions(trackfrom:trackuntil))) == 0 %if there is no directions data for the track (because for example it's at the beginning of the movie, and the window is larger than the largest frame index, then don't even bother)
                        objects(i).behaviour(trackfrom:trackuntil) = CONST_BEHAVIOUR_INVALID;
                    else %there is something to look at
                        
                        trackframeindex = trackfrom;
                        while ~isnan(trackframeindex) && trackframeindex <= trackuntil %going through the track
                            
                            %checking how long the worm can be said to be dwelling from the current frame onwards
                            dwellingfrom = trackframeindex;
                            dwellingx = objects(i).x(dwellingfrom);
                            dwellingy = objects(i).y(dwellingfrom);
                            dwellingindex = dwellingfrom+1;
                            dwellinguntil = NaN;
                            while dwellingindex <= trackuntil
                                currentdwellingdistance = hypot(objects(i).x(dwellingindex)-dwellingx, objects(i).y(dwellingindex)-dwellingy);
                                if currentdwellingdistance > revdistance / scalingfactor %if the worm moved more than the threshold amount of micrometers between the start frame and the current frame,...
                                    dwellinguntil = dwellingindex - 1; %...the last frame that the worm can be said to be dwelling was the previous one
                                    break;
                                end
                                dwellingindex = dwellingindex + 1;
                            end
                            if dwellingindex > trackuntil || isnan(dwellinguntil) %the loop finished without terminating due to finding a frame where the worm is no longer dwelling,...
                                dwellinguntil = trackuntil; %...which means that the worm was dwelling the whole time
                            end
                            
                            if consistentheads(trackframeindex) && trackframeindex < trackuntil && ~consistentheads(trackframeindex+1) %if the "consistent" part of the track consists of a single frame (followed by inconsistent frames), then we're better off assuming that single frame is inconsistent as well, and do reversal detection on a larger inconsistent interval instead of a single consistent frame
                                consistentheads(trackframeindex) = false;
                            end
                            
                            if consistentheads(trackframeindex)
                                [consistentfrom consistentuntil] = findinterval(consistentheads, '#', 'first', trackframeindex, trackuntil);
                                nondwellingcouldhandle = consistentuntil-consistentfrom; %how many frames we could move forwards if we asked for headdirection user input in a non-dwelling style
                                inconsistentfrom = NaN; inconsistentuntil = NaN;
                            else %~consistentheads(trackframeindex)
                                [inconsistentfrom inconsistentuntil] = findinterval(consistentheads, '~#', 'first', trackframeindex, trackuntil);
                                nondwellingcouldhandle = min([inconsistentfrom+2*revextrapolateframes, trackuntil]) - inconsistentfrom; %how many frames we could move forwards if we asked for headdirection user input in a non-dwelling style
                                consistentfrom = NaN; consistentuntil = NaN;
                            end
                            
                            flaggingdone = false;
                            if dwellinguntil-dwellingfrom > nondwellingcouldhandle %if the worm can be considered dwelling for a longer period of time than it can be considered moving consistently or inconsistently (with "inconsistently" including the frames we could extrapolate based on user input) , then we ask the user for head direction (or to tell us if it's not really dwelling)
                                
                                if sum(~isnan(directions(dwellingfrom:dwellinguntil))) == 0 %if there is no directions data for the interval (because for example it's at the beginning of the movie, and the window is larger than the largest frame index, then don't even bother)
                                    objects(i).behaviour(dwellingfrom:dwellinguntil) = CONST_BEHAVIOUR_INVALID;
                                    trackframeindex = dwellinguntil + 1;
                                else
                                    
                                    middleframe = dwellingfrom+ceil((dwellinguntil-dwellingfrom)/2); %we'll show a frame in the middle of the interval. we don't have to worry about not having directiondata for the shown frame, because we'll get the direction directly from the user, and we'll use that user-specified direction directly.
                                    [headdirection aborting] = manualflagreversal(i, dwellingfrom, dwellinguntil, middleframe, 'dwellinglike');
                                    uncertaincount = uncertaincount + 1;

                                    if aborting
                                        unknowns = 0;
                                        for j=1:numel(objects)
                                            unknowns = unknowns + sum(objects(j).behaviour == CONST_BEHAVIOUR_UNKNOWN);
                                        end
                                        fprintf('Reversal detection finished. The user was prompted %d times. %d unknown frames remain.\n', uncertaincount, unknowns);
                                        wormshow;
                                        return;
                                    end
                                    
                                    if ~isnan(headdirection)
                                        for j=dwellingfrom:dwellinguntil
                                            anglefromforwards = checkangleoverflow(directions(j)-headdirection);
                                            if abs(anglefromforwards) <= pi/2
                                                objects(i).behaviour(j) = CONST_BEHAVIOUR_FORWARDS;
                                            elseif abs(anglefromforwards) > pi/2
                                                objects(i).behaviour(j) = CONST_BEHAVIOUR_REVERSAL;
                                            else
                                                objects(i).behaviour(j) = CONST_BEHAVIOUR_INVALID;
                                            end
                                        end
                                        flaggingdone = true;
                                        consistentheads(dwellingfrom:dwellinguntil) = false; %we don't want to extrapolate based on directions of movement during dwelling. TODO: unfortunately this only sets consistentheads to false in the current session (i.e. if the user clicks abort and then tries to analyse again, now consistentheads will be recalculate and could be true for frames we flagged based on dwelling headdirection)
                                        trackframeindex = dwellinguntil + 1;
                                    else
                                        flaggingdone = false;
                                        %we'll need to do head direction specification more manually than what we do in dwelling headdirection detection (because e.g. the worm is performing an omega)
                                        %importantly, we don't increase trackframeindex, so that other headdirection detection methods can kick in (consistent or inconsistent intervals)
                                    end
                                        
                                end
                                
                            end
                                
                            if ~flaggingdone && consistentheads(trackframeindex)
                                
                                [samedirectionfrom samedirectionuntil] = findinterval(deltaangles, ['abs(#) <= ' num2str(samedirectionmax)], 'longest', consistentfrom, consistentuntil);
                                
                                canflagconsistent = true; %by default we do things normally
                                
                                if isnan(samedirectionfrom) %if no "samedirection" was found because for example there's only one frame in this consistent interval, which is has a large deltaangle compared to the previous frame (which is outside of this interval), then we 
                                    samedirectionfrom = consistentfrom;
                                    samedirectionuntil = consistentfrom;
                                end
                                
                                %consistent movement directions can start at the beginning of the track with a low deltaangle, or anywhere in the track with a high deltaangle
                                %(because deltaangle is between the previous and the current direction, it means that in the current frame it's already moving in the direction
                                %it will be moving in the following frames). So if we can start from one frame before the low deltaangles (within the same consistent interval), we should.
                                if samedirectionfrom > consistentfrom && abs(deltaangles(samedirectionfrom)) <= samedirectionmax && abs(deltaangles(samedirectionfrom-1)) > samedirectionmax
                                    samedirectionfrom = samedirectionfrom - 1;
                                end
                                
                                %if the worm was moving consistently in the same direction for more than the maximum duration of a reversal, we can assume it was moving forwards
                                if samedirectionuntil-samedirectionfrom+1 > round(revdurationmax*framerate)
                                    whichdirection = CONST_BEHAVIOUR_FORWARDS;
                                    canflagconsistent = true;
                                    aborting = false;
                                else %otherwise, if the longest interval when the worm was moving in the same direction is not longer than the maximum duration of a reversal, we don't know what's going on and have to ask the user
                                    middleframe = samedirectionfrom+ceil((samedirectionuntil-samedirectionfrom)/2);
                                    if isnan(directions(middleframe)) %but if we don't have direction data for the frame we'd try to show,...
                                        middleframe = inconsistentuntil; %...we'll try to show a later frame, which has the highest chance of having direction data
                                    end
                                    if isnan(directions(middleframe)) %but if we still don't have direction data, then we're screwed, and there's no point in showing getting user input, because it will just get set to invalid anyway
                                        whichdirection = CONST_BEHAVIOUR_INVALID;
                                    else %we can show the frame to the user because we have directiondata to compare it with
                                        [headdirection aborting] = manualflagreversal(i, samedirectionfrom, samedirectionuntil, middleframe, 'consistent');
                                        uncertaincount = uncertaincount + 1;
                                        deltadirection = checkangleoverflow(headdirection - directions(middleframe));
                                        if abs(deltadirection) <= samedirectionmax
                                            whichdirection = CONST_BEHAVIOUR_FORWARDS;
                                            canflagconsistent = true;
                                        elseif abs(deltadirection) >= reversedirectionmin
                                            whichdirection = CONST_BEHAVIOUR_REVERSAL;
                                            canflagconsistent = true;
                                        elseif isnan(deltadirection)
                                            whichdirection = CONST_BEHAVIOUR_INVALID;
                                            canflagconsistent = true;
                                        else %when abs(deltadirection) is an intermediate angle between samedirectionmax and reversaldirectionmin
                                            whichdirection = CONST_BEHAVIOUR_INVALID;
                                            canflagconsistent = false;
                                        end
                                    end
                                    
                                end
                                
                                if aborting
                                    unknowns = 0;
                                    for j=1:numel(objects)
                                        unknowns = unknowns + sum(objects(j).behaviour == CONST_BEHAVIOUR_UNKNOWN);
                                    end
                                    fprintf('Reversal detection finished. The user was prompted %d times. %d unknown frames remain.\n', uncertaincount, unknowns);
                                    wormshow;
                                    return;
                                else
                                    if (whichdirection == CONST_BEHAVIOUR_FORWARDS || whichdirection == CONST_BEHAVIOUR_REVERSAL) && canflagconsistent
                                        %first we flag the samedirection interval for which the user told us the actual direction
                                        objects(i).behaviour(samedirectionfrom:samedirectionuntil) = whichdirection;
                                        %then we flag the whole consistent interval, assuming that large deltaangles correspond to changes in movement direction
                                        currentindexneg = samedirectionfrom;
                                        currentindexpos = samedirectionuntil;
                                        currentforwardsneg = (whichdirection == CONST_BEHAVIOUR_FORWARDS);
                                        currentforwardspos = (whichdirection == CONST_BEHAVIOUR_FORWARDS);
                                        while currentindexneg > consistentfrom || currentindexpos < consistentuntil
                                            if currentindexneg > consistentfrom
                                                if abs(deltaangles(currentindexneg)) >= reversedirectionmin %delta angles are between the current direction and the previous direction, so the previous direction is the opposite if there's a large deltaangle in the current frame
                                                    currentforwardsneg = ~currentforwardsneg;
                                                end
                                                currentindexneg = currentindexneg - 1;
                                                if currentforwardsneg
                                                    objects(i).behaviour(currentindexneg) = CONST_BEHAVIOUR_FORWARDS;
                                                else
                                                    objects(i).behaviour(currentindexneg) = CONST_BEHAVIOUR_REVERSAL;
                                                end
                                            end
                                            if currentindexpos < consistentuntil
                                                currentindexpos = currentindexpos + 1;
                                                if abs(deltaangles(currentindexpos)) >= reversedirectionmin %delta angles are between the current direction and the previous direction, so the next direction is the opposite if there's a large deltaangle in the next frame
                                                    currentforwardspos = ~currentforwardspos;
                                                end
                                                if currentforwardspos
                                                    objects(i).behaviour(currentindexpos) = CONST_BEHAVIOUR_FORWARDS;
                                                else
                                                    objects(i).behaviour(currentindexpos) = CONST_BEHAVIOUR_REVERSAL;
                                                end
                                            end
                                        end
                                        trackframeindex = consistentuntil + 1;
                                        flaggingdone = true;
                                    elseif whichdirection == CONST_BEHAVIOUR_INVALID && canflagconsistent
                                        objects(i).behaviour(samedirectionfrom:samedirectionuntil) = CONST_BEHAVIOUR_INVALID;
                                        if samedirectionfrom == trackframeindex
                                            trackfrom = samedirectionuntil + 1;
                                            trackframeindex = trackfrom;
                                            flaggingdone = true;
                                        else %if there are frames between where we started from in the track and where the samedirection interval begins (which can happen if these intermediate frames are consistent, but not samedirection), then unknown behaviour frames remain between trackframeindex and samedirectionfrom-1, which we'll need to check again
                                            consistentheads(trackframeindex:samedirectionfrom-1) = false;
                                            flaggingdone = false;
                                            inconsistentfrom = trackframeindex;
                                            inconsistentuntil = samedirectionfrom-1;
                                            %importantly, we don't increase trackframeindex, so that the inconsistent headdirection detection method can kick in
                                        end
                                    elseif ~canflagconsistent %the delta direction between the user-specified headdirection and the worm's direction is kinda sideways (between samedirectionmax and reversaldirectionmin)
                                        %then we flag the directions as if they were inconsistent (which they are), and then we'll reinvestigate the consistent directions if some still remain after extrapolating the inconsistent frames from the user headdirection input
                                        inconsistentfrom = consistentfrom;
                                        inconsistentuntil = min([consistentfrom+2*revextrapolateframes, consistentuntil]);
                                        consistentheads(inconsistentfrom:inconsistentuntil) = false; %we can deal with at most consistentfrom+2*revextrapolateframes inconsistent frames in one go, so we'll flag at most that many of the earliest supposely consistent but actually bad frames as inconsistent, and then do the flagging as if they were inconsistent
                                        flaggingdone = false;
                                        %importantly, we don't increase trackframeindex, so that the inconsistent headdirection detection method can kick in
                                        %unfortunately we do need to redo it with the inconsistent headdirection detection because the "middleframe" for which we asked the user input from may be more than revextrapolateframes frames away from trackframeindex
                                    else
                                        fprintf(2, 'Warning: did not understand which direction the worm is moving.\n');
                                        trackframeindex = consistentuntil + 1;
                                    end
                                end
                            end    
                                
                            if ~flaggingdone && ~consistentheads(trackframeindex)
                                
                                if inconsistentuntil-inconsistentfrom > 2*revextrapolateframes %if the inconsistent interval is longer than how much we could extrapolate (in both directions) based on a single user input, then we'll have to ask for user input multiple times for this long interval
                                    inconsistentuntil = inconsistentfrom + 2*revextrapolateframes; %so we'll reduce how far we'll look in the inconsistent interval to at most 2*revextrapolateframes (getting a user input + extrapolating in both directions)
                                elseif inconsistentuntil-inconsistentfrom < 2*revextrapolateframes && inconsistentuntil<trackuntil %if the inconsistent interval would be less than the amount we can extrapolate, see if we should increase it
                                    canextenduntil = min([inconsistentfrom+2*revextrapolateframes, trackuntil]);
                                    if ~isempty(find(~consistentheads(inconsistentuntil+1:canextenduntil), 1)) %if we would find further inconsistent movement frames within the interval we could extrapolate into,...
                                        inconsistentuntil = canextenduntil; %...then increase the inconsistent interval to make it as large as we can extrapolate, so that we can flag multiple short inconsistent intervals at the same time
                                    end
                                end
                                
                                if sum(~isnan(directions(inconsistentfrom:inconsistentuntil))) == 0 %if there is no directions data for the interval (because for example it's at the beginning of the movie, and the window is larger than the largest frame index, then don't even bother)
                                    objects(i).behaviour(inconsistentfrom:inconsistentuntil) = CONST_BEHAVIOUR_INVALID;
                                else
                                    %if the inconsistent interval is both short, and we have a consistent interval nearby that we can use to extrapolate the direction in the inconcistent interval
                                    if inconsistentuntil-inconsistentfrom+1 <= revextrapolateframes && (inconsistentfrom > trackfrom && consistentheads(inconsistentfrom-1) && objects(i).behaviour(inconsistentfrom-1) ~= CONST_BEHAVIOUR_INVALID)

                                        referencedirection = directions(inconsistentfrom-1);
                                        if objects(i).behaviour(inconsistentfrom-1) == CONST_BEHAVIOUR_REVERSAL
                                            headdirection = checkangleoverflow(referencedirection + pi);
                                        elseif objects(i).behaviour(inconsistentfrom-1) == CONST_BEHAVIOUR_FORWARDS
                                            headdirection = referencedirection;
                                        else
                                            fprintf(2, 'Warning: the reference direction frame that we tried to use for the inconsistent interval between frames %d and %d for worm %d is actually an invalid frame, which cannot be used.\n', objects(i).frame(inconsistentfrom), objects(i).frame(inconsistentuntil), i);
                                            headdirection = NaN;
                                        end

                                    else %we have to ask for user input
                                        
                                        middleframe = inconsistentfrom+ceil((inconsistentuntil-inconsistentfrom)/2); %we'll show a frame in the middle of the interval. we don't have to worry about not having directiondata for the shown frame, because we'll get the direction directly from the user, and we'll use that user-specified direction directly.
                                        [headdirection aborting] = manualflagreversal(i, inconsistentfrom, inconsistentuntil, middleframe, 'inconsistent');
                                        uncertaincount = uncertaincount + 1;
                                        
                                        if aborting
                                            unknowns = 0;
                                            for j=1:numel(objects)
                                                unknowns = unknowns + sum(objects(j).behaviour == CONST_BEHAVIOUR_UNKNOWN);
                                            end
                                            fprintf('Reversal detection finished. The user was prompted %d times. %d unknown frames remain.\n', uncertaincount, unknowns);
                                            wormshow;
                                            return;
                                        end
                                    
                                    end
                                    
                                    for j=inconsistentfrom:inconsistentuntil
                                        anglefromforwards = checkangleoverflow(directions(j)-headdirection);
                                        if abs(anglefromforwards) <= pi/2
                                            objects(i).behaviour(j) = CONST_BEHAVIOUR_FORWARDS;
                                        elseif abs(anglefromforwards) > pi/2
                                            objects(i).behaviour(j) = CONST_BEHAVIOUR_REVERSAL;
                                        else
                                            objects(i).behaviour(j) = CONST_BEHAVIOUR_INVALID;
                                        end
                                    end
                                        
                                end
                                
                                trackframeindex = inconsistentuntil + 1;
                                
                            end
                            
                        end
                        
                    end
                    
                end
                
                objectframeindex = trackuntil + 1;
            end
            
        end
        
        unknowns = 0;
        for j=1:numel(objects)
            unknowns = unknowns + sum(objects(j).behaviour == CONST_BEHAVIOUR_UNKNOWN);
        end
        fprintf('Reversal detection finished. The user was prompted %d times. %d unknown frames remain.\n', uncertaincount, unknowns);
        
        questdlg('Reversal detection completed successfully.', 'Reversal detection successful', 'OK', 'OK');
        
        wormshow;
        
    end

    function [headdirection aborting] = manualflagreversal(whichobject, objectframefrom, objectframeuntil, referenceframe, detectiontype)
        
        if exist('referenceframe', 'var') ~= 1
            referenceframe = objectframefrom;
        end
        if exist('detectiontype', 'var') ~= 1
            detectiontype = 'unknown';
        end
        
        aborting = false;
        
        minextraareaonsides = 1000; %the minimal extra area (in micrometes) to show relative to the centroid of the worm %CHANGEME: move this into advanced rev detection settings
        minextraareaonsides = minextraareaonsides/scalingfactor; %now in pixels!
        revextrapolateframes = round(revextrapolate*framerate);
        
        %we figure out which frames to display to the user
        earlyframetodisplayoriginal = objects(whichobject).frame(objectframefrom);
        earlyframetodisplay = earlyframetodisplayoriginal;
        laterframetodisplayoriginal = objects(whichobject).frame(objectframeuntil);
        laterframetodisplay = laterframetodisplayoriginal;
        
        if earlyframetodisplay >= laterframetodisplay
            if laterframetodisplay < lastframe && objectframeuntil < objects(whichobject).duration %if the object still exists in the next frame
                laterframetodisplay = laterframetodisplay + 1;
            elseif earlyframetodisplay > 1 && objectframefrom > 1 %if the object still exists in the previous frame
                earlyframetodisplay = earlyframetodisplay - 1;
            elseif laterframetodisplay < lastframe %if the next frame still exists
                laterframetodisplay = laterframetodisplay + 1;
            elseif earlyframetodisplay > 1 %if the previous frame still exists
                earlyframetodisplay = earlyframetodisplay - 1;
            else
                fprintf(2, 'Warning: not enough frames to display for worm %d around frame %d.\n', whichobject, middleframetodisplay);
                headdirection = NaN;
                return;
            end
        end

        %if we don't have enough frames to display, we try to find addition ones where the object we're looking at still exists
        maybecanbeearlier = true;
        maybecanbelater = true;
        while (maybecanbeearlier || maybecanbelater) && laterframetodisplay - earlyframetodisplay + 1 < ceil(revdisplayduration*framerate)
            maybecanbeearlier = ~isempty(find(objects(whichobject).frame == earlyframetodisplay - 1, 1));
            maybecanbelater = ~isempty(find(objects(whichobject).frame == laterframetodisplay + 1, 1));
            if maybecanbelater %we prefer adding later frames
                laterframetodisplay = laterframetodisplay + 1;
            elseif maybecanbeearlier
                earlyframetodisplay = earlyframetodisplay - 1;
            end
        end

        %these indices are the object's frame indices, so obviously we can only have them point to frames where the object still exists
        earlyindex = find(objects(whichobject).frame == earlyframetodisplay);
        laterindex = find(objects(whichobject).frame == laterframetodisplay);

        %if we still haven't found enough frames to display, we just try to get more frames in either directions, disregarding whether the object is present in the frame
        maybecanbeearlier = true;
        maybecanbelater = true;
        while (maybecanbeearlier || maybecanbelater) && laterframetodisplay - earlyframetodisplay + 1 < ceil(revdisplayduration*framerate)
            maybecanbeearlier = (earlyframetodisplay > 1);
            maybecanbelater = (laterframetodisplay < lastframe);
            if maybecanbelater %here we try to add frames in both directions
                laterframetodisplay = laterframetodisplay + 1;
            end
            if maybecanbeearlier && laterframetodisplay - earlyframetodisplay + 1 < ceil(revdisplayduration*framerate)
                earlyframetodisplay = earlyframetodisplay - 1;
            end
        end
        
        %now we figure out how large an area we'll need to display
        xmin = min(vertcat(objects(whichobject).x(earlyindex:laterindex))) - minextraareaonsides;
        xmax = max(vertcat(objects(whichobject).x(earlyindex:laterindex))) + minextraareaonsides;
        ymin = min(vertcat(objects(whichobject).y(earlyindex:laterindex))) - minextraareaonsides;
        ymax = max(vertcat(objects(whichobject).y(earlyindex:laterindex))) + minextraareaonsides;
        
        xmin = max([round(xmin) 1]);
        xmax = min([round(xmax) moviewidth]);
        ymin = max([round(ymin) 1]);
        ymax = min([round(ymax) movieheight]);
        
        %and finally we can finally show the frame to the user and ask for a decision
        if strcmpi(detectiontype, 'dwellinglike') && objectframeuntil-objectframefrom>2*revextrapolateframes
            figurecolor = get(0,'DefaultFigureColor')*0.66; %darker than default background when long dwelling detection is taking place, to remind the user to check if the head direction is indeed consistent over the indicated frames
        else
            figurecolor = get(0,'DefaultFigureColor');
        end
        manualflagreversalfigure = figure('Color', figurecolor);
        
        manualreversaltitlepanel = uipanel(manualflagreversalfigure, 'Units','Normalized',...
        'DefaultUicontrolUnits','Normalized','Position',[0.00 0.90 1.00 0.10]);
        
        titletextstring = sprintf('Deciding the direction of %s movement for worm %d / %d in frames %d - %d', detectiontype, whichobject, numel(objects), earlyframetodisplayoriginal, laterframetodisplayoriginal);
        if earlyframetodisplay ~= earlyframetodisplayoriginal || laterframetodisplay ~= laterframetodisplayoriginal
            titletextstring = [titletextstring, sprintf(' (showing frames %d - %d)', earlyframetodisplay, laterframetodisplay)];
        end
        titletextstring = [titletextstring, '.'];
        uicontrol(manualreversaltitlepanel,'Style','Text','String',titletextstring,'Position',[0.00 0.00 1.00 1.00]);
        
        displayimages = struct('data', []);
        displayimagecount = 0;
        displayimagereferenceindex = NaN;
        for i=earlyframetodisplay:laterframetodisplay
            displayimagecount = displayimagecount + 1;
            if i == objects(whichobject).frame(referenceframe)
                displayimagereferenceindex = displayimagecount;
            end
            currentframe = readframe(i);
            displayimages(displayimagecount).data = currentframe(ymin:ymax, xmin:xmax);
            displayimages(displayimagecount).frame = i;
            
            %it is possible that we're displaying frames to the user in which the object we're looking at is not present
            %so we'll check if it is present, and if so, set the later to be display centroid coordinates accordingly; otherwise we set them to NaN so that no centriod is displayed in those frames
            currentobjectframe = find(objects(whichobject).frame == i, 1);
            if ~isempty(currentobjectframe)
                displayimages(displayimagecount).x = objects(whichobject).x(currentobjectframe) - xmin + 1;
                displayimages(displayimagecount).y = objects(whichobject).y(currentobjectframe) - ymin + 1;
                if currentobjectframe >= objectframefrom && currentobjectframe <= objectframeuntil && objects(whichobject).behaviour(currentobjectframe) ~= CONST_BEHAVIOUR_INVALID %colouring the worm's centroid blue in the valid frames we're currently looking at,...
                    displayimages(displayimagecount).color = 'b';
                elseif objects(whichobject).behaviour(currentobjectframe) ~= CONST_BEHAVIOUR_INVALID %...green in valid frames that are just displayed to help the user know which way the worm faces...
                    displayimages(displayimagecount).color = 'g';
                else %...and red in invalid frames that are just displayed to help the user know which way the worm faces
                    displayimages(displayimagecount).color = 'r';
                end
            else
                displayimages(displayimagecount).x = NaN;
                displayimages(displayimagecount).y = NaN;
                displayimages(displayimagecount).color = 'r';
            end
            
        end
        
        whichbuttonpressed = CONST_BUTTON_NONE;
        manualflagreversalpanel = uipanel(manualflagreversalfigure, 'Units','Normalized', 'DefaultUicontrolUnits','Normalized', 'Position', [0.00 0.00 1.00 0.30]);
        
        headclickbutton = uicontrol(manualflagreversalpanel, 'Style', 'Pushbutton', 'String', 'I know where the head is!', 'Position', [0.00 0.00 0.60 1.00], 'Callback', {@buttonpressed, CONST_BUTTON_HEAD});
        if strcmpi(detectiontype, 'dwellinglike')
            invalidstring = 'Inconsistent';
        else
            invalidstring = 'Invalid';
        end
        uicontrol(manualflagreversalpanel, 'Style', 'Pushbutton', 'String', invalidstring, 'Position', [0.60 0.00 0.20 1.00], 'Callback', {@buttonpressed, CONST_BUTTON_INVALID});
        uicontrol(manualflagreversalpanel, 'Style', 'Pushbutton', 'String', 'Abort', 'Position', [0.80 0.00 0.20 1.00], 'Callback', {@buttonpressed, CONST_BUTTON_ABORT});
        
        moviehandle = subplot('Position', [0.00 0.20 1.00 0.65]);
        
        pause on
        currentframehandle = NaN;
        centroidhandle = NaN;
        displayimagestartframe = find(vertcat(displayimages.frame) == objects(whichobject).frame(objectframefrom)); %the first time the movie is shown, we start from the first frame that we're interested in (subsequent showings start from the beginning of all the frames shown). this is to make sure that when it's easy to tell which direction the head is (and so the user doesn't even need to see all the frames), the user can immediately see the relevant frame
        
        currentmovieFPS = max([movieFPS, displayimagecount/moviemaxduration]);
        
        while whichbuttonpressed == CONST_BUTTON_NONE
            
            for i=displayimagestartframe:displayimagecount
                if ishandle(currentframehandle)
                    delete(currentframehandle);
                end
                if ishandle(centroidhandle)
                    delete(centroidhandle);
                end
                try
                    currentframehandle = imshow(displayimages(i).data, [], 'parent', moviehandle); hold on;
                    centroidhandle = scatter(moviehandle, displayimages(i).x, displayimages(i).y, 3, displayimages(i).color);
                    title(moviehandle, sprintf('frame %d', displayimages(i).frame));
                catch, err = lasterror; %#ok<LERR,CTCH> %catch err would be nicer, but that doesn't work on older versions of Matlab
                    if ~ishandle(moviehandle) %if the movie window was closed (e.g. the user clicked on the x), it's interpreted as an abort command
                        whichbuttonpressed = CONST_BUTTON_ABORT;
                    else
                        rethrow(err);
                    end
                end
                
                drawnow;
                pause(1/currentmovieFPS);
                if whichbuttonpressed ~= CONST_BUTTON_NONE
                    break;
                end
            end
            displayimagestartframe = 1;
            if ishandle(currentframehandle)
                delete(currentframehandle);
            end
            if ishandle(centroidhandle)
                delete(centroidhandle);
            end
            drawnow;
            pause(1/currentmovieFPS);
            
            if whichbuttonpressed == CONST_BUTTON_HEAD
                currentframehandle = imshow(displayimages(displayimagereferenceindex).data, [], 'parent', moviehandle); hold on;
                centroidhandle = scatter(moviehandle, displayimages(displayimagereferenceindex).x, displayimages(displayimagereferenceindex).y, 3, displayimages(displayimagereferenceindex).color);
                title(moviehandle, sprintf('Frame %d', displayimages(displayimagereferenceindex).frame));
                set(headclickbutton, 'String', 'Left click on the head of the worm, or right click to cancel', 'Enable', 'off');
                drawnow;
                [x y clicktype] = zinput('crosshair');
                if strcmpi(clicktype, 'alt') %right click returns the user to the reversal detection movie, as if the user didn't click anything
                    whichbuttonpressed = CONST_BUTTON_NONE;
                    set(headclickbutton, 'String', 'I know where the head is!', 'Enable', 'on');
                    displayimagestartframe = displayimagereferenceindex; %we'll show the movie starting from the reference frame (that was shown as a static image) for the first time (subsequent repeats of the movie start from the beginning of course)
                else
                    cursormiddlex = displayimages(displayimagereferenceindex).x;
                    cursormiddley = displayimages(displayimagereferenceindex).y;
                    cursordx = x-cursormiddlex;
                    cursordy = y-cursormiddley;
                    headdirection = atan2(cursordy, cursordx);
                    if isnan(headdirection)
                        fprintf(2, 'Warning: could not calculate the angle-difference between where the mouse cursor pointed, and the movement of the worm.\n');
                    end
                end
            elseif whichbuttonpressed == CONST_BUTTON_INVALID
                headdirection = NaN;
            elseif whichbuttonpressed == CONST_BUTTON_ABORT
                headdirection = NaN;
                aborting = true;
            end
        
        end
        
        if ishandle(manualflagreversalfigure)
            delete(manualflagreversalfigure); %we remove the popup decision figure when we're done
        end
        
    end

    %This button function looks really stupid, but if I try to set whichbuttonpressed directly from the callback, it doesn't seem to actually set the value!!
    function buttonpressed (hobj, eventdata, whichbutton)  %#ok<INUSL>
       whichbuttonpressed = whichbutton;
       uiresume;
    end

    function [intervalfrom intervaluntil] = findinterval(data, condition, firstorlongest, startindex, endindex)
        if exist('firstorlongest', 'var') ~= 1
            firstorlongest = 'first'; %by default we look for the first interval
        end
        if exist('startindex', 'var') ~= 1
            startindex = 1;
        end
        if exist('endindex', 'var') ~= 1
            endindex = numel(data);
        end
        condition = strrep(condition, '#', 'data(i)'); % '#' is the symbol representing the current element
        
        intervalfrom = NaN;
        intervaluntil = NaN;
        currentintervalfrom = NaN;
        for i=startindex:endindex
            if isnan(currentintervalfrom) %not in an interval
                if eval(condition) %starting an interval
                    currentintervalfrom = i;
                end
            else %in an interval
                if ~eval(condition) %ending an interval
                    currentintervaluntil = i-1;
                    if strcmpi(firstorlongest, 'first')
                        intervalfrom = currentintervalfrom;
                        intervaluntil = currentintervaluntil;
                        return;
                    elseif strcmpi(firstorlongest, 'longest') %trying to find longest
                        if isnan(intervalfrom) || isnan(intervaluntil) || currentintervaluntil-currentintervalfrom+1 > intervaluntil-intervalfrom+1 %longer than the longest so far
                            intervalfrom = currentintervalfrom;
                            intervaluntil = currentintervaluntil;
                        end
                    else
                        fprintf(2, 'Warning: did not understand whether to look for the first or the longest interval.\n');
                    end
                    currentintervalfrom = NaN;
                end
            end
        end
        if ~isnan(currentintervalfrom) %we ended the loop with an interval open, so we'll need to close that
            currentintervaluntil = endindex;
            if strcmpi(firstorlongest, 'first')
                intervalfrom = currentintervalfrom;
                intervaluntil = currentintervaluntil;
                return;
            elseif strcmpi(firstorlongest, 'longest') %trying to find longest
                if isnan(intervalfrom) || isnan(intervaluntil) || currentintervaluntil-currentintervalfrom+1 > intervaluntil-intervalfrom+1 %longer than the longest so far
                    intervalfrom = currentintervalfrom;
                    intervaluntil = currentintervaluntil;
                end
            else
                fprintf(2, 'Warning: did not understand whether to look for the first or the longest interval.\n');
            end
        end
    end

    function closeqtobjects (hobj,eventdata) %#ok<INUSD>
        for i=1:numel(qtreaders)
            try
                qtreaders(i).server.close;
            catch, err = lasterror; %#ok<LERR,CTCH> %catch err would be nicer, but that doesn't work on older versions of Matlab
                fprintf(2, 'Warning: could not close the QTFrameServer object appropriately for ');
                if isfield(qtreaders(i), 'filename')
                    fprintf(2, 'file %s\n', qtreaders(i).filename);
                else
                    fprintf(2, 'movie number %d\n', i);
                end
                fprintf(2, '%s\n', err.message);
            end
        end
        qtreaders = struct([]);
    end

    function closetiffobjects (hobj, eventdata) %#ok<INUSD>
        for i=1:numel(tiffservers)
            try
                tiffservers(i).server.close;
            catch, err = lasterror; %#ok<LERR,CTCH> %catch err would be nicer, but that doesn't work on older versions of Matlab
                fprintf(2, 'Warning: could not close the TIFFServer object appropriately for ');
                if isfield(tiffservers(i), 'filename')
                    fprintf(2, 'file %s\n', tiffservers(i).filename);
                else
                    fprintf(2, 'movie number %d\n', i);
                end
                fprintf(2, '%s\n', err.message);
            end
        end
        tiffservers = struct([]);
    end


    function itisearlier = earlierversion (isthisearlier, thanthis)
        %kind of like the built-in verlessthan function, except for zentracker
        %return values are 'earlier', 'later', 'same', 'unknown'
        
        string1 = isthisearlier;
        string2 = thanthis;
        
        wherepre1 = strfind(lower(string1), 'pre');
        wherepre2 = strfind(lower(string2), 'pre');
        
        delimiters1 = find(string1 < '0' | string1 > '9');
        delimiters2 = find(string2 < '0' | string2 > '9');
        
        %adding dummy delimiters to the beginning and end of the string so as to be able to process the entire string just by looking at string between delimiters
        delimiters1 = [0 delimiters1 numel(string1)+1];
        delimiters2 = [0 delimiters2 numel(string2)+1];
        
        numbers1 = [];
        numbers2 = [];
        
        for i=1:numel(delimiters1)-1
            if ismember(delimiters1(i), wherepre1)
                numbers1(end+1) = -2; %#ok<AGROW> %pre denotes a pre-release version (i.e. earlier than an unnumbered version ("-1"), which is earlier than any numbered version (0>)
            else
                currentstring = string1(delimiters1(i)+1:delimiters1(i+1)-1);
                if ~isempty(currentstring) %when encountering more than one consecutive delimiters (e.g. in "2.7.0pre3", "pre" counts are three consecutive delimiters, just continue after the last consecutive delimiter
                    currentnumber = str2double(currentstring);
                    if ~isnan(currentnumber)
                        numbers1(end+1) = currentnumber; %#ok<AGROW>
                    else
                        itisearlier = 'unknown';
                        return;
                    end
                end
            end
        end
        
        for i=1:numel(delimiters2)-1
            if ismember(delimiters2(i), wherepre2)
                numbers2(end+1) = -2; %#ok<AGROW> %pre denotes a pre-release version
            else
                currentstring = string2(delimiters2(i)+1:delimiters2(i+1)-1);
                if ~isempty(currentstring) %when encountering more than one consecutive delimiters (e.g. in "2.7.0pre3", "pre" counts are three consecutive delimiters, just continue after the last consecutive delimiter
                    currentnumber = str2double(currentstring);
                    if ~isnan(currentnumber)
                        numbers2(end+1) = currentnumber; %#ok<AGROW>
                    else
                        itisearlier = 'unknown';
                        return;
                    end
                end
            end
        end
        
        if isempty(numbers1) || isempty(numbers2)
            itisearlier = 'unknown';
            return;
        end
        
        %e.g. 2.7 is an earlier version than 2.7.5, so to make them comparable, we'll add a "-1" (later than pre-release (-2), but earlier than any numbered version) as the last number(s) to the shorter version number, i.e. turning [2, 7] into [2, 7, -2]
        if numel(numbers1) < numel(numbers2)
            numbers1(end+1:numel(numbers2)) = -1;
        elseif numel(numbers2) < numel(numbers1)
            numbers2(end+1:numel(numbers1)) = -1;
        end
        
        earlier1 = find(numbers1 < numbers2, 1, 'first');
        later1 = find(numbers1 > numbers2, 1, 'first');
        
        if isempty(earlier1)
            earlier1 = Inf;
        end
        if isempty(later1)
            later1 = Inf;
        end
        
        if earlier1 < later1
            itisearlier = 'earlier';
            return;
        elseif later1 < earlier1
            itisearlier = 'later';
            return;
        else
            %we haven't found any difference, therefore they're considered the same
            itisearlier = 'same';
        end
        
    end

    function spectraldensity (hobj, eventdata) %#ok<INUSD>
        
        mindurationforor = 20;
        stretches = cell(0);
        
        for i=1:numel(objects)
            
            wheregood = objects(i).behaviour ~= CONST_BEHAVIOUR_INVALID & ~isnan(objects(i).orientation);
            
            startindices = strfind(wheregood, [false true]);
            endindices = strfind(wheregood, [true false]);
            
            if objects(i).behaviour(1) ~= CONST_BEHAVIOUR_INVALID && ~isnan(objects(i).orientation(1))
                startindices = [1, startindices]; %#ok<AGROW>
            end
            if objects(i).behaviour(end) ~= CONST_BEHAVIOUR_INVALID && ~isnan(objects(i).orientation(end))
                endindices = [endindices, objects(i).duration]; %#ok<AGROW>
            end
            
            durations = endindices - startindices + 1;
            
            goodstretches = find(durations >= mindurationforor);
            
            for j=1:numel(goodstretches)
                stretches{end+1} = objects(i).orientation(startindices(goodstretches(j)):endindices(goodstretches(j))); %#ok<AGROW>
            end
            
        end
        
        smalleststep = 0.05;
        fbins = 0:smalleststep:framerate/2-smalleststep;
        powers = zeros(1, numel(fbins));
        powersn = zeros(1, numel(fbins));
        
        for i=1:numel(stretches)
            orchanges{i} = diff(stretches{i}); %#ok<AGROW>
            wheremorethan90 = orchanges{i}>90;
            wherelessthanm90 = orchanges{i}<-90;
            orchanges{i}(wheremorethan90) = 180-orchanges{i}(wheremorethan90); %#ok<AGROW>
            orchanges{i}(wherelessthanm90) = 180+orchanges{i}(wherelessthanm90); %#ok<AGROW>
            
            x = orchanges{i};% - mean(orchanges{i});
            
            %[pxx, f] = periodogram(x, [], numel(x), framerate);
            
            NFFT = numel(x);
            xdft = fft(x, NFFT);
            xdft = xdft(1:floor(NFFT/2)+1);
            pxx = (1/(framerate*NFFT)).*abs(xdft).^2;
            pxx(2:end-1) = 2*pxx(2:end-1);
            f = 0:framerate/NFFT:framerate/2;
            
            %{
            NFFT = numel(x);
            pxx = abs(fft(x, NFFT)).^2; %power spectrum
            pxx = pxx(1:round(NFFT/2));
            %frequency axis
            f = 0:framerate/NFFT:(framerate-framerate/NFFT);
            f = f(1:round(NFFT/2));
            %}
            
            
            for j=1:numel(f)
                intowhichbin = find(f(j)>=fbins, 1, 'last');
                powers(intowhichbin) = powers(intowhichbin) + pxx(j);
                powersn(intowhichbin) = powersn(intowhichbin) + 1;
            end
            
        end
        
        figure; plot(fbins, powers./powersn);
        ylabel('Spectral density');
        xlabel('Frequency (Hz)')
    end


    function debuggingfunction (hobj, eventdata) %#ok<INUSD>
        disp('start');
        
        keyboard;
        
        %{
        %Recovering frames that were probably incorrectly flagged as invalid
        %TODO: incorporate this as an advanced option into validity checking
        maxperimeterfactor = 1.3;
        overallrecovered = 0;
        
        for i=1:numel(objects)
            j = 2;
            while j <= objects(i).duration-1
                if objects(i).behaviour(j) == CONST_BEHAVIOUR_INVALID
                    earlierindex = j-1;
                    while objects(i).behaviour(earlierindex) == CONST_BEHAVIOUR_INVALID
                        earlierindex = earlierindex - 1;
                        if earlierindex < 1
                            earlierindex = NaN;
                            break;
                        end
                    end
                    laterindex = j+1;
                    while objects(i).behaviour(laterindex) == CONST_BEHAVIOUR_INVALID
                        laterindex = laterindex + 1;
                        if laterindex > objects(i).duration
                            laterindex = NaN;
                            break;
                        end
                    end
                    
                    
                    if ~isnan(earlierindex) && ~isnan(laterindex)
                        currentwormstring = sprintf('Worm %d: ', i);
                        currentwormstringappend = '';
                        atleastonegood = false;
                        for k=earlierindex+1:laterindex-1
                            if measurementarea(round(objects(i).y(k)), round(objects(i).x(k))) && objects(i).area(k) >= validareamin/scalingfactor/scalingfactor && objects(i).perimeter(k) <= max([objects(i).perimeter(earlierindex), objects(i).perimeter(laterindex)])*maxperimeterfactor
                                objects(i).behaviour(k) = CONST_BEHAVIOUR_UNKNOWN;
                                atleastonegood = true;
                                overallrecovered = overallrecovered+1;
                                currentwormstring = [currentwormstring sprintf('%d, ', objects(i).frame(k))];
                            else
                                currentwormstringappend = [currentwormstringappend sprintf('~%d, ', objects(i).frame(k))];
                            end
                        end
                        if ~isempty(currentwormstringappend)
                            currentwormstringappend = ['but ' currentwormstringappend];
                        end
                        currentwormstring = [currentwormstring currentwormstringappend '\n'];
                        if atleastonegood
                            fprintf(currentwormstring);
                        end
                        j = laterindex+1;
                    else
                        j = j+1;
                    end
                else
                    j = j+1;
                end
            end
        end
        
        fprintf('Recovered %d frames overall.\n', overallrecovered);
        
        wormshow;
        %}
        
        disp('end');
    end
end