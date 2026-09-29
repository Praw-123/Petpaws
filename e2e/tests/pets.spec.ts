import { test, expect, type APIRequestContext } from '@playwright/test';

// คู่มือใช้แอป taskflow (list / create / mark done) ของเราแทนด้วยประกาศหาบ้านสัตว์เลี้ยง:
// list = ดูประกาศของตัวเอง, create = ลงประกาศใหม่, mark done = เปลี่ยนสถานะเป็นถูกรับเลี้ยงแล้ว
// ยิงผ่าน API จริงที่ต่อ Postgres จริง ไม่ได้ mock อะไร

test.describe.configure({ mode: 'serial' });

let api: APIRequestContext;
let petId: string;

test.beforeAll(async ({ playwright, baseURL }) => {
  const suffix = Date.now().toString(36);
  const account = {
    username: `e2e_${suffix}`,
    email: `e2e_${suffix}@petpaws.test`,
    password: 'Petpaws#E2e2026',
  };

  const anon = await playwright.request.newContext({ baseURL });
  const register = await anon.post('/auth/register', { data: account });
  expect(register.status(), await register.text()).toBe(201);

  const login = await anon.post('/auth/login', {
    data: { identifier: account.username, password: account.password },
  });
  expect(login.ok(), await login.text()).toBeTruthy();
  const { accessToken } = await login.json();
  await anon.dispose();

  api = await playwright.request.newContext({
    baseURL,
    extraHTTPHeaders: { Authorization: `Bearer ${accessToken}` },
  });
});

test.afterAll(async () => {
  await api?.dispose();
});

test('list: ผู้ใช้ใหม่ยังไม่มีประกาศ ได้รายการว่าง', async () => {
  const res = await api.get('/pets/mine');
  expect(res.ok()).toBeTruthy();
  expect(await res.json()).toEqual([]);
});

test('create: ลงประกาศใหม่ แล้วเห็นในรายการของตัวเอง', async () => {
  const res = await api.post('/pets', {
    data: {
      name: 'มอมแมม',
      province: 'สงขลา',
      age: '2 ปี',
      gender: 'เมีย',
      tags: ['chill'],
      story: 'สร้างจาก Playwright E2E',
    },
  });
  expect(res.status(), await res.text()).toBe(201);
  petId = (await res.json()).id;
  expect(petId).toBeTruthy();

  const mine = await (await api.get('/pets/mine')).json();
  expect(mine).toHaveLength(1);
  expect(mine[0]).toMatchObject({ id: petId, name: 'มอมแมม', status: 'ยังไม่ถูกรับเลี้ยง' });
});

test('mark done: เปลี่ยนสถานะเป็นถูกรับเลี้ยงแล้ว', async () => {
  const res = await api.patch(`/pets/${petId}`, { data: { status: 'ถูกรับเลี้ยงแล้ว' } });
  expect(res.ok(), await res.text()).toBeTruthy();

  const pet = await (await api.get(`/pets/${petId}`)).json();
  expect(pet.status).toBe('ถูกรับเลี้ยงแล้ว');
});
