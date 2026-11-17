// Microphone recording: raw capture through an AudioWorklet (no echo cancellation, noise
// suppression or automatic gain, which would alter the spectrum) and a 24-bit PCM WAV
// encoder, so a recording goes through exactly the same path as an opened file.

const WORKLET = `
class Capture extends AudioWorkletProcessor {
  constructor() { super(); this.buf = new Float32Array(4096); this.n = 0; this.peak = 0; }
  process(inputs) {
    const ch = inputs[0] && inputs[0][0];
    if (!ch) return true;
    for (let i = 0; i < ch.length; i++) {
      const v = ch[i], a = v < 0 ? -v : v;
      if (a > this.peak) this.peak = a;
      this.buf[this.n++] = v;
      if (this.n === this.buf.length) {
        this.port.postMessage({ chunk: this.buf, peak: this.peak });
        this.buf = new Float32Array(4096); this.n = 0; this.peak = 0;
      }
    }
    return true;
  }
}
registerProcessor("capture", Capture);
`;

// Microphones as [{ id, label }]; labels are only available after microphone permission was given
export async function listMics() {
  const all = await navigator.mediaDevices.enumerateDevices();
  return all.filter((d) => d.kind === "audioinput" && d.deviceId !== "default" && d.deviceId !== "communications")
    .map((d, i) => ({ id: d.deviceId, label: d.label || `Microphone ${i + 1}` }));
}

export const micSupported = () => !!(navigator.mediaDevices?.getUserMedia && window.AudioWorklet && window.isSecureContext);

// 24-bit mono PCM WAV from Float32 samples (full scale = +/-1)
export function encodeWav24(x, fs) {
  const n = x.length, dataLen = n * 3;
  const buf = new ArrayBuffer(44 + dataLen), dv = new DataView(buf);
  const str = (o, s) => { for (let i = 0; i < s.length; i++) dv.setUint8(o + i, s.charCodeAt(i)); };
  str(0, "RIFF"); dv.setUint32(4, 36 + dataLen, true); str(8, "WAVE");
  str(12, "fmt "); dv.setUint32(16, 16, true); dv.setUint16(20, 1, true); dv.setUint16(22, 1, true);
  dv.setUint32(24, fs, true); dv.setUint32(28, fs * 3, true); dv.setUint16(32, 3, true); dv.setUint16(34, 24, true);
  str(36, "data"); dv.setUint32(40, dataLen, true);
  for (let i = 0, p = 44; i < n; i++, p += 3) {
    const v = Math.round(Math.max(-1, Math.min(1, x[i])) * 8388607);
    dv.setUint8(p, v & 255); dv.setUint8(p + 1, (v >> 8) & 255); dv.setUint8(p + 2, (v >> 16) & 255);
  }
  return buf;
}

export class Recorder {
  // onLevel(peak 0..1, clippedSoFar: boolean), onFull(): called when maxSamples is reached
  constructor({ maxSamples, onLevel, onFull }) {
    Object.assign(this, { maxSamples, onLevel, onFull, chunks: [], samples: 0, clipped: false, peak: 0 });
  }

  // deviceId: a microphone chosen from the list, or "" for the system default
  async start(deviceId = "") {
    const audio = { echoCancellation: false, noiseSuppression: false, autoGainControl: false, channelCount: 1 };
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: deviceId ? { ...audio, deviceId: { exact: deviceId } } : audio });
    } catch (e) {
      if (!deviceId || e?.name !== "OverconstrainedError") throw e;
      this.stream = await navigator.mediaDevices.getUserMedia({ audio });      // the chosen device is gone
      this.fellBack = true;
    }
    try {
      this.ctx = new AudioContext();
      const url = URL.createObjectURL(new Blob([WORKLET], { type: "text/javascript" }));
      try { await this.ctx.audioWorklet.addModule(url); } finally { URL.revokeObjectURL(url); }
      this.src = this.ctx.createMediaStreamSource(this.stream);
      this.node = new AudioWorkletNode(this.ctx, "capture", { numberOfOutputs: 1, outputChannelCount: [1] });
      this.mute = this.ctx.createGain(); this.mute.gain.value = 0;      // keeps the graph running, no monitoring
      this.src.connect(this.node); this.node.connect(this.mute); this.mute.connect(this.ctx.destination);
      this.fs = this.ctx.sampleRate;
      this.node.port.onmessage = (e) => {
        if (this.done) return;
        const { chunk, peak } = e.data;
        this.chunks.push(chunk); this.samples += chunk.length;
        if (peak > this.peak) this.peak = peak;
        if (peak >= 0.999) this.clipped = true;
        this.onLevel?.(peak, this.clipped);
        if (this.samples >= this.maxSamples) this.onFull?.();
      };
    } catch (e) { this.release(); throw e; }
    // report anything the browser did not honour
    const s = this.stream.getAudioTracks()[0]?.getSettings?.() ?? {};
    return { processing: !!(s.echoCancellation || s.noiseSuppression || s.autoGainControl), label: this.stream.getAudioTracks()[0]?.label ?? "" };
  }

  release() {
    this.stream?.getTracks().forEach((t) => t.stop());
    try { this.node?.disconnect(); this.src?.disconnect(); this.mute?.disconnect(); } catch { /* already gone */ }
    this.ctx?.close().catch(() => {});
  }

  // Stops and returns { x: Float32Array, fs, peak, clipped }
  stop() {
    this.done = true;
    this.release();
    const n = Math.min(this.samples, this.maxSamples), x = new Float32Array(n);
    let o = 0;
    for (const c of this.chunks) {
      if (o >= n) break;
      const k = Math.min(c.length, n - o);
      x.set(k < c.length ? c.subarray(0, k) : c, o); o += k;
    }
    this.chunks = [];
    return { x, fs: this.fs, peak: this.peak, clipped: this.clipped };
  }
}
