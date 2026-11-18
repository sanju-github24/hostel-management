USE hostel_db;

-- ===== CRUD =====
INSERT INTO Student (usn,name,email,phone,department,year) VALUES ('2092408099','Test Student','test@svyasa.edu','9800000099','CSE',2);   -- Create
SELECT * FROM Student WHERE department = 'CSE';                                                                                          -- Read
UPDATE Student SET phone = '9811122233' WHERE usn = '2092408099';                                                                        -- Update
DELETE FROM Student WHERE usn = '2092408099';                                                                                            -- Delete

-- ===== JOINS (3+) =====
-- J1: INNER JOIN - who lives where
SELECT s.name, s.usn, h.name AS hostel, r.room_no
FROM Student s JOIN Allocation a ON a.student_id = s.student_id AND a.end_date IS NULL
JOIN Room r ON r.room_id = a.room_id JOIN Hostel h ON h.hostel_id = r.hostel_id;

-- J2: LEFT JOIN - students still without a room
SELECT s.name, s.usn FROM Student s
LEFT JOIN Allocation a ON a.student_id = s.student_id AND a.end_date IS NULL
WHERE a.allocation_id IS NULL;

-- J3: multi-table JOIN - complaint with student, category and assigned staff
SELECT c.complaint_id, s.name AS student, cc.name AS category, st.name AS staff, c.status
FROM Complaint c JOIN Student s ON s.student_id = c.student_id
JOIN Complaint_Category cc ON cc.category_id = c.category_id
LEFT JOIN Staff st ON st.staff_id = c.staff_id;

-- J4: SELF-style comparison - roommates sharing a room
SELECT r.room_no, s1.name AS roommate_1, s2.name AS roommate_2
FROM Allocation a1 JOIN Allocation a2 ON a1.room_id = a2.room_id AND a1.student_id < a2.student_id
JOIN Student s1 ON s1.student_id = a1.student_id JOIN Student s2 ON s2.student_id = a2.student_id
JOIN Room r ON r.room_id = a1.room_id WHERE a1.end_date IS NULL AND a2.end_date IS NULL;

-- ===== AGGREGATES =====
SELECT cc.name, COUNT(*) AS total_complaints FROM Complaint c JOIN Complaint_Category cc USING (category_id) GROUP BY cc.name;   -- COUNT
SELECT fee_type, SUM(amount) AS collected FROM Fee_Payment WHERE status = 'Paid' GROUP BY fee_type;                              -- SUM
SELECT ROUND(AVG(DATEDIFF(resolved_date, raised_date)),1) AS avg_days_to_resolve FROM Complaint WHERE status = 'Resolved';        -- AVG
SELECT MIN(monthly_charge) AS cheapest, MAX(monthly_charge) AS costliest FROM Mess_Plan;                                          -- MIN / MAX
SELECT cc.name, COUNT(*) AS n FROM Complaint c JOIN Complaint_Category cc USING (category_id)
GROUP BY cc.name HAVING COUNT(*) >= 3;                                                                                            -- HAVING

-- ===== NESTED QUERIES (2+) =====
-- N1: students who complained more than the average student
SELECT s.name, COUNT(*) AS complaints FROM Complaint c JOIN Student s USING (student_id)
GROUP BY s.student_id, s.name
HAVING COUNT(*) > (SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM Complaint GROUP BY student_id) t);

-- N2: rooms that still have a free bed (correlated subquery)
SELECT r.room_no, r.capacity FROM Room r
WHERE r.capacity > (SELECT COUNT(*) FROM Allocation a WHERE a.room_id = r.room_id AND a.end_date IS NULL);

-- N3: students with no complaint at all (NOT IN)
SELECT name FROM Student WHERE student_id NOT IN (SELECT student_id FROM Complaint);

-- N4: students owing more than the average pending amount
SELECT s.name, SUM(f.amount) AS owed FROM Fee_Payment f JOIN Student s USING (student_id)
WHERE f.status = 'Pending' GROUP BY s.student_id, s.name
HAVING SUM(f.amount) > (SELECT AVG(amount) FROM Fee_Payment WHERE status = 'Pending');

-- ===== VIEWS =====
SELECT * FROM v_pending_complaints ORDER BY days_pending DESC;
SELECT * FROM v_fee_defaulters ORDER BY days_overdue DESC;
SELECT * FROM v_room_occupancy;

-- ===== REPORTS =====
-- R1: complaint resolution time by category
SELECT cc.name AS category, COUNT(*) AS resolved, ROUND(AVG(DATEDIFF(c.resolved_date,c.raised_date)),1) AS avg_days
FROM Complaint c JOIN Complaint_Category cc USING (category_id) WHERE c.status = 'Resolved' GROUP BY cc.name ORDER BY avg_days DESC;

-- R2: fee collection vs pending
SELECT fee_type, SUM(CASE WHEN status='Paid' THEN amount ELSE 0 END) AS collected,
       SUM(CASE WHEN status='Pending' THEN amount ELSE 0 END) AS pending FROM Fee_Payment GROUP BY fee_type;

-- R3: hostel occupancy
SELECT hostel, SUM(capacity) AS beds, SUM(occupied) AS occupied, SUM(free_beds) AS free FROM v_room_occupancy GROUP BY hostel;

-- R4: mess subscription revenue for the month
SELECT mp.plan_name, COUNT(*) AS students, SUM(mp.monthly_charge) AS revenue
FROM Mess_Subscription ms JOIN Mess_Plan mp USING (plan_id) WHERE ms.month = 11 AND ms.year = 2026 GROUP BY mp.plan_name;

-- ===== TRIGGER / CONSTRAINT DEMOS (these should FAIL) =====
-- INSERT INTO Allocation (student_id, room_id, start_date) VALUES (14, 8, CURDATE());   -- room G104 full / wrong hostel type is app-level
-- INSERT INTO Allocation (student_id, room_id, start_date) VALUES (1, 4, CURDATE());    -- student already has a room
-- INSERT INTO Room (hostel_id, room_no, capacity) VALUES (1,'A105',9);                  -- CHECK capacity fails

-- ===== TRANSACTION DEMO (ACID) =====
START TRANSACTION;
UPDATE Allocation SET end_date = CURDATE() WHERE student_id = 5 AND end_date IS NULL;   -- vacate
INSERT INTO Allocation (student_id, room_id, start_date) VALUES (5, 10, CURDATE());     -- move
COMMIT;   -- use ROLLBACK; instead to undo both steps

-- ===== ESCALATION DEMO (stored procedure + view) =====
SELECT complaint_id, priority, status, DATEDIFF(CURDATE(), raised_date) AS days FROM Complaint WHERE status <> 'Resolved';   -- before
CALL escalate_overdue_complaints(3, @n);
SELECT @n AS complaints_escalated;
SELECT * FROM v_escalated_complaints ORDER BY days_pending DESC;                                                              -- after
