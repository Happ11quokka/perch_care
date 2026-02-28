-- =============================================================
-- Perch Care 홍보용 데모 데이터
-- 실행: Railway psql에서 복사-붙여넣기 또는
--       railway run psql $DATABASE_URL -f seed_demo_data.sql
-- =============================================================

BEGIN;

-- 1) 사용자 ID 조회
DO $$
DECLARE
  v_user_id UUID;
  v_pet_id  UUID := gen_random_uuid();
BEGIN

  SELECT id INTO v_user_id
  FROM users
  WHERE email = 'limdonghyun@hanyang.ac.kr';

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found: limdonghyun@hanyang.ac.kr';
  END IF;

  -- 기존 펫의 is_active를 false로 (충돌 방지)
  UPDATE pets SET is_active = false WHERE user_id = v_user_id;

  -- =========================================================
  -- 2) 반려동물: Mango the Cockatiel
  -- =========================================================
  INSERT INTO pets (id, user_id, name, species, breed, birth_date, gender, growth_stage, is_active)
  VALUES (
    v_pet_id,
    v_user_id,
    'Mango',
    'bird',
    'Cockatiel',
    '2024-03-15',
    'male',
    'adult',
    true
  );

  -- =========================================================
  -- 3) 체중 기록 - 3개월치 (2025-12 ~ 2026-02)
  --    코카틸 정상 체중: 80~100g, 완만한 곡선
  -- =========================================================
  INSERT INTO weight_records (id, pet_id, recorded_date, weight, memo) VALUES
  -- 2025년 12월
  (gen_random_uuid(), v_pet_id, '2025-12-01', 82.0, NULL),
  (gen_random_uuid(), v_pet_id, '2025-12-04', 83.5, NULL),
  (gen_random_uuid(), v_pet_id, '2025-12-07', 82.8, NULL),
  (gen_random_uuid(), v_pet_id, '2025-12-10', 84.0, NULL),
  (gen_random_uuid(), v_pet_id, '2025-12-13', 85.2, NULL),
  (gen_random_uuid(), v_pet_id, '2025-12-16', 84.5, NULL),
  (gen_random_uuid(), v_pet_id, '2025-12-19', 86.0, NULL),
  (gen_random_uuid(), v_pet_id, '2025-12-22', 85.8, NULL),
  (gen_random_uuid(), v_pet_id, '2025-12-25', 87.0, NULL),
  (gen_random_uuid(), v_pet_id, '2025-12-28', 86.5, NULL),
  (gen_random_uuid(), v_pet_id, '2025-12-31', 87.2, NULL),

  -- 2026년 1월
  (gen_random_uuid(), v_pet_id, '2026-01-02', 87.5, NULL),
  (gen_random_uuid(), v_pet_id, '2026-01-05', 88.0, NULL),
  (gen_random_uuid(), v_pet_id, '2026-01-08', 87.3, NULL),
  (gen_random_uuid(), v_pet_id, '2026-01-11', 88.5, NULL),
  (gen_random_uuid(), v_pet_id, '2026-01-14', 89.0, NULL),
  (gen_random_uuid(), v_pet_id, '2026-01-17', 88.2, NULL),
  (gen_random_uuid(), v_pet_id, '2026-01-20', 89.5, NULL),
  (gen_random_uuid(), v_pet_id, '2026-01-23', 90.0, NULL),
  (gen_random_uuid(), v_pet_id, '2026-01-26', 89.8, NULL),
  (gen_random_uuid(), v_pet_id, '2026-01-29', 90.5, NULL),

  -- 2026년 2월
  (gen_random_uuid(), v_pet_id, '2026-02-01', 90.2, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-03', 91.0, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-06', 90.5, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-09', 91.5, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-12', 91.0, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-15', 92.0, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-17', 91.8, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-19', 92.5, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-21', 92.0, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-23', 92.8, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-25', 93.0, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-27', 92.5, NULL),
  (gen_random_uuid(), v_pet_id, '2026-02-28', 93.2, NULL);

  -- =========================================================
  -- 4) 일일 기록 - 최근 14일
  --    mood: great/good/normal/bad/sick
  --    activity_level: 1~5
  -- =========================================================
  INSERT INTO daily_records (id, pet_id, recorded_date, notes, mood, activity_level) VALUES
  (gen_random_uuid(), v_pet_id, '2026-02-15', 'Sang a new melody today!', 'great', 5),
  (gen_random_uuid(), v_pet_id, '2026-02-16', 'Calm morning, napped a lot', 'good', 3),
  (gen_random_uuid(), v_pet_id, '2026-02-17', 'Played with bell toy', 'great', 5),
  (gen_random_uuid(), v_pet_id, '2026-02-18', 'Ate well, preened feathers', 'good', 4),
  (gen_random_uuid(), v_pet_id, '2026-02-19', 'Quiet day, stayed on perch', 'normal', 2),
  (gen_random_uuid(), v_pet_id, '2026-02-20', 'Very chatty and active!', 'great', 5),
  (gen_random_uuid(), v_pet_id, '2026-02-21', 'Enjoyed head scratches', 'good', 4),
  (gen_random_uuid(), v_pet_id, '2026-02-22', 'Tried new veggie treats', 'good', 3),
  (gen_random_uuid(), v_pet_id, '2026-02-23', 'Flew around the room happily', 'great', 5),
  (gen_random_uuid(), v_pet_id, '2026-02-24', 'Relaxed day, soft chirping', 'good', 3),
  (gen_random_uuid(), v_pet_id, '2026-02-25', 'Morning stretch & singing', 'great', 4),
  (gen_random_uuid(), v_pet_id, '2026-02-26', 'Cuddly mood, shoulder time', 'good', 4),
  (gen_random_uuid(), v_pet_id, '2026-02-27', 'Loved the new perch toy', 'great', 5),
  (gen_random_uuid(), v_pet_id, '2026-02-28', 'Happy and healthy today!', 'great', 4);

  -- =========================================================
  -- 5) 음식 기록 - 최근 14일
  --    코카틸 일일 식사량: 15~25g, 목표 20g
  -- =========================================================
  INSERT INTO food_records (id, pet_id, recorded_date, total_grams, target_grams, count) VALUES
  (gen_random_uuid(), v_pet_id, '2026-02-15', 18.5, 20.0, 2),
  (gen_random_uuid(), v_pet_id, '2026-02-16', 20.0, 20.0, 2),
  (gen_random_uuid(), v_pet_id, '2026-02-17', 22.0, 20.0, 3),
  (gen_random_uuid(), v_pet_id, '2026-02-18', 19.5, 20.0, 2),
  (gen_random_uuid(), v_pet_id, '2026-02-19', 17.0, 20.0, 2),
  (gen_random_uuid(), v_pet_id, '2026-02-20', 21.5, 20.0, 3),
  (gen_random_uuid(), v_pet_id, '2026-02-21', 20.0, 20.0, 2),
  (gen_random_uuid(), v_pet_id, '2026-02-22', 23.0, 20.0, 3),
  (gen_random_uuid(), v_pet_id, '2026-02-23', 19.0, 20.0, 2),
  (gen_random_uuid(), v_pet_id, '2026-02-24', 20.5, 20.0, 2),
  (gen_random_uuid(), v_pet_id, '2026-02-25', 21.0, 20.0, 2),
  (gen_random_uuid(), v_pet_id, '2026-02-26', 18.0, 20.0, 2),
  (gen_random_uuid(), v_pet_id, '2026-02-27', 22.5, 20.0, 3),
  (gen_random_uuid(), v_pet_id, '2026-02-28', 20.0, 20.0, 2);

  -- =========================================================
  -- 6) 물 기록 - 최근 14일
  --    코카틸 일일 음수량: 5~15ml, 목표 10ml
  -- =========================================================
  INSERT INTO water_records (id, pet_id, recorded_date, total_ml, target_ml, count) VALUES
  (gen_random_uuid(), v_pet_id, '2026-02-15', 8.0,  10.0, 3),
  (gen_random_uuid(), v_pet_id, '2026-02-16', 10.0, 10.0, 4),
  (gen_random_uuid(), v_pet_id, '2026-02-17', 12.0, 10.0, 5),
  (gen_random_uuid(), v_pet_id, '2026-02-18', 9.5,  10.0, 3),
  (gen_random_uuid(), v_pet_id, '2026-02-19', 7.0,  10.0, 3),
  (gen_random_uuid(), v_pet_id, '2026-02-20', 11.5, 10.0, 4),
  (gen_random_uuid(), v_pet_id, '2026-02-21', 10.0, 10.0, 4),
  (gen_random_uuid(), v_pet_id, '2026-02-22', 13.0, 10.0, 5),
  (gen_random_uuid(), v_pet_id, '2026-02-23', 9.0,  10.0, 3),
  (gen_random_uuid(), v_pet_id, '2026-02-24', 10.5, 10.0, 4),
  (gen_random_uuid(), v_pet_id, '2026-02-25', 11.0, 10.0, 4),
  (gen_random_uuid(), v_pet_id, '2026-02-26', 8.5,  10.0, 3),
  (gen_random_uuid(), v_pet_id, '2026-02-27', 12.5, 10.0, 5),
  (gen_random_uuid(), v_pet_id, '2026-02-28', 10.0, 10.0, 4);

  -- =========================================================
  -- 7) 스케줄 - 향후 2주 (다양한 색상)
  -- =========================================================
  INSERT INTO schedules (id, pet_id, start_time, end_time, title, description, color, reminder_minutes) VALUES
  -- 이번 주
  (gen_random_uuid(), v_pet_id,
   '2026-03-01 10:00:00+09', '2026-03-01 11:00:00+09',
   'Vet Checkup', 'Regular health checkup', '#4CAF50', 30),
  (gen_random_uuid(), v_pet_id,
   '2026-03-02 14:00:00+09', '2026-03-02 14:30:00+09',
   'Nail Trimming', 'Trim nails carefully', '#FF9A42', 15),
  (gen_random_uuid(), v_pet_id,
   '2026-03-03 09:00:00+09', '2026-03-03 09:30:00+09',
   'Bath Time', 'Gentle mist bath', '#42A5F5', 10),
  (gen_random_uuid(), v_pet_id,
   '2026-03-05 15:00:00+09', '2026-03-05 15:30:00+09',
   'Wing Check', 'Check flight feathers', '#AB47BC', 15),
  -- 다음 주
  (gen_random_uuid(), v_pet_id,
   '2026-03-07 10:00:00+09', '2026-03-07 10:30:00+09',
   'Weigh-in Day', 'Weekly weight check', '#FF7043', 10),
  (gen_random_uuid(), v_pet_id,
   '2026-03-09 11:00:00+09', '2026-03-09 12:00:00+09',
   'Cage Deep Clean', 'Full cage cleaning', '#26A69A', 30),
  (gen_random_uuid(), v_pet_id,
   '2026-03-11 14:00:00+09', '2026-03-11 14:30:00+09',
   'New Toy Setup', 'Install foraging toys', '#FFA726', 10);

  -- =========================================================
  -- 8) 알림 - 최근 며칠
  -- =========================================================
  INSERT INTO notifications (id, user_id, pet_id, type, title, message, is_read) VALUES
  (gen_random_uuid(), v_user_id, v_pet_id, 'weight',
   'Weight Recorded!', 'Mango weighs 93.2g today. Looking healthy!', false),
  (gen_random_uuid(), v_user_id, v_pet_id, 'schedule',
   'Upcoming: Vet Checkup', 'Mango has a vet checkup on Mar 1 at 10:00 AM', false),
  (gen_random_uuid(), v_user_id, v_pet_id, 'health',
   'Weekly Health Summary', 'Mango had a great week! Activity level: High', true),
  (gen_random_uuid(), v_user_id, v_pet_id, 'reminder',
   'Time to Record Weight', 'Don''t forget to record Mango''s weight today!', true);

  RAISE NOTICE 'Demo data inserted successfully for user % with pet Mango (id: %)', v_user_id, v_pet_id;

END $$;

COMMIT;
