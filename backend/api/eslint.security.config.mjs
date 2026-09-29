// ESLint ใช้สำหรับ SAST (Lab 06) เท่านั้น ส่วน lint รูปแบบโค้ดปกติยังใช้ oxlint ตามเดิม
// จึงเปิดแค่กฎของ eslint-plugin-security ไม่เปิดกฎอื่น ไม่งั้นจะซ้ำกับ oxlint
import tseslint from 'typescript-eslint';
import security from 'eslint-plugin-security';

export default [
  {
    files: ['src/**/*.ts'],
    ignores: ['src/**/*.spec.ts'],
    languageOptions: { parser: tseslint.parser },
    // โค้ดมี eslint-disable ของ oxlint (no-console) ค้างอยู่ ไม่ต้องเตือนว่าไม่ได้ใช้
    linterOptions: { reportUnusedDisableDirectives: 'off' },
    ...security.configs.recommended,
  },
];
