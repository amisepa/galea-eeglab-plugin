%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function opt = galea_process_defaults()
%GALEA_PROCESS_DEFAULTS  Default processing options for the Galea plugin.
%
%   >> opt = galea_process_defaults()
%
% One struct for every processing parameter (EEG, the ERP epoching and the
% other signals alike), so the main window, the parameters dialog,
% pop_galea_preprocess and galea_erp_workflow all speak the same option
% names. Every signal is on by default; a signal the recording does not
% carry is skipped with a message when processing runs.
%
% Cedric Cannard, 2026

opt = struct( ...
    'montage',      'default', ...   % 'default' (10 EEG) or 'custom' (12 EEG, Fp1/Fp2)
    'erp',          false, ...       % ERP data (set by pop_galea's data type)
    'eeg',          true, ...
    'trim',         1, ...           % s; paper pipeline: 1 s around first/last event
    'resample',     0, ...           % Hz; 0 = keep
    'locut',        0.5, ...
    'hicut',        30, ...
    'causal',       true, ...        % paper pipeline: minimum-phase causal (pre-stimulus safety)
    'polarity',     false, ...       % Fp1/Fp2 lead check (custom montage only)
    'badchan',      true, ...
    'interpchan',   true, ...        % paper pipeline: detected bad channels are interpolated before ICA
    'mincorr',      0.55, ...        % channel cross-correlation threshold (lax .35, aggressive .85)
    'maxtol',       0.30, ...        % max fraction of windows a channel may fail (5-50%)
    'asr',          100, ...         % ASR 1st pass threshold; 0 = skip
    'asrmode',      'remove', ...
    'ica',          true, ...
    'icaconfirm',   true, ...        % command-line only now: the GUI always confirms
    'asr2',         0, ...           % continuous data: 2nd ASR pass after ICA (GUI offers 10); 0 = skip
    'asr2mode',     'reconstruct', ...
    'plotspectra',  false, ...       % continuous data: pop_spectopo (1-70 Hz) of the cleaned EEG
    'viseeg',       true, ...
    'epochwin',     [-1.5 1.5], ...  % ERP epoch window, s
    'epochevents',  {{}}, ...        % ERP: event labels to epoch around; {} = all
    'rejtrials',    false, ...       % ERP: reject bad trials (find_badTrials)
    'rejmethod',    'mean', ...      % 'mean' (conservative), 'median', 'grubbs' (aggressive)
    'plotconds',    {{}}, ...        % ERP: event labels to plot, overlaid; {} = none ({{}}: struct() needs it)
    'eog',          true, ...        % filter EOG + blink detection
    'eoglocut',     0.5, ...
    'eoghicut',     20, ...
    'viseog',       true, ...
    'ppg',          true, 'ppglocut',0.5, 'ppghicut',3, ...
    'ppgdetect',    'valleys', ...   % pulse-wave detection: 'valleys' (default) or 'peaks'
    'rrcorrect',    'pchip', ...     % kept for BrainBeats compatibility; not exposed in the GUI
    'hrvtime',      true, 'hrvfreq',true, 'hrvnonlin',false, 'visppg',true, ...
    'eda',          true, 'edalocut',0.01, 'edahicut',1, ...
    'edaphasic',    true, ...        % cvxEDA tonic/phasic (data auto-downsampled to 8 Hz)
    'viscvx',       true, ...        % plot the tonic/phasic decomposition
    'viseda',       true, ...
    'emg',          true, 'emglocut',20, 'emghicut',0, ...   % 0 = no low-pass
    'emgenvelope',  true, 'visemg',true, ...
    'imu',          true, 'imuhicut',10, 'imumagnitude',true, 'visimu',true);
end
