%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function EEG = galea_erp_workflow(EEG, opt, S)
%GALEA_ERP_WORKFLOW  Segment, reject bad trials, plot condition ERPs.
%
%   >> EEG = galea_erp_workflow(EEG, opt, S)
%
% The ERP branch of the main Galea window, after the continuous processing
% has run. Segments around the markers in the file, optionally rejects bad
% trials (find_badTrials: amplitude + high-frequency residual outliers), and
% plots the conditions of interest as 20% trimmed means +/- SEM, the robust
% summary used in the Cannard pipeline.
%
% OPT needs 'trimWindow' ([pre post] seconds) and 'plotConds' (cell of event
% labels or {}). S carries 'btOn' and 'btMethod'.
%
% Cedric Cannard, 2026

win = opt.trimWindow;
if numel(win) ~= 2 || any(~isfinite(win))
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
fprintf('Epoched %g s around all markers: %g epochs.\n', diff(win), EEG.trials);

% ---------------- bad trials ----------------
if isfield(S,'btOn') && S.btOn
    method = 'mean';
    if isfield(S,'btMethod'), method = S.btMethod; end
    try
        bad = find_badTrials(EEG, method, false);
        if ~isempty(bad)
            fprintf('Removing %g bad epochs (%s criterion).\n', numel(bad), method);
            EEG = pop_select(EEG, 'noepoch', bad);
        else
            fprintf('Bad-trial detection: no bad epochs found.\n');
        end
    catch ME
        fprintf(2, 'Bad-trial detection failed: %s\n', ME.message);
    end
end

% ---------------- condition ERPs ----------------
conds = {};
if isfield(opt,'plotConds')
    conds = opt.plotConds(~cellfun(@isempty, opt.plotConds));
end
if isempty(conds)
    return
end

figure('Color','w'); hold on
cols = [0.85 0.33 0.10; 0.20 0.40 0.70; 0.00 0.62 0.45; 0.58 0.40 0.62;
        0.93 0.69 0.13; 0.49 0.18 0.55];   % Okabe-Ito subset, cycles
times = EEG.times;
for k = 1:numel(conds)
    idx = find(cellfun(@(c) any(strcmp(c, conds{k})), {EEG.epoch.eventtype}));
    if isempty(idx)
        fprintf('No epochs of condition %s; skipping.\n', conds{k});
        continue
    end
    SET = pop_select(EEG, 'trial', idx);
    % per-channel trimmed mean, then across channels: robust to artefact
    % epochs that survived rejection
    trimERP = zeros(SET.nbchan, numel(times));
    for iCh = 1:SET.nbchan
        trimERP(iCh,:) = trimmean(SET.data(iCh,:,:), 20, 2);
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
xlabel('Time (s)'); ylabel('Amplitude (\muV)');
title(sprintf('Condition ERPs, 20%% trimmed mean +/- SEM across %g channels (one participant)', EEG.nbchan));
legend('Location','best'); box on; set(gca,'TickDir','out');
fprintf('Condition ERP plot: %s\n', strjoin(conds, ' vs '));
end