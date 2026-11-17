# Violin Acoustic Spectrum Analyzer (browser version)

**Use it here: <https://tmeeha.github.io/inspectra_js/>**

Compares the frequency content of violin recordings supplied as WAV files: bowed glissandi,
scales or musical passages, or bridge taps. It shows long-time-average spectra, compares single
recordings or groups of repeated takes (for example before and after an adjustment), summarises
the energy in frequency bands, checks the pitch range and tuning of played recordings, estimates
the damping of the main body modes from taps, and exports charts and data.

Everything runs in the visitor's browser. Recordings are analysed on the visitor's own computer
and are never uploaded. The app is a set of static files with no build step, so it can be hosted
on GitHub Pages or any web server.

This is a JavaScript port of the Violin Acoustic Spectrum Analyzer first written in R (Shiny).
The analysis was checked against the R version and agrees to within rounding (see [Tests](#tests)).

## Features

- **Recording types:** bowed strings (glissandi, scales, semitones, musical passages) and bridge
  taps, with suitable defaults for each. The type and the groups of repeated takes are
  recognised from the file names; glissandi are also recognised from the pitch track.
- **Spectra:** Welch long-time-average power spectra with a Hann window, optional quiet-frame
  gating, optional restriction to the common pitch range, in-band level normalization and
  fractional-octave smoothing. Taps are detected automatically, windowed exponentially and
  averaged; double hits, clipped taps and taps at the file edges are rejected.
- **Comparisons:** individual recordings, group means with ±1 SE or ≈95% error bands, and
  differences between two groups.
- **Band levels:** Dünnwald regions, Bark critical bands, Curtin 4- and 5-band sets and
  Bark violin zones, with the signature-mode regions (A0, CBR, B1−, B1+, bridge hill) marked
  on the plot.
- **Pitch:** pitch tracking, pitch range and a tuning check that warns when groups differ in
  tuning; a note-level view for played recordings.
- **Mode damping:** peak frequency, Q and damping ratio of A0, B1− and B1+ from tap
  recordings, with a check for ringing open strings.
- **Microphone calibration:** upload the two-column text file supplied with a measurement
  microphone (frequency in Hz, deviation in dB) and its response is subtracted from every
  spectrum.
- **Export:** PNG, SVG and PDF charts and CSV curve data; playback of each recording.

The Read Me tab inside the app (the file `content/readme.md`) is the full user guide: a quick
start, advice on making recordings, a walk-through of every control, the analysis methods and
references.

## Running locally

**Quickest way (no coding or command line):** download the project folder, unzip it, and double-click
the starter for your computer:

- **Windows:** `start.bat`. It uses PowerShell, which is built into Windows. If Windows says it
  protected your PC, choose *More info*, then *Run anyway*.
- **macOS:** `start.command`. It uses Perl, which is built into macOS. The first time, right-click
  (or Control-click) the file, choose *Open*, then *Open* again. If it says it cannot be opened
  because it is not executable, open Terminal once and run `chmod +x start.command` in the folder.
- **Linux:** run `./start.command` in a terminal (Perl is installed on almost every system), or set
  your file manager to run executable text files.

A window opens and then the app opens in your browser. The server runs on this computer only (nothing
is reachable from the network or the internet), and it picks a free port if 8000 is busy. **Keep the
window open while you use the app; close it to stop the server.** To record, allow the microphone
when the browser asks.

The starters run `serve.ps1` (Windows) or `serve.pl` (macOS/Linux). `serve.py` does the same job if
you already have Python 3 (`python serve.py`).

**Or by hand:**

Because the app loads its modules, guide and example files over HTTP, open it through a local
web server rather than directly from the file system. Any static server works, for example:

```
git clone https://github.com/tmeeha/inspectra_js.git
cd inspectra_js
python -m http.server 8000 --bind 127.0.0.1
```

then open <http://localhost:8000/>. The `--bind 127.0.0.1` option keeps the server reachable from this computer only. Recording from a microphone also needs this (or https): browsers allow the microphone only on `localhost` or secure pages. There is nothing to install or build: the three libraries
the app uses (Plotly.js, marked and jsPDF) are bundled in `vendor/`.

To host your own copy, publish the repository with GitHub Pages or copy the files to any web
server. The `.nojekyll` file stops GitHub Pages from processing the files with Jekyll.

## Project layout

```
index.html          the page: sidebar controls, plot area and Read Me tab
css/style.css       styles
js/app.js           application controller: state, controls, file loading, exports
js/analysis.js      analysis pipeline: spectra, groups, pitch box, band and damping tables
js/wav.js           WAV reader (8/16/24/32-bit integer, 32/64-bit float, multichannel)
js/fft.js           FFT
js/dsp.js           Welch and tap spectra, tap detection, mode damping, band powers, smoothing, group summaries
js/pitch.js         pitch tracking, tuning offset, pitch range and note levels
js/stats.js         numeric helpers matching R: rounding, median, quantiles, SD, error-band multipliers
js/plot.js          Plotly figures for the spectrum and note-level views
js/format.js        note names, colours and frequency-axis helpers
js/config.js        limits, defaults, band sets, resonance regions, keywords, examples
content/readme.md   the user guide shown in the Read Me tab
examples/           example recordings loaded by the links in the app
vendor/             bundled libraries (Plotly.js, marked, jsPDF)
tests/              browser tests, reference values and the R script that makes them
```

## Tests

Both test pages run in a browser through a local web server started in the project folder, and
print `DONE <passed> passed, <failed> failed` when finished. See `tests/README.md` for details.

- `tests/test.html` compares the JavaScript analysis with results from the R version, stored in
  `tests/fixtures/reference.json`, on the example recordings and on synthetic test files. It
  covers WAV reading, spectra, gating, tap detection, mode damping, band levels, smoothing,
  normalization, pitch tracking, tuning, note levels, group statistics and the helpers.
  Results agree to about 1e-9 or better.
- `tests/e2e.html` opens the app in a frame, loads the example sets and goes through every
  view, plot mode, setting, message, the zoom and readout, and the exports.

To run them headless, for example with Chrome:

```
python -m http.server 8000
google-chrome --headless=new --virtual-time-budget=600000 --dump-dom http://localhost:8000/tests/test.html
google-chrome --headless=new --virtual-time-budget=900000 --dump-dom http://localhost:8000/tests/e2e.html
```

Regenerating the reference values needs R and the R version of the app in a sibling folder
`../inspectra_r`:

```
Rscript tests/make_reference.R
```

## License

Released under the [MIT License](LICENSE.md).

The bundled libraries in `vendor/` (Plotly.js, marked, jsPDF) keep their own MIT licenses.
