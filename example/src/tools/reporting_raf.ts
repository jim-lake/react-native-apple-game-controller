export type Handle = { cancel: () => void };

export type ReportingParams = {
  work: (t: number) => void;
  fpsReporter?: (fps: number) => void;
  fpsInterval?: number;
};

const FPS = 120;
const FRAME_TIME = 1000 / FPS;
const MIN_DELAY = FRAME_TIME / 5;

export function startReportingRAF(params: ReportingParams): Handle {
  const { work, fpsReporter, fpsInterval = 5000 } = params;

  let running = true;

  let frames = 0;
  let start = Date.now();

  let nextFrameTime = Date.now();

  let frameTimer: any = 0;
  let fpsTimer: any = 0;

  function loop() {
    if (!running) {
      return;
    }

    const now = Date.now();

    work(now);
    frames++;

    nextFrameTime += FRAME_TIME;

    const rawDelay = nextFrameTime - Date.now();

    // clamp delay so we never go into ultra-tight spinning
    const delay = Math.max(MIN_DELAY, Math.min(FRAME_TIME, rawDelay));

    frameTimer = setTimeout(loop, delay);
  }

  function fpsLoop() {
    if (!running) {
      return;
    }

    const now = Date.now();
    const elapsed = now - start;

    if (elapsed > 0) {
      fpsReporter?.((frames * 1000) / elapsed);
    }

    frames = 0;
    start = now;

    fpsTimer = setTimeout(fpsLoop, fpsInterval);
  }

  const now = Date.now();
  nextFrameTime = now + FRAME_TIME;

  frameTimer = setTimeout(loop, FRAME_TIME);
  fpsTimer = setTimeout(fpsLoop, fpsInterval);

  return {
    cancel() {
      running = false;
      clearTimeout(frameTimer);
      clearTimeout(fpsTimer);
    },
  };
}

export function cancelReportingRAF(handle: Handle): void {
  handle.cancel();
}
