# galea-eeglab-plugin

EEGLAB plugin for importing and preprocessing recordings from the Galea
multimodal VR headset (OpenBCI) — dry-electrode EEG integrated into a Varjo Aero
head-mounted display.

Cedric Cannard, 2026. GPL-3.0 (see LICENSE).

## Install

**From the EEGLAB extension manager (recommended):** in EEGLAB, *File > Manage
extension manager* (or *Tools > Manage extensions* depending on version), search
for **galea**, and install.

**From this repository:** copy or clone this folder into `eeglab/plugins/` and
restart EEGLAB. Either way, a single **Galea** entry appears in the EEGLAB menu
bar. It opens one window that does everything, top to bottom: load a recording
(step 1), then optionally process it (step 2), one section per modality.

Dependencies: none for import/EEG processing. The optional PPG (heart-rate)
branch uses the [BrainBeats](https://github.com/sccn/brainbeats) plugin; the
Galea window finds and installs it automatically if missing.

## What it does

Standard EEGLAB import and cleaning routines assume a gel-based, high-density
montage and a nominal sampling rate. Galea recordings break three of those
assumptions, and this plugin handles each one.

**`pop_galea`** (the menu entry, one window):

- **Load** — reads the plain-text files written by the Galea/OpenBCI GUI. A
  recording is a pair (`OpenBCI-RAW-<date>.txt` with EEG/EOG/EMG +
  `OpenBCI-RAW-Aux-<date>.txt` with PPG/EDA/IMU); select the main file and its
  Aux twin is picked up automatically. The multiplexed streams are split into
  EEG, EOG, EMG, PPG, EDA and IMU (nothing discarded — non-EEG streams stay in
  `EEG.etc.galea`), the sampling rate is derived from the device timestamps
  (the effective rate is typically ~248 Hz, not the advertised 250 Hz, and the
  difference propagates into every latency and wavelet frequency downstream),
  both the stock 10-channel montage and the 12-channel custom montage (the two
  EMG disc electrodes reconfigured as Fp1/Fp2) are supported, and the numeric
  trigger codes are converted into readable event labels for the VR driving
  paradigm.
- **Process** (all optional, per-modality switches):
  - *Trim* — drops the head and tail of the recording around the first and
    last event, for the EEG **and** all auxiliary signals, each at its own
    sampling rate.
  - *Downsample* — with a rate-aware divide-by-1/2/4 helper (detected rate is
    shown next to the field; dividing avoids resampling artefacts at
    non-integer ratios).
  - *Minimum-phase causal bandpass* — keeps the pre-stimulus period free of
    post-stimulus leakage. A zero-phase filter smears post-stimulus activity
    backwards in time and can manufacture anticipatory effects that are
    entirely artefactual; only needed for pre-stimulus analyses.
  - *Polarity correction for the prefrontal disc electrodes*, which the Galea
    amplifier sometimes records with inverted leads (custom montage).
  - *Bad-channel detection tuned for a sparse dry montage* — `clean_rawdata`
    assumes enough neighbours for its correlation criterion to be meaningful;
    with 12 electrodes it does not. This uses a sliding-window combination of
    amplitude outliers and inter-channel correlation, with explicit thresholds.
  - *ASR* with remove (default) or reconstruct mode, plus an optional second,
    stricter pass after ICA.
  - *ICA* with ocular-component removal (eyes-open tasks only).
  - *Peripheral branches* (separate dialog): PPG through BrainBeats with RR
    artefact correction and HRV features, EDA tonic/phasic, EMG envelope,
    IMU magnitude.

## Tutorial

From a raw Galea recording to an ERP, step by step with screenshots:
**[TUTORIAL.md](TUTORIAL.md)**. A runnable script version of the same steps,
with more parameter detail, is [`tutorial_galea.m`](tutorial_galea.m) — open it
in MATLAB and run section by section.

## Sample data

Two sample recordings ship in `sample_data/`:

- **`Sample-Data-OpenBCI-RAW.txt` (+ Aux)** — epoched ERP recording (subject
  sub-005, trials 1-98 of the VR collision study), for trying the full
  preprocessing pipeline.
- **`Sample-Data-OpenBCI-RAW-RestingState.txt` (+ Aux)** — 5.5-minute
  continuous resting-state recording (250 Hz, no markers), for trying the
  import on a continuous dataset.

## Scripting

```matlab
EEG = pop_galea_import('montage', 'custom');
EEG = pop_galea_preprocess(EEG, 'locut', 0.5, 'hicut', 30, 'causal', true);
```

or the one-window route:

```matlab
EEG = pop_galea();
```

Both return an EEGLAB history string, so they work with `eegh` and in batch
scripts. The GUIs and the script interface take identical options.

## Also included

- `find_badTrials.m` — epoch rejection by amplitude and high-frequency
  residual, using a mean-based outlier criterion.
- `capture_gui_screenshots.m` — regeneration of the GUI screenshots in
  `figures/` (requires the MATLAB desktop).

## Citation

Cannard, C., & Yeşilbaş, D. (2026). *Reactive and predictive processes during
unpredictable driving hazards in virtual reality: an exploratory brain and body
study with multimodal neurophysiological monitoring.* The VR driving paradigm
this plugin was built for is replicated by
[github.com/amisepa/galea-vr-driving-hazards](https://github.com/amisepa/galea-vr-driving-hazards).

## License

GPL-3.0. Anyone redistributing the code (including commercial users) must
release their modifications under the same terms; academic use is unaffected.
