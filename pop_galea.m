%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function [EEG, com] = pop_galea(EEG)
%POP_GALEA  Load and process a Galea recording. One window, top to bottom.
%
%   >> [EEG, com] = pop_galea;
%
% Step 1 loads the recording. Step 2 is optional processing, one section per
% modality, each with its own parameters and its own plot option. Everything
% below the "process" box is disabled until you tick it.
%
% Processing runs on CONTINUOUS data. Epoching and ERPs come afterwards from
% the usual EEGLAB menus; tutorial_galea.m walks through it.
%
% Cedric Cannard, 2026

if nargin < 1, EEG = []; end
com = '';

c = galea_colors();
S = struct('file','', 'path','', 'EEG',[], 'ok',false);

W = 700;
scr = get(0,'ScreenSize');
% Content height is measured by galea_pop_layout() (same arithmetic as the
% layout code below), so the window always fits its content and never crops.
H = galea_pop_layout(true);
H = min(H, scr(4) - 80);
f = figure('Name','Galea', 'NumberTitle','off', 'MenuBar','none', 'ToolBar','none', ...
    'Resize','off', 'Color',c.back, 'WindowStyle','modal', ...
    'Position',[(scr(3)-W)/2 max(40,(scr(4)-H)/2) W H]);

% ---------- header ----------
logo = fullfile(fileparts(mfilename('fullpath')), 'figures', 'galea_headset.png');
if isfile(logo)
    try
        [img,~,alpha] = imread(logo);
        ax = axes('Parent',f,'Units','pixels','Position',[22 H-108 92 92]);
        h = image(ax,img); axis(ax,'image','off');
        if ~isempty(alpha), set(h,'AlphaData',alpha); end
    catch, end
end
uicontrol(f,'style','text','string','Galea','fontsize',16,'fontweight','bold', ...
    'horizontalalignment','left','backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'position',[128 H-58 400 28]);
uicontrol(f,'style','text','string', ...
    'Import and process recordings from the Galea multimodal VR headset.', ...
    'horizontalalignment','left','backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'position',[128 H-82 540 20]);

% ---------- 1. load ----------
y = H - 130;
lbl('1.  Load data', [22 y 300 24], 'fontweight','bold','fontsize',11);
y = y - 26;
lbl(['Select the main .txt file only. Its OpenBCI-RAW-Aux-*.txt twin in the same ' ...
     'folder is loaded automatically.'], [22 y 500 32]);

hLoad = uicontrol(f,'style','pushbutton','string','Select file...','position',[540 y+2 140 30], ...
    'backgroundcolor',c.btn,'callback',@(~,~) onSelect());
y = y - 26;
hFile = uicontrol(f,'style','text','string','no file selected','fontangle','italic', ...
    'horizontalalignment','left','backgroundcolor',c.back,'foregroundcolor',[.35 .1 .1], ...
    'position',[22 y 660 20]);

y = y - 30;
lbl('Montage:', [22 y 70 20]);
hMont = uicontrol(f,'style','popupmenu','position',[92 y+2 330 24],'backgroundcolor',c.btn, ...
    'string',{'default (10 EEG)','custom (12 EEG, Fp1/Fp2 from disc electrodes)'}, ...
    'callback',@(~,~) montageNote());
y = y - 30;
hMontNote = lbl('', [22 y 660 28], 'fontangle','italic','fontsize',8);
montageNote();

% ---------- 2. process ----------
y = y - 38;
hDo = uicontrol(f,'style','checkbox', ...
    'string','2.  Process using the plugin''s custom methods (see Cannard 2026)', ...
    'value',0,'fontweight','bold','fontsize',11,'position',[22 y 520 24], ...
    'backgroundcolor',c.back,'foregroundcolor',c.text,'callback',@(~,~) toggle());

procKids = gobjects(0);    % everything gated by the "2. Process" master box
secBox = gobjects(0);      % the per-modality "process" checkboxes
secKids = {};              % their controls, one cell per section

% ---- trim (global, all signals) ----
y = y - 28; sepline(y+18);
sec('Trim (all signals)', [22 y 200 22]);
lbl('pad (s):', [228 y 45 20]);
hTrim = edt('3',[275 y 48 24]); procKids(end+1) = hTrim;
k = gobjects(0);
y = y - 34;
k(end+1) = lbl(['Data before the first event and after the last event, plus this pad, is ' ...
    'removed. Applies to the EEG and ALL auxiliary signals (PPG, EDA, EMG, IMU). ' ...
    '0 = keep everything.'], [40 y 620 30], 'fontangle','italic','fontsize',8);
procKids(end+1) = k(end);

% ---- EEG ----
y = y - 30; sepline(y+18);
sec('EEG', [22 y 120 22]);
hEEG = box('process', [150 y 90 22]);
k = gobjects(0);
y = y - 26;
k(end+1) = lbl('Bandpass (Hz):', [40 y 130 20]);
hLo = edt('0.5',[175 y 60 24]); k(end+1) = hLo;
k(end+1) = lbl('to',[240 y 20 20]);
hHi = edt('30',[262 y 60 24]);  k(end+1) = hHi;
k(end+1) = lbl('Downsample (Hz, 0 = keep):', [340 y 170 20]);
hRes = edt('-',[515 y 60 24]);  k(end+1) = hRes;
set(hRes, 'tooltipstring', 'Select a file first: the detected rate fills this box (keep = detected rate). Then pick a division or type a lower target.');
hEegRate = lbl('detected: -', [583 y 100 20], 'fontangle','italic','fontsize',8);
k(end+1) = hEegRate;
hDiv = uicontrol(f,'style','popupmenu','position',[515 y-24 60 24],'backgroundcolor',c.btn, ...
    'string',{'÷1','÷2','÷4'},'value',1, 'callback',@(~,~) onDiv(), ...
    'tooltipstring','Fill the Downsample box with the detected rate divided by 1, 2 or 4 (e.g. 500 > 250 > 125). Dividing the rate avoids resampling artefacts at non-integer ratios.');
k(end+1) = hDiv;
y = y - 24;
hCaus = chk('Causal minimum-phase filter (pre-stimulus analyses only)', 0, [40 y 420 22]); k(end+1) = hCaus;
y = y - 22;
hBad  = chk('Detect bad channels', 1, [40 y 170 22]); k(end+1) = hBad;
hInt  = chk('Interpolate them', 0, [215 y 150 22]);   k(end+1) = hInt;
y = y - 22;
k(end+1) = lbl('Channel cross-correlation (R^2) threshold:', [40 y 250 20]);
hCorr = edt('0.55', [290 y 60 24]); k(end+1) = hCorr;
y = y - 20;
k(end+1) = lbl('Max % of windows a channel may fail (10-50%):', [40 y 250 20], ...
    'fontsize',9);
hMaxTol = edt('30', [290 y 60 24]); k(end+1) = hMaxTol;
k(end+1) = lbl('%', [352 y 20 20]);
y = y - 44;
hAsrOn = chk('Artifact subspace reconstruction (ASR), threshold:', 1, [40 y 300 22]); k(end+1) = hAsrOn;
hAsr = edt('100',[345 y 55 24]); k(end+1) = hAsr;
hAsrMode = uicontrol(f,'style','popupmenu','position',[408 y 130 24],'backgroundcolor',c.btn, ...
    'string',{'reconstruct','remove'},'value',2, 'tooltipstring', ...
    ['remove: flagged segments are deleted (default; any event markers inside them are listed in the ' ...
    'command window). reconstruct: ASR interpolates the flagged segments instead.']);
k(end+1) = hAsrMode;
y = y - 48;
k(end+1) = lbl(['       Before ICA, a lenient threshold deletes only the worst segments while leaving ' ...
                'ocular activity, so ICA can separate the eye-blink source cleanly. A strict ' ...
                'threshold here would eat part of the blinks and the decomposition would no ' ...
                'longer be clean.'], [40 y 560 44], ...
               'fontangle','italic','fontsize',8);
y = y - 28;
hIca  = chk('ICA, remove the ocular component  (eyes-open tasks only)', 1, [40 y 420 22]); k(end+1) = hIca;
y = y - 24;
hAsr2On = chk('ASR pass after ICA, threshold (0 = skip):', 0, [40 y 300 22]); k(end+1) = hAsr2On;
hAsr2 = edt('20',[345 y 55 24]); k(end+1) = hAsr2;
k(end+1) = lbl('mode:', [410 y 40 20]);
hAsr2Mode = uicontrol(f,'style','popupmenu','position',[450 y 115 24],'backgroundcolor',c.btn, ...
    'string',{'reconstruct','remove'},'value',1, 'tooltipstring', ...
    ['reconstruct: flagged segments are interpolated (default, safest for ' ...
     'continuous data). remove: the segments are deleted and any event markers ' ...
     'inside them are lost.']); k(end+1) = hAsr2Mode;
y = y - 20;
k(end+1) = lbl(['       Recommended for continuous recordings (e.g. resting state), where ' ...
                'artefacts keep arriving. Skip it for ERP data: instead, reject bad'], [40 y 560 18], ...
               'fontangle','italic','fontsize',8);
y = y - 16;
k(end+1) = lbl(['       EPOCHS after epoching, with the plugin''s bad-trial detection (below).'], ...
    [40 y 560 18], 'fontangle','italic','fontsize',8);
y = y - 24;
hVisE = chk('Plot EEG before / after', 1, [40 y 250 22]); k(end+1) = hVisE;
secBox(end+1) = hEEG; secKids{end+1} = k;

% ---- bad-trial detection (epoched data, replaces ASR2 for ERP) ----
y = y - 28; sepline(y+18);
sec('Bad-trial detection (after epoching)', [22 y 260 22]);
bk = gobjects(0);
y = y - 26;
hBtOn = chk('Reject bad epochs after epoching', 0, [40 y 260 22]);
y = y - 24;
bk(end+1) = lbl('Sensitivity:', [40 y 90 20]);
hBtMethod = uicontrol(f,'style','popupmenu','position',[135 y 130 24], ...
    'backgroundcolor',c.btn, 'string',{'conservative (mean)','medium (median)','aggressive (Grubbs)'}, ...
    'value',1, 'tooltipstring', ...
    ['conservative: mean-based outlier criterion, flags the fewest trials (default). ' ...
    'medium: median-based. aggressive: Grubbs outlier test, flags the most.']);
y = y - 20;
bk(end+1) = lbl(['Amplitude and high-frequency-residual outliers across epochs; the same criterion ' ...
    'the study pipeline used (find_badTrials). Runs whenever the dataset is epoched ' ...
    '(Tools > Extract epochs first).'], [40 y 620 30], 'fontangle','italic','fontsize',8);
procKids = [procKids, hBtOn, bk];

% ---- output ----
y = y - 28; sepline(y+18);
sec('Output', [22 y 200 22]);
y = y - 26;
hSave = chk('Save the processed dataset to a .set file when done', 0, [40 y 430 22]);
hSaveFile = uicontrol(f,'style','pushbutton','string','Save as...', ...
    'position',[560 y-2 118 26],'backgroundcolor',c.btn, 'callback',@(~,~) onPickSave());
hSavePath = lbl('', [22 y-24 660 18], 'fontangle','italic','fontsize',8);
S.savePath = '';
procKids = [procKids, hSave, hSaveFile, hSavePath];

% ---- peripheral signals (separate dialog) ----
y = y - 28; sepline(y+18);
sec('Peripheral signals', [22 y 200 22]);
hPeriph = uicontrol(f,'style','pushbutton','string','Set PPG / EDA / EMG / IMU options...', ...
    'position',[150 y 300 26],'backgroundcolor',c.btn,'callback',@(~,~) openPeriph());
procKids(end+1) = hPeriph;
hAuxRate = lbl('detected: -', [460 y 220 20], 'fontangle','italic','fontsize',8);
perOpt = [];   % options returned by the peripheral dialog ([] = untouched)

% ---------- buttons ----------
uicontrol(f,'style','pushbutton','string','Help','position',[22 18 80 30], ...
    'backgroundcolor',c.btn,'callback','pophelp(''pop_galea'');');
uicontrol(f,'style','pushbutton','string','Cancel','position',[W-210 18 85 30], ...
    'backgroundcolor',c.btn,'callback','close(gcbf)');
hRun = uicontrol(f,'style','pushbutton','string','Run','position',[W-115 18 93 30], ...
    'fontweight','bold','backgroundcolor',c.btn,'enable','off','callback',@(~,~) onRun());

toggle();
uiwait(f);

if ~isempty(S.EEG) && S.ok
    EEG = S.EEG;
    com = sprintf('EEG = pop_galea();');
end

% ===================== helpers =====================
    function h = lbl(str, pos, varargin)
        h = uicontrol(f,'style','text','string',str,'position',pos, ...
            'horizontalalignment','left','backgroundcolor',c.back, ...
            'foregroundcolor',c.text, varargin{:});
    end
    function h = edt(str, pos)
        h = uicontrol(f,'style','edit','string',str,'position',pos,'backgroundcolor',c.btn);
    end
    function h = chk(str, val, pos)
        h = uicontrol(f,'style','checkbox','string',str,'value',val,'position',pos, ...
            'backgroundcolor',c.back,'foregroundcolor',c.text);
    end
    function h = box(str, pos)
        % A modality's own on/off switch. Checked by default; toggling it greys
        % out that section only.
        h = uicontrol(f,'style','checkbox','string',str,'value',1,'position',pos, ...
            'backgroundcolor',c.back,'foregroundcolor',c.text, 'callback',@(~,~) toggle());
    end
    function sec(str, pos)
        uicontrol(f,'style','text','string',str,'position',pos,'horizontalalignment','left', ...
            'fontweight','bold','fontsize',10,'backgroundcolor',c.back,'foregroundcolor',c.text);
    end
    function sepline(yy)
        uicontrol(f,'style','frame','position',[22 yy W-44 1], ...
            'foregroundcolor',[.45 .5 .68],'backgroundcolor',[.45 .5 .68]);
    end

    function montageNote()
        if get(hMont,'value') == 1
            set(hMontNote,'string', ...
                ['Default: the 10 stock EEG sites. The two spare ExG channels stay as EMG ' ...
                 'and are kept in EEG.etc.galea.EMG.']);
        else
            set(hMontNote,'string', ...
                ['Custom: ExG channels 7 and 8 (EMG5/EMG6) are treated as EEG at Fp1/Fp2. ' ...
                 'Only pick this if you reconfigured those two disc electrodes as EEG in the ' ...
                 'Galea software when recording - otherwise you are relabelling facial EMG as brain data.']);
        end
    end

    function toggle()
        % Master box gates everything, including the global Trim section.
        % Within it, each modality's own box gates its parameters and its
        % plot option.
        on = logical(get(hDo,'value'));
        set(procKids(isgraphics(procKids)), 'enable', onoff(on));
        for iS = 1:numel(secBox)
            set(secBox(iS), 'enable', onoff(on));
            kk = secKids{iS};
            set(kk(isgraphics(kk)), 'enable', onoff(on && get(secBox(iS),'value')));
        end
    end
    function s = onoff(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end
    function v = asrValue()
        % 0 tells pop_galea_preprocess to skip ASR entirely.
        v = 0;
        if get(hAsrOn,'value'), v = str2double(get(hAsr,'string')); end
    end
    function v = asr2Value()
        % Second, stricter ASR pass after ICA. 0 = skip (default).
        v = 0;
        if get(hAsr2On,'value'), v = str2double(get(hAsr2,'string')); end
    end

    function v = resampleValue()
        % '-' = no file probed yet -> keep (0). Numeric string = target rate.
        s = strtrim(get(hRes,'string'));
        v = str2double(s);
        if ~isfinite(v), v = 0; end
    end

    function onSelect()
        % Start the dialog where the plugin lives, in its sample_data
        % folder: the shipped sample recordings are the natural first pick,
        % and eegplugin_galea.m has already added this folder to the path.
        startFolder = '';
        try
            pluginDir = fileparts(which('eegplugin_galea'));
            if isempty(pluginDir), pluginDir = fileparts(mfilename('fullpath')); end
            cand = fullfile(pluginDir, 'sample_data');
            if isfolder(cand), startFolder = cand; end
        catch
        end
        [fn, fp] = uigetfile({'*.txt','Galea raw files (*.txt)'}, ...
            'Select the main RAW file', startFolder);
        if isequal(fn,0), return; end

        % Check the pair NOW, not at Run: no point letting someone set every
        % parameter before telling them the file was wrong.
        [aux, why] = galea_aux_filename(fn, fp);
        if isempty(aux)
            S.file = ''; set(hRun,'enable','off');
            set(hFile,'string','no valid file selected','foregroundcolor',[.55 .1 .1]);
            warndlg(why, 'Galea');
            return
        end

        S.file = fn; S.path = fp;
        % Two lines: the name wraps instead of being cropped at the right edge.
        set(hFile, 'string', {['selected:  ' fn], ['+ ' aux]}, 'foregroundcolor',c.text);
        set(hFile, 'position', [22 y 660 32]);
        set(hRun,'enable','on');

        % show the detected sampling rates next to the downsample fields, and
        % prefill the EEG downsample box with the detected rate (= keep, since
        % downsampling to the current rate is a no-op)
        try
            rates = galea_probe_rates(fn, fp);
            if isfinite(rates.eeg)
                S.eegRate = rates.eeg;
                set(hEegRate, 'string', sprintf('detected: %g Hz', rates.eeg), ...
                    'foregroundcolor', c.text);
                % The box holds the TARGET rate; start at keep (detected rate).
                set(hRes, 'string', sprintf('%g', rates.eeg), 'tooltipstring', ...
                    sprintf(['Detected EEG rate %g Hz. The box holds the target rate - ' ...
                    'it shows the detected rate (keep) until you pick a division or ' ...
                    'enter a lower value. 0 also keeps.'], rates.eeg));
            end
            if isfinite(rates.ppg)
                set(hAuxRate, 'string', sprintf('detected: %g Hz (EDA/PPG/EMG/IMU)', rates.ppg), ...
                    'foregroundcolor', c.text);
            end
        catch
            % rate probe is a convenience only; never block file selection on it
        end
    end

    function onDiv()
        % Safe downsampling by integer division of the DETECTED rate: 500 ->
        % 250 -> 125, 250 -> 125, etc. The Downsample box always shows the
        % resulting rate, so what you see is what the data will become.
        div = get(hDiv, 'value');          % 1 = keep, 2 = half, 3 = quarter
        r = [];
        try, r = S.eegRate; catch, end
        if isempty(r) || ~isfinite(r)
            % fall back to the label text if the probe never ran
            tok = regexp(get(hEegRate, 'string'), '(?<=detected: )[\d.]+', 'match', 'once');
            if isempty(tok)
                set(hRes, 'string', '0');
                return
            end
            r = str2double(tok{1});
        end
        if div == 1
            set(hRes, 'string', sprintf('%g', r));       % keep: the detected rate
        else
            set(hRes, 'string', sprintf('%g', r / 2^(div-1)));
        end
    end

    function onPickSave()
        % Choose where the processed dataset goes. The .set extension is
        % required by pop_saveset; the path shows under the checkbox.
        [svFile, svPath] = uiputfile({'*.set','EEGLAB dataset (*.set)'}, ...
            'Save processed dataset as', 'galea_processed.set');
        if isequal(svFile,0), return; end
        S.savePath = fullfile(svPath, svFile);
        set(hSavePath, 'string', ['->  ' S.savePath], 'foregroundcolor', c.text);
        set(hSave, 'value', 1);
    end

    function openPeriph()
        % Parameters for the auxiliary streams live in their own dialog, so
        % this window stays readable. Values persist for the session.
        def = struct('ppg',true,'ppglocut',0.5,'ppghicut',3,'rrcorrect','pchip', ...
                     'hrvtime',true,'hrvfreq',true,'hrvnonlin',false,'visppg',true, ...
                     'eda',true,'edalocut',0.01,'edahicut',1,'edaresample',8, ...
                     'edaphasic',false,'viseda',true, ...
                     'emg',true,'emglocut',20,'emgenvelope',true,'visemg',true, ...
                     'imu',true,'imuhicut',10,'imumagnitude',true,'visimu',true);
        if ~isempty(perOpt), def = perOpt; end
        res = galea_periph_gui(def, true);
        if ~isempty(res), perOpt = res; end
    end

    function onRun()
        if isempty(S.file)
            warndlg('Select a file first.','Galea'); return
        end
        montages = {'default','custom'};
        set(f,'pointer','watch'); drawnow

        try
            % via pop_galea_import so the non-EEG streams land in EEG.etc.galea
            D = pop_galea_import('montage', montages{get(hMont,'value')}, ...
                'filename', S.file, 'filepath', S.path);
        catch ME
            set(f,'pointer','arrow');
            errordlg(sprintf('Import failed: %s', ME.message), 'Galea'); return
        end

        % collect the process flag now, then CLOSE the GUI before processing:
        % the IC topographies / trim overview / before-after figures must be
        % interactive, and a modal window left open sits on top of them.
        doProcess = logical(get(hDo,'value'));
        asrModes = get(hAsrMode,'string');
        asr2Modes = get(hAsr2Mode,'string');
        btMethods = get(hBtMethod,'string');
        btNames = {'mean','median','grubbs'};   % popup order -> find_badTrials names
        opt = struct( ...
            'eeg',      logical(get(hEEG,'value')), ...
            'trim',     str2double(get(hTrim,'string')), ...
            'locut',    str2double(get(hLo,'string')), ...
            'hicut',    str2double(get(hHi,'string')), ...
            'resample', resampleValue(), ...
            'causal',   logical(get(hCaus,'value')), ...
            'badchan',  logical(get(hBad,'value')), ...
            'interpchan', logical(get(hInt,'value')), ...
            'mincorr',  str2double(get(hCorr,'string')), ...
            'maxtol',   str2double(get(hMaxTol,'string')) / 100, ...   % % -> fraction
            'asr',      asrValue(), ...
            'asrmode',  asrModes{get(hAsrMode,'value')}, ...
            'ica',      logical(get(hIca,'value')), ...
            'asr2',     asr2Value(), ...
            'asr2mode', asr2Modes{get(hAsr2Mode,'value')}, ...
            'viseeg',   logical(get(hVisE,'value')), ...
            'badtrials', logical(get(hBtOn,'value')), ...
            'badtrialmethod', btNames{get(hBtMethod,'value')});

        % peripheral (PPG/EDA/EMG/IMU) options come from the separate dialog;
        % if the user never opened it, keep the EEG-only defaults (ppg etc.
        % stay at their pop_galea_preprocess defaults, i.e. off).
        perDef = struct('ppg',false,'ppglocut',0.5,'ppghicut',3,'rrcorrect','pchip', ...
                        'hrvtime',true,'hrvfreq',true,'hrvnonlin',false,'visppg',true, ...
                        'eda',false,'edalocut',0.01,'edahicut',1,'edaresample',8, ...
                        'edaphasic',false,'viseda',true, ...
                        'emg',false,'emglocut',20,'emgenvelope',true,'visemg',true, ...
                        'imu',false,'imuhicut',10,'imumagnitude',true,'visimu',true);
        per = perDef;
        if ~isempty(perOpt), per = perOpt; end
        pnames = fieldnames(per);
        for iP = 1:numel(pnames)
            opt.(pnames{iP}) = per.(pnames{iP});
        end

        close(f);   % GUI done; figures raised by processing now stack normally

        if doProcess
            args = [fieldnames(opt), struct2cell(opt)]';
            try
                D = pop_galea_preprocess(D, args{:});
            catch ME
                errordlg(sprintf('Processing failed: %s', ME.message), 'Galea');
                return
            end
        end

        % bad-trial rejection runs on the EPOCHED dataset: if the result is
        % still continuous, tell the user to epoch first (the checkbox is for
        % ERP workflows). find_badTrials needs EEG.data as ch x time x epochs.
        if logical(get(hBtOn,'value')) && doProcess
            if D.trials > 1
                try
                    btMethods = get(hBtMethod,'string'); %#ok<NASGU>
                    bad = find_badTrials(D, btNames{get(hBtMethod,'value')}, false);
                    if ~isempty(bad)
                        fprintf('Removing %g bad epochs (%s criterion).\n', numel(bad), btNames{get(hBtMethod,'value')});
                        D = pop_select(D, 'noepoch', bad);
                    else
                        fprintf('Bad-trial detection: no bad epochs found.\n');
                    end
                catch ME
                    errordlg(sprintf('Bad-trial detection failed: %s', ME.message), 'Galea');
                end
            else
                warndlg({'Bad-trial detection needs an EPOCHED dataset.', ...
                         'Run Tools > Extract epochs first, then re-run this window.'}, 'Galea');
            end
        end

        % optional save, requested in the Output section
        saveIt = logical(get(hSave,'value'));
        if saveIt && isempty(S.savePath)
            % checkbox ticked without picking a file: default next to the data
            try
                S.savePath = fullfile(S.path, [S.file(1:max(1,end-4)) '_processed.set']);
            catch
                S.savePath = fullfile(pwd, 'galea_processed.set');
            end
        end
        if saveIt
            try
                D = pop_saveset(D, 'filename', S.savePath);
                fprintf('Processed dataset saved: %s\n', S.savePath);
            catch ME
                errordlg(sprintf('Save failed: %s', ME.message), 'Galea');
            end
        end

        S.EEG = D; S.ok = true;
    end
end
