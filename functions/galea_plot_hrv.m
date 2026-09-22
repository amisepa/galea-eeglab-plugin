%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function galea_plot_hrv(HRV, PPG)
%GALEA_PLOT_HRV  One figure summarising the HRV outputs.
%
%   >> galea_plot_hrv(HRV)            % HRV = EEG.etc.galea.HRV (Features.HRV)
%   >> galea_plot_hrv(HRV, PPG)       % PPG dataset optional, adds its time base
%
% Panels (only the ones the selected feature sets produced):
%   1. NN-interval tachogram over the whole recording, with the 3-beat local
%      median so slow drifts are visible, plus the time/frequency/nonlinear
%      key numbers as a text column on the right.
%   2. Poincaré plot (NN(i) vs NN(i+1)) with the SD1/SD2 ellipse when the
%      nonlinear features were computed.
%   3. HRV power spectral density with the VLF/LF/HF bands shaded, when the
%      frequency features were computed.
%
% Designed to sit alongside BrainBeats' plot_NN (which shows the beat
% detection and correction); this one is about the HRV METRICS.
%
% Cedric Cannard, 2026

if nargin < 2, PPG = []; end
have = struct('time',isfield(HRV,'time') && ~isempty(fieldnames(HRV.time)), ...
              'freq',isfield(HRV,'frequency') && ~isempty(fieldnames(HRV.frequency)), ...
              'nonlin',isfield(HRV,'nonlinear') && ~isempty(fieldnames(HRV.nonlinear)));
if ~any(struct2array(have))
    fprintf('  no HRV features to plot.\n');
    return
end

c = [0.20 0.40 0.70;          % blue - series
     0.85 0.33 0.10;          % orange - accent
     0.47 0.67 0.19];         % green - accent 2

fig = figure('Color','w', 'Name','HRV outputs (BrainBeats)', 'NumberTitle','off');
tiledlayout(fig, 2, 2, 'TileSpacing','compact', 'Padding','compact');

% ---------------- NN tachogram + key numbers ----------------
nexttile([1 2]);
if isfield(PPG,'brainbeats') && isfield(PPG.brainbeats,'preprocessings') && ...
        isfield(PPG.brainbeats.preprocessings,'NN')
    nn = PPG.brainbeats.preprocessings.NN;
    tt = PPG.brainbeats.preprocessings.NN_times;
elseif isfield(HRV,'NN') && ~isempty(HRV.NN)
    nn = HRV.NN;  tt = HRV.NN_times;
else
    nn = [];  tt = [];
end
if isempty(nn)
    axis off; text(0.5, 0.5, 'NN series not available (features only)', ...
        'Units','normalized','HorizontalAlignment','center','FontAngle','italic');
    fprintf('  galea_plot_hrv: NN series not found; tachogram skipped.\n');
    return
end
plot(tt, nn * 1000, '-', 'Color', c(1,:), 'LineWidth', 1);
hold on
if numel(nn) > 5
    med3 = movmedian(nn * 1000, [2 0]);       % 3-beat local median
    plot(tt, med3, '--', 'Color', c(2,:), 'LineWidth', 1);
    legend({'NN intervals','3-beat median'}, 'Location','best', 'Box','off');
end
xlabel('Time (s)'); ylabel('NN interval (ms)');
title('NN intervals (tachogram)');
box on; set(gca,'FontSize',10,'FontWeight','bold','TickDir','out');
xlim([tt(1) tt(end)]);

% key numbers, right side of the tachogram tile
if have.time
    s = {};
    if isfield(HRV.time,'SDNN'),   s{end+1} = sprintf('SDNN   %g ms',  HRV.time.SDNN);   end
    if isfield(HRV.time,'RMSSD'),  s{end+1} = sprintf('RMSSD  %g ms',  HRV.time.RMSSD);  end
    if isfield(HRV.time,'pNN50'),  s{end+1} = sprintf('pNN50  %g',     HRV.time.pNN50);   end
    if isfield(HRV.time,'heart_rate'), s{end+1} = sprintf('HR      %g bpm', HRV.time.heart_rate); end
    if ~isempty(s)
        text(0.99, 0.95, strjoin(s, '\n'), 'Units','normalized', ...
            'HorizontalAlignment','right', 'VerticalAlignment','top', ...
            'FontSize',10, 'FontWeight','bold', 'Interpreter','none');
    end
end

% ---------------- Poincaré ----------------
nexttile;
if have.nonlin && isfield(HRV.nonlinear,'Poincare')
    nn1 = nn(1:end-1) * 1000;  nn2 = nn(2:end) * 1000;
    ok = isfinite(nn1) & isfinite(nn2);
    plot(nn1(ok), nn2(ok), '.', 'Color', c(1,:), 'MarkerSize', 5); hold on
    if isfield(HRV.nonlinear.Poincare,'SD1')
        text(0.03, 0.97, sprintf('SD1/SD2 = %g', HRV.nonlinear.Poincare.SD1SD2), ...
            'Units','normalized', 'FontWeight','bold', 'FontSize',10, ...
            'VerticalAlignment','top');
    end
    xlabel('NN_i (ms)'); ylabel('NN_{i+1} (ms)');
    title('Poincaré plot');
    axis square; box on; set(gca,'FontSize',10,'FontWeight','bold','TickDir','out');
else
    axis off; text(0.5, 0.5, 'nonlinear features not computed', ...
        'Units','normalized','HorizontalAlignment','center','FontAngle','italic');
end

% ---------------- PSD ----------------
nexttile;
if have.freq && isfield(HRV.frequency,'pwr')
    pwr = HRV.frequency.pwr;  freqs = HRV.frequency.pwr_freqs;
    bands = HRV.frequency.bands;
    baseval = min(pwr);
    bandCols = [0.6350 0.0780 0.1840;   % VLF
                0.9290 0.6940 0.1250;   % LF
                0.0000 0.4470 0.6980];  % HF
    names = {'VLF','LF','HF'};
    hold on
    % shade the VLF/LF/HF bands (rows 2-4 of the bands matrix; row 1 is ULF)
    for b = 1:min(3, size(bands,1) - 1)
        x = freqs >= bands(b+1, 1) & freqs <= bands(b+1, 2);
        if any(x)
            area(freqs(x), pwr(x), 'BaseValue', baseval, ...
                'FaceColor', bandCols(b,:), 'FaceAlpha', .7, 'EdgeColor','none');
        end
    end
    legend(names, 'Location','best', 'Box','off');
    xlabel('Frequency (Hz)'); ylabel('Power (ms^2/Hz)');
    title('HRV power spectral density');
    axis tight; box on; set(gca,'FontSize',10,'FontWeight','bold','TickDir','out');
else
    axis off; text(0.5, 0.5, 'frequency features not computed', ...
        'Units','normalized','HorizontalAlignment','center','FontAngle','italic');
end

% tidy
set(findall(fig,'type','axes'), 'FontSize',10, 'FontWeight','bold');
axH = findall(fig,'Type','axes');
try, linkaxes(axH(1:2),'x'); catch, end %#ok<LAXST>
end