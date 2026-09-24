%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

%% Galea plugin tutorial
%
% From a raw Galea recording to an ERP, in seven sections. Run one at a time
% (Ctrl+Enter, or "Run Section" in the editor).
%
% A recording is a PAIR of text files written by the Galea / OpenBCI GUI, both
% needed and both in the same folder:
%
%     OpenBCI-RAW-<date>.txt        EEG, EOG, EMG      <- point RAWFILE here
%     OpenBCI-RAW-Aux-<date>.txt    PPG, EDA, IMU      <- found automatically
%
% Everything through step 4 works on CONTINUOUS data. Epoching and ERPs use the
% standard EEGLAB functions, shown in steps 5-7.
%
% Cedric Cannard, August 2026

%% 1. Set up
% Edit these two paths, then run the section. PLUGIN_PATH may point at your
% eeglab/plugins/galea_eeglab_plugin copy or at this repository checkout -
% they are the same code.

EEGLAB_PATH = 'C:\Users\ccann\Documents\MATLAB\eeglab';   % <- edit
PLUGIN_PATH = fileparts(mfilename('fullpath'));              % this folder

RAWFILE = fullfile(PLUGIN_PATH, 'sample_data', 'Sample-Data-OpenBCI-RAW.txt');

% genpath so functions/ comes along too - galea_import lives there. When run
% from the editor, mfilename CAN return empty; fall back to cd then.
if isempty(PLUGIN_PATH), PLUGIN_PATH = pwd; end
addpath(EEGLAB_PATH);
addpath(genpath(PLUGIN_PATH));
eeglab nogui;

assert(isfile(RAWFILE), 'RAWFILE not found: %s', RAWFILE);
[filepath, name, ext] = fileparts(RAWFILE);
fprintf('Ready: %s%s\n', name, ext);


%% 2. Load
% 'default' is the stock 10-channel layout. Use 'custom' for 12 channels, where
% the two EMG disc electrodes are treated as Fp1/Fp2.
% Non-EEG streams are kept in EEG.etc.galea (PPG, EDA, IMU, EOG, EMG).

EEG = pop_galea_import('montage','default', 'filename',[name ext], 'filepath',filepath);

fprintf('\n%d channels, %.1f min, %g Hz\n', EEG.nbchan, EEG.pnts/EEG.srate/60, EEG.srate);
fprintf('%s\n', strjoin({EEG.chanlocs.labels}, ' '));

% Same thing by clicking:  Galea, then Preprocess: No (the button reads Import).


%% 3. Events
% Numeric triggers were mapped to labels during import (only for the VR driving
% paradigm; any other code set is left alone).

types = unique({EEG.event.type});
fprintf('\n%d events\n', numel(EEG.event));
for k = 1:numel(types)
    fprintf('   %-16s %d\n', types{k}, sum(strcmp({EEG.event.type}, types{k})));
end


%% 4. Preprocess
% Downsample, causal filter, polarity check, bad channels, ASR, and ICA with
% the ocular component removed. Causal filtering matters if you will look at
% the PRE-stimulus period: a zero-phase filter smears post-stimulus activity
% backwards and can manufacture an anticipatory effect.
%
% Add 'ppg',true to also run the PPG through BrainBeats.

EEG = pop_galea_preprocess(EEG, 'resample',250, 'locut',0.5, 'hicut',30, ...
    'causal',true, 'badchan',true, 'asr',100, 'ica',true);

% Same thing by clicking:  Galea, Preprocess: Yes, Next, then Run in the
% processing parameters window.


%% 5. Epoch
% Cut around the tyre blowout. No baseline correction, so the pre- and
% post-stimulus periods stay comparable.

EPOCH_WINDOW = [-1.5 1.5];                       % seconds
CONDITIONS   = {'tire_pop', 'no_tire_pop'};      % collision, no-collision

have = intersect(CONDITIONS, unique({EEG.event.type}));
assert(~isempty(have), 'None of %s present - edit CONDITIONS.', strjoin(CONDITIONS,'/'));

EPO = pop_epoch(EEG, have, EPOCH_WINDOW, 'epochinfo','yes');
fprintf('\n%d epochs of %g s\n', EPO.trials, diff(EPOCH_WINDOW));


%% 6. Average by condition
% Split the epoched set with pop_select, then average over trials.

ERP = cell(1, numel(CONDITIONS));
for k = 1:numel(CONDITIONS)
    idx = find(cellfun(@(t) any(strcmp(t, CONDITIONS{k})), {EPO.epoch.eventtype}));
    SET = pop_select(EPO, 'trial', idx);
    ERP{k} = mean(SET.data, 3);                   % [channels x time]
    disp(sprintf('%-14s %d epochs', CONDITIONS{k}, numel(idx)))
end
times = EPO.times;


%% 7. Plot
% One participant, so this is a descriptive picture, not a test: the shaded
% band is the spread across channels, not a confidence interval on an effect.
% Set CHANS to a single site to look at one electrode instead.

CHANS = 1:EPO.nbchan;      % e.g. find(strcmpi({EPO.chanlocs.labels}, 'CZ'))
cols  = [0.85 0.33 0.10; 0.20 0.40 0.70];

figure('Color','w'); hold on
for k = 1:numel(CONDITIONS)
    m  = mean(ERP{k}(CHANS,:), 1);
    se = std(ERP{k}(CHANS,:), 0, 1) ./ sqrt(numel(CHANS));
    if numel(CHANS) > 1
        fill([times fliplr(times)], [m-se fliplr(m+se)], cols(k,:), ...
            'FaceAlpha',0.2, 'EdgeColor','none', 'HandleVisibility','off');
    end
    plot(times, m, 'Color',cols(k,:), 'LineWidth',1.5, 'DisplayName',CONDITIONS{k});
end
xline(0,'k:'); yline(0,'k:');
xlabel('Time from tyre blowout (ms)'); ylabel('Amplitude (\muV)');
if numel(CHANS) > 1
    title(sprintf('ERP, mean +/- SEM across %d channels (one participant)', numel(CHANS)));
else
    title(sprintf('ERP at %s (one participant)', EPO.chanlocs(CHANS).labels));
end
legend('Location','best'); box off; set(gca,'TickDir','out')

% Group level: loop steps 1-6 over participants, collect each one into
% allERP(subject, condition, channel, time), then average over subjects and
% test across them. analysis/rerun_final_stats.m does exactly that.


%% 8. Spectra of a continuous recording
% The resting-state sample (Sample-Data-OpenBCI-RAW-RestingState.txt) has no
% markers: import it, preprocess WITHOUT the causal filter (nothing to
% anticipate), and look at the spectra. pop_spectopo gives the channel
% spectra; 'freqrange' [1 70] covers delta to gamma at the 250 Hz sample rate.
%
% GUI route: load the resting-state file with the Galea menu, preprocess,
% then Plot > Channel properties > Spectra (or the command below).

RESTFILE = fullfile(fileparts(mfilename('fullpath')), ...
    'sample_data', 'Sample-Data-OpenBCI-RAW-RestingState.txt');
if ~isfile(RESTFILE)
    RESTFILE = fullfile(pwd, 'sample_data', 'Sample-Data-OpenBCI-RAW-RestingState.txt');
end
assert(isfile(RESTFILE), 'Resting-state sample not found: %s', RESTFILE);
[rfPath, rName, rExt] = fileparts(RESTFILE);

EEGrest = pop_galea_import('montage','default', 'filename',[rName rExt], 'filepath',rfPath);
EEGrest = pop_galea_preprocess(EEGrest, 'resample',250, 'locut',1, 'hicut',70, ...
    'causal',false, 'badchan',true, 'asr',100, 'ica',false);

figure('Color','w');
pop_spectopo(EEGrest, 1, [], 'EEG', 'freq', [6 10 22], 'freqrange',[1 70], 'electrodes','off');
title('Resting-state spectra, 1-70 Hz (one participant)');

% What to look for: the eyes-closed alpha peak near 10 Hz, theta around 6 Hz,
% beta around 22 Hz. A flat spectrum above ~40 Hz is normal for dry electrodes.
