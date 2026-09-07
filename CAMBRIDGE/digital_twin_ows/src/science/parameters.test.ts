import { describe, expect, it } from 'vitest'
import { createOpticalParameters, normalizeOpticalParameters, OPTICAL_LIMITS } from './parameters'

describe('optical parameter defaults and normalization', () => {
  it('matches the MATLAB optical and noise baseline', () => {
    expect(createOpticalParameters()).toEqual({
      halfPowerAngleDeg: 45,
      detectorAreaM2: 4.8e-3 * 5.5e-3,
      fovHalfAngleDeg: 85,
      noise: { enabled: false, varianceW2: 30e6 * 10 ** -21, averagingSamples: 1000, seed: 42 },
    })
    const first = createOpticalParameters()
    first.noise.seed = 1
    expect(createOpticalParameters().noise.seed).toBe(42)
  })

  it('publishes all physical UI limits', () => {
    expect(OPTICAL_LIMITS).toEqual({
      halfPowerAngleDeg: { min: 1, max: 89 },
      detectorAreaM2: { min: 1e-8, max: 1e-4 },
      fovHalfAngleDeg: { min: 1, max: 90 },
      varianceW2: { min: 0, max: 1e-8 },
      averagingSamples: { min: 1, max: 1e6 },
      seed: { min: 0, max: 4294967295 },
    })
  })

  it.each([undefined, null, false, 10, '45', [], [45]])('defaults malformed root %j', (value) => {
    expect(normalizeOpticalParameters(value)).toEqual(createOpticalParameters())
  })

  it('does not coerce strings, booleans, NaN, infinity or inherited fields', () => {
    expect(normalizeOpticalParameters({
      halfPowerAngleDeg: '60', detectorAreaM2: NaN, fovHalfAngleDeg: Infinity,
      noise: { enabled: 'true', varianceW2: -Infinity, averagingSamples: true, seed: '1' },
    })).toEqual(createOpticalParameters())
    expect(normalizeOpticalParameters(Object.create({
      halfPowerAngleDeg: 60, detectorAreaM2: 1e-4, fovHalfAngleDeg: 90,
      noise: { enabled: true },
    }))).toEqual(createOpticalParameters())
    expect(normalizeOpticalParameters({ noise: Object.create({ enabled: true, seed: 7 }) }))
      .toEqual(createOpticalParameters())
  })

  it('ignores accessor fields without executing them', () => {
    const value = Object.defineProperty({}, 'halfPowerAngleDeg', { get() { throw new Error('accessor') } })
    expect(normalizeOpticalParameters(value)).toEqual(createOpticalParameters())
  })

  it('clamps finite fields and rounds integer counts and seeds without mutating input', () => {
    const input = Object.freeze({
      halfPowerAngleDeg: -2, detectorAreaM2: 2, fovHalfAngleDeg: 200,
      noise: Object.freeze({ enabled: true, varianceW2: -1, averagingSamples: 2.7, seed: 4.2 }),
    })
    expect(normalizeOpticalParameters(input)).toEqual({
      halfPowerAngleDeg: 1, detectorAreaM2: 1e-4, fovHalfAngleDeg: 90,
      noise: { enabled: true, varianceW2: 0, averagingSamples: 3, seed: 4 },
    })
    expect(normalizeOpticalParameters({
      halfPowerAngleDeg: 100, detectorAreaM2: -1, fovHalfAngleDeg: -1,
      noise: { varianceW2: 1, averagingSamples: 1e20, seed: 1e20 },
    })).toEqual({
      halfPowerAngleDeg: 89, detectorAreaM2: 1e-8, fovHalfAngleDeg: 1,
      noise: { enabled: false, varianceW2: 1e-8, averagingSamples: 1e6, seed: 4294967295 },
    })
    expect(normalizeOpticalParameters({ noise: { averagingSamples: -1, seed: -1 } }).noise)
      .toEqual({ enabled: false, varianceW2: 30e6 * 10 ** -21, averagingSamples: 1, seed: 0 })
  })

  it('preserves valid own fields, discards unknown keys and is idempotent', () => {
    const result = normalizeOpticalParameters({
      halfPowerAngleDeg: 30, detectorAreaM2: 2e-5, fovHalfAngleDeg: 60,
      noise: { enabled: true, varianceW2: 1e-12, averagingSamples: 5, seed: 0, unknown: true },
      unknown: 'discard',
    })
    expect(result).toEqual({
      halfPowerAngleDeg: 30, detectorAreaM2: 2e-5, fovHalfAngleDeg: 60,
      noise: { enabled: true, varianceW2: 1e-12, averagingSamples: 5, seed: 0 },
    })
    expect(normalizeOpticalParameters(result)).toEqual(result)
  })
})
