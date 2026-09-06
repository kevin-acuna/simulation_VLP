import { describe, expect, it } from 'vitest'
import { fromNoiseSigmaNanowatts, fromSquareMillimeters, toMicrowatts, toNoiseSigmaNanowatts, toSquareMillimeters } from './units'
import { MODEL_ASSUMPTIONS, MODEL_ID } from './index'

describe('explicit optical unit conversions and public model metadata', () => {
  it('converts watts to microwatts, retaining signed noisy values', () => {
    expect(toMicrowatts(2e-6)).toBe(2)
    expect(toMicrowatts(-2e-6)).toBe(-2)
  })

  it('round trips active area in square metres and square millimetres', () => {
    expect(toSquareMillimeters(4.8e-3 * 5.5e-3)).toBeCloseTo(26.4, 12)
    expect(fromSquareMillimeters(26.4)).toBeCloseTo(4.8e-3 * 5.5e-3, 18)
    expect(fromSquareMillimeters(toSquareMillimeters(1e-8))).toBe(1e-8)
    expect(toSquareMillimeters(1e-4)).toBe(100)
  })

  it('converts per-sample variance to sigma in nanowatts, not averaged sigma', () => {
    expect(toNoiseSigmaNanowatts(3e-14)).toBeCloseTo(Math.sqrt(3e-14) * 1e9, 12)
    expect(fromNoiseSigmaNanowatts(100)).toBeCloseTo(1e-14, 26)
    expect(fromNoiseSigmaNanowatts(toNoiseSigmaNanowatts(3e-14))).toBeCloseTo(3e-14, 26)
    expect(toNoiseSigmaNanowatts(0)).toBe(0)
    expect(fromNoiseSigmaNanowatts(0)).toBe(0)
  })

  it('rejects nonfinite inputs and negative areas, variances and sigmas', () => {
    for (const convert of [toMicrowatts, toSquareMillimeters, fromSquareMillimeters, toNoiseSigmaNanowatts, fromNoiseSigmaNanowatts]) {
      expect(() => convert(NaN)).toThrow(RangeError)
      expect(() => convert(Infinity)).toThrow(RangeError)
    }
    for (const convert of [toSquareMillimeters, fromSquareMillimeters, toNoiseSigmaNanowatts, fromNoiseSigmaNanowatts]) {
      expect(() => convert(-1)).toThrow(RangeError)
    }
  })

  it('exports stable model identification and readable assumptions', () => {
    expect(MODEL_ID).toBe('lambertian-los-v1')
    const text = MODEL_ASSUMPTIONS.join(' ').toLowerCase()
    for (const expected of ['nlos', 'obstruction', 'fdm', 'bandwidth', 'anchor', 'housing', 'detector center', 'active', 'gaussian', 'independent', 'matlab']) {
      expect(text).toContain(expected)
    }
  })
})
