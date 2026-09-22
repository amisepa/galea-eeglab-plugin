%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function out = galea_periph_gui(def, hasPPG)
% GALEA_PERIPH_GUI  Parameters for the Galea auxiliary signals (EOG/PPG/EDA/EMG/IMU).
%
%   >> out = galea_periph_gui(def, hasPPG)
%
% Separate window so the main Galea dialogs stay compact: each modality has
% its own section, separated by a rule, with its own "process" checkbox and
% its own parameters. Unchecking a section disables (greys out) its
% parameters. DEF holds the current values (any subset; missing keys keep
% their defaults below); OUT returns the full set, or [] if cancelled.
% HASPPG (default true) greys the PPG section out when the recording carries
% no PPG stream.
%
% Cedric Cannard, 2026

if nargin < 2, hasPPG = true; end

d = struct('eog',true, 'eoglocut',0.5, 'eoghicut',20, 'viseog',true, ...
           'ppg',true, 'ppglocut',0.5, 'ppghicut',3, 'ppgdetect','valleys', ...
           'hrvtime',true, 'hrvfreq',true, 'hrvnonlin',false, 'visppg',true, ...
           'eda',true, 'edalocut',0.01, 'edahicut',1, ...
           'edaphasic',true, 'viscvx',true, 'viseda',true, ...
           'emg',true, 'emglocut',20, 'emghicut',0, 'emgenvelope',true, 'visemg',true, ...
           'imu',true, 'imuhicut',10, 'imumagnitude',true, 'visimu',true);
fn = fieldnames(def);
for iF = 1:numel(fn)
    if isfield(d, fn{iF}), d.(fn{iF}) = def.(fn{iF}); end
end

c = galea_colors();
W = 620;
scr = get(0, 'ScreenSize');
% height budget (must stay in sync with the layout below): top margin 36 +
% title 30 + rows + 5 separators (20) + buttons 56
% EOG: box 26, bandpass 26, plot 26 = 78
% PPG: box 26, bandpass+detect 26, RR label 26, pchip note 22+26, HRV 26 = 152
% EDA: box 26, bandpass 26, tonic-phasic 24, plot 26 = 102
% EMG: box 26, filters 26, envelope 24, plot 26 = 102
% IMU: box 26, lowpass 26, ACC_MAG 26, plot 24 = 104
rowsEOG = 78;  rowsPPG = 152;  rowsEDA = 102;  rowsEMG = 102;  rowsIMU = 104;
H = 36 + 30 + rowsEOG + rowsPPG + rowsEDA + rowsEMG + rowsIMU + 20*5 + 56;
H = min(H, scr(4) - 80);
f = figure('Name','Galea peripheral signals', 'NumberTitle','off', 'MenuBar','none', ...
    'ToolBar','none', 'Resize','off', 'Color',c.back, 'WindowStyle','modal', ...
    'Position',[(scr(3)-W)/2 max(20,(scr(4)-H)/2) W H]);

    function h = txt(str, pos, varargin)
        h = uicontrol(f,'style','text','string',str,'position',pos, ...
            'horizontalalignment','left','backgroundcolor',c.back, ...
            'foregroundcolor',c.text, varargin{:});
    end
    function h = ed(str, pos)
        h = uicontrol(f,'style','edit','string',str,'position',pos, ...
            'backgroundcolor',c.btn);
    end
    function h = cb(str, val, pos, varargin)
        h = uicontrol(f,'style','checkbox','string',str,'value',val,'position',pos, ...
            'backgroundcolor',c.back,'foregroundcolor',c.text, varargin{:});
    end
    function h = box(str, val, pos)
        h = uicontrol(f,'style','checkbox','string',str,'value',val,'position',pos, ...
            'fontweight','bold','fontsize',11,'backgroundcolor',c.back,'foregroundcolor',c.text);
    end
    function sep(yy)
        uicontrol(f,'style','frame','position',[20 yy W-40 1], ...
            'foregroundcolor',[.4 .45 .6],'backgroundcolor',[.4 .45 .6]);
    end
    function onoff(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end %#ok<NASGU>

y = H - 36;
txt('Peripheral signal processing', [20 y 300 24], 'fontweight','bold','fontsize',12);
y = y - 30;

% ---------------- EOG ----------------
eogKids = gobjects(0);
hEog = box('ElectroOculoGraphy (EOG; eye movements & blinks)', double(d.eog), [20 y 440 24]);
y = y - 26;
txt('Bandpass (Hz):', [40 y 130 20]);
hOLo = ed(sprintf('%g', d.eoglocut), [175 y 60 24]);
txt('to', [242 y 20 20]);
hOHi = ed(sprintf('%g', d.eoghicut), [268 y 60 24]);
eogKids(end+1) = hOLo; eogKids(end+1) = hOHi; %#ok<*AGROW>
y = y - 26;
hVisO = cb('Plot VEOG with detected blinks (blink rate reported in the console)', ...
    double(d.viseog), [40 y W-70 22]);
eogKids(end+1) = hVisO;
y = y - 20; sep(y);

% ---------------- PPG ----------------
y = y - 26;
ppgKids = gobjects(0);
hPpg = box('Photoplethysmography (PPG)', double(d.ppg), [20 y 440 24]);
y = y - 26;
txt('Bandpass (Hz):', [40 y 130 20]);
hPLo = ed(sprintf('%g', d.ppglocut), [175 y 60 24]);
txt('to', [242 y 20 20]);
hPHi = ed(sprintf('%g', d.ppghicut), [268 y 60 24]);
txt('Detect pulse-wave:', [340 y 130 20]);
hDet = uicontrol(f,'style','popupmenu','position',[475 y 110 24], 'backgroundcolor',c.btn, ...
    'string',{'valleys','peaks'}, 'value', find(strcmp({'valleys','peaks'}, d.ppgdetect)), ...
    'tooltipstring', ['Which feature of the pulse wave defines a heartbeat: the ' ...
    'valleys (default) or the peaks. Valleys are the conventional PPG fiducial.']);
ppgKids(end+1) = hPLo; ppgKids(end+1) = hPHi; ppgKids(end+1) = hDet;
y = y - 26;
txt('RR intervals cleaning (via BrainBeats plugin):', [40 y 300 20]);
y = y - 22;
txt('pchip interpolation by default (command line: ''rrcorrect'')', [58 y W-80 20], ...
    'fontangle','italic','fontsize',8);
y = y - 26;
hVisP = cb('Compute HRV features (via BrainBeats plugin)', double(d.visppg), [40 y W-70 22]);
ppgKids(end+1) = hVisP;
y = y - 20; sep(y);

% ---------------- EDA ----------------
y = y - 26;
edaKids = gobjects(0);
hEda = box('ElectroDermal Activity (EDA; skin conductance)', double(d.eda), [20 y 440 24]);
y = y - 26;
txt('Bandpass (Hz):', [40 y 130 20]);
hELo = ed(sprintf('%g', d.edalocut), [175 y 60 24]);
txt('to', [242 y 20 20]);
hEHi = ed(sprintf('%g', d.edahicut), [268 y 60 24]);
edaKids(end+1) = hELo; edaKids(end+1) = hEHi;
y = y - 26;
hPhasic = cb('Compute Tonic / Phasic components (using the cvxEDA algorithm; runs at 8 Hz)', ...
    double(d.edaphasic), [40 y W-70 22]);
edaKids(end+1) = hPhasic;
y = y - 24;
hVisX = cb('Plot the tonic / phasic components', double(d.viscvx), [62 y W-90 22]);
edaKids(end+1) = hVisX;
y = y - 20; sep(y);

% ---------------- EMG ----------------
y = y - 26;
emgKids = gobjects(0);
hEmg = box('ElectroMyoGraphy (EMG; facial)', double(d.emg), [20 y 440 24]);
y = y - 26;
txt('High-pass (Hz):', [40 y 130 20]);
hMLo = ed(sprintf('%g', d.emglocut), [175 y 60 24]);
txt('Low-pass (Hz, 0 = none):', [245 y 160 20]);
hMHi = ed(sprintf('%g', d.emghicut), [410 y 60 24]);
emgKids(end+1) = hMLo; emgKids(end+1) = hMHi;
y = y - 26;
hEnv = cb('Compute the envelope (rectify + 100 ms moving average)', ...
    double(d.emgenvelope), [40 y W-70 22]);
emgKids(end+1) = hEnv;
y = y - 24;
hVisM = cb('Plot EMG with the envelope', double(d.visemg), [40 y W-70 22]);
emgKids(end+1) = hVisM;
y = y - 20; sep(y);

% ---------------- IMU ----------------
y = y - 26;
imuKids = gobjects(0);
hImu = box('Inertial Motion Unit (IMU; head motion)', double(d.imu), [20 y 440 24]);
y = y - 26;
txt('Low-pass (Hz):', [40 y 130 20]);
hIHi = ed(sprintf('%g', d.imuhicut), [175 y 60 24]);
imuKids(end+1) = hIHi;
y = y - 26;
hMag = cb('Compute ACC\_MAG: orientation-independent head-motion metric', ...
    double(d.imumagnitude), [40 y W-70 22]);
imuKids(end+1) = hMag;
y = y - 24;
hVisI = cb('Plot all IMU channels incl. ACC\_MAG', double(d.visimu), [40 y W-70 22]);
imuKids(end+1) = hVisI;

% grey the whole PPG section out when there is no PPG stream
if ~hasPPG
    txt('no PPG stream in this dataset', [300 y+4 240 20], 'fontangle','italic');
    set(ppgKids(isgraphics(ppgKids)), 'enable', 'off');
    set(hPpg, 'enable', 'off');
end

% ---------------- gating ----------------
gateAll();
set(hEog, 'callback', @(~,~) gateAll());
set(hPpg, 'callback', @(~,~) gateAll());
set(hEda, 'callback', @(~,~) gateAll());
set(hEmg, 'callback', @(~,~) gateAll());
set(hImu, 'callback', @(~,~) gateAll());

    function gateAll()
        set(eogKids(isgraphics(eogKids)), 'enable', gateStr(get(hEog,'value')));
        set(ppgKids(isgraphics(ppgKids)), 'enable', gateStr(get(hPpg,'value')));
        set(edaKids(isgraphics(edaKids)), 'enable', gateStr(get(hEda,'value')));
        set(emgKids(isgraphics(emgKids)), 'enable', gateStr(get(hEmg,'value')));
        set(imuKids(isgraphics(imuKids)), 'enable', gateStr(get(hImu,'value')));
    end

    function s = gateStr(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end

% ---------------- buttons ----------------
out = [];
uicontrol(f,'style','pushbutton','string','Cancel','position',[W-200 18 80 30], ...
    'backgroundcolor',c.btn,'callback','close(gcbf)');
uicontrol(f,'style','pushbutton','string','OK','position',[W-105 18 85 30], ...
    'fontweight','bold','backgroundcolor',c.btn,'callback',@(~,~) onOK());

uiwait(f);

    function onOK()
        detOpts = get(hDet,'string');
        out = d;
        out.eog          = logical(get(hEog,'value'));
        out.eoglocut     = str2double(get(hOLo,'string'));
        out.eoghicut     = str2double(get(hOHi,'string'));
        out.viseog       = logical(get(hVisO,'value'));
        out.ppg          = logical(get(hPpg,'value')) && hasPPG;
        out.ppglocut     = str2double(get(hPLo,'string'));
        out.ppghicut     = str2double(get(hPHi,'string'));
        out.ppgdetect    = detOpts{get(hDet,'value')};
        out.visppg       = logical(get(hVisP,'value'));
        out.eda          = logical(get(hEda,'value'));
        out.edalocut     = str2double(get(hELo,'string'));
        out.edahicut     = str2double(get(hEHi,'string'));
        out.edaphasic    = logical(get(hPhasic,'value'));
        out.viscvx       = logical(get(hVisX,'value'));
        out.viseda       = true;
        out.emg          = logical(get(hEmg,'value'));
        out.emglocut     = str2double(get(hMLo,'string'));
        out.emghicut     = str2double(get(hMHi,'string'));
        out.emgenvelope  = logical(get(hEnv,'value'));
        out.visemg       = logical(get(hVisM,'value'));
        out.imu          = logical(get(hImu,'value'));
        out.imuhicut     = str2double(get(hIHi,'string'));
        out.imumagnitude = logical(get(hMag,'value'));
        out.visimu       = logical(get(hVisI,'value'));
        close(f);
    end
end