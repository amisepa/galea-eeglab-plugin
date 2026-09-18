%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function [EEG, com] = pop_galea(EEG)
%POP_GALEA  Load and process a Galea recording. One window, top to bottom.
%
%   >> [EEG, com] = pop_galea;
%
% Step 1 loads the recording. Step 2 runs the plugin's processing: the common
% trim, then the per-modality parameters (EEG, PPG, EDA, EMG, IMU - each as
% important as the EEG for some analyses) in a separate dialog, then a
% Continuous / ERP choice. Continuous keeps the recording unsegmented and can
% plot its power spectra; ERP segments around the file's event markers,
% rejects bad trials, and plots the condition ERPs (20% trimmed mean + SEM).
%
% Cedric Cannard, 2026

if nargin < 1, EEG = []; end
com = '';

c = galea_colors();
S = struct('file','', 'path','', 'EEG',[], 'ok',false, 'savePath','', 'eegRate',NaN);

W = 860;
scr = get(0,'ScreenSize');
H = 620;                              % fixed, roomy: no cropping anywhere
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
uicontrol(f,'style','text','string', ...
    'Galea is a headset by OpenBCI (openbci.com), integrated into a Varjo Aero HMD.', ...
    'horizontalalignment','left','fontangle','italic','fontsize',8, ...
    'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'position',[128 H-102 620 18]);

% ---------- 1. load ----------
y = H - 140;
lbl('1.  Load data', [22 y 300 24], 'fontweight','bold','fontsize',11);
y = y - 26;
lbl(['Select the main .txt file only. Its OpenBCI-RAW-Aux-*.txt twin in the same ' ...
     'folder is loaded automatically.'], [22 y 560 32]);

hLoad = uicontrol(f,'style','pushbutton','string','Select file...','position',[620 y+2 140 30], ...
    'backgroundcolor',c.btn,'callback',@(~,~) onSelect());
y = y - 26;
hFile = uicontrol(f,'style','text','string','no file selected','fontangle','italic', ...
    'horizontalalignment','left','backgroundcolor',c.back,'foregroundcolor',[.35 .1 .1], ...
    'position',[22 y 780 20]);

% ---------- 2. process ----------
y = y - 40;
hDo = uicontrol(f,'style','checkbox', ...
    'string','2.  Process using the plugin''s custom methods (see Cannard 2026)', ...
    'value',0,'fontweight','bold','fontsize',11,'position',[22 y 560 24], ...
    'backgroundcolor',c.back,'foregroundcolor',c.text,'callback',@(~,~) toggle());

procKids = gobjects(0);    % everything gated by the "2. Process" master box

% ---- trim (common to every signal) ----
y = y - 32; sepline(y+18);
sec('Trim (all signals)', [22 y 200 22]);
lbl('pad (s):', [250 y+2 45 20]);
hTrim = edt('3',[300 y+2 60 24]); procKids(end+1) = hTrim;
y = y - 26;
lbl(['Data before the first event and after the last event, plus this pad, is removed. ' ...
     'Applies to the EEG and ALL auxiliary signals (PPG, EDA, EMG, IMU). 0 = keep everything.'], ...
    [40 y 760 30], 'fontangle','italic','fontsize',8);

% ---- processing parameters (separate dialog: EEG + other signals) ----
y = y - 30;
hParams = uicontrol(f,'style','pushbutton','string','Preprocessing parameters (EEG, PPG, EDA, EMG, IMU)...', ...
    'position',[40 y 560 28],'backgroundcolor',c.btn,'callback',@(~,~) openParams());
procKids(end+1) = hParams;
hRates = lbl('detected rates: -', [40 y-26 760 20], 'fontangle','italic','fontsize',8);
procKids(end+1) = hRates;
procOpt = [];    % full option set returned by the parameters dialog ([] = defaults)

% ---------- Continuous / ERP ----------
y = y - 64; sepline(y+18);
sec('Data type', [22 y 200 22]);
y = y - 26;
hCont = uicontrol(f,'style','radiobutton','string','Continuous data (resting state, spectra)', ...
    'value',1,'position',[40 y 400 22], 'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'callback',@(~,~) modeNote());
hErp  = uicontrol(f,'style','radiobutton','string','ERP data (segment, clean, average)', ...
    'value',0,'position',[40 y-24 400 22], 'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'callback',@(~,~) toggleMode());
procKids = [procKids, hCont, hErp];

% --- continuous-only controls ---
y = y - 30;
ck = gobjects(0);
lbl('2nd ASR pass, threshold (0 = skip):', [60 y 260 20]);  hAsr2 = edt('0', [330 y+2 60 24]);
ck(end+1) = hAsr2;
lbl('mode:', [400 y 40 20]);
hAsr2Mode = uicontrol(f,'style','popupmenu','position',[440 y 130 24],'backgroundcolor',c.btn, ...
    'string',{'reconstruct','remove'},'value',1, 'tooltipstring', ...
    ['reconstruct: flagged segments are interpolated (default, safest for ' ...
     'continuous data). remove: the segments are deleted.']);
ck(end+1) = hAsr2Mode;
y = y - 26;
hSpectra = uicontrol(f,'style','checkbox', ...
    'string','Plot power spectra of the whole recording (1-70 Hz) at the end', ...
    'value',0,'position',[60 y 480 22],'backgroundcolor',c.back,'foregroundcolor',c.text);
ck(end+1) = hSpectra;

% --- ERP-only controls ---
ek = gobjects(0);
yE = y;
lbl('Epoch window (s):', [60 yE 140 20]);
hEpWin = edt('[-1.5 1.5]', [200 yE 120 24]);
ek(end+1) = hEpWin;
yE = yE - 26;
hBtOn = chk('Reject bad trials', 0, [60 yE 180 22]);
lbl('sensitivity:', [245 yE+2 90 20]);
hBtMethod = uicontrol(f,'style','popupmenu','position',[340 yE 190 24], ...
    'backgroundcolor',c.btn, 'string',{'conservative (mean)','medium (median)','aggressive (Grubbs)'}, ...
    'value',1, 'tooltipstring', ...
    ['conservative: mean-based outlier criterion, flags the fewest trials (default). ' ...
    'medium: median-based. aggressive: Grubbs outlier test, flags the most. ' ...
    'Amplitude and high-frequency-residual outliers across epochs (find_badTrials).']);
ek(end+1) = hBtOn; ek(end+1) = hBtMethod;
yE = yE - 28;
lbl('Plot condition ERPs:', [60 yE 140 20]);
hCond = uicontrol(f,'style','popupmenu','position',[210 yE 440 24],'backgroundcolor',c.btn, ...
    'string',{'(select a file to list its events)'}, 'enable','off', ...
    'tooltipstring','Condition of interest for the ERP plot. The list comes from the markers in the selected file.');
ek(end+1) = hCond;
yE = yE - 26;
hEegPlot = chk('Also plot EEG before / after cleaning', 1, [60 yE 420 22]);
ek(end+1) = hEegPlot;

% ---------- output ----------
y = yE - 24; sepline(y+18);
y = y - 26;
hSave = chk('Save the processed dataset to a .set file when done', 0, [40 y 430 24]);
hSaveFile = uicontrol(f,'style','pushbutton','string','Save as...', ...
    'position',[560 y-2 118 26],'backgroundcolor',c.btn, 'callback',@(~,~) onPickSave());
hSavePath = lbl('', [22 y-22 780 18], 'fontangle','italic','fontsize',8);
S.savePath = '';
procKids = [procKids, hSave, hSaveFile, hSavePath];

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
    function sec(str, pos)
        uicontrol(f,'style','text','string',str,'position',pos,'horizontalalignment','left', ...
            'fontweight','bold','fontsize',10,'backgroundcolor',c.back,'foregroundcolor',c.text);
    end
    function sepline(yy)
        uicontrol(f,'style','frame','position',[22 yy W-44 1], ...
            'foregroundcolor',[.45 .5 .68],'backgroundcolor',[.45 .5 .68]);
    end

    function toggle()
        % Master box gates everything below it.
        on = logical(get(hDo,'value'));
        set(procKids(isgraphics(procKids)), 'enable', onoff(on));
        toggleMode();
    end
    function s = onoff(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end

    function toggleMode()
        % Continuous vs ERP: show that side's controls, grey the other side.
        cont = logical(get(hCont,'value'));
        set(ck(isgraphics(ck)), 'visible', onoffstr(cont));
        set(ek(isgraphics(ek)),  'visible', onoffstr(~cont));
    end
    function s = onoffstr(tf)
        if tf, s = 'on'; else, s = 'off'; end
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

        % Probe the sampling rates; fill the condition list from the markers.
        try
            rates = galea_probe_rates(fn, fp);
            if isfinite(rates.eeg)
                S.eegRate = rates.eeg;
                if ~isempty(procOpt)
                    procOpt.resample = rates.eeg;
                end
            end
            if isfinite(rates.ppg)
                set(hRates, 'string', sprintf(['detected rates:  EEG %g Hz   |   ' ...
                    'PPG/EDA/EMG/IMU %g Hz'], rates.eeg, rates.ppg), 'foregroundcolor', c.text);
            end
        catch
            % rate probe is a convenience only; never block file selection on it
        end
        try
            ev = galea_list_events(fn, fp);
            if ~isempty(ev)
                set(hCond, 'string', [{'(none)'}, ev], 'value', 1);
            else
                set(hCond, 'string', {'(no markers in this file)'}, 'value', 1);
            end
        catch
            set(hCond, 'string', {'(event list unavailable)'}, 'value', 1);
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

    function openParams()
        % All processing parameters (EEG and other signals alike) in one
        % dialog. Values persist for the session. Starts from the current
        % set, then the detected EEG rate.
        def = galea_process_defaults();
        if ~isempty(procOpt)
            fn = fieldnames(procOpt);
            for iF = 1:numel(fn), def.(fn{iF}) = procOpt.(fn{iF}); end
        end
        if isfinite(S.eegRate), def.srate = S.eegRate; end
        res = galea_process_gui(def);
        if ~isempty(res), procOpt = res; end
    end

    function onRun()
        if isempty(S.file)
            warndlg('Select a file first.','Galea'); return
        end
        set(f,'pointer','watch'); drawnow

        % resolve the montage + processing options
        if isempty(procOpt)
            opt = galea_process_defaults();
        else
            opt = procOpt;
        end
        if isfinite(S.eegRate) && opt.resample <= 0, opt.resample = 0; end %#ok<STRNU>

        try
            % via pop_galea_import so the non-EEG streams land in EEG.etc.galea
            D = pop_galea_import('montage', opt.montage, ...
                'filename', S.file, 'filepath', S.path);
        catch ME
            set(f,'pointer','arrow');
            errordlg(sprintf('Import failed: %s', ME.message), 'Galea'); return
        end

        % collect the process flag now, then CLOSE the GUI before processing:
        % the IC topographies / trim overview / before-after figures must be
        % interactive, and a modal window left open sits on top of them.
        doProcess = logical(get(hDo,'value'));
        isErp     = logical(get(hErp,'value'));

        % drop the GUI-only keys, pass the rest to pop_galea_preprocess
        procKeys = opt;
        procKeys = rmfield(procKeys, 'montage');
        if ~isfield(procKeys, 'asr2'),      procKeys.asr2 = 0; end
        if ~isfield(procKeys, 'asr2mode'),  procKeys.asr2mode = 'reconstruct'; end

        close(f);   % GUI done; figures raised by processing now stack normally

        if doProcess
            args = [fieldnames(procKeys), struct2cell(procKeys)]';
            try
                D = pop_galea_preprocess(D, args{:});
            catch ME
                errordlg(sprintf('Processing failed: %s', ME.message), 'Galea');
                return
            end
        end

        % ---- continuous vs ERP ----
        if ~doProcess
            S.EEG = D; S.ok = true; return
        end

        if isErp
            opt.trimWindow = str2num(get(hEpWin,'string')); %#ok<ST2NM> % e.g. [-1.5 1.5]
            condList = get(hCond,'string');
            if logical(get(hCont,'value')) || get(hCond,'value') <= 1
                opt.plotConds = {};
            else
                opt.plotConds = {condList{get(hCond,'value')}};
            end
            S.btOn = logical(get(hBtOn,'value'));
            btList = get(hBtMethod,'string');
            btNames = {'mean','median','grubbs'};
            S.btMethod = btNames{get(hBtMethod,'value')};
            D = galea_erp_workflow(D, opt, S);
        else
            if logical(get(hSpectra,'value')) && usejava('desktop')
                try
                    figure('Color','w');
                    pop_spectopo(D, 1, [], 'EEG', 'freq', [6 10 22], ...
                        'freqrange',[1 70], 'electrodes','off');
                    title('Spectra, 1-70 Hz');
                catch ME
                    fprintf(2, 'Spectra plot failed: %s\n', ME.message);
                end
            end
        end

        % optional save, requested in the Output section
        saveIt = logical(get(hSave,'value'));
        if saveIt && isempty(S.savePath)
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