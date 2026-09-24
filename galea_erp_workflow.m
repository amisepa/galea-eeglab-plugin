%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function [EEG, com] = galea_erp_workflow(EEG, varargin)
%GALEA_ERP_WORKFLOW  Segment, reject bad trials, plot condition ERPs.
%
%   >> EEG = galea_erp_workflow(EEG, opt)
%   >> EEG = galea_erp_workflow(EEG, 'epochwin',[-3 3], 'rejtrials',true, ...
%                               'plotconds',{'tire_pop'})
%
% The ERP branch of pop_galea, after the continuous processing has run.
% Segments around the markers in the file, optionally rejects bad trials
% (find_badTrials: amplitude + high-frequency residual outliers), and plots
% the condition of interest as a 20% trimmed mean +/- SEM (the robust
% summary used in the Cannard pipeline) plus its single-trial ERP image
% (erpimage).
%
% Options, as a struct or as name/value pairs, use the galea_process_defaults
% names (missing keys keep defaults):
%   'epochwin'   [pre post] epoch window in s              [-1.5 1.5]
%   'rejtrials'  reject bad trials                         [false]
%   'rejmethod'  'mean' (conservative), 'median', 'grubbs' (aggressive) ['mean']
%   'plotconds'  cell of event labels to plot, {} = none   [{}]
%
% COM is the command-line equivalent, for the EEGLAB history (eegh).
%
% Cedric Cannard, 2026

com = '';
if numel(varargin) == 1 && isstruct(varargin{1})
    opt = varargin{1};
else
    opt = struct();
    for iA = 1:2:numel(varargin), opt.(lower(varargin{iA})) = varargin{iA+1}; end
end
d = galea_process_defaults();
fn = fieldnames(opt);
for iF = 1:numel(fn), d.(fn{iF}) = opt.(fn{iF}); end
opt = d;

win = opt.epochwin;
if numel(win) ~= 2 || any(~isfinite(win)) || win(1) >= win(2)
    fprintf(2, 'Invalid epoch window; using [-1.5 1.5] s.\n');
    win = [-1.5 1.5];
end

% ---------------- segment ----------------
if isempty(EEG.event)
    fprintf('No markers in this recording: no epoching, nothing to plot.\n');
    return
end
types = unique({EEG.event.type});
% every labeled marker is a potential epoch source
EEG = pop_epoch(EEG, types, win, 'epochinfo','yes');
fprintf('Epoched [%g %g] s around all markers: %g epochs.\n', win(1), win(2), EEG.trials);

conds = opt.plotconds;
if ischar(conds), conds = {conds}; end
conds = conds(~cellfun(@isempty, conds));
com = sprintf('EEG = galea_erp_workflow(EEG, %s);', vararg2str({'epochwin', win, ...
    'rejtrials', logical(opt.rejtrials), 'rejmethod', opt.rejmethod, 'plotconds', conds}));

% ---------------- bad trials ----------------
if opt.rejtrials
    try
        bad = find_badTrials(EEG, opt.rejmethod, false);
        if ~isempty(bad)
            fprintf('Removing %g bad epochs (%s criterion).\n', numel(bad), opt.rejmethod);
            EEG = pop_select(EEG, 'notrial', bad);
        else
            fprintf('Bad-trial detection: no bad epochs found.\n');
        end
    catch ME
        fprintf(2, 'Bad-trial detection failed: %s\n', ME.message);
    end
end

% ---------------- condition ERPs ----------------
if isempty(conds)
    return
end

% the event each epoch is time-locked to (latency 0). An epoch that merely
% CONTAINS a condition marker is time-locked to another event, so matching
% any marker in the window would mix other events' ERPs into the average.
lockType = cell(1, EEG.trials);
halfSample = 500 / EEG.srate;                      % ms
for iE = 1:EEG.trials
    et = EEG.epoch(iE).eventtype;
    el = EEG.epoch(iE).eventlatency;
    if ~iscell(et), et = {et}; end
    if ~iscell(el), el = {el}; end
    k0 = find(cellfun(@(x) abs(x) < halfSample, el), 1);
    if ~isempty(k0), lockType{iE} = et{k0}; else, lockType{iE} = ''; end
end

figure('Color','w'); hold on
cols = [0.85 0.33 0.10; 0.20 0.40 0.70; 0.00 0.62 0.45; 0.58 0.40 0.62;
        0.93 0.69 0.13; 0.49 0.18 0.55];   % Okabe-Ito subset, cycles
times = EEG.times;
for k = 1:numel(conds)
    idx = find(strcmp(lockType, conds{k}));
    if isempty(idx)
        fprintf('No epochs of condition %s; skipping.\n', conds{k});
        continue
    end
    SET = pop_select(EEG, 'trial', idx);

    % single-trial ERP image (EEGLAB erpimage): one row per trial, the
    % condition's mean ERP underneath. It shows the trial-to-trial
    % variability that the average hides. Plotted on the mean across
    % channels so one image summarizes the condition.
    try
        meanChan = squeeze(mean(SET.data, 1));        % (time, trials)
        figure('Color','w');
        erpimage(meanChan, 1:size(meanChan,2), ...
            linspace(SET.xmin*1000, SET.xmax*1000, SET.pnts), ...
            sprintf('%s: single trials (mean across channels)', conds{k}), 5, 0, ...
            'erp', 'on', 'cbar', 'on');
    catch ME
        fprintf(2, 'Single-trial ERP image failed (%s): %s\n', conds{k}, ME.message);
    end

    % per-channel trimmed mean, then across channels: robust to artefact
    % epochs that survived rejection
    trimERP = zeros(SET.nbchan, numel(times));
    for iCh = 1:SET.nbchan
        % dim 3 = trials. Averaging over dim 2 would collapse TIME, not
        % trials, and the assignment below would then be a size mismatch.
        trimERP(iCh,:) = trimmean(SET.data(iCh,:,:), 20, 3);
    end
    m  = mean(trimERP, 1);                          % across channels
    se = std(trimERP, 0, 1) / sqrt(SET.nbchan);
    if SET.nbchan > 1
        fill([times fliplr(times)], [m-se fliplr(m+se)], cols(mod(k-1,6)+1,:), ...
            'FaceAlpha',0.2, 'EdgeColor','none', 'HandleVisibility','off');
    end
    plot(times, m, 'Color',cols(mod(k-1,6)+1,:), 'LineWidth',1.6, ...
        'DisplayName', sprintf('%s (%g trials, 20%% trimmed)', conds{k}, numel(idx)));
end
xline(0,'k:'); yline(0,'k:');
xlabel('Time (ms)'); ylabel('Amplitude (\muV)');
title(sprintf('Condition ERPs, 20%% trimmed mean +/- SEM across %g channels (one participant)', EEG.nbchan));
legend('Location','best'); box on; set(gca,'TickDir','out');
fprintf('Condition ERP plot: %s\n', strjoin(conds, ' vs '));
end
