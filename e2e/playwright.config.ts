import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  // 3 เทสต่อกันเป็นลำดับ (สร้าง → เห็นในรายการ → เปลี่ยนสถานะ) ต้องรันทีละตัวบน API ตัวเดียว
  workers: 1,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['junit', { outputFile: 'results/junit.xml' }],
  ],
  use: {
    baseURL: process.env.API_URL ?? 'http://localhost:3000',
    extraHTTPHeaders: { Accept: 'application/json' },
  },
});
