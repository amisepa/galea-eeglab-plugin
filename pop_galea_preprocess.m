%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function [EEG, com] = pop_galea_preprocess(EEG, varargin)
% POP_GALEA_PREPROCESS  Clean continuous Galea data (Cannard 2026 methods).
%
% Runs on CONTINUOUS data. For ERP data, pop_galea then segments, rejects bad
% trials and plots the conditions (galea_erp_workflow); tutorial_galea.m shows
% the same route from the command line.
%
% EEG steps, each optional:
%   0. Trim. Drop the data before the first event (minus a pad, default 1 s)
%      and after the last event (plus the same pad). The head and tail of a
%      Galea recording are often full of adjustment artefacts that bias ASR
%      and ICA. Applies to the EEG AND all auxiliary streams (PPG, EDA, EMG,
%      IMU), each at its own sampling rate.
%   1. Downsample.
%   2. Bandpass, minimum-phase CAUSAL by default, which keeps the pre-stimulus
%      period free of post-stimulus leakage (the paper's setting). Set
%      'causal' to false for a zero-phase filter in post-stimulus-only work.
%   3. Polarity check on the two prefrontal disc electrodes, which the Galea
%      amplifier sometimes records with inverted leads. Off by default; turn it
%      on if you are using the custom montage with Fp1/Fp2.
%   4. Bad-channel detection tuned for a sparse dry montage, then interpolation.
%   5. ASR, run leniently so it removes bursts without flattening the data.
%   6. ICA with the ocular component removed, after you confirm which one.
%      Only sensible for EYES-OPEN recordings: the step assumes blinks dominate
%      the variance, which is not true of eyes-closed or resting-state data.
%   7. Optional second, stricter ASR pass AFTER ICA (default threshold 20, off
%      by default) to mop up residual artefacts once the ocular source has been
%      subtracted.
%
% PPG is handled separately, through the BrainBeats plugin.
%
% Usage:
%   >> EEG = pop_galea_preprocess(EEG);        % GUI (processing parameters window)
%   >> EEG = pop_galea_preprocess(EEG, 'asr', 100, 'ica', true);
%
% EEG key/value (defaults in brackets):
%   'trim'     trim around first/last event, seconds (0 = keep); applies to
%              all signals                                [1]
%   'resample' target Hz, 0 = keep                  [0]
%   'locut'    high-pass cutoff, Hz                 [0.5]
%   'hicut'    low-pass cutoff, Hz                  [30]
%   'causal'   minimum-phase causal filter          [true]
%   'polarity' fix Fp1/Fp2 polarity                 [false]
%   'badchan'  detect bad channels                     [true]
%   'mincorr'  correlation threshold (paper=.55, aggressive=.75, medium=.5, lax=.35) [0.55]
%   'maxtol'   max fraction of flagged windows      [0.30]
%   'interpchan' interpolate the detected bad channels [true]
%   'asr'      ASR SD threshold, 0 = skip           [100]
%   'asrmode'  'remove' (the affected segments are deleted, and any event
%              markers that fell inside them are listed in the console) or
%              'reconstruct' (ASR interpolates the bad segments)  ['remove']
%   'ica'      ICA, remove the ocular component     [true]
%   'icaconfirm' ask before removing the component  [true]
%              (command line only; the GUI always asks)
%   'asr2'     second ASR pass after ICA, 0 = skip; the GUI offers it for
%              continuous data only, threshold 10  [0]
%   'asr2mode' 'reconstruct' (default) or 'remove' for the second pass
%   'plotspectra' plot pop_spectopo (1-70 Hz) at the end of EEG cleaning
%              (GUI: continuous data only) [false]
%   'viseeg'   plot the EEG before / after          [true]
%   'badtrials' / 'badtrialmethod' - accepted and ignored here: bad-trial
%              rejection is applied by pop_galea AFTER epoching (find_badTrials).
%%
% EOG key/value (ElectroOculoGraphy - the VEOG/HEOG eye channels):
%   'eog'       filter the EOG and detect blinks    [true]
%   'eoglocut'  EOG high-pass, Hz                   [0.5]
%   'eoghicut'  EOG low-pass, Hz                    [20]
%   'viseog'    plot VEOG with detected blinks + the blink rate [true]
%
% PPG key/value:
%   'ppg'       process PPG with BrainBeats         [true if a PPG stream exists]
%   'ppglocut'  PPG high-pass, Hz                   [0.5]
%   'ppghicut'  PPG low-pass, Hz                    [3]
%   'ppgdetect' pulse-wave detection                ['valleys']
%               'valleys' (default) or 'peaks' - passed to BrainBeats get_RR
%   'rrcorrect' RR artefact interpolation           ['pchip']
%               pchip | linear | spline | makima | nearest | remove
%               (command line only; pchip is the default and the GUI does not
%               expose it - ask for removal first, interpolation second)
%   'hrvtime' / 'hrvfreq' / 'hrvnonlin'  feature sets   [true/true/false]
%   'visppg'    BrainBeats cleaning plot (plot_NN) + the HRV output plots [true]
%
% EDA key/value:
%   'eda'       filter the EDA (0.01-1 Hz)          [false]
%   'edalocut' / 'edahicut'  EDA bandpass, Hz       [0.01 / 1]
%   'edaphasic' cvxEDA tonic/phasic decomposition   [true]
%               (solved at 8 Hz - inside the 4-10 Hz band the literature
%               finds useful for EDA deconvolution; no user-facing
%               downsample option)
%   'viscvx'    plot the tonic/phasic decomposition on one time-course [true]
%   'viseda'    plot the EDA raw vs processed       [true]
%
% EMG key/value (facial EMG on the Galea disc electrodes; the Aux stream is
% only ~50 Hz, so this is a coarse activity index, not a conventional EMG):
%   'emg'         filter the EMG (high-pass)        [false]
%   'emglocut'    EMG high-pass, Hz                 [20]
%   'emghicut'    EMG low-pass, Hz, 0 = none        [0]
%   'emgenvelope' rectify + 100 ms moving-average envelope [true]
%   'visemg'      plot the EMG (+ envelope when computed)  [true]
%
% IMU key/value (inertial measurement unit - head motion):
%   'imu'          filter the IMU (low-pass)        [false]
%   'imuhicut'     IMU low-pass, Hz                 [10]
%   'imumagnitude' add the ACC_MAG channel: the magnitude of the 3 acceleration
%                  axes, i.e. a single orientation-independent HEAD-MOTION
%                  METRIC (deviations from 1 g = movement)  [true]
%   'visimu'       plot all IMU channels incl. ACC_MAG [true]
%
% Cedric Cannard, 2026

com = '';
if nargin < 1, help pop_galea_preprocess; return; end

% 'eeglab nogui' puts the plugin folder on the path but not functions/
% (only the menu registration in eegplugin_galea adds it), so scripts need this.
if ~exist('galea_import', 'file')
    addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));
end

hasPPG = isfield(EEG.etc,'galea') && isfield(EEG.etc.galea,'PPG') && ...
         ~isempty(EEG.etc.galea.PPG) && EEG.etc.galea.PPG.nbchan > 0;
hasEvents = ~isempty(EEG.event);

g = struct('eeg',true, 'trim',1, 'resample',0, 'locut',0.5, 'hicut',30, 'causal',true, ...
           'polarity',false, 'badchan',true, 'mincorr',0.55, 'maxtol',0.30, 'interpchan',true, ...
           'asr',100, 'asrmode','remove', 'ica',true, 'icaconfirm',true, 'asr2',0, 'asr2mode','reconstruct', ...
           'plotspectra',false, 'viseeg',true, ...
           'eog',true, 'eoglocut',0.5, 'eoghicut',20, 'viseog',true, ...
           'ppg',hasPPG, 'ppglocut',0.5, 'ppghicut',3, 'ppgdetect','valleys', ...
           'rrcorrect','pchip', ...   % BrainBeats RR interpolation; pchip by default, command line only
           'hrvtime',true, 'hrvfreq',true, 'hrvnonlin',false, 'visppg',true, ...
           'eda',false, 'edalocut',0.01, 'edahicut',1, ...
           'edaphasic',true, 'viscvx',true, 'viseda',true, ...
           'emg',false, 'emglocut',20, 'emghicut',0, 'emgenvelope',true, 'visemg',true, ...
           'imu',false, 'imuhicut',10, 'imumagnitude',true, 'visimu',true);

% Keys the parameters window carries that are not used here: its own flags
% and the ERP options (galea_erp_workflow reads those). Accepted and ignored.
guiOnly = {'srate','montage','erp','preprocess','epochwin','epochevents','erpevents', ...
           'rejtrials','rejmethod','plotconds','trimwindow'};
if nargin > 1
    for i = 1:2:numel(varargin)
        if ~ischar(varargin{i})
            error(['Options are name/value pairs: argument %d should be an option ' ...
                   'name but is a %s.'], i + 1, class(varargin{i}));
        end
        key = lower(varargin{i});
        if any(strcmp(key, guiOnly)), continue; end
        g.(key) = varargin{i+1};
    end
else
    % GUI: the same processing-parameters window pop_galea opens
    def = galea_process_defaults();
    def.srate = EEG.srate;                  % true rate, for the Downsample list
    if isfield(EEG.etc,'galea') && isfield(EEG.etc.galea,'montage')
        def.montage = EEG.etc.galea.montage;
    end
    res = galea_process_gui(def, EEG);
    if isempty(res), return; end            % cancelled
    fn = fieldnames(res);
    for i = 1:numel(fn)
        if ~any(strcmp(lower(fn{i}), guiOnly)), g.(lower(fn{i})) = res.(fn{i}); end
    end
end

oriEEG = EEG;

% ---- 0. trim head/tail around the first and last event (ALL signals) ----
% The EEG and every auxiliary stream are cut to the same time span, each at
% its own sampling rate. Done first so ASR and ICA never see the artefact-
% filled head and tail of the recording.
if g.trim > 0 && hasEvents
    lat = [EEG.event.latency];
    pad = round(g.trim * EEG.srate);
    lo = max(1, min(lat) - pad);
    hi = min(EEG.pnts, max(lat) + pad);
    if lo > 1 || hi < EEG.pnts
        fprintf('Trimming EEG to samples %d-%d (first/last event +- %g s)...\n', lo, hi, g.trim);
        before = EEG.pnts;
        EEG = pop_select(EEG, 'point', [lo hi]);
        fprintf('  removed %.1f s (%.1f%% of the recording).\n', ...
            (before - EEG.pnts)/EEG.srate, 100*(before - EEG.pnts)/before);
        % same span, in seconds, for the auxiliary streams
        t0 = (lo - 1) / EEG.srate;
        t1 = (hi - 1) / EEG.srate;
        for auxName = {'PPG','EDA','EMG','IMU'}
            an = auxName{1};
            if isfield(EEG.etc,'galea') && isfield(EEG.etc.galea, an) && ...
                    ~isempty(EEG.etc.galea.(an)) && EEG.etc.galea.(an).nbchan > 0
                A = EEG.etc.galea.(an);
                alo = max(1, round(t0 * A.srate) + 1);
                ahi = min(A.pnts, round(t1 * A.srate) + 1);
                if alo > 1 || ahi < A.pnts
                    beforeA = A.pnts;
                    A = pop_select(A, 'point', [alo ahi]);
                    fprintf('  trimmed %s: %d -> %d samples\n', an, beforeA, A.pnts);
                    EEG.etc.galea.(an) = A;
                end
            end
        end
        % overview figure: what was removed (oriEEG still holds the untrimmed data)
        galea_show_trim(oriEEG, EEG, g.trim);
    end
end

badChan = [];      % stay empty when the EEG steps are skipped ('eeg', false)
icaInfo = [];
if g.eeg
% ---- 1. downsample ----
if g.resample > 0 && g.resample ~= EEG.srate
    fprintf('Resampling %g -> %g Hz...\n', EEG.srate, g.resample);
    EEG = pop_resample(EEG, g.resample);
end

% ---- 2. filter ----
if g.causal, filt = 'minimum-phase causal'; else, filt = 'zero-phase'; end
fprintf('Filtering %.2f-%.2f Hz (%s)...\n', g.locut, g.hicut, filt);
EEG = pop_eegfiltnew(EEG, 'hicutoff', g.hicut, 'minphase', g.causal);
EEG = pop_eegfiltnew(EEG, 'locutoff', g.locut, 'minphase', g.causal);

% ---- 3. prefrontal polarity ----
if g.polarity
    labs = {EEG.chanlocs.labels};
    suspect = labs(ismember(lower(labs), {'fp1','fp2'}));
    if ~isempty(suspect)
        EEG = fix_polarity(EEG, suspect, 8, 0.5);
    else
        warning('No Fp1/Fp2 channels found; skipping polarity correction.');
    end
end

% ---- 4. bad channels ----
badChan = [];
if g.badchan
    badChan = flag_bad_eeg_channels_window(EEG.data, EEG.srate, g.mincorr, 0.2, g.maxtol);
    if any(badChan)
        fprintf('Bad channels (correlation threshold %.2f): %s\n', g.mincorr, ...
            strjoin({EEG.chanlocs(badChan).labels}, ', '));
        if g.interpchan
            EEG = pop_select(EEG, 'nochannel', find(badChan));
            EEG = pop_interp(EEG, oriEEG.chanlocs, 'spherical');
            fprintf('  bad channels removed and interpolated.\n');
        else
            fprintf('  flagged only (interpolation is a separate option); continuing with them.\n');
            badChan = [];
        end
    else
        fprintf('No bad channels detected.\n');
    end
end

% Reference for the final before/after: the state going INTO artefact removal.
preClean = EEG;

% ---- 5. ASR ----
% clean_asr always RECONSTRUCTS (interpolates) the segments it flags. Two
% modes here:
%   'reconstruct' - keep the ASR output as is (pipeline convention);
%   'remove'      - compute the affected-sample mask, delete those segments
%                   entirely (same convention as galea_pipeline_v6_EEG.m:
%                   pop_select 'nopoint' + drop segments <= 5 samples), and
%                   report which event markers fell inside them.
if g.asr > 0
    fprintf('ASR (threshold %g, mode %s)...\n', g.asr, g.asrmode);
    before = EEG.pnts;
    cleanEEG = clean_asr(EEG, g.asr, [], [], [], [], [], [], [], false, []);
    if strcmpi(g.asrmode, 'remove')
        mask = sum(abs(EEG.data - cleanEEG.data), 1) > 1e-10;
        pct  = 100 * mean(mask);
        fprintf('  %.2f%% of samples flagged by ASR; removing those segments.\n', pct);
        % segment list, small gaps <= 5 samples merged away (pipeline convention)
        badData = reshape(find(diff([false mask false])), 2, [])';
        badData(:,2) = badData(:,2) - 1;
        badData(diff(badData,[],2) <= 5, :) = [];
        % which event markers fall inside the removed segments?
        if ~isempty(EEG.event) && ~isempty(badData)
            lat = [EEG.event.latency];
            inBad = false(size(lat));
            for iSeg = 1:size(badData,1)
                inBad = inBad | (lat >= badData(iSeg,1) & lat <= badData(iSeg,2));
            end
            if any(inBad)
                dropped = EEG.event(inBad);
                fprintf('  WARNING: %d event marker(s) inside removed segments:\n', sum(inBad));
                for iE = 1:sum(inBad)
                    fprintf('    t=%.2f s  type=%s\n', ...
                        (dropped(iE).latency-1)/EEG.srate, dropped(iE).type);
                end
                EEG.etc.galea_asr_dropped_events = ...
                    struct('type',{{dropped.type}}, 'latency',[dropped.latency]);
            end
        end
        if ~isempty(badData)
            EEG = pop_select(EEG, 'nopoint', badData);
        end
        fprintf('  %.1f%% of the recording removed (%.1f s).\n', ...
            100*(1 - EEG.pnts/before), (before - EEG.pnts)/EEG.srate);
    else
        EEG = cleanEEG;
        fprintf('  %.2f%% of samples reconstructed.\n', 100*(1 - EEG.pnts/before));
    end
end

% ---- 6. ICA ----
icaInfo = [];
if g.ica
    [EEG, icaInfo] = galea_remove_ocular_ic(EEG, g.icaconfirm);
end

% ---- 7. optional second, stricter ASR pass after ICA ----
% After the ocular source is subtracted, a stricter pass can safely remove
% smaller residual artefacts that the lenient pre-ICA pass deliberately left
% alone. Off by default.
if g.asr2 > 0
    fprintf('Second ASR pass (threshold %g, mode %s), after ICA...\n', g.asr2, g.asr2mode);
    before = EEG.pnts;
    cleanEEG = clean_asr(EEG, g.asr2, [], [], [], [], [], [], [], false, []);
    if strcmpi(g.asr2mode, 'remove')
        mask = sum(abs(EEG.data - cleanEEG.data), 1) > 1e-10;
        pct  = 100 * mean(mask);
        fprintf('  %.2f%% of samples flagged; removing those segments.\n', pct);
        badData = reshape(find(diff([false mask false])), 2, [])';
        badData(:,2) = badData(:,2) - 1;
        badData(diff(badData,[],2) <= 5, :) = [];
        if ~isempty(EEG.event) && ~isempty(badData)
            lat = [EEG.event.latency];
            inBad = false(size(lat));
            for iSeg = 1:size(badData,1)
                inBad = inBad | (lat >= badData(iSeg,1) & lat <= badData(iSeg,2));
            end
            if any(inBad)
                dropped = EEG.event(inBad);
                fprintf('  WARNING: %d event marker(s) inside removed segments:\n', sum(inBad));
                for iE = 1:sum(inBad)
                    fprintf('    t=%.2f s  type=%s\n', ...
                        (dropped(iE).latency-1)/EEG.srate, dropped(iE).type);
                end
                EEG.etc.galea_asr_dropped_events = ...
                    struct('type',{{dropped.type}}, 'latency',[dropped.latency]);
            end
        end
        if ~isempty(badData)
            EEG = pop_select(EEG, 'nopoint', badData);
        end
        fprintf('  %.1f%% of the recording removed (%.1f s).\n', ...
            100*(1 - EEG.pnts/before), (before - EEG.pnts)/EEG.srate);
    else
        EEG = cleanEEG;
        fprintf('  %.2f%% of samples reconstructed.\n', 100*(1 - EEG.pnts/before));
    end
end

% ---- optional power-spectra plot of the whole recording ----
if g.plotspectra && usejava('desktop')
    try
        figure('Color','w');
        pop_spectopo(EEG, 1, [], 'EEG', 'freq', [6 10 22], ...
            'freqrange',[1 70], 'electrodes','off');
        title('Spectra, 1-70 Hz');
    catch ME
        fprintf(2, 'Spectra plot failed: %s\n', ME.message);
    end
end

% ---- before / after ----
if g.viseeg && (g.asr > 0 || g.ica || g.asr2 > 0)
    % vis_artifacts overlays the two datasets, so it needs identical sample
    % counts; ASR in 'remove' mode shortens the data, then fall back to the
    % plain scrolling plot of the cleaned data.
    if exist('vis_artifacts','file') && EEG.pnts == preClean.pnts
        vis_artifacts(EEG, preClean);
        set(gcf, 'Name', 'Before (red) vs after ASR + ICA (blue)');
    else
        pop_eegplot(EEG, 1, 1, 1);
        galea_eegplot_yscale(100);
    end
end

end  % if g.eeg

% ---- other modalities, one at a time ----
if g.eog, EEG = galea_process_eog(EEG, g); end
if g.ppg, EEG = galea_process_ppg(EEG, g); end
if g.eda, EEG = galea_process_eda(EEG, g); end
if g.emg, EEG = galea_process_stream(EEG, 'EMG', g); end
if g.imu, EEG = galea_process_stream(EEG, 'IMU', g); end

EEG.etc.galea_preprocess = g;
EEG.etc.galea_preprocess.badChan = badChan;
EEG.etc.galea_preprocess.ica = icaInfo;
EEG = eeg_checkset(EEG);

% Every option, so the EEGLAB history (eegh) replays exactly what ran,
% including the EOG, PPG, EDA, EMG and IMU settings.
args = [fieldnames(g), struct2cell(g)]';
com = sprintf('EEG = pop_galea_preprocess(EEG, %s);', vararg2str(args(:)'));

end

% ===========================================================================
function [EEG, info] = galea_remove_ocular_ic(EEG, confirm)
% ICA on a 1 Hz high-passed copy (ICA does poorly below 1 Hz), weights
% transferred back.
%
% IMPORTANT: this ASSUMES the first component is ocular. That has held on every
% Galea recording we have looked at, because blinks dominate the variance on
% this montage, but it is an assumption and not a classification: with 10-12 dry
% channels ICLabel is not reliable enough to decide. So the components are
% plotted and the user is asked to confirm before anything is subtracted.
%
% It also assumes an EYES-OPEN task. In eyes-closed or resting-state recordings
% there are few or no blinks, so IC1 will be something else entirely - most
% likely alpha - and removing it would delete real brain activity. Skip the ICA
% step for those, or pick the component by hand.

fprintf('ICA...\n');
TMP = pop_eegfiltnew(EEG, 'locutoff', 1);
dataRank = sum(eig(cov(double(TMP.data'))) > 1e-7);
TMP = pop_runica(TMP, 'icatype', 'picard', 'mode', 'standard', 'pca', dataRank);

EEG.icaweights  = TMP.icaweights;
EEG.icasphere   = TMP.icasphere;
EEG.icawinv     = TMP.icawinv;
EEG.icachansind = TMP.icachansind;
EEG = eeg_checkset(EEG);

badComp = 1;
if confirm && usejava('desktop')
    EEG.reject.gcompreject = false(1, dataRank);
    EEG.reject.gcompreject(1) = true;

    pop_selectcomps(EEG, 1:dataRank);          % topographies, IC1 flagged
    set(gcf, 'Name', 'Component topographies - IC1 is the proposed ocular one');
    pop_eegplot(EEG, 0, 1, 1);                 % component time series
    galea_eegplot_yscale(100);                 % default vertical scale 100 uV
    set(gcf, 'Name', 'Component time series - check IC1 for blinks');
    drawnow

    % user can flag components in the pop_selectcomps window (click to flag);
    % whatever is flagged there prefills the edit box (default: IC1)
    fl = find([EEG.reject.gcompreject]);
    if isempty(fl), fl = 1; EEG.reject.gcompreject(1) = true; end
    prefill = strtrim(sprintf('%d ', fl));

    uilist = { ...
        {'style','text','string', ...
         ['The plugin assumes IC1 is the ocular component. That has been reliable on ' ...
          'this montage, but it is an assumption: with 10-12 dry channels automatic ' ...
          'classification is not trustworthy.']} ...
        {'style','text','string', ...
         ['This only holds for EYES-OPEN tasks, where blinks dominate the variance. ' ...
          'In eyes-closed or resting-state data IC1 is likely alpha, not an artefact - ' ...
          'removing it would delete real brain activity. Leave the box blank to keep ' ...
          'everything.'], 'foregroundcolor',[0.6 0 0]} ...
        {'style','text','string', ...
         ['Check the two figures. A blink component looks frontal in the topography and ' ...
          'shows slow, large deflections in the time series. You can flag any number of ' ...
          'components in the topography window (click); they appear below.']} ...
        {} ...
        {'style','text','string','Component(s) to remove (blank = none):'} ...
        {'style','edit','string',prefill} };
    [res, ~, ~, o] = inputgui('geometry', {1 1 1 1 [3 1]}, 'geomvert', [3 3 2 1 1], ...
        'uilist', uilist, 'title', 'Confirm ocular component');
    if isempty(res)
        fprintf('  cancelled: no component removed.\n');
        info = struct('dataRank', dataRank, 'removed', []);
        return
    end
    % inputgui's output shape differs between EEGLAB versions (the 4th output is
    % a cell here but has been numeric/char elsewhere), so read the edit-box
    % text defensively instead of brace-indexing whatever came back.
    txtVal = [];
    if iscell(res) && ~isempty(res)
        txtVal = res{end};
    elseif ischar(res)
        txtVal = res;
    elseif iscell(o) && ~isempty(o)
        txtVal = o{1};
    elseif isnumeric(o) || islogical(o)
        txtVal = o;
    end
    if isnumeric(txtVal)
        badComp = txtVal;
        if isscalar(badComp) && badComp == 0, badComp = []; end %#ok<SCAL>
    else
        txtVal = strtrim(char(txtVal));
        if isempty(txtVal)
            badComp = [];
        else
            badComp = str2num(txtVal); %#ok<ST2NM>
            if isempty(badComp) || any(~isfinite(badComp))
                warning('Could not read the component list "%s"; no component removed.', txtVal);
                badComp = [];
            end
        end
    end
    if isnumeric(badComp) && isscalar(badComp)
        badComp = double(badComp);
    end
end

if isempty(badComp)
    fprintf('  no component removed.\n');
else
    fprintf('  removing IC%s.\n', mat2str(badComp));
    EEG = pop_subcomp(EEG, badComp, 0);
end
info = struct('dataRank', dataRank, 'removed', badComp);
end

% ---------------------------------------------------------------------------
function EEG = galea_process_ppg(EEG, g)
% Filter the PPG, then hand it to BrainBeats for beat detection and HRV.

if ~isfield(EEG.etc,'galea') || ~isfield(EEG.etc.galea,'PPG') || isempty(EEG.etc.galea.PPG)
    warning('No PPG stream in EEG.etc.galea; skipping.');
    return
end

if ~exist('brainbeats_process','file')
    % find it on disk, install it on the fly, or give up with clear guidance
    if ~galea_ensure_brainbeats(), return; end
end

PPG = EEG.etc.galea.PPG;
fprintf('PPG: %d channel(s) @ %g Hz, bandpass %.2f-%.2f Hz\n', ...
    PPG.nbchan, PPG.srate, g.ppglocut, g.ppghicut);
PPG = pop_eegfiltnew(PPG, 'locutoff', g.ppglocut, 'hicutoff', g.ppghicut, 'minphase', true);

feats = {};
if g.hrvtime,   feats{end+1} = 'time';      end
if g.hrvfreq,   feats{end+1} = 'frequency'; end
if g.hrvnonlin, feats{end+1} = 'nonlinear'; end

try
    PPG = brainbeats_process(PPG, 'analysis','features', ...
        'heart_signal','ppg', 'heart_channels',{PPG.chanlocs.labels}, ...
        'eeg', false, ...                          % heart only (else BrainBeats asks for EEG coordinates and returns no HRV)
        'clean_eeg', 0, ...                        % EEG is cleaned above, not here
        'ppg_detect_mode', g.ppgdetect, ...        % pulse-wave valleys (default) or peaks
        'rr_correct', g.rrcorrect, ...
        'hrv_features', feats, ...
        'vis_cleaning', double(g.visppg), 'vis_outputs', double(g.visppg), ...
        'save', 0);
    EEG.etc.galea.PPG = PPG;
    if isfield(PPG.etc,'features')
        EEG.etc.galea.HRV = PPG.etc.features;
        fprintf('  HRV features stored in EEG.etc.galea.HRV\n');
    end
    % BrainBeats already drew plot_NN (signal + detected/corrected beats +
    % NN series) above when vis_cleaning was on; add our richer HRV figure.
    if g.visppg && isfield(EEG.etc.galea,'HRV') && ~isempty(EEG.etc.galea.HRV)
        galea_plot_hrv(EEG.etc.galea.HRV, PPG);
    end
catch ME
    warning('BrainBeats failed: %s', ME.message);
end
end

% ---------------------------------------------------------------------------
function EEG = galea_process_eog(EEG, g)
% ElectroOculoGraphy: the VEOG (vertical, blinks) and HEOG (horizontal,
% saccades) channels recorded on the headset rim. Filter them in an eye band,
% then detect blinks on VEOG with an amplitude + duration criterion - the
% same approach as the analysis pipeline (galea_pipeline_v5_EOG.m). The blink
% count and rate are the standard EOG output metrics; the figure shows VEOG
% with the detected blinks marked.

if ~isfield(EEG.etc,'galea') || ~isfield(EEG.etc.galea,'EOG') || ...
        isempty(EEG.etc.galea.EOG) || EEG.etc.galea.EOG.nbchan == 0
    disp('No EOG stream in this recording; skipping.');
    return
end

D = EEG.etc.galea.EOG;
fprintf('EOG: %.2f-%.2f Hz (min-phase causal), blink detection on VEOG\n', ...
    g.eoglocut, g.eoghicut);
D = pop_eegfiltnew(D, 'locutoff', g.eoglocut, 'hicutoff', g.eoghicut, 'minphase', true);
EEG.etc.galea.EOG = D;

% ---- blink detection on VEOG (amplitude threshold + plausible duration) ----
labs = lower({D.chanlocs.labels});
vIdx = find(strcmp(labs, 'veog'));
if isempty(vIdx)
    % tolerant match: anything starting with 'v' + eog
    vIdx = find(strncmp(labs, 'veog', 4));
end
if isempty(vIdx)
    warning('No VEOG channel found; blink detection skipped.');
    return
end
veog = double(D.data(vIdx(1),:));

blinkThreshUv  = 100;   % uV; Galea VEOG blinks are far larger than this
blinkMinDur_ms = 50;
blinkMaxDur_ms = 400;

above     = abs(veog) > blinkThreshUv;
on        = find(diff([false above]) == 1);
off       = find(diff([above false]) == -1);
nSamp     = min(numel(on), numel(off));
dur       = (off(1:nSamp) - on(1:nSamp) + 1) / D.srate * 1000;   % ms
keep      = dur >= blinkMinDur_ms & dur <= blinkMaxDur_ms;
blinkOns  = on(keep);

nBlinks   = numel(blinkOns);
ratePerMin = nBlinks / max(D.xmax/60, eps);
fprintf('  blinks detected on VEOG: %d (%.1f / min)\n', nBlinks, ratePerMin);
EEG.etc.galea.EOG.etc.blinks_n    = nBlinks;
EEG.etc.galea.EOG.etc.blinks_rate = ratePerMin;
EEG.etc.galea.EOG.etc.blinks_samp = blinkOns;
EEG.etc.galea.EOG.etc.blink_thresh_uV = blinkThreshUv;

if g.viseog
    galea_plot_eog(EEG.etc.galea.EOG);
end
end

% ---------------------------------------------------------------------------
function EEG = galea_process_eda(EEG, g)
% ElectroDermal Activity (skin conductance). Bandpass 0.01-1 Hz as in the
% analysis pipeline, then optionally the cvxEDA tonic/phasic decomposition.
%
% cvxEDA is solved on a fixed 8 Hz copy of the signal. Literature check
% (2026-09-21): Greco et al. 2015 (the cvxEDA paper) fixes no rate - the
% model's information content is far below that (tonic spectrum < 0.05 Hz,
% knots every 10 s; SCR rise times ~1 s). Benchmarks (Ait-Ouarab et al. 2016,
% compressed-sensing decomposition paper; Mahdiani 2015; Ledalab docs) put
% the useful range at 4-10 Hz: 4 Hz captures SCR timing, 8-10 Hz is the
% ceiling where decomposition quality stops improving. 8 Hz sits in that
% band, matches the Empatica-class wearables, and keeps the solver fast.
% The filtered full-rate signal is what gets stored back; only the
% decomposition runs on the 8 Hz copy.

if ~isfield(EEG.etc,'galea') || ~isfield(EEG.etc.galea,'EDA') || ...
        isempty(EEG.etc.galea.EDA) || EEG.etc.galea.EDA.nbchan == 0
    disp('No EDA stream in this recording; skipping.');
    return
end

D = EEG.etc.galea.EDA;
raw = D;
fprintf('EDA: %.3f-%.2f Hz\n', g.edalocut, g.edahicut);
D = pop_eegfiltnew(D, 'hicutoff', g.edahicut);
D = pop_eegfiltnew(D, 'locutoff', g.edalocut);

if g.edaphasic
    if ~exist('cvxEDA','file')
        p = fileparts(mfilename('fullpath'));
        addpath(fullfile(p, 'functions'));
    end
    if ~exist('cvxEDA','file')
        warning('cvxEDA not on the path (functions/cvxEDA.m); tonic/phasic skipped.');
    else
        fprintf('cvxEDA tonic/phasic decomposition (at 8 Hz)...\n');
        E8 = pop_resample(D, 8);
        y  = zscore(double(E8.data(1,:))');      % cvxEDA expects a normalised column
        delta = 1 / E8.srate;
        % Tuned on the study recordings (galea_pipeline_v5_eda.m):
        % tau0=2, tau1=0.7, knots every 10 s, alpha=5e-3, gamma=0.01,
        % quadprog, linear baseline correction.
        [r, p_, t, ~, ~, e] = cvxEDA(y, delta, 2, 0.7, 10, 5e-3, 0.01, [], 2);
        % store back on the 8 Hz time base, and resample the components onto
        % the full-rate time base so both views line up
        E8.etc.eda_phasic = r';
        E8.etc.eda_tonic  = t';
        E8.etc.eda_driver = p_';                  % sparse SMNA driver
        E8.etc.eda_resid  = e';
        E8.etc.eda_full_rate = false;
        D.etc.eda_phasic = resample(r', D.srate, E8.srate);
        D.etc.eda_tonic  = resample(t', D.srate, E8.srate);
        D.etc.eda_resample_hz = 8;
        disp('  tonic and phasic stored in .etc.eda_tonic / .etc.eda_phasic (8 Hz)');
        if g.viscvx && usejava('desktop')
            galea_plot_eda(E8);
        end
    end
end

EEG.etc.galea.EDA = D;

if g.viseda && usejava('desktop')
    figure('Color','w','Name','EDA - raw (grey) vs processed');
    tt = (0:D.pnts-1) / D.srate;
    tr = (0:raw.pnts-1) / raw.srate;
    subplot(2,1,1); hold on
    plot(tr, raw.data(1,:), 'Color',[.65 .65 .65], 'LineWidth',0.8, 'DisplayName','raw');
    plot(tt, D.data(1,:), 'Color',[0.85 0.33 0.10], 'LineWidth',1.4, 'DisplayName','processed');
    legend('Location','best', 'FontSize',9, 'Box','off');
    ylabel('EDA', 'FontWeight','bold', 'FontSize',11);
    set(gca,'FontSize',10, 'FontWeight','bold', 'Box','on', 'TickDir','out', 'Layer','top');
    title('Skin conductance, raw vs processed');
    if isfield(D.etc,'eda_phasic')
        subplot(2,1,2); hold on
        t8 = (0:size(D.etc.eda_tonic,2)-1) / D.srate;
        plot(t8, D.etc.eda_tonic,  'Color',[0.85 0.33 0.10], 'LineWidth',1.4, 'DisplayName','tonic (cvxEDA)');
        plot(t8, D.etc.eda_phasic, 'Color',[0.11 0.62 0.46], 'LineWidth',1.0, 'DisplayName','phasic (cvxEDA)');
        legend('Location','best', 'FontSize',9, 'Box','off');
        ylabel('a.u.', 'FontWeight','bold', 'FontSize',11);
        set(gca,'FontSize',10, 'FontWeight','bold', 'Box','on', 'TickDir','out', 'Layer','top');
        title('Tonic / phasic components');
    end
    xlabel('Time (s)', 'FontWeight','bold', 'FontSize',11);
    axH = findall(gcf,'Type','axes');
    try, linkaxes(axH); catch, end
end
end

% ---------------------------------------------------------------------------
function EEG = galea_process_stream(EEG, name, g)
% EMG and IMU. Each is filtered in its own band, optionally given a derived
% channel, and stored back in EEG.etc.galea. They are not merged into the EEG
% dataset: the sampling rates and units differ. (EDA and EOG have their own
% dedicated functions above.)
%
% EMG settings are sensible defaults rather than a validated pipeline - note
% the Aux stream is only 50 Hz, so EMG here is a coarse activity index, not a
% conventional EMG measurement.

if ~isfield(EEG.etc,'galea') || ~isfield(EEG.etc.galea, name) || isempty(EEG.etc.galea.(name))
    disp(sprintf('No %s stream in this recording; skipping.', name));
    return
end

D = EEG.etc.galea.(name);
if D.nbchan == 0, return; end
raw = D;

switch name
    case 'EMG'
        msg = sprintf('EMG: high-pass %g Hz', g.emglocut);
        if g.emghicut > 0, msg = [msg sprintf(', low-pass %g Hz', g.emghicut)]; end
        disp(msg);
        D = pop_eegfiltnew(D, 'locutoff', g.emglocut);
        if g.emghicut > 0
            D = pop_eegfiltnew(D, 'hicutoff', g.emghicut);
        end
        if g.emgenvelope
            env = movmean(abs(double(D.data)), max(1, round(0.1 * D.srate)), 2);
            D.etc.emg_envelope = env;   % kept separately: the stored EMG stays unrectified
            disp('  100 ms envelope stored in .etc.emg_envelope');
        end
        vis = g.visemg;

    case 'IMU'
        disp(sprintf('IMU: low-pass %g Hz', g.imuhicut));
        D = pop_eegfiltnew(D, 'hicutoff', g.imuhicut);
        if g.imumagnitude
            acc = find(contains(lower({D.chanlocs.labels}), 'acc'));
            if numel(acc) >= 3
                mag = sqrt(sum(D.data(acc(1:3),:).^2, 1));
                D.data(end+1,:) = mag;
                D.nbchan = size(D.data,1);
                D.chanlocs(end+1).labels = 'ACC_MAG';
                D = eeg_checkset(D);
                disp('  ACC_MAG channel added (head-motion metric; see help)');
            end
        end
        vis = g.visimu;
end

EEG.etc.galea.(name) = D;

if vis && usejava('desktop')
    % Uniform styling across EMG / IMU: one panel per channel (all of them for
    % IMU, so ACC_MAG is shown alongside its axes), raw vs processed, legend
    % on the first panel, bold 11-pt labels, box on, no grid, and a per-panel
    % y range that clips extreme outliers so the shape of the signal stays
    % readable (full range in the axis tooltip).
    figure('Color','w','Name',[name ' - raw (grey) vs processed']);
    tt = (0:D.pnts-1) / D.srate;
    tr = (0:raw.pnts-1) / raw.srate;
    n = D.nbchan;
    for k = 1:n
        subplot(n,1,k); hold on
        if k <= raw.nbchan
            plot(tr, raw.data(k,:), 'Color',[.65 .65 .65], 'LineWidth',0.8, ...
                'DisplayName','raw');
        end
        plot(tt, D.data(k,:), 'Color',[0.85 0.33 0.10], 'LineWidth',1.4, ...
            'DisplayName','processed');
        if strcmp(name,'EMG') && isfield(D.etc,'emg_envelope') && k <= size(D.etc.emg_envelope,1)
            plot(tt, D.etc.emg_envelope(k,:), 'Color',[0 0.45 0.74], 'LineWidth',1.6, ...
                'DisplayName','envelope (100 ms)');
        end
        if k == 1, legend('Location','best', 'FontSize',9, 'Box','off'); end
        ylabel(D.chanlocs(k).labels, 'Interpreter','none', ...
            'FontWeight','bold', 'FontSize',11);
        set(gca,'FontSize',10, 'FontWeight','bold', 'Box','on', ...
            'TickDir','out', 'XGrid','off', 'YGrid','off', 'Layer','top');
        % clip the y range to the robust signal band so single-sample spikes
        % do not squash the trace (raw and processed share the range)
        allv = [];
        if k <= raw.nbchan, allv = [allv, raw.data(k,:)]; end
        allv = [allv, D.data(k,:)];
        lo = prctile(allv, 1); hi = prctile(allv, 99);
        pad = 0.1 * max(hi - lo, eps);
        ylim([lo - pad, hi + pad]);
        if strcmp(name,'IMU') && strcmpi(D.chanlocs(k).labels, 'ACC_MAG')
            ylabel('ACC\_MAG (g, head motion)', 'FontWeight','bold', 'FontSize',11);
        end
    end
    xlabel('Time (s)', 'FontWeight','bold', 'FontSize',11);
    axH = findall(gcf,'Type','axes');
    try, linkaxes(axH); catch, end
end
end
