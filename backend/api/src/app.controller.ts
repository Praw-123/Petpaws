import { Controller, Get, Inject, ServiceUnavailableException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from './database/database.module.js';
import { Public } from './common/public.decorator.js';

@Controller()
export class AppController {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  // เช็ก Postgres ต่อติดจริง ไม่ใช่แค่ process ยังไม่ crash
  // ROADMAP.md Phase 1.8
  @Public()
  @Get('health')
  async health() {
    // TEST (Lab 07 รอบ C): จำลอง release ที่พัง แอปเปิดได้แต่ /health ตอบ 503
    // เพื่อให้ smoke test ล้มและดู rollback อัตโนมัติ ต้อง revert ทันทีหลังทดสอบ
    throw new ServiceUnavailableException('Lab 07 test: broken release');
    await this.pool.query('SELECT 1');
    return { status: 'ok', db: 'connected' };
  }
}
