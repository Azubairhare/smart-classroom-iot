# عقد البيانات - Smart Classroom IoT

## الجداول الأساسية (Supabase)
- **rooms**: id, room_code, room_name, building, floor, is_active
- **courses**: id, course_code, course_name
- **instructors**: id, full_name
- **schedules**: id, room_id, course_id, instructor_id, day_of_week (1=الاثنين...7=الأحد), start_time, end_time, is_published
- **schedule_exceptions**: id, room_id, exception_date, action ('cancel'|'replace'), start_time, end_time, course_id, instructor_id, status ('pending'|'approved'|'rejected'), is_published
- **announcements**: id, title, body, start_at, end_at, is_active
- **profiles**: id, full_name, role ('admin'|'viewer')

## دالة القراءة العامة (RPC)
- الاسم: `get_room_day(p_room_code text, p_date date)`
- الاستخدام في الموقع: `db.rpc('get_room_day', { p_room_code: 'A101' })`
- ترجع JSON يحتوي على: `room_code`, `date`, `timezone`, `schedule`, `exceptions`.

## الإعدادات الهامة
- **المنطقة الزمنية:** Asia/Aden (UTC+3)
- **مفاتيح الوصول (لمحمد):** يتم مشاركتها عبر قناة خاصة (لا تُرفع على GitHub).