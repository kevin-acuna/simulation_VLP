import { Check } from 'lucide-react'
import type { CSSProperties } from 'react'
import type { ThemeId } from '../model/types'
import { getTheme, THEMES } from '../theme/themes'

export default function ThemePicker({ value, onChange }: { value: ThemeId; onChange: (value: ThemeId) => void }) {
  const current = getTheme(value)
  return (
    <section className="control-section theme-section">
      <div className="section-title"><h3>Workspace palette</h3><span>APPEARANCE</span></div>
      <p className="section-description">Matte backgrounds with matching labels and controls.</p>
      <div className="theme-grid" role="group" aria-label="Workspace palette">
        {THEMES.map((theme) => (
          <button
            key={theme.id}
            type="button"
            className="theme-option"
            aria-label={`${theme.name} palette`}
            aria-pressed={value === theme.id}
            title={theme.description}
            onClick={() => onChange(theme.id)}
            style={{ '--swatch-background': theme.colors['bg-edge'], '--swatch-accent': theme.colors.accent } as CSSProperties}
          >
            <span className="theme-preview" aria-hidden="true">{value === theme.id && <span className="theme-check"><Check size={12} /></span>}</span>
            <span className="theme-name">{theme.name}</span>
          </button>
        ))}
      </div>
      <p className="theme-caption">{current.description}</p>
      <div className="theme-current"><span>Background · {current.name}</span><code>{current.colors['bg-edge'].toUpperCase()}</code></div>
      <p className="helper">Appearance only. LED power and colour temperature stay unchanged.</p>
    </section>
  )
}
