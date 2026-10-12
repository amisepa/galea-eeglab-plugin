%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function smoke_test
% SMOKE_TEST  Import and preprocess the sample recordings without the GUI.
%
% Run by the GitHub Actions workflow (.github/workflows/test.yml) and usable
% locally:
%
%   >> cd galea-eeglab-plugin/tests; smoke_test
%
% EEGLAB must be on the MATLAB path, or its folder given in the EEGLAB_PATH
% environment variable. The PPG step is left out: it needs the BrainBeats
% extension, which is downloaded on first use.

pluginPath = fileparts(fileparts(mfilename('fullpath')));
if ~exist('eeglab', 'file')
    eeglabPath = getenv('EEGLAB_PATH');
    if isempty(eeglabPath)
        error('EEGLAB not found: add it to the path or set EEGLAB_PATH');
    end
    addpath(eeglabPath);
end
eeglab('nogui');
addpath(genpath(pluginPath), '-begin');   % test this checkout, not an installed copy of the plugin

samplePath = fullfile(pluginPath, 'sample_data');
taskFile = 'Sample-Data-OpenBCI-RAW.txt';
restFile = 'Sample-Data-OpenBCI-RAW-RestingState.txt';
noPlots = {'viseeg',false, 'viseog',false, 'visppg',false, 'viseda',false, ...
    'viscvx',false, 'visemg',false, 'visimu',false, 'plotspectra',false};

%% Import, both montages
fprintf('\n=== import %s (default montage)\n', taskFile);
[EEG, com] = pop_galea_import('montage','default', 'filename',taskFile, 'filepath',samplePath);
check_set(EEG);
assert(EEG.nbchan == 10, 'default montage should have 10 EEG channels, got %d', EEG.nbchan);
assert(~isempty(EEG.event), 'task recording should have events');
assert(ischar(com) && ~isempty(com), 'empty history string');
streams = {'EOG' 'EMG' 'PPG' 'EDA' 'IMU'};
for k = 1:numel(streams)
    assert(isfield(EEG.etc.galea, streams{k}), 'missing stream %s', streams{k});
end

fprintf('\n=== import %s (custom montage)\n', taskFile);
EEG12 = pop_galea_import('montage','custom', 'filename',taskFile, 'filepath',samplePath);
check_set(EEG12);
assert(EEG12.nbchan == 12, 'custom montage should have 12 EEG channels, got %d', EEG12.nbchan);

fprintf('\n=== import %s\n', restFile);
EEGrest = pop_galea_import('montage','default', 'filename',restFile, 'filepath',samplePath);
check_set(EEGrest);

%% Preprocess the task recording (causal filter, ASR, ICA) and epoch it
fprintf('\n=== preprocess %s\n', taskFile);
EEG = pop_galea_preprocess(EEG, 'resample',250, 'locut',0.5, 'hicut',30, ...
    'causal',true, 'badchan',true, 'asr',100, 'ica',true, 'icaconfirm',false, ...
    'ppg',false, 'eda',true, 'edaphasic',false, 'emg',true, 'imu',true, noPlots{:});
check_set(EEG);
assert(EEG.srate == 250, 'resampling to 250 Hz failed');
assert(~isempty(EEG.icaweights), 'ICA was not computed');

EPO = pop_epoch(EEG, {}, [-1.5 1.5], 'epochinfo','yes');
check_set(EPO);
assert(EPO.trials > 0, 'no epochs extracted');

%% Preprocess the resting-state recording (zero-phase filter, no ICA)
fprintf('\n=== preprocess %s\n', restFile);
EEGrest = pop_galea_preprocess(EEGrest, 'resample',250, 'locut',1, 'hicut',70, ...
    'causal',false, 'badchan',true, 'asr',100, 'ica',false, 'ppg',false, noPlots{:});
check_set(EEGrest);
assert(EEGrest.srate == 250, 'resampling to 250 Hz failed');

fprintf('\nAll smoke tests passed.\n');
end

function check_set(EEG)
EEG = eeg_checkset(EEG);
assert(~isempty(EEG.data), 'no data');
assert(EEG.nbchan == size(EEG.data,1), 'nbchan does not match data');
assert(EEG.pnts == size(EEG.data,2), 'pnts does not match data');
assert(EEG.srate > 0, 'invalid sampling rate');
assert(numel(EEG.chanlocs) == EEG.nbchan, 'chanlocs do not match channels');
assert(all(isfinite(EEG.data(:))), 'non-finite values in data');
end
