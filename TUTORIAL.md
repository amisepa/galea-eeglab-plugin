<!-- Part of the galea-eeglab-plugin repository. GPL-3.0 (c) 2026 Cedric Cannard. -->

# Tutorial: from a raw Galea recording to an ERP

This walkthrough takes a raw recording from the Galea multimodal headset
(OpenBCI) to a condition-average ERP, entirely through the EEGLAB plugin. It
takes about ten minutes, and everything shown works on the sample data shipped
in [`sample_data/`](sample_data/). A
runnable script version of the same steps, with more detail on each parameter,
is [`tutorial_galea.m`](tutorial_galea.m)
— open it in MATLAB and run it section by section.

### 1. Install

Copy (or clone) `galea_eeglab_plugin/` into `eeglab/plugins/` and restart
EEGLAB. A single **Galea** entry appears in the EEGLAB menu bar.

You also need the
[BrainBeats](https://github.com/amisepa/BrainBeats) plugin if you want the PPG
branch (heart rate); the plugin finds it for you if it is installed.

### 2. About the files

A Galea recording is a **pair** of plain-text files written by the Galea /
OpenBCI GUI, and both must sit in the same folder:

```
OpenBCI-RAW-<date>.txt        EEG, EOG, EMG      <- you select this one
OpenBCI-RAW-Aux-<date>.txt    PPG, EDA, IMU      <- found automatically
```

Select the main file only; the plugin picks up its Aux twin itself.

### 3. Load a recording

**Menu: Galea** (this opens one window that does everything, top to bottom).

1. Click **Select file...** and choose the main `OpenBCI-RAW-*.txt` file.
2. Choose the montage:
   - **default** — the stock 10-EEG layout. The two spare ExG channels stay as
     EMG (kept in `EEG.etc.galea.EMG`).
   - **custom** — 12 EEG, where the two EMG disc electrodes become Fp1/Fp2.
     Only use this if you actually reconfigured those electrodes as EEG in the
     Galea software *when recording* — otherwise you would be relabelling
     facial EMG as brain data.
3. Optionally tick **Preprocess with customized methods (Cannard 2026)** to go
   straight to step 3.

![Import dialog](figures/gui_import.png)

The import splits the multiplexed streams into EEG, EOG, EMG, PPG, EDA and IMU
(non-EEG streams are kept in `EEG.etc.galea`, nothing is discarded), sets the
sampling rate from the device itself — the effective rate is typically ~248 Hz,
not the advertised 250 Hz, and that difference propagates into every latency
downstream — and converts the numeric trigger codes into readable event labels
when the file comes from the VR driving paradigm.

### 4. Process

Tick **2. Process using the plugin's custom methods**. Every section below is
optional and each can be switched off individually.

![Preprocessing dialog](figures/gui_preprocess.png)

- **Trim (all signals)** — removes data before the first event and after the
  last event, plus a pad. Applies to the EEG *and* all auxiliary signals. `0`
  keeps everything.
- **EEG**
  - *Bandpass* — 0.5–30 Hz for ERP work.
  - *Causal minimum-phase filter* — tick this for any **pre-stimulus**
    analysis. A zero-phase filter smears post-stimulus activity backwards in
    time and can manufacture an anticipatory effect that is entirely
    artefactual. Leave unticked for post-stimulus-only analyses.
  - *Bad-channel detection* — tuned for a sparse dry montage (12 electrodes),
    where `clean_rawdata`'s correlation criterion is unreliable. Defaults:
    correlation threshold 0.55, at most 30% of windows tolerated. Tick
    **Interpolate** if you want the flagged channels replaced.
  - *ASR (artifact subspace reconstruction)* — default threshold 100 in
    **remove** mode (flagged segments deleted; any event markers inside them
    are listed in the command window). Use *reconstruct* if you must keep every
    trial. A lenient first pass is deliberate: it deletes only the worst
    segments while leaving ocular activity, so ICA can separate the blink
    source cleanly.
  - *ICA, remove the ocular component* — eyes-open tasks only.
  - *ASR pass after ICA* — optional second, stricter pass (default off).
  - Tick **Plot EEG before / after** to see what was done.
- **Peripheral signals** — click **Set PPG / EDA / EMG / IMU options...** for
  the heart-rate, EDA, EMG and IMU branches, each with its own parameters and
  plot option.

![Peripheral signals dialog](figures/gui_periph.png)

Click **Run**.

### 5. Epoch

Processing runs on continuous data; epoching and ERPs come from the standard
EEGLAB menus. Eyeball the cleaned signal first (**Plot > Channel data and
scroll**), then **Tools > Extract epochs**: cut `[-1.5 1.5]` s around the event
of interest (e.g. `tire_pop` — the tyre blowout). Leave *baseline removal*
off, so the pre- and post-stimulus periods stay comparable.

### 6. Average and plot

Compute the condition average with **Tools > Average across files or across
channels > Average over trials** (or, in the script version,
`pop_select` + `mean(SET.data, 3)`), then plot with
**Plot > Channel data and scalp maps > Channel ERPs**.

### 7. Where to go next

- Epoch rejection by amplitude and high-frequency residual:
  `functions/find_badTrials.m`
- The full study pipeline this plugin was built for:
  [github.com/amisepa/galea-vr-driving-hazards](https://github.com/amisepa/galea-vr-driving-hazards)
- A continuous (resting-state, no markers) sample recording for trying the
  import on a continuous dataset:
  [`sample_data/`](sample_data/)

