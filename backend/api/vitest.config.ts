import { defineConfig } from 'vitest/config';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  // Resolves the path aliases declared in tsconfig.json, including the ones
  // added by `nest g library`.
  plugins: [tsconfigPaths()],
  test: {
    globals: true,
    root: './',
    include: ['**/*.spec.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text-summary', 'cobertura', 'lcov'],
      include: ['src/**/*.ts'],
      // วัด coverage เฉพาะ logic ที่ unit test ได้ (กฎ, การแปลงค่า) ส่วน controller/service/module
      // ต้องต่อ DB/Redis จริง ครอบคลุมด้วย e2e แทน ไม่งั้นตัวเลขรวมจะต่ำจนเกณฑ์ 70% ไม่มีความหมาย
      exclude: [
        'src/**/*.spec.ts',
        'src/**/*.{controller,service,module,guard,strategy,decorator,filter,gateway,processor}.ts',
        'src/**/dto/**',
        'src/config/**',
        'src/main.ts',
      ],
    },
  },
});
