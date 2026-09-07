import { readFileSync, readdirSync } from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

const root = fileURLToPath(new URL('.', import.meta.url))

function runtimeFiles(directory: string): string[] {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name)
    return entry.isDirectory() ? runtimeFiles(path) : entry.name.endsWith('.ts') && !entry.name.endsWith('.test.ts') ? [path] : []
  })
}

describe('scientific review boundary', () => {
  it.each(runtimeFiles(root))('%s has no application, rendering or runtime-package dependencies', (path) => {
    const source = readFileSync(path, 'utf8')
    const imports = [...source.matchAll(/(?:\bfrom\s*|\bimport\s*\(|\brequire\s*\(|\bimport\s*)['"]([^'"]+)['"]/g)]
    for (const [, specifier] of imports) {
      expect(specifier.startsWith('.'), specifier).toBe(true)
      expect(relative(root, resolve(dirname(path), specifier)).startsWith('..'), specifier).toBe(false)
    }
    expect(source).not.toMatch(/\b(?:window|document|localStorage|requestAnimationFrame)\b/)
  })
})
