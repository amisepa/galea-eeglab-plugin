%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function galea_plot_eda(E8)
%GALEA_PLOT_EDA  cvxEDA decomposition on one shared time-course.
%
%   >> galea_plot_eda(E8)
%
% E8 is the 8 Hz EDA dataset with the cvxEDA outputs stored on .etc by
% pop_galea_preprocess (eda_tonic, eda_phasic, optional eda_driver/eda_resid,
% optional eda_z the normalised input). Two panels:
%   top    - the EDA signal the decomposition was run on (normalised), with
%            the TONIC component overlaid;
%   bottom - the PHASIC component (SCR) with the sparse SMNA driver as stems,
%            which is the standard cvxEDA presentation.
%
% Adapted from the figure in the study pipeline (galea_pipeline_v5_eda.m).
%
% Cedric Cannard, 2026

t = (0:E8.pnts-1) / E8.srate;

figure('Color','w', 'Name','EDA - cvxEDA tonic/phasic decomposition', 'NumberTitle','off');

if isfield(E8.etc,'eda_z')
    y = E8.etc.eda_z;
else
    y = E8.data(1,:);
end

subplot(2,1,1); hold on
plot(t, y, 'Color', [0.2 0.5 0.8], 'LineWidth', 1);
plot(t, E8.etc.eda_tonic, 'Color', [0.85 0.35 0.19], 'LineWidth', 1.6);
legend({'EDA (z-scored input)','Tonic component'}, 'Location','best', 'Box','off');
ylabel('a.u. (z)'); title('Observed EDA and tonic component');
box on; set(gca,'FontSize',10,'FontWeight','bold','TickDir','out');

subplot(2,1,2); hold on
if isfield(E8.etc,'eda_driver')
    stem(t, E8.etc.eda_driver, 'Color', [0.50 0.47 0.87], 'LineWidth', 0.8, ...
        'MarkerSize', 3, 'Marker','none', 'BaseValue', 0, ...
        'DisplayName','SMNA driver');
else
    plot(t, E8.etc.eda_phasic, 'Color', [0.50 0.47 0.87], 'LineWidth', 0.8, ...
        'DisplayName','SMNA driver');
end
plot(t, E8.etc.eda_phasic, 'Color', [0.11 0.62 0.46], 'LineWidth', 1, ...
    'DisplayName','phasic (SCR)');
title('Phasic component and sparse driver');
ylabel('a.u.'); xlabel('Time (s)');
box on; set(gca,'FontSize',10,'FontWeight','bold','TickDir','out');
legend('Location','best', 'Box','off');

axH = findall(gcf,'Type','axes');
try, linkaxes(axH, 'x'); catch, end
xlim([t(1) t(end)]);
end