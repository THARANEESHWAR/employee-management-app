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

  // ── AFTER READ EMPLOYEE ──────────────────
  srv.after('READ', 'Employees', (data) => {
    const list = Array.isArray(data) ? data : [data];
    list.forEach(emp => {
      // Salary Grade
      if (emp.Salary) {
        if      (emp.Salary >= 90000) emp.SalaryGrade = '⭐ Grade A';
        else if (emp.Salary >= 70000) emp.SalaryGrade = '🔵 Grade B';
        else if (emp.Salary >= 50000) emp.SalaryGrade = '🟢 Grade C';
        else                          emp.SalaryGrade = '🟡 Grade D';
      }

      // Experience in years
      if (emp.JoiningDate) {
        const years = Math.floor(
          (new Date() - new Date(emp.JoiningDate)) / (365.25 * 24 * 60 * 60 * 1000)
        );
        emp.Experience = `${years} year(s)`;
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

  // ── ACTION: APPROVE LEAVE ────────────────
  srv.on('approveLeave', async (req) => {
    const { leaveId, remarks } = req.data;

    const leave = await SELECT.one
      .from('com.employee.app.LeaveRequest')
      .where({ ID: leaveId });

    if (!leave) {
      return req.error(404, 'Leave request not found');
    }
    if (leave.Status !== 'Pending') {
      return req.error(400, `Leave is already ${leave.Status}`);
    }

    // Update leave status
    await UPDATE('com.employee.app.LeaveRequest')
      .set({
        Status      : 'Approved',
        ApprovedBy  : req.user?.id || 'Manager',
        ApprovedDate: new Date().toISOString().split('T')[0],
        Remarks     : remarks || 'Approved'
      })
      .where({ ID: leaveId });

    // Deduct leave balance
    await UPDATE('com.employee.app.Employee')
      .set({ LeaveBalance: { '-=': leave.NoOfDays } })
      .where({ EmpId: leave.EmpId });

    return `✅ Leave approved for ${leave.EmpId}. ${leave.NoOfDays} days deducted.`;
  });

  // ── ACTION: REJECT LEAVE ─────────────────
  srv.on('rejectLeave', async (req) => {
    const { leaveId, remarks } = req.data;

    const leave = await SELECT.one
      .from('com.employee.app.LeaveRequest')
      .where({ ID: leaveId });

    if (!leave) return req.error(404, 'Leave request not found');
    if (leave.Status !== 'Pending') {
      return req.error(400, `Leave is already ${leave.Status}`);
    }

    await UPDATE('com.employee.app.LeaveRequest')
      .set({
        Status  : 'Rejected',
        Remarks : remarks || 'Rejected by Manager'
      })
      .where({ ID: leaveId });

    return `❌ Leave rejected for ${leave.EmpId}`;
  });

  // ── ACTION: PROCESS PAYROLL ──────────────
  srv.on('processPayroll', async (req) => {
    const { empId, payMonth } = req.data;

    const emp = await SELECT.one
      .from('com.employee.app.Employee')
      .where({ EmpId: empId });

    if (!emp) return req.error(404, `Employee ${empId} not found`);

    const basic      = emp.Salary;
    const hra        = Math.round(basic * 0.20);
    const allowances = Math.round(basic * 0.10);
    const deductions = Math.round(basic * 0.02);
    const tax        = Math.round(basic * 0.10);
    const netSalary  = basic + hra + allowances - deductions - tax;

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

    return `✅ Payroll processed for ${empId}. Net Salary: ₹${netSalary}`;
  });

  // ── ACTION: MARK ATTENDANCE ──────────────
  srv.on('markAttendance', async (req) => {
    const { empId, status } = req.data;

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

    return `✅ Attendance marked for ${empId} on ${today}`;
  });

  // ── BEFORE DELETE EMPLOYEE ───────────────
  srv.before('DELETE', 'Employees', async (req) => {
    const id  = req.params[0].ID;
    const emp = await SELECT.one
      .from('com.employee.app.Employee')
      .where({ ID: id });

    if (!emp) return req.error(404, 'Employee not found');

    // Soft delete — set inactive instead
    await UPDATE('com.employee.app.Employee')
      .set({ Status: 'Resigned', IsActive: false })
      .where({ ID: id });

    req.error(400,
      `Employee ${emp.EmpId} marked as Resigned instead of deleted (Soft Delete)`
    );
  });

};