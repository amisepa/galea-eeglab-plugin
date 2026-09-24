%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function [EEG, com] = pop_galea_import(varargin)
% POP_GALEA_IMPORT  Import raw Galea (OpenBCI) recordings into EEGLAB.
%
% Splits the multiplexed streams (EEG, EOG, EMG, PPG, EDA, IMU), sets the
% sampling rate from the board's nominal rate, and maps the numeric triggers to
% readable labels when the file comes from the VR driving paradigm.
%
% File format: the plain-text files written by the Galea / OpenBCI GUI. A
% recording is a PAIR and both must sit in the same folder:
%     OpenBCI-RAW-<date>.txt        EEG, EOG, EMG        (select this one)
%     OpenBCI-RAW-Aux-<date>.txt    PPG, EDA, IMU        (found automatically)
%
% Usage:
%   >> EEG = pop_galea_import;                          % GUI (opens pop_galea)
%   >> EEG = pop_galea_import('montage','custom');       % script
%
% Optional key/value:
%   'montage'    - 'default' (10 EEG channels, stock Galea layout) or 'custom'
%                  (12 EEG; the two EMG disc electrodes become Fp1/Fp2).
%                  Default 'default'.
%   'preprocess' - true|false, run pop_galea_preprocess straight after the
%                  import. Default false.
%   'filename','filepath' - skip the file-selection dialog.
%
% Non-EEG streams are kept in EEG.etc.galea (.EOG .EMG .PPG .EDA .IMU .AUX).
%
% Cedric Cannard, 2026

EEG = []; com = '';

% 'eeglab nogui' puts the plugin folder on the path but not functions/
% (only the menu registration in eegplugin_galea adds it), so scripts need this.
if ~exist('galea_import', 'file')
    addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));
end

% No arguments: open the plugin's main window, the one place the GUI loads data.
if nargin == 0
    [EEG, com] = pop_galea();
    return
end

g = struct('montage','default','preprocess',false,'filename','','filepath','');
for i = 1:2:numel(varargin)
    g.(lower(varargin{i})) = varargin{i+1};
end

% ---------------- import ----------------
fprintf('Importing Galea data (montage: %s)...\n', g.montage);
if ~isempty(g.filename)
    [EEG, EOG, EMG, PPG, EDA, IMU, AUX] = galea_import(g.montage, g.filename, g.filepath);
else
    [EEG, EOG, EMG, PPG, EDA, IMU, AUX] = galea_import(g.montage);
end
if isempty(EEG)
    error('pop_galea_import: import returned no EEG data.');
end

EEG.etc.galea = struct('EOG',EOG, 'EMG',EMG, 'PPG',PPG, ...
                       'EDA',EDA, 'IMU',IMU, 'AUX',AUX, ...
                       'montage',g.montage, 'plugin_version','galea1.1');

% Trigger labels. Applied only if the codes match the VR driving paradigm.
EEG = galea_rename_events(EEG);
EEG = eeg_checkset(EEG);

fprintf('Imported %d channels, %.1f min at %g Hz.\n', ...
    EEG.nbchan, EEG.pnts/EEG.srate/60, EEG.srate);

com = sprintf('EEG = pop_galea_import(''montage'', ''%s'');', g.montage);

% ---------------- optional preprocessing ----------------
if g.preprocess
    [EEG, pcom] = pop_galea_preprocess(EEG);
    if ~isempty(pcom), com = [com ' ' pcom]; end
end

end
