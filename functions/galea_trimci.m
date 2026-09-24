%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function [tm, lo, hi, n] = galea_trimci(X, pct, alpha)
%GALEA_TRIMCI  Trimmed mean and its confidence interval, along columns.
%
%   >> [tm, lo, hi] = galea_trimci(X)             % 20% trimming, 95% CI
%   >> [tm, lo, hi, n] = galea_trimci(X, pct, alpha)
%
% X is points x observations (e.g. time x trials); each row is summarised
% across its columns. PCT is the percentage trimmed from EACH tail (default
% 20) and ALPHA the error rate of the interval (default 0.05, a 95% CI).
%
% The interval is the Tukey-McLaughlin one used for trimmed means (Wilcox's
% trimci): the standard error comes from the winsorized variance,
%   se = sqrt(var(winsorized X)) / ((1 - 2*pct/100) * sqrt(n)),
% with n - 2g - 1 degrees of freedom, g = floor(pct/100 * n) values trimmed
% per tail. Same result as scipy.stats.mstats.trimmed_mean_ci.
%
% No toolbox needed: the t quantile comes from betaincinv.
%
% Reference: Wilcox, R. R. (2012). Introduction to Robust Estimation and
% Hypothesis Testing (3rd ed.), sections 3.3 and 4.4.
%
% Cedric Cannard, 2026

if nargin < 2 || isempty(pct),   pct = 20;      end
if nargin < 3 || isempty(alpha), alpha = 0.05;  end

X = double(X);
n = size(X, 2);
g = floor(pct/100 * n);
Xs = sort(X, 2);
tm = mean(Xs(:, g+1:n-g), 2);

lo = nan(size(tm));  hi = nan(size(tm));
df = n - 2*g - 1;
if df < 1
    return                                    % too few observations for an interval
end

% winsorize: the g lowest / highest values take the next value inward
W = Xs;
if g > 0
    W(:, 1:g)       = repmat(Xs(:, g+1), 1, g);
    W(:, n-g+1:n)   = repmat(Xs(:, n-g), 1, g);
end
se = std(W, 0, 2) ./ ((1 - 2*pct/100) * sqrt(n));

% two-sided t quantile, t(1 - alpha/2, df), without the Statistics Toolbox
t = sqrt(df * (1 / betaincinv(alpha, df/2, 0.5) - 1));

lo = tm - t .* se;
hi = tm + t .* se;
end
