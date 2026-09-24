%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function [EEG, com] = galea_erp_workflow(EEG, varargin)
%GALEA_ERP_WORKFLOW  Segment, reject bad trials, plot condition ERPs.
%
%   >> EEG = galea_erp_workflow(EEG, opt)
%   >> EEG = galea_erp_workflow(EEG, 'epochwin',[-3 3], ...
%              'epochevents',{'no_tire_pop','tire_pop'}, 'rejtrials',true, ...
%              'plotconds',{'no_tire_pop','tire_pop'})
%
% The ERP branch of pop_galea, after the continuous processing has run.
% Segments around the chosen event markers, optionally rejects bad trials
% (find_badTrials: amplitude + high-frequency residual outliers), and plots
% the chosen conditions overlaid in one figure (galea_plot_conditions): for
% each condition, the 20% trimmed mean across trials with its 95% confidence
% interval shaded, each condition in its own color, as many conditions as
% selected, plus each condition's single-trial ERP image.
%
% Options, as a struct or as name/value pairs, use the galea_process_defaults
% names (missing keys keep defaults):
%   'epochwin'     [pre post] epoch window in s                    [-1.5 1.5]
%   'epochevents'  cell of event labels to epoch around, {} = all  [{}]
%   'rejtrials'    reject bad trials                               [false]
%   'rejmethod'    'mean' (conservative), 'median', 'grubbs' (aggressive) ['mean']
%   'plotconds'    cell of event labels to plot, {} = none         [{}]
%                  (each must be one of the epoched events)
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

% ---------------- events to epoch around ----------------
if isempty(EEG.event)
    fprintf('No markers in this recording: no epoching, nothing to plot.\n');
    return
end
% numeric codes become labels (pop_epoch and the lists below compare text)
isNum = cellfun(@isnumeric, {EEG.event.type});
for iE = find(isNum), EEG.event(iE).type = num2str(EEG.event(iE).type); end
types = unique({EEG.event.type});
types = types(~strcmpi(types, 'boundary'));      % data-break markers, not events

evs = galea_cellstr(opt.epochevents);
if isempty(evs)
    evs = types;                                  % {} = every marker in the file
else
    missing = setdiff(evs, types);
    if ~isempty(missing)
        fprintf(2, 'Not in this file, ignored: %s\n', strjoin(missing, ', '));
    end
    evs = evs(ismember(evs, types));
    if isempty(evs)
        fprintf(2, 'None of the requested events is in this file: no epoching.\n');
        return
    end
end

conds = galea_cellstr(opt.plotconds);
notEpoched = setdiff(conds, evs);
if ~isempty(notEpoched)
    fprintf(2, 'Not epoched, so not plotted: %s\n', strjoin(notEpoched, ', '));
    conds = conds(ismember(conds, evs));
end

com = sprintf('EEG = galea_erp_workflow(EEG, %s);', vararg2str({'epochwin', win, ...
    'epochevents', evs, 'rejtrials', logical(opt.rejtrials), 'rejmethod', opt.rejmethod, ...
    'plotconds', conds}));

% ---------------- segment ----------------
EEG = pop_epoch(EEG, evs, win, 'epochinfo','yes');
fprintf('Epoched [%g %g] s around %s: %g epochs.\n', win(1), win(2), strjoin(evs, ', '), EEG.trials);

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
if ~isempty(conds)
    galea_plot_conditions(EEG, conds);
end
end
