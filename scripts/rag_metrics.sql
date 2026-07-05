-- RAG 검색률 측정용 SQL 묶음 (production Postgres)
-- 사용: psql "$DATABASE_PUBLIC_URL" -f scripts/rag_metrics.sql
-- 작성일: 2026-05-14

\echo '================================'
\echo '  0. 데이터 기간 확인'
\echo '================================'
SELECT 'encyclopedia' AS feature,
       MIN(created_at) AS first, MAX(created_at) AS last,
       COUNT(*) AS total_rows
FROM ai_encyclopedia_logs
UNION ALL
SELECT 'vision',
       MIN(created_at), MAX(created_at), COUNT(*)
FROM ai_vision_logs;

\echo ''
\echo '================================'
\echo '  1. Encyclopedia: 일별 호출 수 (최근 30일)'
\echo '================================'
SELECT date_trunc('day', created_at)::date AS day,
       COUNT(*) AS calls,
       ROUND(AVG(response_time_ms)::numeric, 0) AS avg_ms,
       ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms)::numeric, 0) AS p95_ms,
       ROUND(AVG(query_length)::numeric, 0) AS avg_q_len,
       ROUND(AVG(response_length)::numeric, 0) AS avg_r_len
FROM ai_encyclopedia_logs
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY day ORDER BY day;

\echo ''
\echo '================================'
\echo '  2. Vision: 모드/부위별 호출 수 (최근 30일)'
\echo '================================'
SELECT mode, COALESCE(part, '(none)') AS part,
       COUNT(*) AS calls,
       ROUND(AVG(confidence_score)::numeric, 1) AS avg_conf,
       ROUND(AVG(response_time_ms)::numeric, 0) AS avg_ms,
       COUNT(*) FILTER (WHERE overall_status='normal') AS normal,
       COUNT(*) FILTER (WHERE overall_status='caution') AS caution,
       COUNT(*) FILTER (WHERE overall_status='warning') AS warning,
       COUNT(*) FILTER (WHERE overall_status='critical') AS critical
FROM ai_vision_logs
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY mode, part ORDER BY calls DESC;

\echo ''
\echo '================================'
\echo '  3. 사용자별 분포 (Top 20, 최근 30일)'
\echo '================================'
WITH enc AS (
  SELECT user_id, COUNT(*) AS enc_calls
  FROM ai_encyclopedia_logs
  WHERE created_at >= NOW() - INTERVAL '30 days'
  GROUP BY user_id
),
vis AS (
  SELECT user_id, COUNT(*) AS vis_calls
  FROM ai_vision_logs
  WHERE created_at >= NOW() - INTERVAL '30 days'
  GROUP BY user_id
)
SELECT COALESCE(enc.user_id, vis.user_id) AS user_id,
       COALESCE(enc_calls, 0) AS enc, COALESCE(vis_calls, 0) AS vis,
       COALESCE(enc_calls, 0) + COALESCE(vis_calls, 0) AS total
FROM enc FULL OUTER JOIN vis USING (user_id)
ORDER BY total DESC LIMIT 20;

\echo ''
\echo '================================'
\echo '  4. Vision: 신뢰도(confidence) 분포 — 10단계 히스토그램'
\echo '================================'
SELECT width_bucket(confidence_score, 0, 100, 10) AS bucket,
       (width_bucket(confidence_score, 0, 100, 10) - 1) * 10 || '–' || (width_bucket(confidence_score, 0, 100, 10) * 10) AS range,
       COUNT(*) AS n
FROM ai_vision_logs
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY bucket ORDER BY bucket;

\echo ''
\echo '================================'
\echo '  5. Encyclopedia: 응답시간 분포 (전체 기간)'
\echo '================================'
SELECT
  ROUND(MIN(response_time_ms)::numeric, 0) AS min_ms,
  ROUND(AVG(response_time_ms)::numeric, 0) AS avg_ms,
  ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY response_time_ms)::numeric, 0) AS p50_ms,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms)::numeric, 0) AS p95_ms,
  ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY response_time_ms)::numeric, 0) AS p99_ms,
  ROUND(MAX(response_time_ms)::numeric, 0) AS max_ms,
  COUNT(*) AS n
FROM ai_encyclopedia_logs;

\echo ''
\echo '================================'
\echo '  6. Vision: 응답시간 분포 (전체 기간)'
\echo '================================'
SELECT
  ROUND(MIN(response_time_ms)::numeric, 0) AS min_ms,
  ROUND(AVG(response_time_ms)::numeric, 0) AS avg_ms,
  ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY response_time_ms)::numeric, 0) AS p50_ms,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms)::numeric, 0) AS p95_ms,
  ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY response_time_ms)::numeric, 0) AS p99_ms,
  ROUND(MAX(response_time_ms)::numeric, 0) AS max_ms,
  COUNT(*) AS n
FROM ai_vision_logs;

\echo ''
\echo '================================'
\echo '  7. 전체 요약 (Coverage 분모)'
\echo '================================'
SELECT 'encyclopedia_30d' AS metric, COUNT(*) AS value
FROM ai_encyclopedia_logs WHERE created_at >= NOW() - INTERVAL '30 days'
UNION ALL
SELECT 'encyclopedia_7d', COUNT(*) FROM ai_encyclopedia_logs WHERE created_at >= NOW() - INTERVAL '7 days'
UNION ALL
SELECT 'encyclopedia_total', COUNT(*) FROM ai_encyclopedia_logs
UNION ALL
SELECT 'vision_30d', COUNT(*) FROM ai_vision_logs WHERE created_at >= NOW() - INTERVAL '30 days'
UNION ALL
SELECT 'vision_7d', COUNT(*) FROM ai_vision_logs WHERE created_at >= NOW() - INTERVAL '7 days'
UNION ALL
SELECT 'vision_total', COUNT(*) FROM ai_vision_logs;
