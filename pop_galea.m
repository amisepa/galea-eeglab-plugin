%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function [EEG, com] = pop_galea(EEG)
%POP_GALEA  Load and process a Galea recording. One window, top to bottom.
%
%   >> [EEG, com] = pop_galea;
%
% Step 1 loads the recording and picks the montage. Step 2 chooses Continuous
% or ERP data. Step 3 decides whether to preprocess (default yes): pressing
% Run with Yes first imports the file, then opens the preprocessing options
% (EEG, PPG, EDA, EMG, IMU) before any cleaning starts. Continuous mode keeps
% the recording unsegmented and can plot its power spectra; ERP mode segments
% around the file's event markers, rejects bad trials, and plots the condition
% ERPs (20% trimmed mean + SEM) plus the single-trial ERP image.
%
% Cedric Cannard, 2026

if nargin < 1, EEG = []; end
com = '';

c = galea_colors();
S = struct('file','', 'path','', 'EEG',[], 'ok',false, 'savePath','', ...
    'eventsScanned',false);
procOpt = [];                         % option set returned by the parameters dialog ([] = defaults)

W = 860;
scr = get(0,'ScreenSize');
H = 760;                              % fixed, roomy: no cropping anywhere
H = min(H, scr(4) - 80);
f = figure('Name','Galea', 'NumberTitle','off', 'MenuBar','none', 'ToolBar','none', ...
    'Resize','off', 'Color',c.back, 'WindowStyle','modal', ...
    'Position',[(scr(3)-W)/2 max(40,(scr(4)-H)/2) W H]);

RIGHT = 838;                          % right edge shared by the rules and the buttons

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
uicontrol(f,'style','text','string', ...
    'Galea is a headset by OpenBCI (openbci.com), integrated into a Varjo Aero HMD.', ...
    'horizontalalignment','left','fontangle','italic','fontsize',8, ...
    'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'position',[128 H-104 620 22]);

% ---------- 1. load ----------
y = H - 136;
lbl('1.  Load data', [22 y 300 24], 'fontweight','bold','fontsize',11);
y = y - 34;
lbl(['Select the main .txt file only. Its OpenBCI-RAW-Aux-*.txt twin in the same ' ...
     'folder is loaded automatically.'], [22 y 660 22]);
uicontrol(f,'style','pushbutton','string','Select file...', ...
    'position',[RIGHT-140 y-6 140 30], 'backgroundcolor',c.btn,'callback',@(~,~) onSelect());
y = y - 26;
hFile = uicontrol(f,'style','text','string','no file selected','fontangle','italic', ...
    'horizontalalignment','left','backgroundcolor',c.back,'foregroundcolor',[.35 .1 .1], ...
    'position',[22 y RIGHT-22 20]);
y = y - 24;
% progress line for the slow steps (marker scan, import): announcing them is
% the whole point - without it the window just looks frozen.
hStatus = lbl('', [40 y RIGHT-22 20], 'fontangle','italic','fontsize',8);
y = y - 22;
lbl('Montage:', [40 y 70 20]);
hMont = uicontrol(f,'style','popupmenu','position',[120 y-2 340 24],'backgroundcolor',c.btn, ...
    'string',{'default (10 EEG)','custom (12 EEG, Fp1/Fp2 from disc electrodes)'},'value',1, ...
    'tooltipstring', ['Default: ExG 7-8 stay facial EMG. Custom: they become EEG at Fp1/Fp2 - ' ...
    'only if reconfigured as EEG in the Galea software when recording.']);
y = y - 20;
lbl(['Default: ExG 7-8 stay facial EMG.  Custom: they become EEG at Fp1/Fp2 - ' ...
     'only if reconfigured as EEG in the Galea software when recording.'], ...
    [40 y 796 18], 'fontangle','italic','fontsize',8);

% ---------- 2. data type ----------
y = y - 38; sepline(y+11);
sec('2.  Data type', [22 y 200 22]);
y = y - 34;
hCont = uicontrol(f,'style','radiobutton','string','Continuous data (resting state, spectra)', ...
    'value',1,'position',[40 y 420 22], 'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'callback',@(~,~) onCont());
hErp  = uicontrol(f,'style','radiobutton','string','ERP data (segment, clean, average)', ...
    'value',0,'position',[40 y-26 420 22], 'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'callback',@(~,~) onErp());

% ERP-only controls, on their own rows below the radios. Visible only when
% ERP is selected (toggleMode hides them for continuous data).
ek = gobjects(0);
y = y - 60;
ek(end+1) = lbl('Epoch window (s):', [60 y 140 20]);
hEpWin = edt('[-1.5 1.5]', [204 y-2 120 24]);
ek(end+1) = hEpWin;
y = y - 30;
hBtOn = chk('Reject bad trials', 0, [60 y-1 180 22]);
ek(end+1) = hBtOn;
ek(end+1) = lbl('sensitivity:', [250 y 90 20]);
hBtMethod = uicontrol(f,'style','popupmenu','position',[345 y-2 200 24], ...
    'backgroundcolor',c.btn, 'string',{'conservative (mean)','medium (median)','aggressive (Grubbs)'}, ...
    'value',1, 'tooltipstring', ...
    ['conservative: mean-based outlier criterion, flags the fewest trials (default). ' ...
    'medium: median-based. aggressive: Grubbs outlier test, flags the most. ' ...
    'Amplitude and high-frequency-residual outliers across epochs (find_badTrials).']);
ek(end+1) = hBtMethod;
y = y - 30;
ek(end+1) = lbl('Plot condition ERPs:', [60 y 150 20]);
hCond = uicontrol(f,'style','popupmenu','position',[220 y-2 440 24],'backgroundcolor',c.btn, ...
    'string',{'(select a file to list its events)'}, ...
    'tooltipstring','Condition of interest for the ERP plot. The list comes from the markers in the selected file.');
ek(end+1) = hCond;
% NB: "plot EEG before / after cleaning" lives in the parameters dialog
% (galea_process_gui, 'viseeg'). One owner only.

% ---------- 3. preprocess ----------
y = y - 38; sepline(y+11);
sec('3.  Preprocess (Cannard 2026 methods)', [22 y 400 22]);
y = y - 32;
hPreYes = uicontrol(f,'style','radiobutton','string','Yes (recommended)', ...
    'value',1,'position',[40 y 170 22], 'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'callback',@(~,~) onPreYes());
hPreNo  = uicontrol(f,'style','radiobutton','string','No (keep raw)', ...
    'value',0,'position',[220 y 170 22], 'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'callback',@(~,~) onPreNo());
y = y - 26;
lbl('Trim pad (s, 0 = keep all):', [60 y 170 20]);
hTrim = edt('1', [240 y-2 60 24]);
y = y - 26;
% continuous-only rows: the second ASR pass and the spectra plot make no
% sense for ERP data, so they are hidden unless Continuous is selected.
ck = gobjects(0);
ck(end+1) = lbl('2nd ASR pass, threshold (0 = skip):', [60 y 260 20]);
hAsr2 = edt('0', [330 y-2 60 24]);
ck(end+1) = hAsr2;
ck(end+1) = lbl('mode:', [406 y 45 20]);
hAsr2Mode = uicontrol(f,'style','popupmenu','position',[454 y-2 130 24],'backgroundcolor',c.btn, ...
    'string',{'reconstruct','remove'},'value',1, 'tooltipstring', ...
    ['reconstruct: flagged segments are interpolated (default, safest for ' ...
     'continuous data). remove: the segments are deleted.']);
ck(end+1) = hAsr2Mode;
y = y - 24;
hSpectra = uicontrol(f,'style','checkbox', ...
    'string','Plot power spectra of the whole recording (1-70 Hz) at the end', ...
    'value',0,'position',[60 y 520 22],'backgroundcolor',c.back,'foregroundcolor',c.text);
ck(end+1) = hSpectra;
y = y - 26;
hPreNote = lbl(['Pressing Run imports the file, then opens the preprocessing options ' ...
     '(EEG, PPG, EDA, EMG, IMU).'], [40 y 796 22], 'fontangle','italic','fontsize',8);

% ---------- output ----------
y = y - 16; sepline(y);
y = y - 32;
hSave = chk('Save the processed dataset to a .set file when done', 0, [40 y 430 24]);
uicontrol(f,'style','pushbutton','string','Save as...', ...
    'position',[RIGHT-118 y-2 118 26],'backgroundcolor',c.btn, 'callback',@(~,~) onPickSave());
hSavePath = lbl('', [40 y-24 796 22], 'fontangle','italic','fontsize',8);
S.savePath = '';

% ---------- buttons ----------
uicontrol(f,'style','pushbutton','string','Help','position',[22 18 80 30], ...
    'backgroundcolor',c.btn,'callback','pophelp(''pop_galea'');');
uicontrol(f,'style','pushbutton','string','Cancel','position',[RIGHT-198 18 85 30], ...
    'backgroundcolor',c.btn,'callback','close(gcbf)');
hRun = uicontrol(f,'style','pushbutton','string','Run','position',[RIGHT-93 18 93 30], ...
    'fontweight','bold','backgroundcolor',c.btn,'enable','off','callback',@(~,~) onRun());

toggleMode();
gatePre();
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
    function sec(str, pos)
        uicontrol(f,'style','text','string',str,'position',pos,'horizontalalignment','left', ...
            'fontweight','bold','fontsize',10,'backgroundcolor',c.back,'foregroundcolor',c.text);
    end
    function sepline(yy)
        uicontrol(f,'style','frame','position',[22 yy W-44 1], ...
            'foregroundcolor',[.45 .5 .68],'backgroundcolor',[.45 .5 .68]);
    end
    function s = onoff(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end
    function s = onoffstr(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end

    function onCont()
        % radio behaviour is NOT automatic outside a uibuttongroup: clear the
        % sibling explicitly, then re-gate the visible blocks
        set(hErp, 'value', 0);
        toggleMode();
    end

    function onErp()
        set(hCont, 'value', 0);
        toggleMode();
    end

    function toggleMode()
        % Continuous vs ERP: show that side's controls, hide the other side.
        % Selecting ERP needs the marker list (a slow full import), so the
        % scan starts here, the moment ERP is chosen with a file selected.
        cont = logical(get(hCont,'value'));
        set(ek(isgraphics(ek)), 'visible', onoffstr(~cont));   % ERP block: ERP only
        set(ck(isgraphics(ck)), 'visible', onoffstr(cont));    % continuous block only
        if ~cont && ~isempty(S.file) && ~S.eventsScanned
            scanEvents();
        end
        gatePre();
    end

    function onPreYes()
        % radio behaviour is NOT automatic outside a uibuttongroup: clear the
        % sibling explicitly, then re-gate
        set(hPreNo, 'value', 0);
        gatePre();
    end

    function onPreNo()
        set(hPreYes, 'value', 0);
        gatePre();
    end

    function gatePre()
        % These only act when preprocessing runs: grey them out for "No".
        on = logical(get(hPreYes,'value'));
        kids = [hTrim, hAsr2, hAsr2Mode, hSpectra];
        set(kids(isgraphics(kids)), 'enable', onoff(on));
        if on
            set(hPreNote, 'foregroundcolor', c.text);
        else
            set(hPreNote, 'foregroundcolor', c.text * 0.55);   % dimmed
        end
    end

    function v = asr2Value()
        % Second, stricter ASR pass after ICA. 0 = skip (default).
        v = str2double(get(hAsr2,'string'));
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
        set(hFile, 'string', ['selected:  ' fn '    (+ ' aux ')'], 'foregroundcolor',c.text);
        set(hRun,'enable','on');

        % Nothing is imported here: reading a recording takes seconds, so the
        % marker scan is deferred until the ERP condition list needs it (or
        % Run). Reset any list from a previously selected file.
        S.eventsScanned = false;
        set(hStatus,'string','','foregroundcolor',c.text);
        set(hCond,'string',{'(select a file to list its events)'},'value',1);
        if logical(get(hErp,'value'))
            scanEvents();
        end
    end

    function scanEvents()
        % Listing the markers runs a full import (the only way to read them),
        % which is slow on long recordings - so it runs only when the ERP
        % condition list needs it, and says so while it works.
        set(hStatus,'string','Importing data and converting to EEGLAB format...', ...
            'foregroundcolor',c.text);
        drawnow
        try
            ev = galea_list_events(S.file, S.path);
            if isempty(ev)
                set(hCond,'string',{'(no markers in this file)'},'value',1);
                set(hStatus,'string', ...
                    'Data imported successfully into EEGLAB (no event markers found).', ...
                    'foregroundcolor',c.text);
            else
                set(hCond,'string',[{'(none)'}, ev], 'value',1);
                set(hStatus,'string', ...
                    sprintf('Data imported successfully into EEGLAB (%g marker types found).', ...
                    numel(ev)), 'foregroundcolor',c.text);
            end
            S.eventsScanned = true;
        catch
            set(hCond,'string',{'(event list unavailable)'},'value',1);
            set(hStatus,'string','Could not read the event list from this file.', ...
                'foregroundcolor',[.55 .1 .1]);
        end
    end

    function onPickSave()
        [svFile, svPath] = uiputfile({'*.set','EEGLAB dataset (*.set)'}, ...
            'Save processed dataset as', 'galea_processed.set');
        if isequal(svFile,0), return; end
        S.savePath = fullfile(svPath, svFile);
        set(hSavePath, 'string', ['->  ' S.savePath], 'foregroundcolor', c.text);
        set(hSave, 'value', 1);
    end

    function onRun()
        if isempty(S.file)
            warndlg('Select a file first.','Galea'); return
        end
        set(f,'pointer','watch'); drawnow
        set(hStatus,'string','Importing data and converting to EEGLAB format...', ...
            'foregroundcolor',c.text); drawnow

        isErp = logical(get(hErp,'value'));
        doPre = logical(get(hPreYes,'value'));

        % ERP mode needs the marker list (a full import) before the options
        if isErp && ~S.eventsScanned
            scanEvents();
        end

        % ---- import (via pop_galea_import so the non-EEG streams land in
        %      EEG.etc.galea) ----
        % the popup shows long labels; galea_import matches the short keys
        montKeys = {'default', 'custom'};
        montKey = montKeys{get(hMont,'value')};
        try
            D = pop_galea_import('montage', montKey, ...
                'filename', S.file, 'filepath', S.path);
        catch ME
            set(f,'pointer','arrow');
            set(hStatus,'string','Import failed.','foregroundcolor',[.55 .1 .1]);
            errordlg(sprintf('Import failed: %s', ME.message), 'Galea'); return
        end
        set(hStatus,'string','Data imported successfully into EEGLAB.','foregroundcolor',c.text);

        % ---- preprocessing options: pop up after Run, when Yes ----
        opt = struct();
        if doPre
            def = galea_process_defaults();
            if ~isempty(procOpt)
                fn = fieldnames(procOpt);
                for iF = 1:numel(fn), def.(fn{iF}) = procOpt.(fn{iF}); end
            end
            def.montage = montKey;
            def.srate   = D.srate;    % true rate, for the Downsample list
            res = galea_process_gui(def);
            if isempty(res)
                set(f,'pointer','arrow');
                set(hStatus,'string','Cancelled - preprocessing options were closed.', ...
                    'foregroundcolor',[.55 .1 .1]);
                return
            end
            procOpt = res;
            opt = res;
            % keys the dialog carries that pop_galea_preprocess must not see
            for drop = {'srate','montage'}
                if isfield(opt, drop{1}), opt = rmfield(opt, drop{1}); end
            end
        end

        % the main window owns four parameters the dialog never sees: the
        % common trim pad, the 2nd ASR pass and the spectra plot (continuous
        % only), and the ERP options
        opt.trim = str2double(get(hTrim,'string'));
        if ~isfinite(opt.trim) || opt.trim < 0, opt.trim = 3; end
        if isErp
            opt.asr2 = 0;                 % the 2nd pass is a continuous-data step
            opt.asr2mode = 'reconstruct';
        else
            opt.asr2 = asr2Value();
            modes = get(hAsr2Mode,'string');
            opt.asr2mode = modes{get(hAsr2Mode,'value')};
        end
        if isErp
            opt.trimWindow = str2num(get(hEpWin,'string')); %#ok<ST2NM> % e.g. [-1.5 1.5]
            condList = get(hCond,'string');
            if get(hCond,'value') <= 1
                opt.plotConds = {};
            else
                opt.plotConds = condList(get(hCond,'value'));
            end
            S.btOn = logical(get(hBtOn,'value'));
            btNames = {'mean','median','grubbs'};
            S.btMethod = btNames{get(hBtMethod,'value')};
        end

        % flags read before the window closes
        plotSpectra = ~isErp && logical(get(hSpectra,'value'));
        saveIt = logical(get(hSave,'value'));
        if saveIt && isempty(S.savePath)
            try
                S.savePath = fullfile(S.path, [S.file(1:max(1,end-4)) '_processed.set']);
            catch
                S.savePath = fullfile(pwd, 'galea_processed.set');
            end
        end

        % close BEFORE processing: the IC topographies / trim overview /
        % before-after figures must be interactive, and a modal window left
        % open sits on top of them.
        close(f);

        if doPre
            args = [fieldnames(opt), struct2cell(opt)];
            try
                D = pop_galea_preprocess(D, args{:});
            catch ME
                errordlg(sprintf('Processing failed: %s', ME.message), 'Galea');
                return
            end
        end

        % ---- continuous vs ERP ----
        if isErp
            D = galea_erp_workflow(D, opt, S);
        elseif plotSpectra && usejava('desktop')
            try
                figure('Color','w');
                pop_spectopo(D, 1, [], 'EEG', 'freq', [6 10 22], ...
                    'freqrange',[1 70], 'electrodes','off');
                title('Spectra, 1-70 Hz');
            catch ME
                fprintf(2, 'Spectra plot failed: %s\n', ME.message);
            end
        end

        % optional save, requested in the Output section
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