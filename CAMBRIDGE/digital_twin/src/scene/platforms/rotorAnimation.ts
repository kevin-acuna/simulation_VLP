import type { ReceiverPlatform } from '../../model/types'

const fullTurn = Math.PI * 2
const radiansPerSecond = 42

export function shouldAnimateRotors(platform: ReceiverPlatform, spinning: boolean, visible: boolean, reducedMotion: boolean): boolean {
  return platform === 'drone' && spinning && visible && !reducedMotion
}

export function advanceRotorAngle(angle: number, delta: number, index: number): number {
  const step = Number.isFinite(delta) ? Math.max(0, Math.min(delta, 0.05)) : 0
  const direction = index % 2 === 0 ? 1 : -1
  const next = angle + direction * radiansPerSecond * step
  return ((next % fullTurn) + fullTurn) % fullTurn
}
