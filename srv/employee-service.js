module.exports = (srv) => {

  // AUTO GENERATE EmpId 
  async function generateEmpId() {
    try {
      const employees = await SELECT
        .from('com.employee.app.Employee')
        .columns('EmpId')
        .orderBy('EmpId desc');

      if (!employees || employees.length === 0) return 'E001';
      const withId  = employees.filter(e => e.EmpId);
      if (withId.length === 0) return 'E001';

      const lastId  = withId[0].EmpId;
      const num     = parseInt(lastId.replace(/[^0-9]/g, ''));
      const nextNum = isNaN(num) ? 1 : num + 1;
      return 'E' + String(nextNum).padStart(3, '0');
    } catch (err) {
      return 'E001';
    }
  }

  // WHEN DRAFT IS CREATED 
  srv.before('NEW', 'Employees', async (req) => {
    req.data.EmpId        = await generateEmpId();
    req.data.IsActive     = true;
    req.data.Status       = 'Active';
    req.data.LeaveBalance = 20;
    req.data.FullName     = '';
});

  // BEFORE CREATE EMPLOYEE 
  srv.before('CREATE', 'Employees', async (req) => {
    const emp = req.data;

    if (!emp.EmpId) req.data.EmpId = await generateEmpId();

    // Set FullName
    if (emp.FirstName && emp.LastName) {
      req.data.FullName = `${emp.FirstName} ${emp.LastName}`;
    }

    // Name validations
    if (!emp.FirstName || emp.FirstName.trim() === '') {
      return req.error(400, 'First name cannot be empty');
    }
    if (!emp.LastName || emp.LastName.trim() === '') {
      return req.error(400, 'Last name cannot be empty');
    }

    // Department validation
    if (!emp.DeptId) {
      return req.error(400, 'Please select a Department');
    }
    const dept = await SELECT.one
      .from('com.employee.app.Department')
      .where({ DeptId: emp.DeptId });
    if (!dept) {
      return req.error(400, 'Invalid Department selected');
    }

    // Salary validation
    if (!emp.Salary || emp.Salary <= 0) {
      return req.error(400, 'Salary must be greater than zero');
    }
    if (emp.Salary > 9999999) {
      return req.error(400, 'Salary cannot exceed 9,999,999');
    }

    // Email validation
    if (!emp.Email || emp.Email.trim() === '') {
      return req.error(400, 'Email cannot be empty');
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emp.Email)) {
      return req.error(400, 'Enter valid email like name@company.com');
    }

    // Duplicate email
    const dupEmail = await SELECT.one
      .from('com.employee.app.Employee')
      .where({ Email: emp.Email });
    if (dupEmail) {
      return req.error(400, `Email ${emp.Email} already registered`);
    }

    // Joining date
    if (emp.JoiningDate) {
      const today = new Date().toISOString().split('T')[0];
      if (emp.JoiningDate > today) {
        return req.error(400, 'Joining date cannot be future date');
      }
    }

    // Phone validation
    if (emp.Phone && !/^[0-9]{10}$/.test(emp.Phone)) {
      return req.error(400, 'Phone must be 10 digits');
    }
  });

  // ── BEFORE UPDATE EMPLOYEE ───────────────
  srv.before('UPDATE', 'Employees', async (req) => {
    const emp = req.data;

    // Update FullName
    if (emp.FirstName || emp.LastName) {
      const id = req.params[0]?.ID;
      const current = id ? await SELECT.one
        .from('com.employee.app.Employee')
        .where({ ID: id }) : null;

      const first = emp.FirstName || (current?.FirstName || '');
      const last  = emp.LastName  || (current?.LastName  || '');
      req.data.FullName = `${first} ${last}`.trim();
    }

    if (emp.Salary !== undefined && emp.Salary !== null) {
      if (emp.Salary <= 0) {
        return req.error(400, 'Salary must be greater than zero');
      }

      // Save Salary History
      const id = req.params[0]?.ID;
      if (id) {
        const current = await SELECT.one
          .from('com.employee.app.Employee')
          .where({ ID: id });

        if (current && current.Salary !== emp.Salary) {
          await INSERT.into('com.employee.app.SalaryHistory').entries({
            ID            : require('crypto').randomUUID(),
            EmpId         : current.EmpId,
            PreviousSalary: current.Salary,
            NewSalary     : emp.Salary,
            EffectiveDate : new Date().toISOString().split('T')[0],
            Reason        : 'Manual Update',
            ChangedBy     : req.user?.id || 'System'
          });
        }
      }
    }

    if (emp.Email !== undefined) {
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emp.Email)) {
        return req.error(400, 'Enter valid email');
      }
    }

    if (emp.Phone && !/^[0-9]{10}$/.test(emp.Phone)) {
      return req.error(400, 'Phone must be 10 digits');
    }
  });

  // ── BEFORE READ EMPLOYEE ─────────────────
  // Virtual fields need Salary/JoiningDate to be computed,
  // but the UI does not always $select them — add them to the query
  srv.before('READ', 'Employees', (req) => {
    const cols = req.query.SELECT?.columns;
    if (!cols) return;
    const has = (name) =>
      cols.some(c => c === '*' || (c.ref && c.ref[c.ref.length - 1] === name));
    if (!has('SalaryGrade') && !has('Experience')) return;
    for (const dep of ['Salary', 'JoiningDate']) {
      if (!has(dep)) cols.push({ ref: [dep] });
    }
  });

  // ── AFTER READ EMPLOYEE ──────────────────
  srv.after('READ', 'Employees', (data) => {
    const list = Array.isArray(data) ? data : [data];
    list.forEach(emp => {
      if (!emp) return;

      // Salary Grade
      if (emp.Salary) {
        if      (emp.Salary >= 90000) emp.SalaryGrade = 'Grade A';
        else if (emp.Salary >= 70000) emp.SalaryGrade = 'Grade B';
        else if (emp.Salary >= 50000) emp.SalaryGrade = 'Grade C';
        else                          emp.SalaryGrade = 'Grade D';
      } else {
        emp.SalaryGrade = null;
      }

      // Experience in years
      if (emp.JoiningDate) {
        const years = Math.floor(
          (new Date() - new Date(emp.JoiningDate)) / (365.25 * 24 * 60 * 60 * 1000)
        );
        emp.Experience = `${years} year(s)`;
      } else {
        emp.Experience = null;
      }
    });
  });

  // ── BEFORE CREATE LEAVE REQUEST ──────────
  srv.before('CREATE', 'LeaveRequests', async (req) => {
    const leave = req.data;

    if (!leave.EmpId) {
      return req.error(400, 'Employee ID is required');
    }
    if (!leave.FromDate || !leave.ToDate) {
      return req.error(400, 'From Date and To Date are required');
    }
    if (leave.FromDate > leave.ToDate) {
      return req.error(400, 'From Date cannot be after To Date');
    }
    if (!leave.Reason || leave.Reason.trim() === '') {
      return req.error(400, 'Reason is required');
    }

    // Calculate number of days
    const from = new Date(leave.FromDate);
    const to   = new Date(leave.ToDate);
    const days = Math.floor((to - from) / (1000 * 60 * 60 * 24)) + 1;
    req.data.NoOfDays = days;
    req.data.Status   = 'Pending';

    // Check leave balance
    const emp = await SELECT.one
      .from('com.employee.app.Employee')
      .where({ EmpId: leave.EmpId });

    if (emp && emp.LeaveBalance < days) {
      return req.error(400,
        `Insufficient leave balance. Available: ${emp.LeaveBalance} days, Requested: ${days} days`
      );
    }
  });

  // ── BOUND ACTION: APPROVE LEAVE ──────────
  srv.on('approve', 'LeaveRequests', async (req) => {
    const { remarks } = req.data;
    const leaveId = req.params[req.params.length - 1]?.ID;

    const leave = await SELECT.one
      .from('com.employee.app.LeaveRequest')
      .where({ ID: leaveId });

    if (!leave) {
      return req.error(404, 'Leave request not found');
    }
    if (leave.Status !== 'Pending') {
      return req.error(400, `Leave is already ${leave.Status}`);
    }

    // Guard: never let the balance go negative
    const emp = await SELECT.one
      .from('com.employee.app.Employee')
      .where({ EmpId: leave.EmpId });
    if (emp && emp.LeaveBalance < leave.NoOfDays) {
      return req.error(400,
        `Cannot approve: ${leave.EmpId} has only ${emp.LeaveBalance} day(s) left, ` +
        `but this request needs ${leave.NoOfDays} day(s)`
      );
    }

    // Update leave status — ApprovedBy is the real logged-in user
    await UPDATE('com.employee.app.LeaveRequest')
      .set({
        Status      : 'Approved',
        ApprovedBy  : req.user.id,
        ApprovedDate: new Date().toISOString().split('T')[0],
        Remarks     : remarks || 'Approved'
      })
      .where({ ID: leaveId });

    // Deduct leave balance
    await UPDATE('com.employee.app.Employee')
      .set({ LeaveBalance: { '-=': leave.NoOfDays } })
      .where({ EmpId: leave.EmpId });

    return `Leave approved for ${leave.EmpId}. ${leave.NoOfDays} day(s) deducted.`;
  });

  // ── BOUND ACTION: REJECT LEAVE ───────────
  srv.on('reject', 'LeaveRequests', async (req) => {
    const { remarks } = req.data;
    const leaveId = req.params[req.params.length - 1]?.ID;

    const leave = await SELECT.one
      .from('com.employee.app.LeaveRequest')
      .where({ ID: leaveId });

    if (!leave) return req.error(404, 'Leave request not found');
    if (leave.Status !== 'Pending') {
      return req.error(400, `Leave is already ${leave.Status}`);
    }

    await UPDATE('com.employee.app.LeaveRequest')
      .set({
        Status      : 'Rejected',
        ApprovedBy  : req.user.id,
        ApprovedDate: new Date().toISOString().split('T')[0],
        Remarks     : remarks || 'Rejected'
      })
      .where({ ID: leaveId });

    return `Leave rejected for ${leave.EmpId}`;
  });

  // ── BOUND ACTION: CANCEL LEAVE ───────────
  srv.on('cancel', 'LeaveRequests', async (req) => {
    const leaveId = req.params[req.params.length - 1]?.ID;

    const leave = await SELECT.one
      .from('com.employee.app.LeaveRequest')
      .where({ ID: leaveId });

    if (!leave) return req.error(404, 'Leave request not found');
    if (leave.Status !== 'Pending') {
      return req.error(400, `Only Pending requests can be cancelled (current: ${leave.Status})`);
    }

    await UPDATE('com.employee.app.LeaveRequest')
      .set({ Status: 'Cancelled', Remarks: 'Cancelled by ' + req.user.id })
      .where({ ID: leaveId });

    return `Leave request cancelled for ${leave.EmpId}`;
  });

  // ── ACTION: PROCESS PAYROLL ──────────────
  srv.on('processPayroll', async (req) => {
    const { empId, payMonth } = req.data;

    if (!payMonth || !/^\d{4}-(0[1-9]|1[0-2])$/.test(payMonth)) {
      return req.error(400, 'Pay month must be in YYYY-MM format, e.g. 2026-06');
    }

    const emp = await SELECT.one
      .from('com.employee.app.Employee')
      .where({ EmpId: empId });

    if (!emp) return req.error(404, `Employee ${empId} not found`);

    // Salary is the gross — split into components, then deduct.
    // Net is always less than gross.
    const gross      = emp.Salary;
    const basic      = Math.round(gross * 0.50);
    const hra        = Math.round(gross * 0.20);
    const allowances = gross - basic - hra;          // remaining 30%
    const tax        = Math.round(gross * 0.10);
    const deductions = Math.round(gross * 0.02);     // PF etc.
    const netSalary  = gross - tax - deductions;

    // Check if payroll already processed
    const existing = await SELECT.one
      .from('com.employee.app.Payroll')
      .where({ EmpId: empId, PayMonth: payMonth });

    if (existing) {
      return req.error(400, `Payroll already processed for ${empId} in ${payMonth}`);
    }

    await INSERT.into('com.employee.app.Payroll').entries({
      ID          : require('crypto').randomUUID(),
      EmpId       : empId,
      PayMonth    : payMonth,
      BasicSalary : basic,
      HRA         : hra,
      Allowances  : allowances,
      Deductions  : deductions,
      Tax         : tax,
      NetSalary   : netSalary,
      PaymentDate : new Date().toISOString().split('T')[0],
      PayStatus   : 'Paid'
    });

    return `Payroll processed for ${empId}. Net Salary: ${netSalary} INR`;
  });

  // ── ACTION: MARK ATTENDANCE ──────────────
  srv.on('markAttendance', async (req) => {
    const { empId, status } = req.data;

    const validStatuses = ['Present', 'Absent', 'Half Day', 'On Leave', 'Holiday'];
    if (status && !validStatuses.includes(status)) {
      return req.error(400, `Invalid status. Allowed: ${validStatuses.join(', ')}`);
    }

    const today = new Date().toISOString().split('T')[0];

    const existing = await SELECT.one
      .from('com.employee.app.Attendance')
      .where({ EmpId: empId, AttDate: today });

    if (existing) {
      return req.error(400, `Attendance already marked for ${empId} today`);
    }

    const checkIn = new Date().toTimeString().split(' ')[0].slice(0, 5);

    await INSERT.into('com.employee.app.Attendance').entries({
      ID       : require('crypto').randomUUID(),
      EmpId    : empId,
      AttDate  : today,
      AttStatus: status || 'Present',
      CheckIn  : checkIn,
      CheckOut : '',
      WorkingHours: 0
    });

    return `Attendance marked for ${empId} on ${today}`;
  });

  // ── ACTION: CHECK OUT ───────────────────
  srv.on('checkOut', async (req) => {
    const { empId } = req.data;
    const today = new Date().toISOString().split('T')[0];

    const record = await SELECT.one
      .from('com.employee.app.Attendance')
      .where({ EmpId: empId, AttDate: today });

    if (!record) {
      return req.error(400, `No attendance record found for ${empId} today. Please mark attendance first.`);
    }
    if (record.CheckOut) {
      return req.error(400, `${empId} has already checked out today at ${record.CheckOut}`);
    }

    const checkOut = new Date().toTimeString().split(' ')[0].slice(0, 5);

    // Calculate working hours from CheckIn to CheckOut
    const [inH, inM]   = record.CheckIn.split(':').map(Number);
    const [outH, outM] = checkOut.split(':').map(Number);
    const workingHours = parseFloat(((outH * 60 + outM - (inH * 60 + inM)) / 60).toFixed(2));

    await UPDATE('com.employee.app.Attendance')
      .set({ CheckOut: checkOut, WorkingHours: workingHours > 0 ? workingHours : 0 })
      .where({ EmpId: empId, AttDate: today });

    return `Check-out recorded for ${empId} at ${checkOut}. Working hours: ${workingHours}h`;
  });

  // ── ON DELETE EMPLOYEE (SOFT DELETE) ─────
  // Intercepts the delete entirely: marks the employee as Resigned
  // and returns success, so the UI shows a normal confirmation
  // instead of an error.
  srv.on('DELETE', 'Employees', async (req) => {
    const id  = req.params[req.params.length - 1]?.ID || req.data.ID;
    const emp = await SELECT.one
      .from('com.employee.app.Employee')
      .where({ ID: id });

    if (!emp) return req.error(404, 'Employee not found');

    await UPDATE('com.employee.app.Employee')
      .set({ Status: 'Resigned', IsActive: false })
      .where({ ID: id });

    req.notify(`Employee ${emp.EmpId} marked as Resigned (records are kept for history)`);
  });

};