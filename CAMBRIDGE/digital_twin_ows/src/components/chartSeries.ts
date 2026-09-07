import type { CSSProperties } from 'react'

export function channelStyle(id: string): CSSProperties {
  const suffix = id.match(/(\d+)$/)
  const index = suffix ? Number(suffix[1]) - 1 : Array.from(id).reduce((hash, character) => hash * 31 + character.charCodeAt(0) | 0, 0)
  return { '--rss-channel-color': `var(--rss-series-${((index % 9) + 9) % 9 + 1})` } as CSSProperties
}
