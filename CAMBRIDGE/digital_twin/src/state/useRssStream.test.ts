import { describe, expect, it } from 'vitest'
import { appendRssSample } from './useRssStream'
import type { RssSample } from './useRssStream'

const sample = (time: number): RssSample => ({ time, channels: [] })

describe('RSS display history', () => {
  it('retains only the last twenty seconds without mutating prior samples', () => {
    const history = [sample(0), sample(1), sample(15), sample(20)]
    const next = sample(21)
    expect(appendRssSample(history, next)).toEqual([history[1], history[2], history[3], next])
    expect(history.map((entry) => entry.time)).toEqual([0, 1, 15, 20])
  })

  it('caps the display buffer even if samples arrive faster than expected', () => {
    const history = Array.from({ length: 500 }, (_, index) => sample(index / 100))
    const result = appendRssSample(history, sample(5))
    expect(result).toHaveLength(401)
    expect(result[0].time).toBe(1)
    expect(result.at(-1)?.time).toBe(5)
  })

  it('starts immediately with an actual first sample and handles long sampling gaps', () => {
    const first = sample(0)
    expect(appendRssSample([], first)).toEqual([first])
    expect(appendRssSample([first], sample(25))).toEqual([sample(25)])
  })
})
