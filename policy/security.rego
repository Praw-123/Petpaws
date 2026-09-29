# Policy Gate ของ Lab 06: ตัดสินจากผล npm audit (JSON) ของ dependency ที่ขึ้นโปรดักชัน
# input = ไฟล์ audit.json ตรง ๆ ใช้ช่อง input.metadata.vulnerabilities.{critical,high}
package petpaws.security

import rego.v1

vulns := input.metadata.vulnerabilities

# บล็อก: มีช่องโหว่ระดับ critical แม้แต่ตัวเดียว
deny contains msg if {
	vulns.critical > 0
	msg := sprintf("BLOCK: พบช่องโหว่ระดับ critical %d รายการ ต้องแก้ก่อน deploy", [vulns.critical])
}

# เตือนแต่ไม่บล็อก: high ยังปล่อยผ่าน เพราะ dependency จริงมี high ค้างอยู่บ่อย
# ถ้าบล็อกทุกระดับ pipeline จะแดงตลอดจนคนเลิกสนใจผล
warn contains msg if {
	vulns.high > 0
	msg := sprintf("WARN: พบช่องโหว่ระดับ high %d รายการ ควรวางแผนอัปเดต", [vulns.high])
}

default allow := false

allow if count(deny) == 0
