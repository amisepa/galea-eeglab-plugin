%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function out = galea_process_gui(def, EEG)
%GALEA_PROCESS_GUI  Processing parameters for every Galea signal.
%
%   >> out = galea_process_gui(def)
%   >> out = galea_process_gui(def, EEG)   % EEG lets the trim row detect events
%
% One dialog for ALL processing parameters - EEG first (trim pad, filters,
% bad channels, ASR 1st pass, ICA, optional 2nd ASR pass, spectra plot),
% then, for ERP data only, the epoching options (epoch window, bad-trial
% rejection, condition ERP plot), then the other recorded signals (EOG, PPG,
% EDA, EMG, IMU). Every signal is ticked by default. They are not
% "peripherals": for many studies they are as or more important than the
% EEG, so they sit in the same window with the same structure, separated by
% horizontal rules. Each modality's "process" checkbox enables/disables its
% parameters. The montage and the data type (DEF.erp) are chosen in the main
% window (pop_galea); the Fp1/Fp2 polarity check arrives pre-ticked for the
% custom montage. Run returns the parameters; processing starts after.
%
% Row discipline (keep the window sized to its content): every row does
% "y = y - rowH" FIRST, then places controls of height <= rowH - 2 at y. The
% height budget below must match the decrements exactly.
%
% DEF holds the current values (a galea_process_defaults struct, any subset;
% missing keys keep their defaults). DEF.srate, when present and finite, fills
% the Downsample list with the true rate. EEG.event fills the condition list
% of the ERP section. OUT returns the full set, or [] if cancelled.
%
% Cedric Cannard, 2026

d = galea_process_defaults();
if nargin < 2, EEG = struct(); EEG.event = {}; end
fn = fieldnames(def);
for iF = 1:numel(fn)
    if isfield(d, fn{iF}), d.(fn{iF}) = def.(fn{iF}); end
end

c = galea_colors();
W = 780;
scr = get(0, 'ScreenSize');

% ---- height budget (must stay in sync with the layout below) ----
% top margin 24 + rows + buttons 68; NO screen clamp (controls must never
% overlap; a too-tall window just extends past the screen bottom)
% EEG: title 26, trim 22, polarity 22, downsample 22, bandpass+causal 22,
%      badchan 22, corr 22, max% 22, interp 22, ASR+note 22, ICA 22,
%      ASR2+note 22, plots 22, sep 20 = 310
% ERP (ERP data only): title 26, epoch+bad trials 24, conditions 24,
%      sep 20 = 94
% EOG: box 24, bandpass 24, plot 24, sep 20 = 92
% PPG: box 24, bandpass+detect 24, RR label+note 22, HRV 22, sep 20 = 112
% EDA: box 24, bandpass 24, tonic-phasic 24, plot 22, sep 20 = 114
% EMG: box 24, filters 24, envelope+plot 24, sep 20 = 92
% IMU: box 24, lowpass 24, ACC_MAG+plot 22 = 70
% Notes sit beside their controls and paired checkboxes share a row, so the
% ERP version still fits a 1080-pixel screen.
rowsEEG   = 310;  rowsEOG = 92;  rowsPPG = 112;
rowsEDA   = 114;  rowsEMG = 92;  rowsIMU = 70;
rowsERP   = 94 * double(logical(d.erp));
H = 24 + 68 + rowsEEG + rowsERP + rowsEOG + rowsPPG + rowsEDA + rowsEMG + rowsIMU;
% never clamp: controls must never overlap; a too-tall window
% just extends past the screen bottom, every control stays usable
% H = min(H, scr(4) - 80);
if d.erp, dataType = 'ERP data'; else, dataType = 'continuous data'; end
f = figure('Name',['Galea processing parameters (' dataType ')'], 'NumberTitle','off', 'MenuBar','none', ...
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
    function s = gateStr(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end

% ---------------- EEG ----------------
y = H - 24;
y = y - 26;
txt('EEG', [20 y 200 24], 'fontweight','bold','fontsize',12);

y = y - 22;
if isfield(EEG, 'event') && ~isempty(EEG.event)
    txt('Trim pad (s, 0 = keep all; cuts before the first / after the last event, ALL signals):', [20 y 560 20]);
    hTrim = ed(sprintf('%g', d.trim), [585 y 60 22]);
else
    txt('No events in this dataset; nothing to trim.', [20 y 400 20], 'fontangle','italic');
    hTrim = ed('0', [585 y 60 22]);
    set(hTrim, 'enable', 'off');
end

y = y - 22;
txt('Polarity check:', [20 y 100 20]);
% pre-ticked for the custom montage: the two disc electrodes ARE Fp1/Fp2
% there, and that amplifier path is the one known to invert leads
hPol = cb('fix inverted Fp1/Fp2 disc electrodes (custom montage only)', ...
    double(d.polarity || strcmpi(d.montage, 'custom')), [125 y 470 22], ...
    'tooltipstring', ['ExG channels 7-8 become Fp1/Fp2 in the custom montage. Only correct ' ...
    'polarity if they were reconfigured as EEG in the Galea software when recording.']);

% ---- downsample: a list, not a free box. The current rate sits on top;
% dividing it avoids resampling artefacts at non-integer ratios. Falls back
% to an edit box when the rate is unknown (command-line use).
dsVals = [];
srate = NaN;
if isfield(def, 'srate') && isfinite(def.srate) && def.srate > 0
    srate = double(def.srate);   % def, not d: galea_process_defaults has no srate key
end
y = y - 22;
txt('Downsample:', [20 y 100 20]);
if isnan(srate)
    hRes = ed(sprintf('%g', d.resample), [205 y 90 22]);
    set(hRes, 'tooltipstring', 'Target rate in Hz; 0 keeps the current rate.');
else
    dsOpts = {sprintf('keep current rate (%g Hz)', srate), ...
              sprintf('%g Hz (divide by 2)', srate/2), ...
              sprintf('%g Hz (divide by 4)', srate/4), ...
              '128 Hz', '250 Hz', '512 Hz'};
    dsVals = [0, srate/2, srate/4, 128, 250, 512];      % 0 = keep (no resampling)
    if isfinite(d.resample) && d.resample > 0 && ~any(abs(dsVals - d.resample) < 0.05)
        dsOpts{end+1} = sprintf('%g Hz (as previously set)', d.resample);
        dsVals(end+1) = d.resample;
    end
    hRes = uicontrol(f,'style','popupmenu','position',[205 y 220 22],'backgroundcolor',c.btn, ...
        'string',dsOpts, 'value', max(1, find(abs(dsVals - d.resample) < 0.05, 1)), ...
        'tooltipstring', ['Dividing the current rate avoids resampling artefacts at ' ...
        'non-integer ratios. "keep current rate" leaves the recording untouched.']);
end

y = y - 22;
txt('Bandpass (Hz):', [20 y 100 20]);
hLo = ed(sprintf('%g', d.locut), [125 y 60 22]);
txt('to', [192 y 20 20]);
hHi = ed(sprintf('%g', d.hicut), [218 y 60 22]);
hCaus = cb('minimum-phase causal filter (only for pre-stimulus analyses)', ...
    double(d.causal), [290 y W-310 22]);

y = y - 22;
hBad = cb('Detect bad channels', double(d.badchan), [20 y 180 22], ...
    'callback', @(~,~) gateBad());

y = y - 22;
txt('Channel cross-correlation threshold (lax 0.35 - aggressive 0.85):', [40 y 400 20]);
hCorr = ed(sprintf('%g', d.mincorr), [445 y 60 22]);

y = y - 22;
txt('Max % of windows a channel may fail before removal (5-50%):', [40 y 400 20]);
hMaxTol = ed(sprintf('%g', d.maxtol*100), [445 y 60 22]);

y = y - 22;
hInterp = cb('Interpolate the detected bad channels', double(d.interpchan), [40 y 320 22]);

y = y - 22;
hAsr = cb('ASR 1st pass', double(d.asr > 0), [20 y 180 22]);
hAsrTh = ed(sprintf('%g', d.asr), [205 y 60 22]);
hAsrMode = uicontrol(f,'style','popupmenu','position',[275 y 130 22], ...
    'backgroundcolor',c.btn, 'string',{'reconstruct','remove'}, ...
    'value', find(strcmp({'reconstruct','remove'}, d.asrmode)), ...
    'tooltipstring', ['remove: flagged segments are deleted (default; any event markers inside them are ' ...
    'listed in the command window). reconstruct: ASR interpolates the flagged segments instead.']);
txt('Lenient pass (100) so ICA can still separate the blink source.', ...
    [415 y-2 W-435 20], 'fontangle','italic','fontsize',8);

y = y - 22;
hIca = cb('ICA: Extract the most likely eye component (eyes-open data; visual check and confirmation required)', ...
    double(d.ica), [20 y W-40 22]);

y = y - 22;
hAsr2 = cb('ASR 2nd pass (after ICA)', double(d.asr2 > 0), [20 y 180 22], ...
    'callback', @(~,~) gateAsr2());
hAsr2Th = ed(sprintf('%g', max(d.asr2, 5)), [205 y 60 22]);
hAsr2Mode = uicontrol(f,'style','popupmenu','position',[275 y 130 22], ...
    'backgroundcolor',c.btn, 'string',{'reconstruct','remove'}, ...
    'value', find(strcmp({'reconstruct','remove'}, d.asr2mode)), ...
    'tooltipstring', ['Stricter second pass on the cleaned data, after ICA removed the eye ' ...
    'component. reconstruct: flagged segments are interpolated (safest, default). ' ...
    'remove: they are deleted.']);
txt('Stricter pass on the cleaned data (default 5).', ...
    [415 y-2 W-435 20], 'fontangle','italic','fontsize',8);

y = y - 22;
hVisE = cb('Plot EEG before / after cleaning', double(d.viseeg), [20 y 260 22]);
hSpectra = cb('Plot power spectra (1-70 Hz) at the end', double(d.plotspectra), ...
    [290 y W-310 22], 'tooltipstring', 'Power spectra of the whole cleaned recording, 1-70 Hz.');

y = y - 20; sep(y);

% ---------------- ERP (ERP data only) ----------------
% The data type is chosen in the main window; continuous data skip this
% section. Segmenting runs after all the continuous cleaning.
rejKeys = {'mean','median','grubbs'};
evTypes = {};
if isfield(EEG, 'event') && ~isempty(EEG.event) && isfield(EEG.event, 'type')
    evTypes = {EEG.event.type};
    isNum = cellfun(@isnumeric, evTypes);
    evTypes(isNum) = cellfun(@num2str, evTypes(isNum), 'UniformOutput', false);
    evTypes = unique(evTypes(~cellfun(@isempty, evTypes)));
end
if d.erp
    y = y - 26;
    txt('ERP', [20 y 200 24], 'fontweight','bold','fontsize',12);

    y = y - 24;
    txt('Epoch window (s):', [40 y 140 20]);
    hEpWin = ed(mat2str(d.epochwin), [185 y 90 22]);
    set(hEpWin, 'tooltipstring', ['Start and end of each epoch, in seconds around every ' ...
        'event marker, e.g. [-1.5 1.5].']);
    hRej = cb('Reject bad trials', double(d.rejtrials), [300 y 130 22], ...
        'callback', @(~,~) gateRej());
    iRej = find(strcmpi(rejKeys, d.rejmethod), 1);
    if isempty(iRej), iRej = 1; end
    hRejM = uicontrol(f,'style','popupmenu','position',[435 y 200 22],'backgroundcolor',c.btn, ...
        'string',{'conservative (mean)','medium (median)','aggressive (Grubbs)'}, 'value',iRej, ...
        'tooltipstring', ['Amplitude and high-frequency-residual outliers across epochs ' ...
        '(find_badTrials). conservative: mean-based criterion, flags the fewest trials ' ...
        '(default). medium: median-based. aggressive: Grubbs test, flags the most.']);

    y = y - 24;
    txt('Plot condition ERPs:', [40 y 140 20]);
    if isempty(evTypes)
        condOpts = {'(no event markers in this file)'};
    else
        condOpts = [{'(none)'}, evTypes];
    end
    iCond = 1;
    if ~isempty(d.plotconds)
        k = find(strcmp(condOpts, d.plotconds{1}), 1);
        if ~isempty(k), iCond = k; end
    end
    hCond = uicontrol(f,'style','popupmenu','position',[185 y 290 22],'backgroundcolor',c.btn, ...
        'string',condOpts, 'value',iCond, 'tooltipstring', ['Condition plotted as a 20% ' ...
        'trimmed-mean ERP (+/- SEM) with its single-trial ERP image. The list is the ' ...
        'event markers in this file.']);

    y = y - 20; sep(y);
end

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
txt('RR intervals cleaning (via BrainBeats plugin):', [40 y 290 20]);
txt('pchip interpolation by default (command line: ''rrcorrect'')', [335 y-2 W-355 20], ...
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
    double(d.emgenvelope), [40 y 400 22]);
emgKids(end+1) = hEnv;
hVisM = cb('Plot EMG with the envelope', double(d.visemg), [450 y W-470 22]);
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
hMag = cb('Compute ACC_MAG: orientation-independent head-motion metric', ...
    double(d.imumagnitude), [40 y 420 22]);
imuKids(end+1) = hMag;
hVisI = cb('Plot all IMU channels incl. ACC_MAG', double(d.visimu), [470 y W-490 22]);
imuKids(end+1) = hVisI;

% ---------------- gating ----------------
gateBad();
gateAsr2();
gateAll();
if d.erp, gateRej(); end

    function gateBad()
        % the correlation / max-% thresholds and the interpolation only act
        % when bad-channel detection runs
        on = gateStr(logical(get(hBad,'value')));
        set([hCorr hMaxTol hInterp], 'enable', on);
    end

    function gateRej()
        % the rejection criterion only acts when bad-trial rejection runs
        set(hRejM, 'enable', gateStr(logical(get(hRej,'value'))));
    end

    function gateAsr2()
        % the 2nd-pass threshold and mode only act when the pass is enabled
        on = gateStr(logical(get(hAsr2,'value')));
        set([hAsr2Th hAsr2Mode], 'enable', on);
    end

    function gateAll()
        % each modality's checkbox enables/disables its parameters
        set(eogKids(isgraphics(eogKids)), 'enable', gateStr(get(hEog,'value')));
        set(ppgKids(isgraphics(ppgKids)), 'enable', gateStr(get(hPpg,'value')));
        set(edaKids(isgraphics(edaKids)), 'enable', gateStr(get(hEda,'value')));
        set(emgKids(isgraphics(emgKids)), 'enable', gateStr(get(hEmg,'value')));
        set(imuKids(isgraphics(imuKids)), 'enable', gateStr(get(hImu,'value')));
    end

% wire the gates to the modality boxes
set(hEog, 'callback', @(~,~) gateAll());
set(hPpg, 'callback', @(~,~) gateAll());
set(hEda, 'callback', @(~,~) gateAll());
set(hEmg, 'callback', @(~,~) gateAll());
set(hImu, 'callback', @(~,~) gateAll());

% ---------------- buttons ----------------
out = [];
uicontrol(f,'style','pushbutton','string','Cancel','position',[W-200 18 80 30], ...
    'backgroundcolor',c.btn,'callback','close(gcbf)');
uicontrol(f,'style','pushbutton','string','Run','position',[W-105 18 85 30], ...
    'fontweight','bold','backgroundcolor',c.btn,'callback',@(~,~) onRun());

uiwait(f);

    function onRun()
        if d.erp
            % epoch window: two numbers, start < end (accepts [-1.5 1.5] or -1.5, 1.5)
            w = sscanf(regexprep(get(hEpWin,'string'), '[\[\],;]', ' '), '%f')';
            if numel(w) ~= 2 || w(1) >= w(2)
                warndlg(['The epoch window needs two numbers in seconds, start < end, ' ...
                    'e.g. [-1.5 1.5].'], 'Galea', 'modal');
                return
            end
        end
        asrM = get(hAsrMode,'string');
        asr2M = get(hAsr2Mode,'string');
        detOpts = get(hDet,'string');
        out = d;
        out.polarity     = logical(get(hPol,'value'));
        out.trim         = str2double(get(hTrim,'string'));
        if ~isempty(dsVals) && isgraphics(hRes) && strcmp(get(hRes,'style'), 'popupmenu')
            out.resample = dsVals(get(hRes,'value'));
        else
            out.resample = str2double(get(hRes,'string'));
        end
        out.locut        = str2double(get(hLo,'string'));
        out.hicut        = str2double(get(hHi,'string'));
        out.causal       = logical(get(hCaus,'value'));
        out.badchan      = logical(get(hBad,'value'));
        out.interpchan   = logical(get(hInterp,'value')) && out.badchan;
        out.mincorr      = str2double(get(hCorr,'string'));
        out.maxtol       = str2double(get(hMaxTol,'string')) / 100;   % % -> fraction
        if logical(get(hAsr,'value'))
            out.asr      = str2double(get(hAsrTh,'string'));
        else
            out.asr      = 0;                    % unchecked = skip the 1st pass
        end
        out.asrmode      = asrM{get(hAsrMode,'value')};
        if logical(get(hAsr2,'value'))
            out.asr2     = str2double(get(hAsr2Th,'string'));
        else
            out.asr2     = 0;                    % unchecked = skip the 2nd pass
        end
        out.asr2mode     = asr2M{get(hAsr2Mode,'value')};
        out.plotspectra  = logical(get(hSpectra,'value'));
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
        if d.erp
            out.epochwin  = w;
            out.rejtrials = logical(get(hRej,'value'));
            out.rejmethod = rejKeys{get(hRejM,'value')};
            if get(hCond,'value') > 1 && ~isempty(evTypes)
                condOpts = get(hCond,'string');
                out.plotconds = condOpts(get(hCond,'value'));
            else
                out.plotconds = {};
            end
        end
        close(f);
    end
end