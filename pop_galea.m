%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function [EEG, com] = pop_galea(EEG)
%POP_GALEA  Load and process a Galea recording.
%
%   >> [EEG, com] = pop_galea;
%
% Step 1 loads the recording and picks the montage. Step 2 chooses
% Continuous or ERP data. Step 3 decides whether to preprocess (default
% yes). With Yes, Next imports the file and opens the processing parameters
% (trim, EEG, the ERP epoching options for ERP data, EOG, PPG, EDA, EMG,
% IMU); Run in that window starts the processing. ERP data are then
% segmented around the file's event markers, bad trials are rejected, and
% the chosen condition is plotted (20% trimmed mean + SEM, and the
% single-trial ERP image). With No, Import loads the raw recording only.
%
% COM holds the equivalent command-line calls (pop_galea_import,
% pop_galea_preprocess, galea_erp_workflow), so the EEGLAB history (eegh)
% replays the session as a script.
%
% Cedric Cannard, 2026

if nargin < 1, EEG = []; end
com = '';

c = galea_colors();
S = struct('file','', 'path','', 'EEG',[], 'ok',false, 'savePath','', 'com','');
procOpt = [];       % parameters set on a previous visit to the parameters window

W = 860;
H = 600;
scr = get(0,'ScreenSize');
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
    catch
    end
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
% progress line for the import, which takes a few seconds: without it the
% window just looks frozen
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
% Only the choice lives here. The ERP options (epoch window, bad trials,
% condition plot) are in the processing parameters window, with the rest of
% the pipeline.
y = y - 38; sepline(y+11);
sec('2.  Data type', [22 y 200 22]);
y = y - 34;
hCont = uicontrol(f,'style','radiobutton','string','Continuous data (resting state, spectra)', ...
    'value',1,'position',[40 y 400 22], 'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'callback',@(~,~) onMode(true));
y = y - 26;
hErp  = uicontrol(f,'style','radiobutton','string','ERP data (segment, clean, average)', ...
    'value',0,'position',[40 y 400 22], 'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'callback',@(~,~) onMode(false));
y = y - 22;
lbl('The ERP options (epoch window, bad trials, condition plot) are set after Next.', ...
    [40 y 796 18], 'fontangle','italic','fontsize',8);

% ---------- 3. preprocess ----------
% Cite the paper the default parameters come from (Cannard & Yesilbas 2026).
% char(351) is the s-cedilla, so the name is right whatever the file encoding.
y = y - 34; sepline(y+11);
sec(['3.  Preprocess (Cannard & Ye' char(351) 'ilba' char(351) ' 2026 methods)'], [22 y 560 22]);
y = y - 32;
hPreYes = uicontrol(f,'style','radiobutton','string','Yes (recommended)', ...
    'value',1,'position',[40 y 170 22], 'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'callback',@(~,~) onPre(true));
hPreNo  = uicontrol(f,'style','radiobutton','string','No (keep raw)', ...
    'value',0,'position',[220 y 170 22], 'backgroundcolor',c.back,'foregroundcolor',c.text, ...
    'callback',@(~,~) onPre(false));
y = y - 26;
hPreNote = lbl('', [40 y 796 18], 'fontangle','italic','fontsize',8);   % text set by gate()

% ---------- output ----------
y = y - 24;
hSave = chk('Save the processed dataset to a .set file when done', 0, [40 y 430 24]);
uicontrol(f,'style','pushbutton','string','Save as...', ...
    'position',[RIGHT-118 y-2 118 26],'backgroundcolor',c.btn,'callback',@(~,~) onPickSave());
hSavePath = lbl('', [40 y-24 796 22], 'fontangle','italic','fontsize',8);

% ---------- buttons ----------
% "Next", not "Run": with preprocessing on, the processing parameters
% window follows, and its Run button starts the processing.
uicontrol(f,'style','pushbutton','string','Help','position',[22 18 80 30], ...
    'backgroundcolor',c.btn,'callback','pophelp(''pop_galea'');');
uicontrol(f,'style','pushbutton','string','Cancel','position',[RIGHT-198 18 85 30], ...
    'backgroundcolor',c.btn,'callback','close(gcbf)');
hNext = uicontrol(f,'style','pushbutton','string','Next','position',[RIGHT-93 18 93 30], ...
    'fontweight','bold','backgroundcolor',c.btn,'enable','off','callback',@(~,~) onNext());

gate();
uiwait(f);

if ~isempty(S.EEG) && S.ok
    EEG = S.EEG;
    com = S.com;
end

% ===================== helpers =====================
    function h = lbl(str, pos, varargin)
        h = uicontrol(f,'style','text','string',str,'position',pos, ...
            'horizontalalignment','left','backgroundcolor',c.back, ...
            'foregroundcolor',c.text, varargin{:});
    end
    function h = chk(str, val, pos)
        h = uicontrol(f,'style','checkbox','string',str,'value',val,'position',pos, ...
            'backgroundcolor',c.back,'foregroundcolor',c.text);
    end
    function h = sec(str, pos)
        h = uicontrol(f,'style','text','string',str,'position',pos,'horizontalalignment','left', ...
            'fontweight','bold','fontsize',10,'backgroundcolor',c.back,'foregroundcolor',c.text);
    end
    function h = sepline(yy)
        h = uicontrol(f,'style','frame','position',[22 yy W-44 1], ...
            'foregroundcolor',[.45 .5 .68],'backgroundcolor',[.45 .5 .68]);
    end

    function onMode(cont)
        % radio behaviour is NOT automatic outside a uibuttongroup: set both
        % explicitly (clicking the selected radio would otherwise untick it)
        set(hCont, 'value', double(cont));
        set(hErp,  'value', double(~cont));
        gate();
    end

    function onPre(yes)
        set(hPreYes, 'value', double(yes));
        set(hPreNo,  'value', double(~yes));
        gate();
    end

    function gate()
        % The button label and the section-3 note follow the choices: Next
        % when the parameters window follows, Import when it does not.
        isErp = logical(get(hErp,'value'));
        if logical(get(hPreYes,'value'))
            set(hNext, 'string', 'Next');
            if isErp
                steps = 'trim, EEG, ERP epoching, EOG, PPG, EDA, EMG, IMU';
            else
                steps = 'trim, EEG, EOG, PPG, EDA, EMG, IMU';
            end
            set(hPreNote, 'string', ['Next imports the file and opens the processing ' ...
                'parameters (' steps ').']);
        else
            set(hNext, 'string', 'Import');
            set(hPreNote, 'string', 'Import loads the raw recording only: no cleaning, no epoching.');
        end
    end

    function onSelect()
        % Start in the plugin's sample_data folder: the shipped sample
        % recordings are the natural first pick.
        startFolder = '';
        pluginDir = fileparts(which('eegplugin_galea'));
        if isempty(pluginDir), pluginDir = fileparts(mfilename('fullpath')); end
        if isfolder(fullfile(pluginDir, 'sample_data'))
            startFolder = fullfile(pluginDir, 'sample_data');
        end
        [fn, fp] = uigetfile({'*.txt','Galea raw files (*.txt)'}, ...
            'Select the main RAW file', startFolder);
        if isequal(fn,0), return; end

        % Check the pair NOW, not at Next: no point letting someone set every
        % parameter before telling them the file was wrong.
        [aux, why] = galea_aux_filename(fn, fp);
        if isempty(aux)
            S.file = ''; set(hNext,'enable','off');
            set(hFile,'string','no valid file selected','foregroundcolor',[.55 .1 .1]);
            warndlg(why, 'Galea', 'modal');     % modal: a plain dialog hides behind this window
            return
        end
        S.file = fn; S.path = fp;
        set(hFile, 'string', ['selected:  ' fn '    (+ ' aux ')'], 'foregroundcolor',c.text);
        set(hStatus, 'string', '');
        set(hNext, 'enable','on');
    end

    function onPickSave()
        [svFile, svPath] = uiputfile({'*.set','EEGLAB dataset (*.set)'}, ...
            'Save processed dataset as', 'galea_processed.set');
        if isequal(svFile,0), return; end
        S.savePath = fullfile(svPath, svFile);
        set(hSavePath, 'string', ['->  ' S.savePath], 'foregroundcolor', c.text);
        set(hSave, 'value', 1);
    end

    function onNext()
        if isempty(S.file)
            warndlg('Select a file first.', 'Galea', 'modal'); return
        end
        isErp = logical(get(hErp,'value'));
        doPre = logical(get(hPreYes,'value'));
        montKeys = {'default', 'custom'};        % the popup shows long labels
        montKey = montKeys{get(hMont,'value')};

        % ---- import (pop_galea_import puts the other signals in EEG.etc.galea) ----
        set(f,'pointer','watch');
        set(hStatus,'string','Importing data and converting to EEGLAB format...', ...
            'foregroundcolor',c.text);
        drawnow
        try
            [D, icom] = pop_galea_import('montage', montKey, 'filename', S.file, 'filepath', S.path);
        catch ME
            set(f,'pointer','arrow');
            set(hStatus,'string','Import failed.','foregroundcolor',[.55 .1 .1]);
            errordlg(sprintf('Import failed: %s', ME.message), 'Galea', 'modal'); return
        end
        set(f,'pointer','arrow');
        set(hStatus,'string', sprintf('Data imported successfully into EEGLAB (%d event markers).', ...
            numel(D.event)), 'foregroundcolor',c.text);

        % ---- processing parameters: the next window ----
        opt = [];
        if doPre
            def = galea_process_defaults();
            if ~isempty(procOpt)                 % reopen with the values last used
                fn = fieldnames(procOpt);
                for iF = 1:numel(fn), def.(fn{iF}) = procOpt.(fn{iF}); end
            end
            def.montage = montKey;
            def.erp     = isErp;
            def.srate   = D.srate;               % true rate, for the Downsample list
            opt = galea_process_gui(def, D);
            if isempty(opt)
                set(hStatus,'string','Cancelled: the processing parameters were closed.', ...
                    'foregroundcolor',[.55 .1 .1]);
                return
            end
            procOpt = opt;
        end

        % flags read before the window closes
        saveIt = logical(get(hSave,'value'));
        if saveIt && isempty(S.savePath)
            [~, base] = fileparts(S.file);
            S.savePath = fullfile(S.path, [base '_processed.set']);
        end

        % Close BEFORE processing: the IC topographies, trim overview and
        % before/after figures must be interactive, and a modal window left
        % open sits on top of them.
        close(f);

        S.com = icom;
        if doPre
            % Name/value pairs. The transpose matters: {:} reads a cell
            % column by column, so an N-by-2 [names values] cell would pass
            % every name first and every value after them.
            args = [fieldnames(opt), struct2cell(opt)]';
            try
                [D, pcom] = pop_galea_preprocess(D, args{:});
            catch ME
                errordlg(sprintf('Processing failed: %s', ME.message), 'Galea');
                return
            end
            S.com = [S.com ' ' pcom];
            if isErp
                [D, ecom] = galea_erp_workflow(D, opt);
                S.com = [S.com ' ' ecom];
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
