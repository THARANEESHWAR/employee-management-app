using EmployeeService as service from '../../srv/employee-service';

// ── DEPARTMENT DROPDOWN ─────────────────────────
annotate service.Employees with {
    DeptId @(
        title: 'Department',
        Common: {
            Text            : DepartmentName,
            TextArrangement : #TextOnly,
            ValueListWithFixedValues: true,
            ValueList: {
                $Type          : 'Common.ValueListType',
                CollectionPath : 'Departments',
                Parameters     : [
                    {
                        $Type             : 'Common.ValueListParameterOut',
                        LocalDataProperty : DeptId,
                        ValueListProperty : 'DeptId'
                    },
                    {
                        $Type             : 'Common.ValueListParameterDisplayOnly',
                        ValueListProperty : 'DeptName'
                    }
                ]
            }
        }
    );
}

annotate service.Departments with {
    DeptId   @( title: 'Department ID'   );
    DeptName @( title: 'Department Name' );
    Location @( title: 'Location'        );
}

// ── SALARY HISTORY LINE ITEM ────────────────────
annotate service.SalaryHistories with @(
    UI.LineItem: [
        { $Type: 'UI.DataField', Value: EffectiveDate,  Label: 'Effective Date'  },
        { $Type: 'UI.DataField', Value: PreviousSalary, Label: 'Previous Salary' },
        { $Type: 'UI.DataField', Value: NewSalary,      Label: 'New Salary'      },
        { $Type: 'UI.DataField', Value: Reason,         Label: 'Reason'          },
        { $Type: 'UI.DataField', Value: ChangedBy,      Label: 'Changed By'      }
    ]
);

// ── LEAVE REQUESTS: actions only available while Pending ──
annotate service.LeaveRequests with actions {
    approve @(
        Core.OperationAvailable: {
            $edmJson: { $Eq: [ { $Path: 'in/Status' }, 'Pending' ] }
        }
    );
    reject @(
        Core.OperationAvailable: {
            $edmJson: { $Eq: [ { $Path: 'in/Status' }, 'Pending' ] }
        }
    );
    cancel @(
        Core.OperationAvailable: {
            $edmJson: { $Eq: [ { $Path: 'in/Status' }, 'Pending' ] }
        }
    );
};

annotate service.LeaveRequests with @(
    UI.LineItem: [
        { $Type: 'UI.DataField', Value: LeaveType, Label: 'Leave Type' },
        { $Type: 'UI.DataField', Value: FromDate,  Label: 'From Date'  },
        { $Type: 'UI.DataField', Value: ToDate,    Label: 'To Date'    },
        { $Type: 'UI.DataField', Value: NoOfDays,  Label: 'Days'       },
        { $Type: 'UI.DataField', Value: Status,    Label: 'Status'     },
        { $Type: 'UI.DataField', Value: ApprovedBy, Label: 'Approved By' },
        { $Type: 'UI.DataField', Value: Reason,    Label: 'Reason'     },
        {
            $Type  : 'UI.DataFieldForAction',
            Label  : 'Approve',
            Action : 'EmployeeService.approve'
        },
        {
            $Type  : 'UI.DataFieldForAction',
            Label  : 'Reject',
            Action : 'EmployeeService.reject'
        },
        {
            $Type  : 'UI.DataFieldForAction',
            Label  : 'Cancel',
            Action : 'EmployeeService.cancel'
        }
    ]
);

annotate service.Attendances with @(
    UI.LineItem: [
        { $Type: 'UI.DataField', Value: AttDate,      Label: 'Date'          },
        { $Type: 'UI.DataField', Value: AttStatus,    Label: 'Status'        },
        { $Type: 'UI.DataField', Value: CheckIn,      Label: 'Check In'      },
        { $Type: 'UI.DataField', Value: CheckOut,     Label: 'Check Out'     },
        { $Type: 'UI.DataField', Value: WorkingHours, Label: 'Working Hours' },
        {
            $Type  : 'UI.DataFieldForAction',
            Label  : 'Mark Attendance',
            Action : 'EmployeeService.markAttendance'
        },
        {
            $Type  : 'UI.DataFieldForAction',
            Label  : 'Check Out',
            Action : 'EmployeeService.checkOut'
        }
    ]
);

// ── PAYROLL LINE ITEM ───────────────────────────
annotate service.Payrolls with @(
    UI.LineItem: [
        { $Type: 'UI.DataField', Value: PayMonth,    Label: 'Pay Month'      },
        { $Type: 'UI.DataField', Value: BasicSalary, Label: 'Basic Salary'   },
        { $Type: 'UI.DataField', Value: HRA,         Label: 'HRA'            },
        { $Type: 'UI.DataField', Value: Allowances,  Label: 'Allowances'     },
        { $Type: 'UI.DataField', Value: Deductions,  Label: 'Deductions'     },
        { $Type: 'UI.DataField', Value: Tax,         Label: 'Tax'            },
        { $Type: 'UI.DataField', Value: NetSalary,   Label: 'Net Salary'     },
        { $Type: 'UI.DataField', Value: PayStatus,   Label: 'Pay Status'     },
        { $Type: 'UI.DataField', Value: PaymentDate, Label: 'Payment Date'   },
        {
            $Type  : 'UI.DataFieldForAction',
            Label  : 'Process Payroll',
            Action : 'EmployeeService.processPayroll'
        }
    ]
);

// ── EMPLOYEE MAIN ANNOTATIONS ───────────────────
annotate service.Employees with @(

    UI.HeaderInfo: {
        TypeName      : 'Employee',
        TypeNamePlural: 'Employees',
        Title         : { $Type: 'UI.DataField', Value: FullName },
        Description   : { $Type: 'UI.DataField', Value: EmpId   }
    },

    UI.LineItem: [
        { $Type: 'UI.DataField', Value: EmpId,          Label: 'Employee ID'   },
        { $Type: 'UI.DataField', Value: FullName,       Label: 'Full Name'     },
        { $Type: 'UI.DataField', Value: Designation,    Label: 'Designation'   },
        { $Type: 'UI.DataField', Value: DepartmentName, Label: 'Department'    },
        { $Type: 'UI.DataField', Value: Salary,         Label: 'Salary (INR)'  },
        { $Type: 'UI.DataField', Value: SalaryGrade,    Label: 'Salary Grade'  },
        { $Type: 'UI.DataField', Value: Experience,     Label: 'Experience'    },
        { $Type: 'UI.DataField', Value: Status,         Label: 'Status'        },
        { $Type: 'UI.DataField', Value: LeaveBalance,   Label: 'Leave Balance' }
    ],

    UI.SelectionFields: [
        EmpId,
        FullName,
        DeptId,
        Status,
        IsActive
    ],

    UI.FieldGroup #GeneralInformation: {
        $Type: 'UI.FieldGroupType',
        Label: 'General Information',
        Data : [
            { $Type: 'UI.DataField', Value: EmpId,          Label: 'Employee ID'   },
            { $Type: 'UI.DataField', Value: FirstName,      Label: 'First Name'    },
            { $Type: 'UI.DataField', Value: LastName,       Label: 'Last Name'     },
            { $Type: 'UI.DataField', Value: Gender,         Label: 'Gender'        },
            { $Type: 'UI.DataField', Value: DateOfBirth,    Label: 'Date of Birth' },
            { $Type: 'UI.DataField', Value: Phone,          Label: 'Phone'         },
            { $Type: 'UI.DataField', Value: Email,          Label: 'Email'         },
            { $Type: 'UI.DataField', Value: Designation,    Label: 'Designation'   },
            { $Type: 'UI.DataField', Value: DeptId,         Label: 'Department'    },
            { $Type: 'UI.DataField', Value: DepartmentName, Label: 'Dept Name'     },
            { $Type: 'UI.DataField', Value: Location,       Label: 'Location'      },
            { $Type: 'UI.DataField', Value: Status,         Label: 'Status'        },
            { $Type: 'UI.DataField', Value: IsActive,       Label: 'Active'        }
        ]
    },

    UI.FieldGroup #SalaryDetails: {
        $Type: 'UI.FieldGroupType',
        Label: 'Salary & Employment Details',
        Data : [
            { $Type: 'UI.DataField', Value: Salary,       Label: 'Salary (INR)'  },
            { $Type: 'UI.DataField', Value: JoiningDate,  Label: 'Joining Date'  },
            { $Type: 'UI.DataField', Value: LeaveBalance, Label: 'Leave Balance' },
            { $Type: 'UI.DataField', Value: SalaryGrade,  Label: 'Salary Grade'  },
            { $Type: 'UI.DataField', Value: Experience,   Label: 'Experience'    }
        ]
    },

    UI.Facets: [
        {
            $Type : 'UI.ReferenceFacet',
            ID    : 'GeneralInfo',
            Label : 'General Information',
            Target: '@UI.FieldGroup#GeneralInformation'
        },
        {
            $Type : 'UI.ReferenceFacet',
            ID    : 'SalaryInfo',
            Label : 'Salary Details',
            Target: '@UI.FieldGroup#SalaryDetails'
        },
        {
            $Type : 'UI.ReferenceFacet',
            ID    : 'SalaryHistory',
            Label : 'Salary History',
            Target: 'SalaryHistories/@UI.LineItem'
        },
        {
            $Type : 'UI.ReferenceFacet',
            ID    : 'LeaveHistory',
            Label : 'Leave Requests',
            Target: 'LeaveRequests/@UI.LineItem'
        },
        {
            $Type : 'UI.ReferenceFacet',
            ID    : 'AttendanceHistory',
            Label : 'Attendance',
            Target: 'Attendances/@UI.LineItem'
        },
        {
            $Type : 'UI.ReferenceFacet',
            ID    : 'PayrollHistory',
            Label : 'Payroll',
            Target: 'Payrolls/@UI.LineItem'
        }
    ],

    Capabilities.InsertRestrictions: { Insertable: true },
    Capabilities.UpdateRestrictions: { Updatable : true },
    Capabilities.DeleteRestrictions: { Deletable : true },

    UI.CreateHidden: false,
    UI.UpdateHidden: false,
    UI.DeleteHidden: false
);
