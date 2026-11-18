DROP DATABASE IF EXISTS hostel_db;
CREATE DATABASE hostel_db;
USE hostel_db;

CREATE TABLE Hostel (
  hostel_id INT PRIMARY KEY AUTO_INCREMENT,
  name      VARCHAR(50) NOT NULL UNIQUE,
  type      VARCHAR(10) NOT NULL CHECK (type IN ('Boys','Girls'))
);

CREATE TABLE Room (
  room_id   INT PRIMARY KEY AUTO_INCREMENT,
  hostel_id INT NOT NULL,
  room_no   VARCHAR(10) NOT NULL,
  capacity  INT NOT NULL DEFAULT 2 CHECK (capacity BETWEEN 1 AND 4),
  UNIQUE (hostel_id, room_no),
  FOREIGN KEY (hostel_id) REFERENCES Hostel(hostel_id) ON DELETE CASCADE
);

CREATE TABLE Student (
  student_id INT PRIMARY KEY AUTO_INCREMENT,
  usn        VARCHAR(15) NOT NULL UNIQUE,
  name       VARCHAR(80) NOT NULL,
  email      VARCHAR(100) NOT NULL UNIQUE,
  phone      VARCHAR(15),
  department VARCHAR(40) NOT NULL,
  year       INT NOT NULL CHECK (year BETWEEN 1 AND 4)
);

CREATE TABLE Allocation (
  allocation_id INT PRIMARY KEY AUTO_INCREMENT,
  student_id    INT NOT NULL,
  room_id       INT NOT NULL,
  start_date    DATE NOT NULL,
  end_date      DATE NULL,                    
  CHECK (end_date IS NULL OR end_date > start_date),
  FOREIGN KEY (student_id) REFERENCES Student(student_id) ON DELETE CASCADE,
  FOREIGN KEY (room_id)    REFERENCES Room(room_id)
);

CREATE TABLE Mess_Plan (
  plan_id        INT PRIMARY KEY AUTO_INCREMENT,
  plan_name      VARCHAR(40) NOT NULL UNIQUE,
  monthly_charge DECIMAL(8,2) NOT NULL CHECK (monthly_charge > 0)
);

CREATE TABLE Mess_Subscription (
  sub_id     INT PRIMARY KEY AUTO_INCREMENT,
  student_id INT NOT NULL,
  plan_id    INT NOT NULL,
  month      INT NOT NULL CHECK (month BETWEEN 1 AND 12),
  year       INT NOT NULL,
  UNIQUE (student_id, month, year),             
  FOREIGN KEY (student_id) REFERENCES Student(student_id) ON DELETE CASCADE,
  FOREIGN KEY (plan_id)    REFERENCES Mess_Plan(plan_id)
);

CREATE TABLE Fee_Payment (
  payment_id INT PRIMARY KEY AUTO_INCREMENT,
  student_id INT NOT NULL,
  fee_type   VARCHAR(20) NOT NULL CHECK (fee_type IN ('Hostel','Mess','Fine')),
  amount     DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  due_date   DATE NOT NULL,
  paid_date  DATE NULL,
  status     VARCHAR(10) NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending','Paid')),
  FOREIGN KEY (student_id) REFERENCES Student(student_id) ON DELETE CASCADE
);

CREATE TABLE Staff (
  staff_id INT PRIMARY KEY AUTO_INCREMENT,
  name     VARCHAR(80) NOT NULL,
  role     VARCHAR(20) NOT NULL CHECK (role IN ('Warden','Cook','Maintenance','Housekeeping')),
  phone    VARCHAR(15) NOT NULL UNIQUE
);

CREATE TABLE Complaint_Category (
  category_id INT PRIMARY KEY AUTO_INCREMENT,
  name        VARCHAR(40) NOT NULL UNIQUE
);

CREATE TABLE Complaint (
  complaint_id  INT PRIMARY KEY AUTO_INCREMENT,
  student_id    INT NOT NULL,
  category_id   INT NOT NULL,
  staff_id      INT NULL,
  description   TEXT NOT NULL,
  priority      VARCHAR(10) NOT NULL DEFAULT 'Medium' CHECK (priority IN ('Low','Medium','High')),
  status        VARCHAR(12) NOT NULL DEFAULT 'Open'   CHECK (status IN ('Open','In Progress','Resolved')),
  raised_date   DATE NOT NULL,
  resolved_date DATE NULL,
  FOREIGN KEY (student_id)  REFERENCES Student(student_id) ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES Complaint_Category(category_id),
  FOREIGN KEY (staff_id)    REFERENCES Staff(staff_id) ON DELETE SET NULL
);

CREATE INDEX idx_complaint_status ON Complaint(status);
CREATE INDEX idx_fee_status       ON Fee_Payment(status, due_date);

-- ---------- TRIGGERS ----------
DELIMITER //

CREATE TRIGGER trg_allocation_check BEFORE INSERT ON Allocation
FOR EACH ROW
BEGIN
  DECLARE occupied INT; DECLARE cap INT; DECLARE already INT;
  SELECT capacity INTO cap FROM Room WHERE room_id = NEW.room_id;
  SELECT COUNT(*) INTO occupied FROM Allocation WHERE room_id = NEW.room_id AND end_date IS NULL;
  SELECT COUNT(*) INTO already  FROM Allocation WHERE student_id = NEW.student_id AND end_date IS NULL;
  IF NEW.end_date IS NULL AND occupied >= cap THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room is full: capacity reached';
  END IF;
  IF NEW.end_date IS NULL AND already > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student already has an active room';
  END IF;
END//

-- 2. Stamp the resolved date automatically when a complaint is closed.
CREATE TRIGGER trg_complaint_resolve BEFORE UPDATE ON Complaint
FOR EACH ROW
BEGIN
  IF NEW.status = 'Resolved' AND OLD.status <> 'Resolved' THEN
    SET NEW.resolved_date = CURDATE();
  END IF;
  IF NEW.status <> 'Resolved' THEN
    SET NEW.resolved_date = NULL;
  END IF;
END//

-- 3. Stamp the paid date automatically when a fee is marked Paid.
CREATE TRIGGER trg_fee_paid BEFORE UPDATE ON Fee_Payment
FOR EACH ROW
BEGIN
  IF NEW.status = 'Paid' AND OLD.status <> 'Paid' THEN
    SET NEW.paid_date = CURDATE();
  END IF;
END//

DELIMITER ;

-- ---------- VIEWS ----------
CREATE VIEW v_pending_complaints AS
SELECT c.complaint_id, s.name AS student, s.usn, cc.name AS category, c.priority, c.status,
       c.raised_date, DATEDIFF(CURDATE(), c.raised_date) AS days_pending,
       st.name AS assigned_to
FROM Complaint c
JOIN Student s ON s.student_id = c.student_id
JOIN Complaint_Category cc ON cc.category_id = c.category_id
LEFT JOIN Staff st ON st.staff_id = c.staff_id
WHERE c.status <> 'Resolved';

CREATE VIEW v_fee_defaulters AS
SELECT s.student_id, s.name, s.usn, f.fee_type, f.amount, f.due_date,
       DATEDIFF(CURDATE(), f.due_date) AS days_overdue
FROM Fee_Payment f
JOIN Student s ON s.student_id = f.student_id
WHERE f.status = 'Pending' AND f.due_date < CURDATE();

CREATE VIEW v_room_occupancy AS
SELECT r.room_id, h.name AS hostel, r.room_no, r.capacity,
       COUNT(a.allocation_id) AS occupied,
       r.capacity - COUNT(a.allocation_id) AS free_beds
FROM Room r
JOIN Hostel h ON h.hostel_id = r.hostel_id
LEFT JOIN Allocation a ON a.room_id = r.room_id AND a.end_date IS NULL
GROUP BY r.room_id, h.name, r.room_no, r.capacity;

-- ---------- ESCALATION (complaints must not sit unnoticed) ----------
DELIMITER //
CREATE PROCEDURE escalate_overdue_complaints(IN max_days INT, OUT escalated INT)
BEGIN
  UPDATE Complaint
  SET priority = 'High'
  WHERE status <> 'Resolved'
    AND priority <> 'High'
    AND DATEDIFF(CURDATE(), raised_date) >= max_days;
  SET escalated = ROW_COUNT();
END//
DELIMITER ;

-- What the warden must act on first: High priority and already waiting 3+ days.
CREATE VIEW v_escalated_complaints AS
SELECT complaint_id, student, usn, category, status, days_pending, assigned_to
FROM v_pending_complaints
WHERE priority = 'High' AND days_pending >= 3;