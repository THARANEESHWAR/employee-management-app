using com.employee.app as db from '../db/schema';

@path: 'employee'
service EmployeeService {

    @odata.draft.enabled: true
    entity Employees as projection on db.Employee {
        *,
        Department.DeptName  as DepartmentName,
        Department.Location  as Location,
        to_SalaryHistory     as SalaryHistories,
        to_LeaveRequests     as LeaveRequests,
        to_Attendance        as Attendances,
        to_Payroll           as Payrolls,
        virtual null         as SalaryGrade : String,
        virtual null         as Experience  : String
    }

    @readonly
    entity Departments    as projection on db.Department;

    entity SalaryHistories as projection on db.SalaryHistory;

    @odata.draft.enabled: true
    entity LeaveRequests   as projection on db.LeaveRequest;

    entity Attendances     as projection on db.Attendance;

    entity Payrolls        as projection on db.Payroll;

    // Custom Actions
    action approveLeave(leaveId : String, remarks : String)
           returns String;

    action rejectLeave(leaveId : String, remarks : String)
           returns String;

    action processPayroll(empId : String, payMonth : String)
           returns String;

    action markAttendance(empId : String, status : String)
           returns String;

    action checkOut(empId : String)
           returns String;
}