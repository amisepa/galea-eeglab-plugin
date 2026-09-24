%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function [fig, S] = galea_plot_conditions(EEG, conds, pct, alpha)
%GALEA_PLOT_CONDITIONS  Overlay condition ERPs: trimmed mean + 95% CI.
%
%   >> galea_plot_conditions(EEG, {'no_tire_pop','tire_pop'})
%   >> [fig, S] = galea_plot_conditions(EEG, conds, pct, alpha)
%
% EEG is an epoched dataset. For every condition in CONDS (event labels),
% the epochs time-locked to that event are summarised across trials as a
% PCT% trimmed mean (default 20) with its (1-ALPHA) confidence interval
% (default 95%) shaded around it (galea_trimci). All conditions share one
% axis, each in its own color, as many as given. The signal is the mean
% across channels, one value per trial and time point (as in the Cannard &
% Yesilbas 2026 pipeline). Each condition also gets its single-trial ERP
% image (EEGLAB erpimage), which shows the trial-to-trial variability the
% average hides.
%
% An epoch belongs to a condition only if that event sits at its latency 0:
% an epoch that merely CONTAINS the marker is time-locked to another event,
% and counting it would mix other events' ERPs into the average.
%
% FIG is the overlay figure (empty if no condition had epochs). S holds, per
% condition: name, n (trials), tm, lo, hi (1 x time), and times (ms).
%
% Cedric Cannard, 2026

if nargin < 3 || isempty(pct),   pct = 20;      end
if nargin < 4 || isempty(alpha), alpha = 0.05;  end
conds = galea_cellstr(conds);
fig = [];
S = struct('name',{}, 'n',{}, 'tm',{}, 'lo',{}, 'hi',{}, 'times',{});
if isempty(conds) || EEG.trials < 2, return; end

% the event each epoch is time-locked to (latency 0)
lockType = cell(1, EEG.trials);
halfSample = 500 / EEG.srate;                      % ms
for iE = 1:EEG.trials
    et = EEG.epoch(iE).eventtype;
    el = EEG.epoch(iE).eventlatency;
    if ~iscell(et), et = {et}; end
    if ~iscell(el), el = {el}; end
    k0 = find(cellfun(@(x) abs(x) < halfSample, el), 1);
    if ~isempty(k0), lockType{iE} = num2str(et{k0}); else, lockType{iE} = ''; end
end

% one signal per trial: mean across channels (time x trials)
sig = squeeze(mean(double(EEG.data), 1));
if isvector(sig), sig = sig(:); end
times = EEG.times(:)';

% colors: MATLAB's default order (plotDiff: blue, red, ...), then evenly
% spaced hues when more conditions are asked for than it holds
nC = numel(conds);
cols = lines(7);
if nC > 7, cols = [cols; 0.85 * hsv(nC - 7)]; end

for k = 1:nC
    idx = find(strcmp(lockType, conds{k}));
    if numel(idx) < 2
        fprintf('Condition %s: %d epoch(s), too few to plot; skipped.\n', conds{k}, numel(idx));
        continue
    end
    [tm, lo, hi, n] = galea_trimci(sig(:, idx), pct, alpha);
    S(end+1) = struct('name',conds{k}, 'n',n, 'tm',tm', 'lo',lo', 'hi',hi', 'times',times); %#ok<AGROW>

    % single-trial ERP image of this condition
    try
        figure('Color','w');
        erpimage(sig(:, idx), 1:numel(idx), times, ...
            sprintf('%s: single trials (mean across channels)', strrep(conds{k}, '_', '\_')), 5, 0, ...
            'erp', 'on', 'cbar', 'on');
    catch ME
        fprintf(2, 'Single-trial ERP image failed (%s): %s\n', conds{k}, ME.message);
    end
end

if isempty(S)
    fprintf('No condition had enough epochs to plot.\n');
    return
end

fig = figure('Color','w', 'Name','Condition ERPs');
hold on
hLine = gobjects(1, numel(S));
for k = 1:numel(S)
    ck = cols(strcmp(conds, S(k).name), :);
    ok = isfinite(S(k).lo);                       % CI needs at least 2 trials left after trimming
    if any(ok)
        patch([times(ok) fliplr(times(ok))], [S(k).lo(ok) fliplr(S(k).hi(ok))], ck, ...
            'FaceAlpha',.3, 'EdgeColor',ck, 'EdgeAlpha',.9, 'HandleVisibility','off');
    end
    hLine(k) = plot(times, S(k).tm, 'LineWidth',2, 'Color',ck, ...
        'DisplayName', sprintf('%s (n=%d)', S(k).name, S(k).n));
end
set(gca, 'FontSize',12, 'layer','top'); axis tight; box on; grid off
yl = ylim;
plot([0 0], yl, 'k--', 'LineWidth',.5, 'HandleVisibility','off');     % time 0
xlabel('Time (ms)', 'FontWeight','bold');
ylabel(sprintf('Amplitude (%sV)', char(956)), 'FontWeight','bold');
title(sprintf('%g%% trimmed mean + %g%% CI (mean across %d channels)', ...
    pct, 100*(1-alpha), EEG.nbchan));
legend(hLine, 'Location','best', 'Interpreter','none');
set(findall(fig, 'type','axes'), 'FontWeight','bold');
fprintf('Condition ERP plot: %s\n', strjoin({S.name}, ' vs '));
end
