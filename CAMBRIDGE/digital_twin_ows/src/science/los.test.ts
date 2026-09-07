import { describe, expect, it } from 'vitest'
import { evaluateLos, evaluateScene, lambertianOrder } from './los'
import type { OpticalDetector, OpticalEmitter, Vector3 } from './types'

const emitter: OpticalEmitter = {
  id: 'anchor', position: [0, 0, 2], normal: [0, 0, -1], powerW: 0.405, halfPowerAngleDeg: 45,
}
const detector: OpticalDetector = {
  position: [0, 0, 0], normal: [0, 0, 1], areaM2: 4.8e-3 * 5.5e-3, fovHalfAngleDeg: 85,
}

function closeRelative(actual: number, expected: number) {
  expect(Math.abs(actual - expected)).toBeLessThanOrEqual(Math.abs(expected) * 1e-12 + 1e-20)
}

describe('Lambertian unobstructed LOS', () => {
  it('has order two at 45 degrees and one at 60 degrees', () => {
    expect(lambertianOrder(45)).toBeCloseTo(2, 14)
    expect(lambertianOrder(60)).toBeCloseTo(1, 14)
  })

  it('matches the independent on-axis closed form', () => {
    const channel = evaluateLos(emitter, detector)
    expect(channel).toMatchObject({ id: 'anchor', status: 'los', distanceM: 2, irradianceAngleDeg: 0, incidenceAngleDeg: 0 })
    closeRelative(channel.powerW, 0.405 * 3 * detector.areaM2 / (8 * Math.PI))
  })

  it('scales as inverse square distance on the optical axis', () => {
    const close = evaluateLos(emitter, { ...detector, position: [0, 0, 1] })
    closeRelative(close.powerW / evaluateLos(emitter, detector).powerW, 4)
  })

  it('scales linearly with transmitted optical power and active detector area', () => {
    const baseline = evaluateLos(emitter, detector).powerW
    closeRelative(evaluateLos({ ...emitter, powerW: emitter.powerW * 3 }, detector).powerW, baseline * 3)
    closeRelative(evaluateLos(emitter, { ...detector, areaM2: detector.areaM2 * 2 }).powerW, baseline * 2)
  })

  it('decreases monotonically laterally at fixed height and matches the off-axis closed form', () => {
    let previous = Infinity
    for (const x of [0, 0.25, 0.5, 1, 1.5]) {
      const power = evaluateLos(emitter, { ...detector, position: [x, 0, 0] }).powerW
      expect(power).toBeLessThan(previous)
      closeRelative(power, 0.405 * 3 * detector.areaM2 * 2 ** 3 / (2 * Math.PI * (x * x + 4) ** 2.5))
      previous = power
    }
  })

  it('normalizes normals and leaves frozen inputs untouched', () => {
    const scaledEmitter = Object.freeze({ ...emitter, normal: Object.freeze([0, 0, -8] as const) })
    const scaledDetector = Object.freeze({ ...detector, normal: Object.freeze([0, 0, 3] as const) })
    expect(evaluateLos(scaledEmitter, scaledDetector)).toEqual(evaluateLos(emitter, detector))
    expect(scaledEmitter.normal).toEqual([0, 0, -8])
    expect(scaledDetector.normal).toEqual([0, 0, 3])
  })

  it('reports both physical angles', () => {
    const channel = evaluateLos(emitter, { ...detector, position: [2, 0, 0] })
    expect(channel.distanceM).toBeCloseTo(Math.sqrt(8), 14)
    expect(channel.irradianceAngleDeg).toBeCloseTo(45, 12)
    expect(channel.incidenceAngleDeg).toBeCloseTo(45, 12)
  })

  it('includes the FOV edge and excludes clearly outside angles', () => {
    const tilted = (degrees: number): OpticalDetector => ({
      ...detector, fovHalfAngleDeg: 60,
      normal: [Math.sin(degrees * Math.PI / 180), 0, Math.cos(degrees * Math.PI / 180)],
    })
    expect(evaluateLos(emitter, tilted(60 - 1e-7)).status).toBe('los')
    expect(evaluateLos(emitter, tilted(60)).status).toBe('los')
    expect(evaluateLos(emitter, tilted(60 + 1e-7))).toMatchObject({ status: 'outside-fov', powerW: 0 })
  })

  it('returns zero for detector backface, emission backface, tangency and power off', () => {
    expect(evaluateLos(emitter, { ...detector, normal: [0, 0, -1] })).toMatchObject({ status: 'outside-fov', powerW: 0, incidenceAngleDeg: 180 })
    expect(evaluateLos({ ...emitter, normal: [0, 0, 1] }, detector)).toMatchObject({ status: 'outside-emission', powerW: 0, irradianceAngleDeg: 180 })
    expect(evaluateLos({ ...emitter, normal: [1, 0, 0] }, detector)).toMatchObject({ status: 'outside-emission', powerW: 0 })
    expect(evaluateLos(emitter, { ...detector, normal: [1, 0, 0], fovHalfAngleDeg: 90 })).toMatchObject({ status: 'outside-fov', powerW: 0 })
    expect(evaluateLos({ ...emitter, powerW: 0 }, detector)).toMatchObject({ status: 'off', powerW: 0, distanceM: 2 })
  })

  it('preserves emitter order and supports empty scenes', () => {
    expect(evaluateScene({ emitters: [], detector })).toEqual([])
    expect(evaluateScene({ emitters: [emitter, { ...emitter, id: 'second', powerW: 0 }], detector }).map((row) => row.id))
      .toEqual(['anchor', 'second'])
  })

  it.each([0, -1, 90, 180, NaN, Infinity, -Infinity, '45'])('rejects invalid half-power angle %s', (angle) => {
    expect(() => lambertianOrder(angle as number)).toThrow(RangeError)
    expect(() => evaluateLos({ ...emitter, halfPowerAngleDeg: angle as number }, detector)).toThrow(RangeError)
  })

  it.each([-1, NaN, Infinity, -Infinity, '1'])('rejects invalid transmitted power %s', (powerW) => {
    expect(() => evaluateLos({ ...emitter, powerW: powerW as number }, detector)).toThrow(RangeError)
  })

  it.each([0, -1, NaN, Infinity, '1'])('rejects invalid active area %s', (areaM2) => {
    expect(() => evaluateLos(emitter, { ...detector, areaM2: areaM2 as number })).toThrow(RangeError)
  })

  it.each([0, -1, 91, NaN, Infinity, '85'])('rejects invalid FOV half-angle %s', (fovHalfAngleDeg) => {
    expect(() => evaluateLos(emitter, { ...detector, fovHalfAngleDeg: fovHalfAngleDeg as number })).toThrow(RangeError)
  })

  it.each([[0, 0, 0], [NaN, 0, 1], [0, Infinity, 1], [1, 2], [1, 2, 3, 4], ['1', 0, 1], null])('rejects invalid normals %j', (...values) => {
    const normal = (values.length === 1 && values[0] === null ? null : values) as unknown as Vector3
    expect(() => evaluateLos({ ...emitter, normal }, detector)).toThrow(RangeError)
    expect(() => evaluateLos(emitter, { ...detector, normal })).toThrow(RangeError)
  })

  it('rejects invalid positions and coincident positions even with power off', () => {
    expect(() => evaluateLos({ ...emitter, position: [Infinity, 0, 2] }, detector)).toThrow(RangeError)
    expect(() => evaluateLos(emitter, { ...detector, position: [0, NaN, 0] })).toThrow(RangeError)
    expect(() => evaluateLos(emitter, { ...detector, position: emitter.position })).toThrow(RangeError)
    expect(() => evaluateLos({ ...emitter, powerW: 0 }, { ...detector, position: emitter.position })).toThrow(RangeError)
    expect(() => evaluateLos({ ...emitter, powerW: 0, normal: [0, 0, 0] }, detector)).toThrow(RangeError)
  })

  it('rejects unrepresentable distance or power rather than producing infinity', () => {
    expect(() => evaluateLos({ ...emitter, position: [1e308, 0, 0] }, { ...detector, position: [-1e308, 0, 0] })).toThrow(RangeError)
    expect(() => evaluateLos({ ...emitter, powerW: Number.MAX_VALUE }, { ...detector, areaM2: Number.MAX_VALUE })).toThrow(RangeError)
  })
})
