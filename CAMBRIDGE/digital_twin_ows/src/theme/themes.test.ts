import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import type { ThemeId } from '../model/types'
import { DEFAULT_THEME, THEMES, getTheme, getThemeVariables, isThemeId } from './themes'

const themeIds: ThemeId[] = ['chalk', 'white', 'sage', 'sand', 'mist', 'rose']
const paletteKeys = [
  'bg-center', 'bg-mid', 'bg-edge', 'surface', 'surface-muted', 'border', 'border-strong',
  'ink', 'text', 'muted', 'accent', 'accent-soft', 'accent-hover', 'on-accent', 'shadow',
]

function luminance(hex: string): number {
  const channels = [1, 3, 5].map((offset) => {
    const channel = parseInt(hex.slice(offset, offset + 2), 16) / 255
    return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4
  })
  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
}

function contrast(foreground: string, background: string): number {
  const first = luminance(foreground)
  const second = luminance(background)
  return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05)
}

describe('theme registry', () => {
  it('contains exactly the six unique supported IDs and readable labels', () => {
    expect(THEMES.map(({ id }) => id)).toEqual(themeIds)
    expect(new Set(THEMES.map(({ id }) => id)).size).toBe(6)
    expect(new Set(THEMES.map(({ name }) => name)).size).toBe(6)
    for (const theme of THEMES) {
      expect(theme.name.trim().length).toBeGreaterThan(0)
      expect(theme.description.trim().length).toBeGreaterThan(0)
    }
  })

  it.each(themeIds)('validates and resolves %s to a complete hexadecimal palette', (id) => {
    expect(isThemeId(id)).toBe(true)
    const theme = getTheme(id)
    expect(theme.id).toBe(id)
    expect(Object.keys(theme.colors).sort()).toEqual([...paletteKeys].sort())
    Object.values(theme.colors).forEach((color) => expect(color).toMatch(/^#[0-9a-f]{6}$/i))
  })

  it.each([undefined, null, false, 0, '', 'SAGE', ' rose ', 'unknown', 'lavender', '__proto__', 'constructor', [], ['sage'], {}, Object('sage')])(
    'rejects the invalid theme ID %s without coercion',
    (id) => expect(isThemeId(id)).toBe(false),
  )

  it('defines Chalk as the default palette', () => {
    expect(DEFAULT_THEME).toBe('chalk')
    expect(getTheme(DEFAULT_THEME).name).toBe('Chalk')
  })

  it.each([undefined, null, '', 'unknown', 'lavender'])('falls back to Chalk for invalid runtime ID %s', (id) => {
    expect(getTheme(id as ThemeId)).toBe(getTheme('chalk'))
    expect(getThemeVariables(id as ThemeId)).toEqual(getThemeVariables('chalk'))
  })

  it('replaces Lavender with Pure White and an entirely neutral palette', () => {
    const theme = getTheme('white')
    expect(theme.name).toBe('Pure White')
    expect(theme.description).toMatch(/neutral white/i)
    expect([theme.colors['bg-center'], theme.colors['bg-mid'], theme.colors['bg-edge']])
      .toEqual(['#ffffff', '#ffffff', '#ffffff'])
    for (const color of Object.values(theme.colors)) {
      expect(color.slice(1, 3)).toBe(color.slice(3, 5))
      expect(color.slice(3, 5)).toBe(color.slice(5, 7))
    }
    for (const key of ['surface', 'surface-muted', 'accent-soft', 'accent-hover'] as const) {
      expect(parseInt(theme.colors[key].slice(1, 3), 16)).toBeGreaterThanOrEqual(240)
    }
  })

  it('matches every root fallback color to Chalk before application initialization', () => {
    const stylesheet = readFileSync(new URL('../styles.css', import.meta.url), 'utf8')
    const root = stylesheet.match(/^:root\s*\{([^}]+)\}/)?.[1] ?? ''
    const variables = Object.fromEntries([...root.matchAll(/(--[\w-]+):\s*(#[0-9a-f]{6});/gi)]
      .map(([, key, color]) => [key, color]))
    expect(variables).toEqual(getThemeVariables('chalk'))
  })
})

describe.each(themeIds)('%s theme variables', (id) => {
  it('exposes exactly every palette color as a valid CSS custom property', () => {
    const variables = getThemeVariables(id)
    expect(Object.keys(variables).sort()).toEqual(paletteKeys.map((key) => `--${key}`).sort())
    for (const [key, color] of Object.entries(getTheme(id).colors)) {
      expect(variables[`--${key}`]).toBe(color)
      expect(variables[`--${key}`]).toMatch(/^#[0-9a-f]{6}$/i)
    }
  })

  it('returns fresh variables without mutating the shared palette', () => {
    const before = JSON.stringify(THEMES)
    const variables = getThemeVariables(id)
    const second = getThemeVariables(id)
    expect(variables).not.toBe(second)
    variables['--ink'] = '#ffffff'
    expect(second['--ink']).toBe(getTheme(id).colors.ink)
    expect(getThemeVariables(id)).toEqual(second)
    expect(JSON.stringify(THEMES)).toBe(before)
  })

  it('keeps core labels readable on surfaces, backgrounds, and selected controls', () => {
    const colors = getTheme(id).colors
    for (const foreground of ['ink', 'text'] as const) {
      for (const background of ['surface', 'surface-muted', 'bg-center', 'bg-mid', 'bg-edge', 'accent-soft'] as const) {
        expect(contrast(colors[foreground], colors[background]), `${id} ${foreground} on ${background}`)
          .toBeGreaterThanOrEqual(4.5)
      }
    }
    expect(contrast(colors.ink, colors['accent-hover'])).toBeGreaterThanOrEqual(4.5)
    expect(colors['on-accent']).toBe('#ffffff')
    expect(contrast(colors['on-accent'], colors.accent)).toBeGreaterThanOrEqual(4.5)
  })
})

describe('muted label contrast', () => {
  it.each(themeIds)('keeps %s muted labels readable on both panel surfaces', (id) => {
    const colors = getTheme(id).colors
    expect(contrast(colors.muted, colors.surface)).toBeGreaterThanOrEqual(4.5)
    expect(contrast(colors.muted, colors['surface-muted'])).toBeGreaterThanOrEqual(4.5)
    expect(contrast(colors.text, colors['accent-hover'])).toBeGreaterThanOrEqual(4.5)
  })
})
