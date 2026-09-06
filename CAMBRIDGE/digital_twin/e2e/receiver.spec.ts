import { expect, test } from '@playwright/test'
import type { Locator, Page } from '@playwright/test'
import { getReceiverBounds, getReceiverGeometry, RECEIVER_ID } from '../src/model/receiver'

async function readConfig(page: Page) {
  return page.evaluate(() => JSON.parse(localStorage.getItem('cambridge-digital-twin:v1') ?? '{}'))
}

async function ready(page: Page) {
  await page.goto('/')
  await expect(page.getByRole('button', { name: 'Move receiver in X and Y', exact: true })).toBeVisible()
}

async function editNumber(page: Page, label: string, value: string) {
  const field = page.getByRole('spinbutton', { name: `${label} value`, exact: true })
  await field.fill(value)
  await field.press('Enter')
}

async function drag(page: Page, target: Locator, dx: number, dy: number, release = true) {
  await target.hover()
  const element = (await target.elementHandle())!
  const bounds = (await element.boundingBox())!
  await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
  await page.mouse.down()
  await expect.poll(() => element.getAttribute('data-dragging')).toBe('true')
  await page.mouse.move(bounds.x + bounds.width / 2 + dx, bounds.y + bounds.height / 2 + dy, { steps: 4 })
  if (release) {
    await page.mouse.up()
    await expect.poll(() => element.getAttribute('data-dragging')).toBe('false')
  }
  return element
}

async function ledCenters(page: Page) {
  return page.locator('.led-tag').evaluateAll((labels) => labels.map((label) => {
    const rect = label.getBoundingClientRect()
    return [rect.x + rect.width / 2, rect.y + rect.height / 2]
  }))
}

async function expectCameraUnchanged(page: Page, initial: number[][]) {
  const current = await ledCenters(page)
  expect(current).toHaveLength(initial.length)
  current.forEach((point, index) => {
    expect(Math.abs(point[0] - initial[index][0])).toBeLessThan(1)
    expect(Math.abs(point[1] - initial[index][1])).toBeLessThan(1)
  })
}

function captureErrors(page: Page) {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()) })
  return errors
}

test('receiver tag stays sober and only deliberate activation opens a drag-safe HUD', async ({ page }) => {
  test.setTimeout(90000)
  const errors = captureErrors(page)
  await ready(page)
  const tag = page.getByRole('button', { name: 'Move receiver in X and Y', exact: true })
  const hud = page.locator('.receiver-hud')
  const panel = page.getByRole('complementary')
  const styles = await page.locator('.receiver-tag, .led-tag').evaluateAll((elements) => elements.map((element) => {
    const style = getComputedStyle(element)
    return {
      font: style.font,
      letterSpacing: style.letterSpacing,
      padding: style.padding,
      minWidth: style.minWidth,
      minHeight: style.minHeight,
      border: style.border,
      borderRadius: style.borderRadius,
      backgroundColor: style.backgroundColor,
      color: style.color,
      boxShadow: style.boxShadow,
    }
  }))
  expect(styles.length).toBeGreaterThan(1)
  styles.forEach((style) => expect(style).toEqual(styles[0]))
  await expect(tag).toHaveText(RECEIVER_ID)
  await expect(tag.locator('svg, img')).toHaveCount(0)
  await expect(tag).toHaveCSS('cursor', 'grab')
  await expect(page.locator('.led-tag').first()).toHaveCSS('cursor', 'pointer')
  await expect(hud).toBeHidden()
  await expect(panel).toHaveCount(0)
  await tag.click()
  await expect(tag).toHaveAttribute('aria-pressed', 'true')
  await expect(hud).toBeHidden()
  await expect(panel).toHaveCount(0)
  const initial = (await readConfig(page)).receiver.position
  await drag(page, tag, 25, -10, false)
  await expect(hud).toBeHidden()
  await expect(panel).toHaveCount(0)
  await page.mouse.up()
  await expect(tag).toHaveAttribute('data-dragging', 'false')
  await expect(hud).toBeHidden()
  const xy = (await readConfig(page)).receiver.position
  expect(Math.hypot(xy[0] - initial[0], xy[1] - initial[1])).toBeGreaterThan(0.02)
  expect(xy[2]).toBe(0.3)
  await tag.dblclick()
  await expect(hud).toBeVisible()
  await expect(hud).toHaveAttribute('aria-hidden', 'false')
  await expect(panel).toHaveCount(0)
  await page.evaluate(() => document.addEventListener('pointerdown', (event) => {
    document.body.dataset.lastPointerId = String(event.pointerId)
  }, true))
  const z = await drag(page, page.getByRole('button', { name: 'Move receiver along Z', exact: true }), 0, -30, false)
  await expect(hud).toHaveCount(1)
  await expect(hud).toHaveCSS('visibility', 'hidden')
  await expect(hud).toHaveAttribute('aria-hidden', 'true')
  expect(await z.evaluate((element) => element.isConnected && element.hasPointerCapture(Number(document.body.dataset.lastPointerId)))).toBe(true)
  await expect.poll(async () => Number((await hud.locator('.receiver-coordinates [data-axis="z"]').textContent())!.replace('Z', '').trim())).toBeGreaterThan(xy[2])
  expect((await readConfig(page)).receiver.position).toEqual(xy)
  await page.mouse.up()
  await expect.poll(() => z.getAttribute('data-dragging')).toBe('false')
  await expect(hud).toBeVisible()
  await expect(hud).toHaveAttribute('aria-hidden', 'false')
  const raised = (await readConfig(page)).receiver.position
  expect(raised[2]).toBeGreaterThan(xy[2])
  expect(raised[0]).toBeCloseTo(xy[0])
  expect(raised[1]).toBeCloseTo(xy[1])
  await drag(page, tag, -15, 10, false)
  await expect(hud).toHaveCount(1)
  await expect(hud).toHaveCSS('visibility', 'hidden')
  await expect(hud).toHaveAttribute('aria-hidden', 'true')
  await expect(panel).toHaveCount(0)
  await page.mouse.up()
  await expect(tag).toHaveAttribute('data-dragging', 'false')
  await expect(hud).toBeVisible()
  await tag.dblclick()
  await expect(hud).toBeHidden()
  await tag.dblclick()
  await expect(hud).toBeVisible()
  await hud.getByRole('button', { name: 'Receiver properties', exact: true }).click()
  await expect(panel).toBeVisible()
  await expect(page.getByRole('tab', { name: 'Receiver', exact: true })).toHaveAttribute('aria-selected', 'true')
  await page.getByRole('button', { name: 'Close configuration panel' }).click()
  await page.locator('.led-tag').first().click()
  await expect(tag).toHaveAttribute('aria-pressed', 'false')
  await expect(hud).toBeHidden()
  await page.getByRole('button', { name: 'Close configuration panel' }).click()
  await tag.click()
  await expect(tag).toHaveAttribute('aria-pressed', 'true')
  await expect(hud).toBeHidden()
  await expect(panel).toHaveCount(0)
  await tag.press('Enter')
  await expect(hud).toBeVisible()
  await expect(panel).toHaveCount(0)
  await tag.press('Enter')
  await expect(hud).toBeHidden()
  expect(errors).toEqual([])
})

test('double-clicking the cylinder itself opens controls without opening settings', async ({ page }) => {
  await ready(page)
  await page.getByRole('button', { name: 'Top view', exact: true }).click()
  await page.getByRole('button', { name: 'Move receiver in X and Y', exact: true }).hover()
  const size = page.viewportSize()!
  await page.mouse.click(size.width / 2 + 8, size.height / 2)
  await expect(page.locator('.receiver-tag')).toHaveAttribute('aria-pressed', 'true')
  await expect(page.locator('.receiver-hud')).toBeHidden()
  await page.mouse.dblclick(size.width / 2 + 8, size.height / 2)
  await expect(page.locator('.receiver-hud')).toBeVisible()
  await expect(page.getByRole('complementary')).toHaveCount(0)
  expect((await readConfig(page)).receiver.position).toEqual([0, 0, 0.3])
})

test('receiver starts at a 0.3 m body-centre height, exposes precise coordinates, and exports its real geometry', async ({ page }, testInfo) => {
  test.setTimeout(90000)
  const errors = captureErrors(page)
  await ready(page)
  const initial = await readConfig(page)
  expect(initial.receiver).toEqual({ position: [0, 0, 0.3], yaw: 0, platform: 'cylinder', rotorsSpinning: true })
  await page.getByRole('button', { name: 'Open settings', exact: true }).click()
  await page.getByRole('tab', { name: 'Receiver', exact: true }).click()
  await expect(page.getByRole('tab', { name: 'Receiver', exact: true })).toHaveAttribute('aria-selected', 'true')
  await expect(page.locator('.receiver-hud')).toBeHidden()
  await editNumber(page, 'Receiver position · X', '0.65')
  await editNumber(page, 'Receiver position · Y', '-0.45')
  await editNumber(page, 'Receiver position · Z', '0.8')
  await editNumber(page, 'Platform rotation · Z', '137')
  expect((await readConfig(page)).receiver).toEqual({ position: [0.65, -0.45, 0.8], yaw: 137, platform: 'cylinder', rotorsSpinning: true })
  await page.screenshot({ path: testInfo.outputPath('receiver-inspector.png'), fullPage: true })
  const downloadEvent = page.waitForEvent('download')
  await page.getByRole('button', { name: 'Export scene' }).click()
  const stream = await (await downloadEvent).createReadStream()
  let text = ''
  for await (const chunk of stream!) text += chunk.toString()
  const exported = JSON.parse(text)
  expect(exported.receiverGeometry).toEqual(getReceiverGeometry('cylinder'))
  expect(exported.receiverGeometry.diameter).toBe(0.1)
  expect(exported.receiverGeometry.pdWidth).toBe(0.01)
  expect(exported.receiverGeometry.pdDepth).toBe(0.01)
  expect(exported.config.receiver).toEqual({ position: [0.65, -0.45, 0.8], yaw: 137, platform: 'cylinder', rotorsSpinning: true })
  await page.reload()
  await expect(page.locator('.receiver-tag')).toBeVisible()
  expect((await readConfig(page)).receiver).toEqual({ position: [0.65, -0.45, 0.8], yaw: 137, platform: 'cylinder', rotorsSpinning: true })
  await page.getByRole('button', { name: 'Open settings', exact: true }).click()
  await page.getByRole('tab', { name: 'Receiver', exact: true }).click()
  await page.getByRole('button', { name: 'Centre receiver', exact: true }).click()
  expect((await readConfig(page)).receiver).toEqual({ position: [0, 0, 0.3], yaw: 137, platform: 'cylinder', rotorsSpinning: true })
  await expect(page.locator('.receiver-hud')).toBeHidden()
  const bounds = getReceiverBounds(initial.room)
  await editNumber(page, 'Receiver position · X', '100')
  await editNumber(page, 'Receiver position · Y', '-100')
  await editNumber(page, 'Receiver position · Z', '100')
  const clamped = (await readConfig(page)).receiver.position
  expect(clamped[0]).toBeCloseTo(bounds.x[1])
  expect(clamped[1]).toBeCloseTo(bounds.y[0])
  expect(clamped[2]).toBeCloseTo(bounds.z[1])
  expect(errors).toEqual([])
})

test('body dragging moves XY, axis handles move independently, and the camera stays fixed', async ({ page }) => {
  test.setTimeout(90000)
  const errors = captureErrors(page)
  await ready(page)
  await page.getByRole('button', { name: 'Top view', exact: true }).click()
  await page.waitForTimeout(250)
  const tag = page.getByRole('button', { name: 'Move receiver in X and Y', exact: true })
  const hud = page.locator('.receiver-hud')
  await tag.hover()
  const camera = await ledCenters(page)
  const size = page.viewportSize()!
  await page.mouse.click(size.width / 2 + 8, size.height / 2)
  await expect(tag).toHaveAttribute('aria-pressed', 'true')
  await expect(hud).toBeHidden()
  await expect(page.getByRole('complementary')).toHaveCount(0)
  await page.mouse.dblclick(size.width / 2 + 8, size.height / 2)
  await expect(hud).toBeVisible()
  await expect(page.getByRole('complementary')).toHaveCount(0)
  await page.mouse.dblclick(size.width / 2 + 8, size.height / 2)
  await expect(hud).toBeHidden()
  await page.mouse.move(size.width / 2 + 8, size.height / 2)
  await page.mouse.down()
  await expect(tag).toHaveAttribute('data-dragging', 'true')
  await page.mouse.move(size.width / 2 + 63, size.height / 2 - 35, { steps: 4 })
  await expect(hud).toBeHidden()
  await page.mouse.up()
  await expect(tag).toHaveAttribute('data-dragging', 'false')
  await expect.poll(async () => (await readConfig(page)).receiver.position[0]).toBeGreaterThan(0.03)
  const xy = (await readConfig(page)).receiver.position
  expect(xy[1]).toBeGreaterThan(0.03)
  expect(xy[2]).toBe(0.3)
  await expect(hud).toBeHidden()
  await expect(page.getByRole('complementary')).toHaveCount(0)
  await expectCameraUnchanged(page, camera)
  await tag.dblclick()
  await expect(hud).toBeVisible()
  await drag(page, page.getByRole('button', { name: 'Move receiver along Z', exact: true }), 0, -45)
  const z = (await readConfig(page)).receiver.position
  expect(z[2]).toBeGreaterThan(xy[2])
  expect(z[0]).toBeCloseTo(xy[0])
  expect(z[1]).toBeCloseTo(xy[1])
  await drag(page, page.getByRole('button', { name: 'Move receiver along X', exact: true }), 30, 0)
  const x = (await readConfig(page)).receiver.position
  expect(x[0]).toBeGreaterThan(z[0])
  expect(x[1]).toBeCloseTo(z[1])
  expect(x[2]).toBeCloseTo(z[2])
  await drag(page, page.getByRole('button', { name: 'Move receiver along Y', exact: true }), 0, -30)
  const y = (await readConfig(page)).receiver.position
  expect(y[1]).toBeGreaterThan(x[1])
  expect(y[0]).toBeCloseTo(x[0])
  expect(y[2]).toBeCloseTo(x[2])
  await expectCameraUnchanged(page, camera)
  await page.reload()
  await expect(page.locator('.receiver-tag')).toBeVisible()
  expect((await readConfig(page)).receiver.position).toEqual(y)
  expect(errors).toEqual([])
})

test('dragging cancels with Escape or blur, clamps outside the canvas and unlocks navigation', async ({ page }) => {
  test.setTimeout(90000)
  const errors = captureErrors(page)
  await ready(page)
  const tag = page.getByRole('button', { name: 'Move receiver in X and Y', exact: true })
  await drag(page, tag, 35, -15)
  await expect(page.locator('.receiver-hud')).toBeHidden()
  const initial = (await readConfig(page)).receiver
  const camera = await ledCenters(page)
  await tag.dblclick()
  await expect(page.locator('.receiver-hud')).toBeVisible()
  const zHandle = page.getByRole('button', { name: 'Move receiver along Z', exact: true })
  await drag(page, zHandle, 0, -60, false)
  expect((await readConfig(page)).receiver).toEqual(initial)
  await page.keyboard.press('Escape')
  await page.mouse.up()
  expect((await readConfig(page)).receiver).toEqual(initial)
  await expectCameraUnchanged(page, camera)
  await drag(page, tag, 50, -20, false)
  await page.evaluate(() => window.dispatchEvent(new Event('blur')))
  await page.mouse.up()
  expect((await readConfig(page)).receiver).toEqual(initial)
  await expectCameraUnchanged(page, camera)
  await page.getByRole('button', { name: 'Top view', exact: true }).click()
  await tag.hover()
  const bounds = (await tag.boundingBox())!
  await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
  await page.mouse.down()
  await expect(tag).toHaveAttribute('data-dragging', 'true')
  await page.mouse.move(-30, -30, { steps: 4 })
  await page.mouse.up()
  const moved = await readConfig(page)
  const limits = getReceiverBounds(moved.room)
  moved.receiver.position.forEach((value: number, axis: number) => {
    const limit = [limits.x, limits.y, limits.z][axis]
    expect(Number.isFinite(value)).toBe(true)
    expect(value).toBeGreaterThanOrEqual(limit[0])
    expect(value).toBeLessThanOrEqual(limit[1])
  })
  expect(moved.receiver.position).not.toEqual(initial.position)
  await page.getByRole('button', { name: 'Isometric view', exact: true }).click()
  await tag.hover()
  const beforeOrbit = await ledCenters(page)
  await page.mouse.move(1100, 750)
  await page.mouse.down()
  await page.mouse.move(1160, 730, { steps: 4 })
  await page.mouse.up()
  await expect.poll(async () => {
    const after = await ledCenters(page)
    return Math.hypot(after[0][0] - beforeOrbit[0][0], after[0][1] - beforeOrbit[0][1])
  }).toBeGreaterThan(4)
  expect(errors).toEqual([])
})

test('camera resets and pointer cancellation discard a receiver preview without leaving controls locked', async ({ page }) => {
  test.setTimeout(90000)
  const errors = captureErrors(page)
  await ready(page)
  await page.evaluate(() => document.addEventListener('pointerdown', (event) => {
    document.body.dataset.lastPointerId = String(event.pointerId)
  }, true))
  const tag = page.getByRole('button', { name: 'Move receiver in X and Y', exact: true })
  await drag(page, tag, 25, -10)
  await expect(page.locator('.receiver-hud')).toBeHidden()
  const initial = (await readConfig(page)).receiver
  await tag.dblclick()
  await expect(page.locator('.receiver-hud')).toBeVisible()
  await drag(page, page.getByRole('button', { name: 'Move receiver along Z', exact: true }), 0, -35, false)
  await page.getByRole('button', { name: 'Reset camera', exact: true }).focus()
  await page.keyboard.press('Enter')
  await expect(tag).toHaveAttribute('data-dragging', 'false')
  await page.mouse.up()
  expect((await readConfig(page)).receiver).toEqual(initial)
  await drag(page, tag, 30, -10, false)
  await tag.evaluate((element) => element.dispatchEvent(new PointerEvent('pointercancel', {
    pointerId: Number(document.body.dataset.lastPointerId), bubbles: true,
  })))
  await expect(tag).toHaveAttribute('data-dragging', 'false')
  await page.mouse.up()
  expect((await readConfig(page)).receiver).toEqual(initial)
  await drag(page, tag, 30, 0)
  expect((await readConfig(page)).receiver.position).not.toEqual(initial.position)
  expect(errors).toEqual([])
})

test('perspective and front views support XY and height dragging without orbit conflicts', async ({ page }, testInfo) => {
  test.setTimeout(90000)
  const errors = captureErrors(page)
  await ready(page)
  for (const view of ['Perspective view', 'Front view']) {
    await page.getByRole('button', { name: view, exact: true }).click()
    const depthRatio = async () => {
      const centers = await ledCenters(page)
      return Math.abs(centers[1][0] - centers[0][0]) / Math.abs(centers[3][0] - centers[2][0])
    }
    if (view === 'Perspective view') await expect.poll(depthRatio).toBeGreaterThan(1.15)
    else await expect.poll(depthRatio).toBeCloseTo(1, 2)
    await page.getByRole('button', { name: 'Move receiver in X and Y', exact: true }).hover()
    const before = (await readConfig(page)).receiver.position
    const camera = await ledCenters(page)
    await drag(page, page.getByRole('button', { name: 'Move receiver in X and Y', exact: true }), 35, -20)
    const xy = (await readConfig(page)).receiver.position
    expect(Math.hypot(xy[0] - before[0], xy[1] - before[1])).toBeGreaterThan(0.02)
    expect(xy[2]).toBeCloseTo(before[2])
    await expect(page.locator('.receiver-hud')).toBeHidden()
    await page.getByRole('button', { name: 'Move receiver in X and Y', exact: true }).dblclick()
    await expect(page.locator('.receiver-hud')).toBeVisible()
    await drag(page, page.getByRole('button', { name: 'Move receiver along Z', exact: true }), 0, -25)
    const z = (await readConfig(page)).receiver.position
    expect(z[2]).toBeGreaterThan(xy[2])
    expect(z[0]).toBeCloseTo(xy[0])
    expect(z[1]).toBeCloseTo(xy[1])
    await expectCameraUnchanged(page, camera)
    if (view === 'Perspective view') {
      await page.getByRole('button', { name: 'Move receiver in X and Y', exact: true }).dblclick()
      await expect(page.locator('.receiver-hud')).toBeHidden()
    }
  }
  await page.screenshot({ path: testInfo.outputPath('receiver-drag-controls.png'), fullPage: true })
  expect(errors).toEqual([])
})

test('legacy rooms initialize a 0.3 m centred receiver and small screens retain precise controls', async ({ page }) => {
  test.setTimeout(90000)
  await page.addInitScript(() => {
    if (!localStorage.getItem('cambridge-digital-twin:v1')) {
      localStorage.setItem('cambridge-digital-twin:v1', JSON.stringify({ room: { width: 5, depth: 4, height: 3 }, appearance: { theme: 'mist' } }))
    }
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await ready(page)
  const config = await readConfig(page)
  expect(config.room).toEqual({ width: 5, depth: 4, height: 3 })
  expect(config.appearance.theme).toBe('mist')
  expect(config.receiver).toEqual({ position: [0, 0, 0.3], yaw: 0, platform: 'cylinder', rotorsSpinning: true })
  await page.getByRole('button', { name: 'Open settings', exact: true }).click()
  await page.getByRole('tab', { name: 'Receiver', exact: true }).click()
  await expect(page.locator('.receiver-hud')).toBeHidden()
  await editNumber(page, 'Receiver position · Z', '1.2')
  await page.getByRole('button', { name: 'Close configuration panel' }).click()
  expect((await readConfig(page)).receiver.position[2]).toBe(1.2)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
  await expect(page.getByRole('toolbar')).toBeInViewport()
})
