create extension if not exists pgcrypto;

-- المستخدمون وصلاحياتهم
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'viewer'
    check (role in ('admin', 'viewer')),
  created_at timestamptz not null default now()
);

-- القاعات
create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  room_code text not null unique,
  room_name text not null,
  building text not null default '',
  floor integer not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- الدكاترة
create table public.instructors (
  id uuid primary key default gen_random_uuid(),
  full_name text not null
);

-- المواد
create table public.courses (
  id uuid primary key default gen_random_uuid(),
  course_code text not null unique,
  course_name text not null
);

-- جدول المحاضرات الأسبوعي
-- day_of_week: الاثنين=1 ... الأحد=7
create table public.schedules (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id),
  course_id uuid not null references public.courses(id),
  instructor_id uuid not null references public.instructors(id),
  day_of_week integer not null
    check (day_of_week between 1 and 7),
  start_time time not null,
  end_time time not null,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  check (start_time < end_time)
);

-- الاستثناءات الخاصة بتاريخ معين
create table public.schedule_exceptions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id),
  exception_date date not null,
  action text not null
    check (action in ('cancel', 'replace')),
  start_time time not null,
  end_time time not null,
  course_id uuid references public.courses(id),
  instructor_id uuid references public.instructors(id),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  is_published boolean not null default false,
  approved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check (start_time < end_time),
  check (
    (action = 'cancel')
    or
    (action = 'replace'
      and course_id is not null
      and instructor_id is not null)
  )
);

-- الإعلانات
create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  is_active boolean not null default false,
  check (start_at < end_at)
);

-- فهارس تساعد في الاستعلامات
create index schedules_room_day_idx
  on public.schedules(room_id, day_of_week, start_time);

create index exceptions_room_date_idx
  on public.schedule_exceptions(room_id, exception_date);

-- دالة للتحقق من مسؤول النظام
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin()
  to authenticated;

-- تفعيل RLS
alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.instructors enable row level security;
alter table public.courses enable row level security;
alter table public.schedules enable row level security;
alter table public.schedule_exceptions enable row level security;
alter table public.announcements enable row level security;

-- المستخدم يرى ملفه، والمسؤول يستطيع إدارة الملفات
create policy "profile_read_self_or_admin"
on public.profiles for select
to authenticated
using (id = (select auth.uid()) or public.is_admin());

create policy "profile_admin_update"
on public.profiles for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- القاعات: معلومات العرض عامة، والكتابة للمسؤول
create policy "rooms_read"
on public.rooms for select
to anon, authenticated
using (true);

create policy "rooms_admin_insert"
on public.rooms for insert
to authenticated
with check (public.is_admin());

create policy "rooms_admin_update"
on public.rooms for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "rooms_admin_delete"
on public.rooms for delete
to authenticated
using (public.is_admin());

-- المواد والدكاترة
create policy "courses_read"
on public.courses for select
to anon, authenticated
using (true);

create policy "instructors_read"
on public.instructors for select
to anon, authenticated
using (true);

create policy "courses_admin_all"
on public.courses for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "instructors_admin_all"
on public.instructors for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- الجدول المنشور فقط متاح للقراءة العامة
create policy "schedules_public_read"
on public.schedules for select
to anon, authenticated
using (is_published = true or public.is_admin());

create policy "schedules_admin_insert"
on public.schedules for insert
to authenticated
with check (public.is_admin());

create policy "schedules_admin_update"
on public.schedules for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "schedules_admin_delete"
on public.schedules for delete
to authenticated
using (public.is_admin());

-- الاستثناءات: المعتمد والمنشور فقط متاح للقراءة
create policy "exceptions_public_read"
on public.schedule_exceptions for select
to anon, authenticated
using (
  (status = 'approved' and is_published = true)
  or public.is_admin()
);

create policy "exceptions_admin_insert"
on public.schedule_exceptions for insert
to authenticated
with check (public.is_admin());

create policy "exceptions_admin_update"
on public.schedule_exceptions for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "exceptions_admin_delete"
on public.schedule_exceptions for delete
to authenticated
using (public.is_admin());

-- الإعلانات المنشورة والفعالة
create policy "announcements_public_read"
on public.announcements for select
to anon, authenticated
using (is_active = true or public.is_admin());

create policy "announcements_admin_all"
on public.announcements for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- صلاحيات SQL تتكامل مع سياسات RLS
grant select on public.rooms, public.courses,
  public.instructors, public.schedules,
  public.schedule_exceptions, public.announcements
to anon, authenticated;

grant select, insert, update, delete
on public.profiles, public.rooms, public.courses,
  public.instructors, public.schedules,
  public.schedule_exceptions, public.announcements
to authenticated;