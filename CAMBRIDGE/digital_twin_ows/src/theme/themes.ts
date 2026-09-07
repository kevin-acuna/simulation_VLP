import type { ThemeId } from '../model/types'

export const DEFAULT_THEME: ThemeId = 'chalk'

export interface ThemePalette {
  id: ThemeId
  name: string
  description: string
  colors: {
    'bg-center': string
    'bg-mid': string
    'bg-edge': string
    surface: string
    'surface-muted': string
    border: string
    'border-strong': string
    ink: string
    text: string
    muted: string
    accent: string
    'accent-soft': string
    'accent-hover': string
    'on-accent': string
    shadow: string
  }
}

const CHALK_THEME: ThemePalette = {
  id: DEFAULT_THEME, name: 'Chalk', description: 'Quiet architectural white',
  colors: {
    'bg-center': '#ffffff', 'bg-mid': '#f5f5f3', 'bg-edge': '#e9eae8',
    surface: '#ffffff', 'surface-muted': '#f4f5f3', border: '#e0e3df', 'border-strong': '#adb7b4',
    ink: '#303936', text: '#525f5b', muted: '#646e6a', accent: '#566b66',
    'accent-soft': '#e8eeeb', 'accent-hover': '#dce5e1', 'on-accent': '#ffffff', shadow: '#353e3a',
  },
}

export const THEMES: readonly ThemePalette[] = [
  CHALK_THEME,
  {
    id: 'white', name: 'Pure White', description: 'Neutral white and soft grey',
    colors: {
      'bg-center': '#ffffff', 'bg-mid': '#ffffff', 'bg-edge': '#ffffff',
      surface: '#ffffff', 'surface-muted': '#fafafa', border: '#e3e3e3', 'border-strong': '#aaaaaa',
      ink: '#2f2f2f', text: '#555555', muted: '#696969', accent: '#5f5f5f',
      'accent-soft': '#f7f7f7', 'accent-hover': '#f0f0f0', 'on-accent': '#ffffff', shadow: '#333333',
    },
  },
  {
    id: 'sage', name: 'Sage', description: 'Soft botanical grey',
    colors: {
      'bg-center': '#f8f9f4', 'bg-mid': '#f0f2ed', 'bg-edge': '#e9ede6',
      surface: '#fcfcf9', 'surface-muted': '#f3f6ee', border: '#dfe6d8', 'border-strong': '#a6b99a',
      ink: '#2e3e34', text: '#53684f', muted: '#626f59', accent: '#507448',
      'accent-soft': '#e7eee2', 'accent-hover': '#dbe7d3', 'on-accent': '#ffffff', shadow: '#354b3d',
    },
  },
  {
    id: 'sand', name: 'Sand', description: 'Warm limestone and linen',
    colors: {
      'bg-center': '#fcf9f3', 'bg-mid': '#f4efe7', 'bg-edge': '#eae1d4',
      surface: '#fdfbf7', 'surface-muted': '#f7f1e8', border: '#e8ded0', 'border-strong': '#c3ab8e',
      ink: '#40382e', text: '#6c5b46', muted: '#7b6c58', accent: '#856443',
      'accent-soft': '#eee4d5', 'accent-hover': '#e4d6c3', 'on-accent': '#ffffff', shadow: '#514331',
    },
  },
  {
    id: 'mist', name: 'Mist', description: 'A cool, airy blue',
    colors: {
      'bg-center': '#f7fbfc', 'bg-mid': '#edf3f7', 'bg-edge': '#dfe9f0',
      surface: '#fbfdfe', 'surface-muted': '#f0f5f9', border: '#dce6ed', 'border-strong': '#9bb4c5',
      ink: '#2c3d49', text: '#4c6678', muted: '#5d7182', accent: '#4c718c',
      'accent-soft': '#e1ecf3', 'accent-hover': '#d3e2ed', 'on-accent': '#ffffff', shadow: '#344a5b',
    },
  },
  {
    id: 'rose', name: 'Rose', description: 'Dusty blush and warm white',
    colors: {
      'bg-center': '#fdf9f9', 'bg-mid': '#f7eeee', 'bg-edge': '#f0e2e3',
      surface: '#fffbfc', 'surface-muted': '#faf1f3', border: '#ecdde1', 'border-strong': '#c9a3ae',
      ink: '#493339', text: '#71515a', muted: '#80656d', accent: '#8f5f6c',
      'accent-soft': '#f2e2e7', 'accent-hover': '#e9d2d9', 'on-accent': '#ffffff', shadow: '#543c43',
    },
  },
]

export function isThemeId(value: unknown): value is ThemeId {
  return typeof value === 'string' && THEMES.some((theme) => theme.id === value)
}

export function getTheme(id: ThemeId): ThemePalette {
  return THEMES.find((theme) => theme.id === id) ?? CHALK_THEME
}

export function getThemeVariables(id: ThemeId): Record<`--${string}`, string> {
  return Object.fromEntries(Object.entries(getTheme(id).colors).map(([key, value]) => [`--${key}`, value]))
}
