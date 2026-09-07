import { describe, expect, it } from 'vitest'
import { advanceRotorAngle, shouldAnimateRotors } from './rotorAnimation'

const fullTurn = Math.PI * 2

function signedAngle(angle: number) {
  return angle > Math.PI ? angle - fullTurn : angle
}

describe('demand-driven rotor animation', () => {
  it('only runs for a spinning drone in a visible document without reduced motion', () => {
    for (const platform of ['cylinder', 'drone'] as const) {
      for (const spinning of [false, true]) {
        for (const visible of [false, true]) {
          for (const reducedMotion of [false, true]) {
            expect(shouldAnimateRotors(platform, spinning, visible, reducedMotion))
              .toBe(platform === 'drone' && spinning && visible && !reducedMotion)
          }
        }
      }
    }
  })

  it('turns adjacent rotors in opposite directions with matching speed', () => {
    const angles = [0, 1, 2, 3].map((index) => signedAngle(advanceRotorAngle(0, 1 / 60, index)))
    expect(angles[0]).toBeGreaterThan(0)
    expect(angles[0]).toBeCloseTo(-angles[1])
    expect(angles[2]).toBeCloseTo(angles[0])
    expect(angles[3]).toBeCloseTo(angles[1])
  })

  it('uses elapsed seconds rather than a frame-dependent increment', () => {
    const oneStep = advanceRotorAngle(0.3, 1 / 30, 0)
    const twoSteps = advanceRotorAngle(advanceRotorAngle(0.3, 1 / 60, 0), 1 / 60, 0)
    expect(twoSteps).toBeCloseTo(oneStep)
  })

  it('caps background/resume delta to fifty milliseconds without catching up', () => {
    expect(advanceRotorAngle(0.2, 40, 0)).toBeCloseTo(advanceRotorAngle(0.2, 0.05, 0))
    expect(advanceRotorAngle(0.2, 0.051, 1)).toBeCloseTo(advanceRotorAngle(0.2, 0.05, 1))
  })

  it.each([0, -1, NaN, Infinity, -Infinity])('does not advance for invalid or nonpositive delta %s', (delta) => {
    expect(advanceRotorAngle(0.3, delta, 0)).toBeCloseTo(0.3)
    expect(advanceRotorAngle(0.3, delta, 1)).toBeCloseTo(0.3)
  })

  it('keeps angles bounded during long sessions in either direction', () => {
    for (const index of [0, 1]) {
      let angle = 0
      for (let frame = 0; frame < 10000; frame++) angle = advanceRotorAngle(angle, 1 / 60, index)
      expect(angle).toBeGreaterThanOrEqual(0)
      expect(angle).toBeLessThan(fullTurn)
    }
  })
})
