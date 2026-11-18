"""Hostel Mess & Complaint Tracker - Flask front end for the DBMS mini project."""
import os
import mysql.connector
from flask import Flask, render_template, request, redirect, url_for, flash

app = Flask(__name__)
app.secret_key = "change-me"

DB = dict(
    host=os.getenv("DB_HOST", "localhost"),
    user=os.getenv("DB_USER", "root"),
    password=os.getenv("DB_PASSWORD", ""),
    database=os.getenv("DB_NAME", "hostel_db"),
)


def run(sql, args=(), write=False):
    """Run one query. Returns rows for SELECT, or lastrowid for writes."""
    conn = mysql.connector.connect(**DB)
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, args)
        if write:
            conn.commit()
            return cur.lastrowid
        return cur.fetchall()
    finally:
        conn.close()


def attempt(sql, args, ok_msg):
    """Write query that shows database errors (triggers, CHECK, UNIQUE) as a flash message."""
    try:
        run(sql, args, write=True)
        flash(ok_msg, "ok")
    except mysql.connector.Error as e:
        flash(e.msg, "error")


@app.route("/")
def dashboard():
    stats = run("""SELECT
        (SELECT COUNT(*) FROM Student) AS students,
        (SELECT COUNT(*) FROM v_pending_complaints) AS open_complaints,
        (SELECT COALESCE(SUM(free_beds),0) FROM v_room_occupancy) AS free_beds,
        (SELECT COALESCE(SUM(amount),0) FROM v_fee_defaulters) AS overdue_amount""")[0]
    stats["escalated"] = run("SELECT COUNT(*) AS n FROM v_escalated_complaints")[0]["n"]
    urgent = run("SELECT * FROM v_pending_complaints ORDER BY days_pending DESC LIMIT 6")
    defaulters = run("SELECT * FROM v_fee_defaulters ORDER BY days_overdue DESC LIMIT 6")
    return render_template("dashboard.html", stats=stats, urgent=urgent, defaulters=defaulters)


@app.route("/students", methods=["GET", "POST"])
def students():
    if request.method == "POST":
        f = request.form
        attempt("INSERT INTO Student (usn,name,email,phone,department,year) VALUES (%s,%s,%s,%s,%s,%s)",
                (f["usn"], f["name"], f["email"], f["phone"], f["department"], f["year"]), "Student added")
        return redirect(url_for("students"))
    q = request.args.get("q", "")
    rows = run("""SELECT s.*, CONCAT(h.name,' / ',r.room_no) AS room
                  FROM Student s
                  LEFT JOIN Allocation a ON a.student_id = s.student_id AND a.end_date IS NULL
                  LEFT JOIN Room r ON r.room_id = a.room_id
                  LEFT JOIN Hostel h ON h.hostel_id = r.hostel_id
                  WHERE s.name LIKE %s OR s.usn LIKE %s ORDER BY s.student_id""", (f"%{q}%", f"%{q}%"))
    return render_template("students.html", rows=rows, q=q)


@app.post("/students/<int:sid>/delete")
def delete_student(sid):
    attempt("DELETE FROM Student WHERE student_id=%s", (sid,), "Student deleted")
    return redirect(url_for("students"))


@app.post("/students/<int:sid>/update")
def update_student(sid):
    attempt("UPDATE Student SET phone=%s, year=%s WHERE student_id=%s",
            (request.form["phone"], request.form["year"], sid), "Student updated")
    return redirect(url_for("students"))


@app.route("/complaints", methods=["GET", "POST"])
def complaints():
    if request.method == "POST":
        f = request.form
        attempt("""INSERT INTO Complaint (student_id,category_id,staff_id,description,priority,raised_date)
                   VALUES (%s,%s,NULLIF(%s,''),%s,%s,CURDATE())""",
                (f["student_id"], f["category_id"], f.get("staff_id", ""), f["description"], f["priority"]),
                "Complaint raised")
        return redirect(url_for("complaints"))
    status = request.args.get("status", "")
    rows = run("""SELECT c.*, s.name AS student, cc.name AS category, st.name AS staff,
                  DATEDIFF(COALESCE(c.resolved_date, CURDATE()), c.raised_date) AS age_days
                  FROM Complaint c JOIN Student s ON s.student_id=c.student_id
                  JOIN Complaint_Category cc ON cc.category_id=c.category_id
                  LEFT JOIN Staff st ON st.staff_id=c.staff_id
                  WHERE (%s='' OR c.status=%s) ORDER BY c.status='Resolved', c.raised_date""", (status, status))
    return render_template("complaints.html", rows=rows, status=status,
                           students=run("SELECT student_id,name FROM Student ORDER BY name"),
                           cats=run("SELECT * FROM Complaint_Category"),
                           staff=run("SELECT * FROM Staff ORDER BY name"))


@app.post("/complaints/<int:cid>/update")
def update_complaint(cid):
    attempt("UPDATE Complaint SET status=%s, staff_id=NULLIF(%s,'') WHERE complaint_id=%s",
            (request.form["status"], request.form.get("staff_id", ""), cid), "Complaint updated")
    return redirect(request.referrer or url_for("complaints"))


@app.post("/complaints/escalate")
def escalate():
    conn = mysql.connector.connect(**DB)
    try:
        cur = conn.cursor()
        n = cur.callproc("escalate_overdue_complaints", [3, 0])[1]
        conn.commit()
        flash(f"{n} overdue complaint(s) raised to High priority" if n else "Nothing to escalate: no complaint older than 3 days is below High", "ok")
    except mysql.connector.Error as e:
        flash(e.msg, "error")
    finally:
        conn.close()
    return redirect(url_for("complaints"))


@app.route("/rooms")
def rooms():
    occ = run("SELECT * FROM v_room_occupancy ORDER BY hostel, room_no")
    unhoused = run("""SELECT s.student_id, s.name FROM Student s
                      LEFT JOIN Allocation a ON a.student_id=s.student_id AND a.end_date IS NULL
                      WHERE a.allocation_id IS NULL""")
    current = run("""SELECT a.allocation_id, s.name, s.usn, h.name AS hostel, r.room_no, a.start_date
                     FROM Allocation a JOIN Student s ON s.student_id=a.student_id
                     JOIN Room r ON r.room_id=a.room_id JOIN Hostel h ON h.hostel_id=r.hostel_id
                     WHERE a.end_date IS NULL ORDER BY h.name, r.room_no""")
    return render_template("rooms.html", occ=occ, unhoused=unhoused, current=current)


@app.post("/rooms/allocate")
def allocate():
    attempt("INSERT INTO Allocation (student_id,room_id,start_date) VALUES (%s,%s,CURDATE())",
            (request.form["student_id"], request.form["room_id"]), "Room allocated")
    return redirect(url_for("rooms"))


@app.post("/rooms/vacate/<int:aid>")
def vacate(aid):
    attempt("UPDATE Allocation SET end_date=DATE_ADD(CURDATE(), INTERVAL 1 DAY) WHERE allocation_id=%s", (aid,),
            "Room vacated")
    return redirect(url_for("rooms"))


@app.route("/fees", methods=["GET", "POST"])
def fees():
    if request.method == "POST":
        f = request.form
        attempt("INSERT INTO Fee_Payment (student_id,fee_type,amount,due_date) VALUES (%s,%s,%s,%s)",
                (f["student_id"], f["fee_type"], f["amount"], f["due_date"]), "Fee added")
        return redirect(url_for("fees"))
    only = request.args.get("view", "")
    rows = run("""SELECT f.*, s.name, s.usn, GREATEST(DATEDIFF(CURDATE(), f.due_date),0) AS days_late
                  FROM Fee_Payment f JOIN Student s ON s.student_id=f.student_id
                  WHERE (%s='' OR f.status=%s) ORDER BY f.status DESC, f.due_date""", (only, only))
    return render_template("fees.html", rows=rows, only=only,
                           students=run("SELECT student_id,name FROM Student ORDER BY name"))


@app.post("/fees/<int:pid>/pay")
def pay(pid):
    attempt("UPDATE Fee_Payment SET status='Paid' WHERE payment_id=%s", (pid,), "Payment recorded")
    return redirect(url_for("fees"))


@app.route("/mess", methods=["GET", "POST"])
def mess():
    if request.method == "POST":
        f = request.form
        attempt("INSERT INTO Mess_Subscription (student_id,plan_id,month,year) VALUES (%s,%s,%s,%s)",
                (f["student_id"], f["plan_id"], f["month"], f["year"]), "Subscribed")
        return redirect(url_for("mess"))
    subs = run("""SELECT ms.*, s.name, mp.plan_name, mp.monthly_charge FROM Mess_Subscription ms
                  JOIN Student s USING (student_id) JOIN Mess_Plan mp USING (plan_id)
                  ORDER BY ms.year DESC, ms.month DESC, s.name""")
    summary = run("""SELECT mp.plan_name, COUNT(*) AS students, SUM(mp.monthly_charge) AS revenue
                     FROM Mess_Subscription ms JOIN Mess_Plan mp USING (plan_id)
                     WHERE ms.month=MONTH(CURDATE()) AND ms.year=YEAR(CURDATE()) GROUP BY mp.plan_name""")
    return render_template("mess.html", subs=subs, summary=summary,
                           students=run("SELECT student_id,name FROM Student ORDER BY name"),
                           plans=run("SELECT * FROM Mess_Plan"))


@app.route("/reports")
def reports():
    r = {
        "resolution": run("""SELECT cc.name AS category, COUNT(*) AS resolved,
                             ROUND(AVG(DATEDIFF(c.resolved_date,c.raised_date)),1) AS avg_days
                             FROM Complaint c JOIN Complaint_Category cc USING (category_id)
                             WHERE c.status='Resolved' GROUP BY cc.name ORDER BY avg_days DESC"""),
        "fees": run("""SELECT fee_type, SUM(CASE WHEN status='Paid' THEN amount ELSE 0 END) AS collected,
                       SUM(CASE WHEN status='Pending' THEN amount ELSE 0 END) AS pending
                       FROM Fee_Payment GROUP BY fee_type"""),
        "occupancy": run("""SELECT hostel, SUM(capacity) AS beds, SUM(occupied) AS occupied, SUM(free_beds) AS free
                            FROM v_room_occupancy GROUP BY hostel"""),
        "frequent": run("""SELECT s.name, COUNT(*) AS complaints FROM Complaint c JOIN Student s USING (student_id)
                           GROUP BY s.student_id, s.name
                           HAVING COUNT(*) > (SELECT AVG(n) FROM (SELECT COUNT(*) AS n FROM Complaint GROUP BY student_id) t)"""),
        "no_complaints": run("SELECT name FROM Student WHERE student_id NOT IN (SELECT student_id FROM Complaint)"),
    }
    return render_template("reports.html", r=r)


@app.errorhandler(mysql.connector.Error)
def db_down(e):
    return render_template("error.html", msg=e.msg), 500


if __name__ == "__main__":
    app.run(debug=True)
