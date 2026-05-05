export function createBrowserCameraAdapter({
  mediaDevices = globalThis.navigator?.mediaDevices,
  qrDecoder,
  constraints = { video: { facingMode: "environment" }, audio: false },
} = {}) {
  if (!mediaDevices || typeof mediaDevices.getUserMedia !== "function") {
    throw new TypeError("SDK_ERR_EXAMPLE_MEDIA_DEVICES_MISSING");
  }
  if (typeof qrDecoder !== "function") {
    throw new TypeError("SDK_ERR_EXAMPLE_QR_DECODER_MISSING");
  }

  let stream = null;

  return {
    async start(videoElement) {
      stream = await mediaDevices.getUserMedia(constraints);
      if (videoElement) {
        videoElement.srcObject = stream;
        if (typeof videoElement.play === "function") {
          await videoElement.play();
        }
      }
      return stream;
    },

    async scanOnce(source) {
      const qrString = await qrDecoder(source);
      return toCameraPayload(qrString, "camera");
    },

    stop() {
      for (const track of stream?.getTracks?.() ?? []) {
        track.stop();
      }
      stream = null;
    },
  };
}

export function createInjectedCameraAdapter(qrStrings) {
  const pending = [...qrStrings];
  return {
    async scanOnce() {
      const qrString = pending.shift();
      return toCameraPayload(qrString, "injected");
    },
    stop() {},
  };
}

function toCameraPayload(qrString, source) {
  if (typeof qrString !== "string" || qrString.trim().length === 0) {
    throw new Error("SDK_ERR_EXAMPLE_CAMERA_DECODE_EMPTY");
  }
  return {
    qrString: qrString.trim(),
    source,
  };
}
