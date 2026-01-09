-- =====================================================
-- Perch Care Storage Buckets
-- 실행 순서: 3번째 (테이블, RLS 후)
-- Supabase SQL Editor에서 실행하세요
-- =====================================================

-- =====================================================
-- 1. PET-IMAGES 버킷 (펫 프로필 이미지)
-- =====================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'pet-images',
  'pet-images',
  true, -- public access
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- pet-images 정책
DROP POLICY IF EXISTS "Users can upload pet images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own pet images" ON storage.objects;

-- 인증된 사용자가 자신의 폴더에 업로드
CREATE POLICY "Users can upload pet images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'pet-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- 공개 조회
CREATE POLICY "Anyone can view pet images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'pet-images');

-- 자신의 이미지 삭제
CREATE POLICY "Users can delete own pet images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'pet-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- =====================================================
-- 2. HEALTH-CHECK-IMAGES 버킷 (AI 건강 체크 이미지)
-- =====================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'health-check-images',
  'health-check-images',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- health-check-images 정책
DROP POLICY IF EXISTS "Users can upload health check images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view health check images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own health check images" ON storage.objects;

CREATE POLICY "Users can upload health check images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'health-check-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Anyone can view health check images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'health-check-images');

CREATE POLICY "Users can delete own health check images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'health-check-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- =====================================================
-- 3. AVATARS 버킷 (사용자 프로필 이미지)
-- =====================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  2097152, -- 2MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- avatars 정책
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;

CREATE POLICY "Users can upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Anyone can view avatars"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

CREATE POLICY "Users can update own avatar"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own avatar"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- =====================================================
-- 4. WCI-IMAGES 버킷 (체형 지수 이미지)
-- =====================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'wci-images',
  'wci-images',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- wci-images 정책
DROP POLICY IF EXISTS "Users can upload wci images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view wci images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own wci images" ON storage.objects;

CREATE POLICY "Users can upload wci images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'wci-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Anyone can view wci images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'wci-images');

CREATE POLICY "Users can delete own wci images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'wci-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- =====================================================
-- 완료 메시지
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '✅ 모든 Storage 버킷이 성공적으로 생성되었습니다!';
END $$;
