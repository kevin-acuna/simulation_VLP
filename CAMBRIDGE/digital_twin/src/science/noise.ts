import { evaluateScene } from './los'
import type { NoiseParameters, OpticalScene, RssChannel } from './types'

export function createGaussianGenerator(seed: number): () => number {
  if (!Number.isInteger(seed) || seed < 0 || seed > 4294967295) {
    throw new RangeError('Gaussian seed must be an unsigned 32-bit integer')
  }
  let state = seed >>> 0
  let spare: number | undefined
  const uniform = (): number => {
    state = (state + 0x6d2b79f5) >>> 0
    let value = state
    value = Math.imul(value ^ (value >>> 15), value | 1)
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61)
    return (((value ^ (value >>> 14)) >>> 0) + 0.5) / 4294967296
  }
  return () => {
    if (spare !== undefined) {
      const value = spare
      spare = undefined
      return value
    }
    const radius = Math.sqrt(-2 * Math.log(uniform()))
    const angle = 2 * Math.PI * uniform()
    spare = radius * Math.sin(angle)
    return radius * Math.cos(angle)
  }
}

export function noiseStandardDeviation(noise: NoiseParameters): number {
  if (noise.enabled === false) return 0
  if (noise.enabled !== true || !Number.isFinite(noise.varianceW2) || noise.varianceW2 < 0) {
    throw new RangeError('Enabled optical noise variance must be finite and nonnegative')
  }
  if (!Number.isSafeInteger(noise.averagingSamples) || noise.averagingSamples < 1) {
    throw new RangeError('Noise averaging count must be a positive safe integer')
  }
  return Math.sqrt(noise.varianceW2 / noise.averagingSamples)
}

export function sampleRss(scene: OpticalScene, noise: NoiseParameters, gaussian: () => number): RssChannel[] {
  const standardDeviationW = noiseStandardDeviation(noise)
  return evaluateScene(scene).map((channel) => {
    const sample = standardDeviationW === 0 ? 0 : gaussian()
    if (!Number.isFinite(sample)) throw new RangeError('Gaussian sample must be finite')
    const rssW = channel.powerW + standardDeviationW * sample
    if (!Number.isFinite(rssW)) throw new RangeError('RSS estimate exceeds the finite numerical range')
    return { ...channel, rssW, standardDeviationW }
  })
}
