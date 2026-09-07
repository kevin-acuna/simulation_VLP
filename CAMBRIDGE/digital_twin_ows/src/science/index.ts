export type { ChannelStatus, LosChannel, NoiseParameters, OpticalDetector, OpticalEmitter, OpticalParameters, OpticalScene, RssChannel, Vector3 } from './types'
export { createOpticalParameters, normalizeOpticalParameters, OPTICAL_LIMITS } from './parameters'
export { evaluateLos, evaluateScene, lambertianOrder } from './los'
export { createGaussianGenerator, noiseStandardDeviation, sampleRss } from './noise'
export { fromNoiseSigmaNanowatts, fromSquareMillimeters, toMicrowatts, toNoiseSigmaNanowatts, toSquareMillimeters } from './units'

export const MODEL_ID = 'lambertian-los-v1'

export const MODEL_ASSUMPTIONS = Object.freeze([
  'Unobstructed Lambertian point-source LOS only; no NLOS reflections or obstruction testing.',
  'Small-detector approximation; not finite-aperture integration or validated near-field/contact radiometry.',
  'Bare photodetector cosine response within its half-angle FOV; no lens, concentrator or optical filter gain.',
  'Ideal LED channel separation; no FDM waveforms or driver bandwidth model.',
  'LED positions are optical reference anchors and exclude decorative housing offsets.',
  'PD position is the actual detector center, not the receiver platform center.',
  'Detector area is the active sensitive area, not the mesh package footprint.',
  'Additive Gaussian optical-domain noise has independent samples and channels; averaging N samples divides variance by N.',
  'RSS estimates are signed and unclipped; optical responsivity and electrical front-end effects are not modeled.',
  'The seeded Mulberry32 and Box-Muller RNG is reproducible but does not reproduce the MATLAB random sequence.',
  'Inputs use right-handed Z-up coordinates in metres, angles in degrees, optical powers in watts, active area in square metres and variance in square watts.',
])
