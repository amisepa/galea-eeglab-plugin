%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function out = galea_process_gui(def)
%GALEA_PROCESS_GUI  Processing parameters for every Galea signal.
%
%   >> out = galea_process_gui(def)
%
% One dialog for ALL processing parameters - EEG first (montage, filters, bad
% channels, ASR, ICA), then the other recorded signals (EOG, PPG, EDA, EMG,
% IMU). They are not "peripherals": for many studies they are as or more
% important than the EEG, so they sit in the same window with the same
% structure, separated by horizontal rules. Each modality's "process" checkbox
% enables/disables its parameters; the Fp1/Fp2 polarity check is only enabled
% for the custom montage.
%
% Row discipline (keep the window sized to its content): every row does
% "y = y - rowH" FIRST, then places controls of height <= rowH - 2 at y. The
% height budget below must match the decrements exactly.
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
W = 780;
scr = get(0, 'ScreenSize');

% ---- height budget (must stay in sync with the layout below) ----
% top margin 36 + rows + buttons 56; NO screen clamp (controls must never
% overlap; a too-tall window just extends past the screen bottom)
% EEG: title 26, montage 20, ExG note 20, polarity 22, downsample 22,
%      bandpass+causal 22, badchan 22, corr 22, max% 22, ASR 22,
%      lenient note 20, ICA 22, plot 22, sep 20 = 302
% EOG: box 24, bandpass 24, plot 24, sep 20 = 92
% PPG: box 24, bandpass+detect 26, RR label 22, pchip note 20, HRV 22,
%      sep 20 = 134
% EDA: box 24, bandpass 24, tonic-phasic 24, plot 22, sep 20 = 114
% EMG: box 24, filters 24, envelope 24, plot 22, sep 20 = 114
% IMU: box 24, lowpass 24, ACC_MAG 22, plot 22 = 92
rowsEEG   = 302;  rowsEOG = 92;  rowsPPG = 134;
rowsEDA   = 114;  rowsEMG = 114;  rowsIMU = 92;
H = 36 + 56 + rowsEEG + rowsEOG + rowsPPG + rowsEDA + rowsEMG + rowsIMU;
% never clamp: controls must never overlap; a too-tall window
% just extends past the screen bottom, every control stays usable
% H = min(H, scr(4) - 80);
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
y = y - 26;
txt('EEG', [20 y 200 24], 'fontweight','bold','fontsize',12);

y = y - 20;
txt('Montage:', [20 y 90 20]);
hMont = uicontrol(f,'style','popupmenu','position',[115 y 340 20],'backgroundcolor',c.btn, ...
    'string',{'default (10 EEG)','custom (12 EEG, Fp1/Fp2 from disc electrodes)'}, ...
    'value', find(strcmp({'default','custom'}, d.montage)));

y = y - 20;
txt(['Default: ExG 7-8 stay facial EMG.  Custom: they become EEG at Fp1/Fp2 - ' ...
     'only if reconfigured as EEG in the Galea software when recording.'], ...
    [40 y W-60 20], 'fontangle','italic','fontsize',8);

y = y - 22;
txt('Polarity check:', [20 y 100 20]);
hPol = cb('correct inverted Fp1/Fp2 disc electrodes', double(d.polarity), [125 y 340 22]);

y = y - 22;
txt('Downsample (Hz, 0 = keep):', [20 y 180 20]);
hRes = ed(sprintf('%g', d.resample), [205 y 60 22]);

y = y - 22;
txt('Bandpass (Hz):', [20 y 100 20]);
hLo = ed(sprintf('%g', d.locut), [125 y 60 22]);
txt('to', [192 y 20 20]);
hHi = ed(sprintf('%g', d.hicut), [218 y 60 22]);
hCaus = cb('minimum-phase causal filter (only for pre-stimulus analyses)', ...
    double(d.causal), [290 y W-310 22]);

y = y - 22;
hBad = cb('Detect bad channels', double(d.badchan), [20 y 180 22]);
hInterp = cb('Interpolate them', double(d.interpchan), [210 y 170 22]);

y = y - 22;
txt('Channel cross-correlation threshold (lax 0.35 - aggressive 0.85):', [40 y 400 20]);
hCorr = ed(sprintf('%g', d.mincorr), [445 y 60 22]);

y = y - 22;
txt('Max % of windows a channel may fail before removal (5-50%):', [40 y 400 20]);
hMaxTol = ed(sprintf('%g', d.maxtol*100), [445 y 60 22]);

y = y - 22;
hAsr = cb('ASR 1st pass', double(d.asr > 0), [20 y 160 22]);
hAsrTh = ed(sprintf('%g', d.asr), [185 y 60 22]);
txt('threshold (lenient ~100):', [252 y 160 20], 'fontangle','italic');
hAsrMode = uicontrol(f,'style','popupmenu','position',[420 y 130 22], ...
    'backgroundcolor',c.btn, 'string',{'reconstruct','remove'}, ...
    'value', find(strcmp({'reconstruct','remove'}, d.asrmode)), ...
    'tooltipstring', ['remove: flagged segments are deleted (default; any event markers inside them are ' ...
    'listed in the command window). reconstruct: ASR interpolates the flagged segments instead.']);

y = y - 20;
txt('   Lenient first pass so ICA can still separate the blink source.', [40 y W-60 18], ...
    'fontangle','italic','fontsize',8);

y = y - 22;
hIca = cb('ICA: Extract the most likely eye component (eyes-open data; visual check and confirmation required)', ...
    double(d.ica), [20 y W-40 22]);

y = y - 22;
hVisE = cb('Plot EEG before / after cleaning', double(d.viseeg), [20 y 350 22]);

y = y - 20; sep(y);

% ---------------- EOG ----------------
y = y - 24;
eogKids = gobjects(0);
hEog = box('ElectroOculoGraphy (EOG; eye movements & blinks)', double(d.eog), [20 y 440 24]);

y = y - 24;
txt('Bandpass (Hz):', [40 y 130 20]);
hOLo = ed(sprintf('%g', d.eoglocut), [175 y 60 22]);
txt('to', [242 y 20 20]);
hOHi = ed(sprintf('%g', d.eoghicut), [268 y 60 22]);
eogKids(end+1) = hOLo; eogKids(end+1) = hOHi; %#ok<*AGROW>

y = y - 24;
hVisO = cb('Plot VEOG with detected blinks (blink rate reported in the console)', ...
    double(d.viseog), [40 y W-70 22]);
eogKids(end+1) = hVisO;

y = y - 20; sep(y);

% ---------------- PPG ----------------
y = y - 24;
ppgKids = gobjects(0);
hPpg = box('Photoplethysmography (PPG)', double(d.ppg), [20 y 440 24]);

y = y - 24;
txt('Bandpass (Hz):', [40 y 130 20]);
hPLo = ed(sprintf('%g', d.ppglocut), [175 y 60 22]);
txt('to', [242 y 20 20]);
hPHi = ed(sprintf('%g', d.ppghicut), [268 y 60 22]);
txt('Detect pulse-wave:', [340 y 130 20]);
hDet = uicontrol(f,'style','popupmenu','position',[475 y 110 22], 'backgroundcolor',c.btn, ...
    'string',{'valleys','peaks'}, 'value', find(strcmp({'valleys','peaks'}, d.ppgdetect)), ...
    'tooltipstring', ['Which feature of the pulse wave defines a heartbeat: the ' ...
    'valleys (default) or the peaks. Valleys are the conventional PPG fiducial.']);
ppgKids(end+1) = hPLo; ppgKids(end+1) = hPHi; ppgKids(end+1) = hDet;

y = y - 22;
txt('RR intervals cleaning (via BrainBeats plugin):', [40 y 300 20]);

y = y - 20;
txt('pchip interpolation by default (command line: ''rrcorrect'')', [58 y W-80 20], ...
    'fontangle','italic','fontsize',8);

y = y - 22;
hVisP = cb('Compute HRV features (via BrainBeats plugin)', double(d.visppg), [40 y W-70 22]);
ppgKids(end+1) = hVisP;

y = y - 20; sep(y);

% ---------------- EDA ----------------
y = y - 24;
edaKids = gobjects(0);
hEda = box('ElectroDermal Activity (EDA; skin conductance)', double(d.eda), [20 y 440 24]);

y = y - 24;
txt('Bandpass (Hz):', [40 y 130 20]);
hELo = ed(sprintf('%g', d.edalocut), [175 y 60 22]);
txt('to', [242 y 20 20]);
hEHi = ed(sprintf('%g', d.edahicut), [268 y 60 22]);
edaKids(end+1) = hELo; edaKids(end+1) = hEHi;

y = y - 24;
hPhasic = cb('Compute Tonic / Phasic components (using the cvxEDA algorithm; runs at 8 Hz)', ...
    double(d.edaphasic), [40 y W-70 22]);
edaKids(end+1) = hPhasic;

y = y - 22;
hVisX = cb('Plot the tonic / phasic components', double(d.viscvx), [40 y 400 22]);
edaKids(end+1) = hVisX;

y = y - 20; sep(y);

% ---------------- EMG ----------------
y = y - 24;
emgKids = gobjects(0);
hEmg = box('ElectroMyoGraphy (EMG; facial)', double(d.emg), [20 y 440 24]);

y = y - 24;
txt('High-pass (Hz):', [40 y 130 20]);
hMLo = ed(sprintf('%g', d.emglocut), [175 y 60 22]);
txt('Low-pass (Hz, 0 = none):', [245 y 160 20]);
hMHi = ed(sprintf('%g', d.emghicut), [410 y 60 22]);
emgKids(end+1) = hMLo; emgKids(end+1) = hMHi;

y = y - 24;
hEnv = cb('Compute the envelope (rectify + 100 ms moving average)', ...
    double(d.emgenvelope), [40 y W-70 22]);
emgKids(end+1) = hEnv;

y = y - 22;
hVisM = cb('Plot EMG with the envelope', double(d.visemg), [40 y 400 22]);
emgKids(end+1) = hVisM;

y = y - 20; sep(y);

% ---------------- IMU ----------------
y = y - 24;
imuKids = gobjects(0);
hImu = box('Inertial Motion Unit (IMU; head motion)', double(d.imu), [20 y 440 24]);

y = y - 24;
txt('Low-pass (Hz):', [40 y 130 20]);
hIHi = ed(sprintf('%g', d.imuhicut), [175 y 60 22]);
imuKids(end+1) = hIHi;

y = y - 22;
hMag = cb('Compute ACC\_MAG: orientation-independent head-motion metric', ...
    double(d.imumagnitude), [40 y W-70 22]);
imuKids(end+1) = hMag;

y = y - 22;
hVisI = cb('Plot all IMU channels incl. ACC\_MAG', double(d.visimu), [40 y W-70 22]);
imuKids(end+1) = hVisI;

% ---------------- gating ----------------
gateMontage();
gateAll();

    function gateMontage()
        % the Fp1/Fp2 polarity check only makes sense when the disc electrodes
        % ARE Fp1/Fp2, i.e. the custom montage
        if get(hMont,'value') == 2
            set(hPol, 'enable', 'on');
            set(hMont, 'tooltipstring', ['ExG channels 7-8 (EMG5/EMG6) become Fp1/Fp2. ' ...
                'Only correct polarity if they were reconfigured as EEG when recording.']);
        else
            set(hPol, 'enable', 'off');
            set(hPol, 'value', 0);
            set(hMont, 'tooltipstring', '');
        end
    end

    function gateAll()
        % each modality's checkbox enables/disables its parameters
        set(eogKids(isgraphics(eogKids)), 'enable', gateStr(get(hEog,'value')));
        set(ppgKids(isgraphics(ppgKids)), 'enable', gateStr(get(hPpg,'value')));
        set(edaKids(isgraphics(edaKids)), 'enable', gateStr(get(hEda,'value')));
        set(emgKids(isgraphics(emgKids)), 'enable', gateStr(get(hEmg,'value')));
        set(imuKids(isgraphics(imuKids)), 'enable', gateStr(get(hImu,'value')));
    end

    function s = gateStr(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end

% wire the gates to the modality boxes and the montage popup
set(hEog, 'callback', @(~,~) gateAll());
set(hPpg, 'callback', @(~,~) gateAll());
set(hEda, 'callback', @(~,~) gateAll());
set(hEmg, 'callback', @(~,~) gateAll());
set(hImu, 'callback', @(~,~) gateAll());
set(hMont, 'callback', @(~,~) gateMontage());

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
        detOpts = get(hDet,'string');
        out = d;
        out.montage      = monts{get(hMont,'value')};
        out.polarity     = logical(get(hPol,'value'));
        out.resample     = str2double(get(hRes,'string'));
        out.locut        = str2double(get(hLo,'string'));
        out.hicut        = str2double(get(hHi,'string'));
        out.causal       = logical(get(hCaus,'value'));
        out.badchan      = logical(get(hBad,'value'));
        out.interpchan   = logical(get(hInterp,'value'));
        out.mincorr      = str2double(get(hCorr,'string'));
        out.maxtol       = str2double(get(hMaxTol,'string')) / 100;   % % -> fraction
        if logical(get(hAsr,'value'))
            out.asr      = str2double(get(hAsrTh,'string'));
        else
            out.asr      = 0;                    % unchecked = skip the 1st pass
        end
        out.asrmode      = asrM{get(hAsrMode,'value')};
        out.ica          = logical(get(hIca,'value'));
        out.icaconfirm   = true;     % GUI always confirms; command line may disable
        out.viseeg       = logical(get(hVisE,'value'));
        out.eog          = logical(get(hEog,'value'));
        out.eoglocut     = str2double(get(hOLo,'string'));
        out.eoghicut     = str2double(get(hOHi,'string'));
        out.viseog       = logical(get(hVisO,'value'));
        out.ppg          = logical(get(hPpg,'value'));
        out.ppglocut     = str2double(get(hPLo,'string'));
        out.ppghicut     = str2double(get(hPHi,'string'));
        out.ppgdetect    = detOpts{get(hDet,'value')};
        out.visppg       = logical(get(hVisP,'value'));
        out.eda          = logical(get(hEda,'value'));
        out.edalocut     = str2double(get(hELo,'string'));
        out.edahicut     = str2double(get(hEHi,'string'));
        out.edaphasic    = logical(get(hPhasic,'value'));
        out.viscvx       = logical(get(hVisX,'value'));
        out.viseda       = true;     % raw-vs-processed plot always available when EDA runs
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