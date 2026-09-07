import { describe, expect, it } from 'vitest'
import { evaluateLos } from './los'
import { createOpticalParameters } from './parameters'
import { MODEL_ID } from './index'
import type { ChannelStatus, OpticalDetector, OpticalEmitter } from './types'
import referenceData from './validation/los-reference.json'

interface ReferenceCase {
  id: string
  emitter: OpticalEmitter
  detector: OpticalDetector
  expected: {
    powerW: number
    distanceM: number
    irradianceAngleDeg: number
    incidenceAngleDeg: number
    status: ChannelStatus
  }
}

const cases = referenceData.cases as unknown as ReferenceCase[]

describe('actual MATLAB rx_powers reference', () => {
  it('records provenance, units, baseline and deliberate coverage', () => {
    expect(referenceData.metadata.modelId).toBe(MODEL_ID)
    expect(referenceData.metadata.sourceFunctions).toEqual(['poc_params', 'rx_powers', 'rotm_zyx'])
    expect(referenceData.metadata.sourceRelativePath).toBe('../../../../simulations/PoC')
    expect(referenceData.metadata.generator).toBe('generate_reference.m')
    expect(referenceData.metadata.matlabRelease).toBeTruthy()
    expect(referenceData.metadata.units).toEqual({ position: 'm', normal: 'unit vector', power: 'W', area: 'm^2', angles: 'deg', variance: 'W^2' })
    const defaults = createOpticalParameters()
    expect(referenceData.baseline.halfPowerAngleDeg).toBe(defaults.halfPowerAngleDeg)
    expect(referenceData.baseline.detectorAreaM2).toBe(defaults.detectorAreaM2)
    expect(referenceData.baseline.fovHalfAngleDeg).toBe(defaults.fovHalfAngleDeg)
    expect(referenceData.baseline.varianceW2).toBeCloseTo(defaults.noise.varianceW2, 27)
    expect(referenceData.baseline.averagingSamples).toBe(defaults.noise.averagingSamples)
    expect(cases.length).toBeGreaterThanOrEqual(30)
    expect(new Set(cases.map((row) => row.id)).size).toBe(cases.length)
    for (const prefix of ['center', 'lateral', 'height', 'tilt', 'attitude', 'power', 'half-angle', 'area', 'fov', 'emission']) {
      expect(cases.some((row) => row.id.startsWith(prefix))).toBe(true)
    }
    expect(new Set(cases.map((row) => row.expected.status))).toEqual(new Set(['los', 'outside-fov', 'outside-emission', 'off']))
  })

  it.each(cases)('$id agrees with original MATLAB optical power, geometry and masks', ({ emitter, detector, expected }) => {
    const actual = evaluateLos(emitter, detector)
    expect(actual.status).toBe(expected.status)
    if (expected.powerW === 0) expect(actual.powerW).toBe(0)
    else expect(Math.abs(actual.powerW - expected.powerW)).toBeLessThanOrEqual(Math.abs(expected.powerW) * 1e-11 + 1e-18)
    expect(Math.abs(actual.distanceM - expected.distanceM)).toBeLessThanOrEqual(expected.distanceM * 1e-12)
    expect(Math.abs(actual.irradianceAngleDeg - expected.irradianceAngleDeg)).toBeLessThanOrEqual(2e-6)
    expect(Math.abs(actual.incidenceAngleDeg - expected.incidenceAngleDeg)).toBeLessThanOrEqual(2e-6)
    expect(Math.abs(expected.incidenceAngleDeg - detector.fovHalfAngleDeg)).toBeGreaterThan(0.01)
  })
})
