namespace com.employee.app;
using { cuid, managed } from '@sap/cds/common';

// ══════════════════════════════════════════
// ENUMS / TYPES
// ══════════════════════════════════════════
type StatusType : String(20) enum {
    Active   = 'Active';
    Inactive = 'Inactive';
    OnLeave  = 'On Leave';
    Resigned = 'Resigned';
}

type GenderType : String(10) enum {
    Male   = 'Male';
    Female = 'Female';
    Other  = 'Other';
}

type LeaveStatusType : String(20) enum {
    Pending   = 'Pending';
    Approved  = 'Approved';
    Rejected  = 'Rejected';
    Cancelled = 'Cancelled';
}

type LeaveType : String(20) enum {
    Casual    = 'Casual';
    Sick      = 'Sick';
    Earned    = 'Earned';
    Emergency = 'Emergency';
}

type AttendanceType : String(20) enum {
    Present = 'Present';
    Absent  = 'Absent';
    HalfDay = 'Half Day';
    OnLeave = 'On Leave';
    Holiday = 'Holiday';
}

// ══════════════════════════════════════════
// DEPARTMENT (defined first — no dependencies)
// ══════════════════════════════════════════
entity Department {
    key DeptId      : String(10);
        DeptName    : String(50);
        Location    : String(50);
        Manager     : String(50);
        Description : String(200);
}

// ══════════════════════════════════════════
// EMPLOYEE MASTER
// ══════════════════════════════════════════
entity Employee : cuid, managed {

    @readonly
    @title: 'Employee ID'
    EmpId           : String(10);

    @title: 'First Name'
    FirstName       : String(50);

    @title: 'Last Name'
    LastName        : String(50);

    @title: 'Full Name'
    FullName        : String(100);

    @title: 'Gender'
    Gender          : GenderType;

    @title: 'Date of Birth'
    DateOfBirth     : Date;

    @title: 'Email Address'
    Email           : String(100);

    @title: 'Phone Number'
    Phone           : String(15);

    @title: 'Designation'
    Designation     : String(100);

    @title: 'Department'
    DeptId          : String(10);

    @title: 'Joining Date'
    JoiningDate     : Date;

    @title: 'Salary'
    Salary          : Decimal(13,2);

    @title: 'Status'
    Status          : StatusType default 'Active';

    @title: 'Leave Balance'
    LeaveBalance    : Integer default 20;

    @title: 'Active'
    IsActive        : Boolean default true;

    // Associations
    Department      : Association to Department
                        on Department.DeptId = DeptId;

    // Back associations
    to_SalaryHistory : Association to many SalaryHistory
                        on to_SalaryHistory.EmpId = EmpId;

    to_LeaveRequests : Association to many LeaveRequest
                        on to_LeaveRequests.EmpId = EmpId;

    to_Attendance    : Association to many Attendance
                        on to_Attendance.EmpId = EmpId;

    to_Payroll       : Association to many Payroll
                        on to_Payroll.EmpId = EmpId;
}

// ══════════════════════════════════════════
// LEAVE REQUEST (defined after Employee)
// ══════════════════════════════════════════
entity LeaveRequest : cuid, managed {

    @title: 'Employee ID'
    EmpId           : String(10);

    @title: 'Leave Type'
    LeaveType       : LeaveType;

    @title: 'From Date'
    FromDate        : Date;

    @title: 'To Date'
    ToDate          : Date;

    @title: 'Number of Days'
    NoOfDays        : Integer;

    @title: 'Reason'
    Reason          : String(200);

    @title: 'Status'
    Status          : LeaveStatusType default 'Pending';

    @title: 'Approved By'
    ApprovedBy      : String(50);

    @title: 'Approved Date'
    ApprovedDate    : Date;

    @title: 'Remarks'
    Remarks         : String(200);

    Employee        : Association to Employee
                        on Employee.EmpId = EmpId;
}

// ══════════════════════════════════════════
// SALARY HISTORY
// ══════════════════════════════════════════
entity SalaryHistory : cuid {

    @title: 'Employee ID'
    EmpId           : String(10);

    @title: 'Previous Salary'
    PreviousSalary  : Decimal(13,2);

    @title: 'New Salary'
    NewSalary       : Decimal(13,2);

    @title: 'Effective Date'
    EffectiveDate   : Date;

    @title: 'Reason'
    Reason          : String(100);

    @title: 'Changed By'
    ChangedBy       : String(50);

    Employee        : Association to Employee
                        on Employee.EmpId = EmpId;
}

// ══════════════════════════════════════════
// ATTENDANCE
// ══════════════════════════════════════════
entity Attendance : cuid {

    @title: 'Employee ID'
    EmpId           : String(10);

    @title: 'Date'
    AttDate         : Date;

    @title: 'Status'
    AttStatus       : AttendanceType default 'Present';

    @title: 'Check In'
    CheckIn         : String(10);

    @title: 'Check Out'
    CheckOut        : String(10);

    @title: 'Working Hours'
    WorkingHours    : Decimal(4,2);

    @title: 'Remarks'
    Remarks         : String(100);

    Employee        : Association to Employee
                        on Employee.EmpId = EmpId;
}

// ══════════════════════════════════════════
// PAYROLL
// ══════════════════════════════════════════
entity Payroll : cuid {

    @title: 'Employee ID'
    EmpId           : String(10);

    @title: 'Pay Month'
    PayMonth        : String(7);

    @title: 'Basic Salary'
    BasicSalary     : Decimal(13,2);

    @title: 'HRA'
    HRA             : Decimal(13,2);

    @title: 'Allowances'
    Allowances      : Decimal(13,2);

    @title: 'Deductions'
    Deductions      : Decimal(13,2);

    @title: 'Tax'
    Tax             : Decimal(13,2);

    @title: 'Net Salary'
    NetSalary       : Decimal(13,2);

    @title: 'Payment Date'
    PaymentDate     : Date;

    @title: 'Pay Status'
    PayStatus       : String(20) default 'Pending';

    Employee        : Association to Employee
                        on Employee.EmpId = EmpId;
}