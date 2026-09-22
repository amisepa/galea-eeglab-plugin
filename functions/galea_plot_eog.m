%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function galea_plot_eog(EOG)
%GALEA_PLOT_EOG  VEOG time-course with the detected blinks marked.
%
%   >> galea_plot_eog(EOG)
%
% EOG is the filtered EOG dataset from pop_galea_preprocess, with the blink
% detection outputs stored on .etc (blinks_n, blinks_rate, blinks_samp,
% blink_thresh_uV). The figure shows the full VEOG series; each detected
% blink onset is marked with a red triangle. The blink count and rate are in
% the title - the standard EOG output metrics.
%
% Cedric Cannard, 2026

labs = lower({EOG.chanlocs.labels});
vIdx = find(strcmp(labs, 'veog'));
if isempty(vIdx), vIdx = find(strncmp(labs, 'veog', 4)); end
if isempty(vIdx)
    fprintf('  galea_plot_eog: no VEOG channel, nothing to plot.\n');
    return
end

t  = (0:EOG.pnts-1) / EOG.srate;
v  = double(EOG.data(vIdx(1),:));

figure('Color','w', 'Name','EOG - blinks detected on VEOG', 'NumberTitle','off');
plot(t, v, 'k', 'LineWidth', 0.8); hold on
if isfield(EOG.etc,'blinks_samp') && ~isempty(EOG.etc.blinks_samp)
    plot(t(EOG.etc.blinks_samp), v(EOG.etc.blinks_samp), 'rv', ...
        'MarkerFaceColor','r', 'MarkerSize', 6, 'LineStyle','none');
    n = EOG.etc.blinks_n;
else
    n = 0;
end
xlabel('Time (s)'); ylabel('Amplitude (\muV)');
title(sprintf('VEOG (filtered) with detected blinks (n=%d, %.1f / min)', ...
    n, EOG.etc.blinks_rate));
legend('VEOG','Blink onset', 'Location','best', 'Box','off');
box on; set(gca,'FontSize',10,'FontWeight','bold','TickDir','out');
end