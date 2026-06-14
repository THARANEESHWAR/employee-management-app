using com.employee.app as db from '../db/schema';

@path: 'employee'
@requires: 'authenticated-user'
service EmployeeService {

    @odata.draft.enabled: true
    @restrict: [
        { grant: 'READ',                         to: 'authenticated-user' },
        { grant: ['CREATE', 'UPDATE', 'DELETE'], to: 'HRAdmin' }
    ]
    entity Employees as projection on db.Employee {
        *,
        Department.DeptName  as DepartmentName,
        Department.Location  as Location,
        to_SalaryHistory     as SalaryHistories,
        to_LeaveRequests     as LeaveRequests,
        to_Attendance        as Attendances,
        to_Payroll           as Payrolls,
        virtual null         as SalaryGrade : String,
        virtual null         as Experience  : String,
        virtual null         as IsEditable  : Boolean
    }

    @restrict: [
        { grant: 'READ',  to: 'authenticated-user' },
        { grant: 'WRITE', to: 'HRAdmin' }
    ]
    entity Departments    as projection on db.Department;

    @restrict: [
        { grant: '*', to: ['HRAdmin', 'Manager'] }
    ]
    entity SalaryHistories as projection on db.SalaryHistory;

    @odata.draft.enabled: true
    entity LeaveRequests   as projection on db.LeaveRequest
        actions {
            @(requires: ['Manager', 'HRAdmin'])
            action approve(remarks : String) returns String;

            @(requires: ['Manager', 'HRAdmin'])
            action reject(remarks : String)  returns String;

            @Common.IsActionCritical: true
            action cancel()                  returns String;
        };

    entity Attendances     as projection on db.Attendance;

    @restrict: [
        { grant: '*', to: ['HRAdmin', 'Manager'] }
    ]
    entity Payrolls        as projection on db.Payroll;

    // Custom Actions
    @requires: ['HRAdmin']
    action processPayroll(empId : String, payMonth : String)
           returns String;

    action markAttendance(empId : String, status : String)
           returns String;

    action checkOut(empId : String)
           returns String;
}
