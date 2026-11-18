USE hostel_db;

INSERT INTO Hostel (name, type) VALUES ('Aryabhata Hostel','Boys'),('Gargi Hostel','Girls'),('Vivekananda Hostel','Boys');

INSERT INTO Room (hostel_id, room_no, capacity) VALUES
(1,'A101',3),(1,'A102',3),(1,'A103',2),(1,'A104',2),
(2,'G101',3),(2,'G102',2),(2,'G103',2),(2,'G104',1),
(3,'V101',2),(3,'V102',2),(3,'V103',3),(3,'V104',1);

INSERT INTO Student (usn, name, email, phone, department, year) VALUES
('2092408001','Rahul Sharma','rahul@svyasa.edu','9800000001','CSE',3),
('2092408002','Arjun Reddy','arjun@svyasa.edu','9800000002','CSE',3),
('2092408003','Karthik N','karthik@svyasa.edu','9800000003','ECE',2),
('2092408004','Vikram S','vikram@svyasa.edu','9800000004','ME',4),
('2092408005','Manoj Kumar','manoj@svyasa.edu','9800000005','CSE',1),
('2092408006','Suresh P','suresh@svyasa.edu','9800000006','ECE',2),
('2092408007','Deepak R','deepak@svyasa.edu','9800000007','CSE',3),
('2092408008','Naveen G','naveen@svyasa.edu','9800000008','CE',4),
('2092408009','Ananya K','ananya@svyasa.edu','9800000009','CSE',3),
('2092408010','Priya M','priya@svyasa.edu','9800000010','ECE',2),
('2092408011','Sneha B','sneha@svyasa.edu','9800000011','CSE',1),
('2092408012','Divya H','divya@svyasa.edu','9800000012','ME',2),
('2092408013','Meghana T','meghana@svyasa.edu','9800000013','CSE',4),
('2092408014','Tarun V','tarun@svyasa.edu','9800000014','CE',1),
('2092408015','Lavanya C','lavanya@svyasa.edu','9800000015','ECE',3);

-- 13 students housed; students 14 and 15 are still waiting for rooms.
INSERT INTO Allocation (student_id, room_id, start_date, end_date) VALUES
(1,1,'2025-07-01',NULL),(2,1,'2025-07-01',NULL),(3,2,'2025-07-01',NULL),
(4,3,'2025-07-01',NULL),(5,4,'2025-07-02',NULL),(6,9,'2025-07-02',NULL),
(7,9,'2025-07-02',NULL),(8,11,'2025-07-03',NULL),(9,5,'2025-07-01',NULL),
(10,5,'2025-07-01',NULL),(11,6,'2025-07-02',NULL),(12,7,'2025-07-02',NULL),
(13,8,'2025-07-03',NULL);

INSERT INTO Mess_Plan (plan_name, monthly_charge) VALUES
('Veg Standard',3200.00),('Non-Veg Standard',3800.00),('Veg Premium',4200.00);

INSERT INTO Mess_Subscription (student_id, plan_id, month, year) VALUES
(1,2,11,2026),(2,1,11,2026),(3,2,11,2026),(4,1,11,2026),(5,3,11,2026),
(6,2,11,2026),(7,1,11,2026),(8,2,11,2026),(9,1,11,2026),(10,3,11,2026),
(11,1,11,2026),(12,2,11,2026),(13,3,11,2026),
(1,2,10,2026),(2,1,10,2026),(9,1,10,2026);

INSERT INTO Fee_Payment (student_id, fee_type, amount, due_date, paid_date, status) VALUES
(1,'Hostel',45000,DATE_SUB(CURDATE(),INTERVAL 60 DAY),DATE_SUB(CURDATE(),INTERVAL 55 DAY),'Paid'),
(2,'Hostel',45000,DATE_SUB(CURDATE(),INTERVAL 60 DAY),DATE_SUB(CURDATE(),INTERVAL 50 DAY),'Paid'),
(3,'Hostel',45000,DATE_SUB(CURDATE(),INTERVAL 60 DAY),NULL,'Pending'),
(4,'Hostel',45000,DATE_SUB(CURDATE(),INTERVAL 60 DAY),DATE_SUB(CURDATE(),INTERVAL 58 DAY),'Paid'),
(5,'Hostel',45000,DATE_SUB(CURDATE(),INTERVAL 60 DAY),NULL,'Pending'),
(9,'Hostel',48000,DATE_SUB(CURDATE(),INTERVAL 60 DAY),DATE_SUB(CURDATE(),INTERVAL 52 DAY),'Paid'),
(10,'Hostel',48000,DATE_SUB(CURDATE(),INTERVAL 60 DAY),NULL,'Pending'),
(1,'Mess',3800,DATE_SUB(CURDATE(),INTERVAL 10 DAY),DATE_SUB(CURDATE(),INTERVAL 8 DAY),'Paid'),
(2,'Mess',3200,DATE_SUB(CURDATE(),INTERVAL 10 DAY),NULL,'Pending'),
(6,'Mess',3800,DATE_SUB(CURDATE(),INTERVAL 10 DAY),NULL,'Pending'),
(7,'Mess',3200,DATE_ADD(CURDATE(),INTERVAL 5 DAY),NULL,'Pending'),
(8,'Hostel',45000,DATE_SUB(CURDATE(),INTERVAL 60 DAY),DATE_SUB(CURDATE(),INTERVAL 45 DAY),'Paid'),
(11,'Hostel',48000,DATE_SUB(CURDATE(),INTERVAL 60 DAY),DATE_SUB(CURDATE(),INTERVAL 40 DAY),'Paid'),
(12,'Fine',500,DATE_SUB(CURDATE(),INTERVAL 20 DAY),NULL,'Pending');

INSERT INTO Staff (name, role, phone) VALUES
('Mr. Ramesh Gowda','Warden','9811111111'),
('Mrs. Lakshmi','Cook','9822222222'),
('Mr. Basavaraj','Maintenance','9833333333'),
('Mr. Shivu','Housekeeping','9844444444'),
('Mrs. Kavitha','Warden','9855555555');

INSERT INTO Complaint_Category (name) VALUES
('Food Quality'),('Water Supply'),('Electrical'),('Cleanliness'),('Internet'),('Furniture');

INSERT INTO Complaint (student_id, category_id, staff_id, description, priority, status, raised_date, resolved_date) VALUES
(1,1,2,'Rice undercooked in dinner','Medium','Resolved',DATE_SUB(CURDATE(),INTERVAL 20 DAY),DATE_SUB(CURDATE(),INTERVAL 18 DAY)),
(2,2,3,'No hot water in block A','High','Resolved',DATE_SUB(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 14 DAY)),
(3,3,3,'Fan not working in A102','Medium','In Progress',DATE_SUB(CURDATE(),INTERVAL 6 DAY),NULL),
(4,4,4,'Corridor not cleaned for 3 days','Low','Open',DATE_SUB(CURDATE(),INTERVAL 5 DAY),NULL),
(5,1,2,'Stale chapati served at breakfast','High','Open',DATE_SUB(CURDATE(),INTERVAL 4 DAY),NULL),
(6,5,NULL,'Wi-Fi drops every evening','Medium','Open',DATE_SUB(CURDATE(),INTERVAL 8 DAY),NULL),
(7,6,3,'Broken study table','Low','Resolved',DATE_SUB(CURDATE(),INTERVAL 12 DAY),DATE_SUB(CURDATE(),INTERVAL 9 DAY)),
(9,2,3,'Water tank overflow near G101','High','In Progress',DATE_SUB(CURDATE(),INTERVAL 3 DAY),NULL),
(10,4,4,'Washroom needs cleaning','Medium','Resolved',DATE_SUB(CURDATE(),INTERVAL 10 DAY),DATE_SUB(CURDATE(),INTERVAL 8 DAY)),
(11,1,2,'Too much oil in curries','Low','Open',DATE_SUB(CURDATE(),INTERVAL 2 DAY),NULL),
(12,3,3,'Tube light flickering','Medium','Open',DATE_SUB(CURDATE(),INTERVAL 7 DAY),NULL),
(1,5,NULL,'Slow internet in room','Low','Open',DATE_SUB(CURDATE(),INTERVAL 1 DAY),NULL),
(2,1,2,'Found insect in food','High','Resolved',DATE_SUB(CURDATE(),INTERVAL 25 DAY),DATE_SUB(CURDATE(),INTERVAL 24 DAY)),
(13,2,3,'Low water pressure','Medium','Resolved',DATE_SUB(CURDATE(),INTERVAL 18 DAY),DATE_SUB(CURDATE(),INTERVAL 15 DAY)),
(8,3,3,'Power socket loose','High','Open',DATE_SUB(CURDATE(),INTERVAL 9 DAY),NULL);
