import { describe, expect, it, vi } from 'vitest'
import { createGaussianGenerator, noiseStandardDeviation, sampleRss } from './noise'
import { createOpticalParameters } from './parameters'
import type { NoiseParameters, OpticalScene } from './types'

const scene: OpticalScene = {
  emitters: [{ id: 'anchor', position: [0, 0, 2], normal: [0, 0, -1], powerW: 0.405, halfPowerAngleDeg: 45 }],
  detector: { position: [0, 0, 0], normal: [0, 0, 1], areaM2: 2.64e-5, fovHalfAngleDeg: 85 },
}
const enabledNoise: NoiseParameters = { enabled: true, varianceW2: 3e-14, averagingSamples: 1000, seed: 42 }

describe('seeded Gaussian optical-domain noise', () => {
  it('disables noise by default and skips random sampling with zero sigma', () => {
    const gaussian = vi.fn(() => 3)
    for (const noise of [createOpticalParameters().noise, { ...enabledNoise, varianceW2: 0 }]) {
      expect(noiseStandardDeviation(noise)).toBe(0)
      const [channel] = sampleRss(scene, noise, gaussian)
      expect(channel.rssW).toBe(channel.powerW)
      expect(channel.standardDeviationW).toBe(0)
    }
    expect(gaussian).not.toHaveBeenCalled()
  })

  it('reduces standard deviation by sqrt(N), not N', () => {
    expect(noiseStandardDeviation(enabledNoise)).toBeCloseTo(Math.sqrt(3e-17), 20)
    const one = noiseStandardDeviation({ ...enabledNoise, averagingSamples: 1 })
    const hundred = noiseStandardDeviation({ ...enabledNoise, averagingSamples: 100 })
    expect(one / hundred).toBeCloseTo(10, 14)
  })

  it('adds an unclipped signed estimate without changing ideal power', () => {
    const noise = { ...enabledNoise, varianceW2: 1e-8, averagingSamples: 1 }
    const [channel] = sampleRss(scene, noise, () => -2)
    expect(channel.powerW).toBeGreaterThan(0)
    expect(channel.rssW).toBeLessThan(0)
    expect(channel.rssW).toBe(channel.powerW - 2e-4)
    expect(channel.standardDeviationW).toBe(1e-4)
  })

  it('samples all separated channels including zero-signal channels independently', () => {
    const gaussian = vi.fn().mockReturnValueOnce(1).mockReturnValueOnce(-1)
    const channels = sampleRss({ ...scene, emitters: [scene.emitters[0], { ...scene.emitters[0], id: 'off', powerW: 0 }] }, enabledNoise, gaussian)
    expect(gaussian).toHaveBeenCalledTimes(2)
    expect(channels[0].rssW).toBe(channels[0].powerW + channels[0].standardDeviationW)
    expect(channels[1].status).toBe('off')
    expect(channels[1].rssW).toBe(-channels[1].standardDeviationW)
    expect(sampleRss({ ...scene, emitters: [] }, enabledNoise, gaussian)).toEqual([])
    expect(gaussian).toHaveBeenCalledTimes(2)
  })

  it.each([0, 42, 4294967295])('is reproducible for uint32 seed %i', (seed) => {
    const first = createGaussianGenerator(seed)
    const second = createGaussianGenerator(seed)
    const values = Array.from({ length: 101 }, () => first())
    expect(values).toEqual(Array.from({ length: 101 }, () => second()))
    expect(values.every(Number.isFinite)).toBe(true)
    expect(new Set(values).size).toBe(values.length)
  })

  it('uses distinct seeded streams without consulting Math.random', () => {
    const random = vi.spyOn(Math, 'random').mockImplementation(() => { throw new Error('unseeded RNG') })
    try {
      const first = createGaussianGenerator(0)
      const second = createGaussianGenerator(1)
      expect(Array.from({ length: 20 }, () => first())).not.toEqual(Array.from({ length: 20 }, () => second()))
    } finally {
      random.mockRestore()
    }
  })

  it('has near-zero mean, unit variance, and negligible adjacent correlation', () => {
    const gaussian = createGaussianGenerator(42)
    const count = 100000
    let sum = 0
    let squares = 0
    let adjacentProducts = 0
    let previous = 0
    for (let i = 0; i < count; i += 1) {
      const value = gaussian()
      sum += value
      squares += value * value
      adjacentProducts += value * previous
      previous = value
    }
    expect(Math.abs(sum / count)).toBeLessThan(0.015)
    expect(Math.abs(squares / count - (sum / count) ** 2 - 1)).toBeLessThan(0.025)
    expect(Math.abs(adjacentProducts / (count - 1))).toBeLessThan(0.02)
  })

  it('produces the requested averaged optical noise variance in RSS samples', () => {
    const gaussian = createGaussianGenerator(17)
    const count = 20000
    let sum = 0
    let squares = 0
    for (let i = 0; i < count; i += 1) {
      const [channel] = sampleRss(scene, enabledNoise, gaussian)
      const error = channel.rssW - channel.powerW
      sum += error
      squares += error * error
    }
    const variance = squares / count - (sum / count) ** 2
    expect(variance / (enabledNoise.varianceW2 / enabledNoise.averagingSamples)).toBeCloseTo(1, 1)
    expect(Math.abs(sum / count) / noiseStandardDeviation(enabledNoise)).toBeLessThan(0.025)
  })

  it.each([-1, 1.5, 4294967296, NaN, Infinity, '42'])('rejects invalid seed %s', (seed) => {
    expect(() => createGaussianGenerator(seed as number)).toThrow(RangeError)
  })

  it.each([
    { varianceW2: -1 }, { varianceW2: Infinity }, { varianceW2: NaN },
    { averagingSamples: 0 }, { averagingSamples: 1.5 }, { averagingSamples: Infinity },
  ])('rejects invalid enabled noise %j', (override) => {
    expect(() => noiseStandardDeviation({ ...enabledNoise, ...override })).toThrow(RangeError)
  })

  it.each([NaN, Infinity, -Infinity])('rejects nonfinite Gaussian samples %s', (value) => {
    expect(() => sampleRss(scene, enabledNoise, () => value)).toThrow(RangeError)
  })
})
