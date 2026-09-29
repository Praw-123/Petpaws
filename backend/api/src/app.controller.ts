import { Controller, Get, Inject } from '@nestjs/common';
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
    await this.pool.query('SELECT 1');
    return { status: 'ok', db: 'connected' };
  }
}
