-- IIOP final functional closure: business idempotency constraints for existing databases.
-- Before applying, verify that the duplicate-detection queries below return no rows.

USE iiop_inspection;

SELECT plan_id, scheduled_start_time, COUNT(*) AS duplicate_count
FROM ins_task
WHERE plan_id IS NOT NULL
GROUP BY plan_id, scheduled_start_time
HAVING COUNT(*) > 1;

ALTER TABLE ins_task
    ADD UNIQUE KEY uk_ins_task_plan_window (plan_id, scheduled_start_time);

USE iiop_maintenance;

SELECT defect_id, COUNT(*) AS duplicate_count
FROM mt_work_order
WHERE defect_id IS NOT NULL
GROUP BY defect_id
HAVING COUNT(*) > 1;

SELECT ai_diagnosis_id, COUNT(*) AS duplicate_count
FROM mt_work_order
WHERE ai_diagnosis_id IS NOT NULL
GROUP BY ai_diagnosis_id
HAVING COUNT(*) > 1;

ALTER TABLE mt_work_order
    ADD UNIQUE KEY uk_mt_work_order_defect (defect_id),
    ADD UNIQUE KEY uk_mt_work_order_ai (ai_diagnosis_id),
    DROP KEY idx_mt_work_order_defect,
    DROP KEY idx_mt_work_order_ai;
