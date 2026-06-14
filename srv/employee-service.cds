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
        virtual null         as SalaryGrade         : String,
        virtual null         as Experience           : String,
        virtual null         as IsEditable           : Boolean,
        virtual null         as IsAdmin              : Boolean,
        virtual null         as StatusCriticality    : Integer,
        virtual null         as Currency             : String(3)
    }

    @restrict: [
        { grant: 'READ',  to: 'authenticated-user' },
        { grant: 'WRITE', to: 'HRAdmin' }
    ]
    entity Departments    as projection on db.Department;

    @restrict: [
        { grant: '*', to: ['HRAdmin', 'Manager'] }
    ]
    entity SalaryHistories as projection on db.SalaryHistory {
        *,
        virtual null as Currency : String(3)
    }

    @odata.draft.enabled: true
    entity LeaveRequests as projection on db.LeaveRequest {
        *,
        virtual null as StatusCriticality : Integer
    }
    actions {
        @(requires: ['Manager', 'HRAdmin'])
        action approve(remarks : String) returns String;

        @(requires: ['Manager', 'HRAdmin'])
        action rejectLeave(remarks : String) returns String;

        @Common.IsActionCritical: true
        action cancel() returns String;
    };

    entity Attendances as projection on db.Attendance {
        *,
        virtual null as StatusCriticality : Integer
    }

    @restrict: [
        { grant: '*', to: ['HRAdmin', 'Manager'] }
    ]
    entity Payrolls as projection on db.Payroll {
        *,
        virtual null as PayCriticality : Integer,
        virtual null as Currency       : String(3)
    }

    // Custom Actions
    @requires: ['HRAdmin']
    action processPayroll(empId : String, payMonth : String) returns String;

    // Unbound versions (kept for API compatibility)
    action markAttendance(empId : String, status : String) returns String;
    action checkOut(empId : String) returns String;

    // Bound versions on Employees — empId auto-known from context
    extend entity Employees with actions {
        action markAttendanceBound(status : String) returns String;
        action checkOutBound()                      returns String;
    }
}
