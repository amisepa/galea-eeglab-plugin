%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function out = galea_process_gui(def)
%GALEA_PROCESS_GUI  Processing parameters for every Galea signal.
%
%   >> out = galea_process_gui(def)
%
% One dialog for ALL processing parameters - EEG first (montage, filters, bad
% channels, ASR, ICA), then the other recorded signals (PPG, EDA, EMG, IMU).
% They are not "peripherals": for many studies they are as or more important
% than the EEG, so they sit in the same window with the same structure.
%
% DEF holds the current values (a galea_process_defaults struct, any subset;
% missing keys keep their defaults). OUT returns the full set, or [] if
% cancelled.
%
% Cedric Cannard, 2026

d = galea_process_defaults();
fn = fieldnames(def);
for iF = 1:numel(fn)
    if isfield(d, fn{iF}), d.(fn{iF}) = def.(fn{iF}); end
end

c = galea_colors();
W = 680;
scr = get(0, 'ScreenSize');
% measure-first: 1 title row (30) + content rows + buttons (56).
% Content: EEG block = 12 rows x 26 + 1 note x 16; PPG 4x26; EDA 4x26;
% EMG 4x26; IMU 4x26; separators 2x20. Total = 742.
H = 36 + 742 + 56;
H = min(H, scr(4) - 80);
f = figure('Name','Galea processing parameters', 'NumberTitle','off', 'MenuBar','none', ...
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

% ---------------- EEG ----------------
y = H - 36;
txt('EEG', [20 y 200 24], 'fontweight','bold','fontsize',12);
y = y - 30;

txt('Montage:', [20 y 90 20]);
hMont = uicontrol(f,'style','popupmenu','position',[115 y 340 24],'backgroundcolor',c.btn, ...
    'string',{'default (10 EEG)','custom (12 EEG, Fp1/Fp2 from disc electrodes)'}, ...
    'value', find(strcmp({'default','custom'}, d.montage)));
y = y - 26;
txt('Bandpass (Hz):', [20 y 130 20]);
hLo = ed(sprintf('%g', d.locut), [155 y 60 24]);
txt('to', [222 y 20 20]);
hHi = ed(sprintf('%g', d.hicut), [248 y 60 24]);
txt('Downsample (Hz, 0 = keep):', [340 y 180 20]);
hRes = ed(sprintf('%g', d.resample), [525 y 60 24]);
y = y - 26;
hCaus = cb('Minimum-phase causal filter (only for pre-stimulus analyses)', double(d.causal), [20 y W-40 22]);
y = y - 26;
txt('Polarity check (Fp1/Fp2, custom montage):', [20 y 300 20]);
hPol = cb('correct inverted disc electrodes', double(d.polarity), [330 y 250 22]);
y = y - 26;
hBad = cb('Detect bad channels', double(d.badchan), [20 y 180 22]);
hInterp = cb('Interpolate them', double(d.interpchan), [210 y 170 22]);
y = y - 26;
txt('Channel cross-correlation (R^2) threshold:', [40 y 280 20]);
hCorr = ed(sprintf('%g', d.mincorr), [325 y 60 24]);
y = y - 26;
txt('Max % of windows a channel may fail (10-50%):', [40 y 300 20]);
hMaxTol = ed(sprintf('%g', d.maxtol*100), [345 y 60 24]);
txt('%', [390 y 20 20]);
y = y - 26;
txt('ASR threshold (0 = skip):', [20 y 180 20]);
hAsr = ed(sprintf('%g', d.asr), [205 y 60 24]);
txt('mode:', [275 y 40 20]);
hAsrMode = uicontrol(f,'style','popupmenu','position',[315 y 130 24], ...
    'backgroundcolor',c.btn, 'string',{'reconstruct','remove'}, ...
    'value', find(strcmp({'reconstruct','remove'}, d.asrmode)), ...
    'tooltipstring', ['remove: flagged segments are deleted (default; any event markers inside them are ' ...
    'listed in the command window). reconstruct: ASR interpolates the flagged segments instead.']);
y = y - 16;
txt('   Lenient first pass so ICA can still separate the blink source.', [40 y W-60 16], ...
    'fontangle','italic','fontsize',8);
y = y - 26;
hIca = cb('ICA, remove the ocular component (eyes-open data)', double(d.ica), [20 y 420 22]);
y = y - 26;
hConf = cb('ask me to confirm which component first (recommended)', double(d.icaconfirm), [40 y 420 22]);
y = y - 26;
hVisE = cb('Plot EEG before / after cleaning', double(d.viseeg), [20 y 350 22]);
y = y - 20; sep(y);

% ---------------- PPG ----------------
y = y - 26;
hPpg = box('PPG (cardiac)', double(d.ppg), [20 y 260 24]);
pg = gobjects(0);
y = y - 26;
txt('Bandpass (Hz):', [40 y 130 20]);
hPLo = ed(sprintf('%g', d.ppglocut), [175 y 60 24]);
txt('to', [242 y 20 20]);
hPHi = ed(sprintf('%g', d.ppghicut), [268 y 60 24]);
txt('RR artefact correction:', [340 y 150 20]);
hRR = uicontrol(f,'style','popupmenu','position',[495 y 70 24], 'backgroundcolor',c.btn, ...
    'string',{'pchip','linear','spline','makima','nearest','remove'}, ...
    'value', find(strcmp({'pchip','linear','spline','makima','nearest','remove'}, d.rrcorrect)));
pg(end+1) = hPLo; pg(end+1) = hPHi; pg(end+1) = hRR; %#ok<*AGROW>
y = y - 26;
txt('HRV features:', [40 y 100 20]);
hHt = cb('time', double(d.hrvtime), [145 y 70 22]);
hHf = cb('frequency', double(d.hrvfreq), [220 y 90 22]);
hHn = cb('nonlinear', double(d.hrvnonlin), [315 y 90 22]);
pg(end+1) = hHt; pg(end+1) = hHf; pg(end+1) = hHn;
y = y - 26;
hVisP = cb('Plot heartbeat detection and HRV outputs', double(d.visppg), [40 y W-70 22]);

% ---------------- EDA ----------------
y = y - 26;
hEda = box('EDA (skin conductance)', double(d.eda), [20 y 260 24]);
y = y - 26;
txt('Bandpass (Hz):', [40 y 130 20]);
hELo = ed(sprintf('%g', d.edalocut), [175 y 60 24]);
txt('to', [242 y 20 20]);
hEHi = ed(sprintf('%g', d.edahicut), [268 y 60 24]);
txt('Downsample (Hz):', [340 y 120 20]);
hERes = ed(sprintf('%g', d.edaresample), [495 y 60 24]);
y = y - 26;
txt('Tonic / phasic split:', [40 y 130 20]);
hPhasic = cb('cvxEDA decomposition', double(d.edaphasic), [175 y 180 22]);
y = y - 26;
hVisD = cb('Plot EDA (raw vs processed)', double(d.viseda), [40 y W-70 22]);

% ---------------- EMG ----------------
y = y - 26;
hEmg = box('EMG (facial)', double(d.emg), [20 y 260 24]);
y = y - 26;
txt('High-pass (Hz):', [40 y 130 20]);
hMLo = ed(sprintf('%g', d.emglocut), [175 y 60 24]);
y = y - 26;
txt('Envelope:', [40 y 130 20]);
hEnv = cb('Rectify + 100 ms moving average', double(d.emgenvelope), [175 y 260 22]);
y = y - 26;
hVisM = cb('Plot EMG (raw vs processed)', double(d.visemg), [40 y W-70 22]);

% ---------------- IMU ----------------
y = y - 26;
hImu = box('IMU (head motion)', double(d.imu), [20 y 260 24]);
y = y - 26;
txt('Low-pass (Hz):', [40 y 130 20]);
hIHi = ed(sprintf('%g', d.imuhicut), [175 y 60 24]);
y = y - 26;
txt('Derived channel:', [40 y 130 20]);
hMag = cb('Acceleration magnitude (ACC_MAG)', double(d.imumagnitude), [175 y 280 22]);
y = y - 26;
hVisI = cb('Plot IMU (raw vs processed)', double(d.visimu), [40 y W-70 22]);

% ---------------- buttons ----------------
out = [];
uicontrol(f,'style','pushbutton','string','Cancel','position',[W-200 18 80 30], ...
    'backgroundcolor',c.btn,'callback','close(gcbf)');
uicontrol(f,'style','pushbutton','string','OK','position',[W-105 18 85 30], ...
    'fontweight','bold','backgroundcolor',c.btn,'callback',@(~,~) onOK());

uiwait(f);

    function onOK()
        monts = get(hMont,'string');
        asrM = get(hAsrMode,'string');
        rrOpts = get(hRR,'string');
        out = d;
        out.montage      = monts{get(hMont,'value')};
        out.locut        = str2double(get(hLo,'string'));
        out.hicut        = str2double(get(hHi,'string'));
        out.resample     = str2double(get(hRes,'string'));
        out.causal       = logical(get(hCaus,'value'));
        out.polarity     = logical(get(hPol,'value'));
        out.badchan      = logical(get(hBad,'value'));
        out.interpchan   = logical(get(hInterp,'value'));
        out.mincorr      = str2double(get(hCorr,'string'));
        out.maxtol       = str2double(get(hMaxTol,'string')) / 100;   % % -> fraction
        out.asr          = str2double(get(hAsr,'string'));
        out.asrmode      = asrM{get(hAsrMode,'value')};
        out.ica          = logical(get(hIca,'value'));
        out.icaconfirm   = logical(get(hConf,'value'));
        out.viseeg       = logical(get(hVisE,'value'));
        out.ppg          = logical(get(hPpg,'value'));
        out.ppglocut     = str2double(get(hPLo,'string'));
        out.ppghicut     = str2double(get(hPHi,'string'));
        out.rrcorrect    = rrOpts{get(hRR,'value')};
        out.hrvtime      = logical(get(hHt,'value'));
        out.hrvfreq      = logical(get(hHf,'value'));
        out.hrvnonlin    = logical(get(hHn,'value'));
        out.visppg       = logical(get(hVisP,'value'));
        out.eda          = logical(get(hEda,'value'));
        out.edalocut     = str2double(get(hELo,'string'));
        out.edahicut     = str2double(get(hEHi,'string'));
        out.edaresample  = str2double(get(hERes,'string'));
        out.edaphasic    = logical(get(hPhasic,'value'));
        out.viseda       = logical(get(hVisD,'value'));
        out.emg          = logical(get(hEmg,'value'));
        out.emglocut     = str2double(get(hMLo,'string'));
        out.emgenvelope  = logical(get(hEnv,'value'));
        out.visemg       = logical(get(hVisM,'value'));
        out.imu          = logical(get(hImu,'value'));
        out.imuhicut     = str2double(get(hIHi,'string'));
        out.imumagnitude = logical(get(hMag,'value'));
        out.visimu       = logical(get(hVisI,'value'));
        close(f);
    end
end