using EmployeeService as service from '../../srv/employee-service';

// ══════════════════════════════════════════════════════════════════
// EMPLOYEES — FIELD-LEVEL ANNOTATIONS
// ══════════════════════════════════════════════════════════════════
annotate service.Employees with {

    // Read-only identity fields
    EmpId          @( title: 'Employee ID',    Common.FieldControl: #ReadOnly );
    FullName       @( title: 'Full Name',      Common.FieldControl: #ReadOnly );
    DepartmentName @( title: 'Department',     Common.FieldControl: #ReadOnly );
    Location       @( title: 'Location',       Common.FieldControl: #ReadOnly );
    SalaryGrade    @( title: 'Salary Grade',   Common.FieldControl: #ReadOnly );
    Experience     @( title: 'Experience',     Common.FieldControl: #ReadOnly );

    // Hidden technical/virtual fields
    IsEditable         @UI.Hidden;
    IsAdmin            @UI.Hidden;
    Username           @UI.Hidden;
    StatusCriticality  @UI.Hidden;
    Currency           @( UI.Hidden, Semantics.currencyCode: true );

    // Currency-annotated monetary fields
    Salary @(
        title                        : 'Salary (INR)',
        Semantics.amount.currencyCode: 'Currency'
    );

    // Input placeholders
    FirstName   @( title: 'First Name',   UI.Placeholder: 'e.g. Arjun'           );
    LastName    @( title: 'Last Name',    UI.Placeholder: 'e.g. Sharma'           );
    Email       @( title: 'Email',        UI.Placeholder: 'name@company.com'      );
    Phone       @( title: 'Phone',        UI.Placeholder: '10-digit mobile number');
    Designation @( title: 'Designation',  UI.Placeholder: 'e.g. Software Engineer');

    // Department value help
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
                    { $Type: 'Common.ValueListParameterOut',         LocalDataProperty: DeptId,   ValueListProperty: 'DeptId'   },
                    { $Type: 'Common.ValueListParameterDisplayOnly',                               ValueListProperty: 'DeptName' }
                ]
            }
        }
    );

    // Other field titles
    Gender       @title: 'Gender';
    DateOfBirth  @title: 'Date of Birth';
    JoiningDate  @title: 'Joining Date';
    LeaveBalance @title: 'Leave Balance';
    Status       @title: 'Status';
    IsActive     @title: 'Active';
}

// ══════════════════════════════════════════════════════════════════
// EMPLOYEES — AGGREGATION SUPPORT (for charts)
// ══════════════════════════════════════════════════════════════════
annotate service.Employees with @(
    Aggregation.ApplySupported: {
        Transformations       : ['aggregate', 'groupby', 'filter'],
        GroupableProperties   : [Status, DepartmentName, SalaryGrade, Gender, DeptId],
        AggregatableProperties: [
            { Property: Salary      },
            { Property: LeaveBalance }
        ]
    }
);

// ══════════════════════════════════════════════════════════════════
// EMPLOYEES — LIST REPORT + OBJECT PAGE
// ══════════════════════════════════════════════════════════════════
annotate service.Employees with @(

    // Default sort by Employee ID ascending
    Presentation.SortOrder: [
        { $Type: 'Common.SortOrderType', Property: EmpId, Descending: false }
    ],

    // ── Analytics: Chart definition ──────────────────────────────
    UI.Chart #ByStatus: {
        $Type              : 'UI.ChartDefinitionType',
        Title              : 'Employees by Status',
        ChartType          : #Donut,
        Dimensions         : [Status],
        DimensionAttributes: [{ $Type: 'UI.ChartDimensionAttributeType', Dimension: Status,         Role: #Category }],
        Measures           : [Salary],
        MeasureAttributes  : [{ $Type: 'UI.ChartMeasureAttributeType',   Measure:   Salary,         Role: #Axis1    }]
    },

    UI.Chart #ByDepartment: {
        $Type              : 'UI.ChartDefinitionType',
        Title              : 'Salary by Department',
        ChartType          : #Bar,
        Dimensions         : [DepartmentName],
        DimensionAttributes: [{ $Type: 'UI.ChartDimensionAttributeType', Dimension: DepartmentName, Role: #Category }],
        Measures           : [Salary],
        MeasureAttributes  : [{ $Type: 'UI.ChartMeasureAttributeType',   Measure:   Salary,         Role: #Axis1    }]
    },

    UI.Chart #BySalaryGrade: {
        $Type              : 'UI.ChartDefinitionType',
        Title              : 'Employees by Salary Grade',
        ChartType          : #Bar,
        Dimensions         : [SalaryGrade],
        DimensionAttributes: [{ $Type: 'UI.ChartDimensionAttributeType', Dimension: SalaryGrade,    Role: #Category }],
        Measures           : [Salary],
        MeasureAttributes  : [{ $Type: 'UI.ChartMeasureAttributeType',   Measure:   Salary,         Role: #Axis1    }]
    },

    // ── Analytics: Default chart used in List Report ─────────────
    UI.Chart: {
        $Type              : 'UI.ChartDefinitionType',
        Title              : 'Employees by Status',
        ChartType          : #Donut,
        Dimensions         : [Status],
        DimensionAttributes: [{ $Type: 'UI.ChartDimensionAttributeType', Dimension: Status, Role: #Category }],
        Measures           : [Salary],
        MeasureAttributes  : [{ $Type: 'UI.ChartMeasureAttributeType',   Measure:   Salary, Role: #Axis1    }]
    },

    // ── Analytics: PresentationVariant — chart + table combined ──
    UI.PresentationVariant: {
        $Type         : 'UI.PresentationVariantType',
        Text          : 'Default',
        SortOrder     : [{ $Type: 'Common.SortOrderType', Property: EmpId, Descending: false }],
        Visualizations: ['@UI.Chart', '@UI.LineItem']
    },

    // Object Page header
    UI.HeaderInfo: {
        TypeName      : 'Employee',
        TypeNamePlural: 'Employees',
        Title         : { $Type: 'UI.DataField', Value: FullName    },
        Description   : { $Type: 'UI.DataField', Value: Designation }
    },

    // KPI DataPoints shown in header strip
    UI.DataPoint #Status: {
        Value      : Status,
        Title      : 'Status',
        Criticality: StatusCriticality
    },
    UI.DataPoint #Salary: {
        Value: Salary,
        Title: 'Salary'
    },
    UI.DataPoint #LeaveBalance: {
        Value: LeaveBalance,
        Title: 'Leave Balance'
    },
    UI.DataPoint #SalaryGrade: {
        Value: SalaryGrade,
        Title: 'Salary Grade'
    },
    UI.DataPoint #Experience: {
        Value: Experience,
        Title: 'Experience'
    },

    // Header facets — KPI strip above the form
    UI.HeaderFacets: [
        { $Type: 'UI.ReferenceFacet', ID: 'StatusKPI',       Target: '@UI.DataPoint#Status'       },
        { $Type: 'UI.ReferenceFacet', ID: 'SalaryKPI',       Target: '@UI.DataPoint#Salary'       },
        { $Type: 'UI.ReferenceFacet', ID: 'LeaveKPI',        Target: '@UI.DataPoint#LeaveBalance' },
        { $Type: 'UI.ReferenceFacet', ID: 'GradeKPI',        Target: '@UI.DataPoint#SalaryGrade'  },
        { $Type: 'UI.ReferenceFacet', ID: 'ExperienceKPI',   Target: '@UI.DataPoint#Experience'   }
    ],

    // List Report columns
    UI.LineItem: [
        { $Type: 'UI.DataField', Value: EmpId,          Label: 'Emp ID',      ![@UI.Importance]: #High   },
        { $Type: 'UI.DataField', Value: FullName,       Label: 'Full Name',   ![@UI.Importance]: #High   },
        { $Type: 'UI.DataField', Value: Designation,    Label: 'Designation', ![@UI.Importance]: #High   },
        { $Type: 'UI.DataField', Value: DepartmentName, Label: 'Department',  ![@UI.Importance]: #High   },
        { $Type: 'UI.DataField', Value: SalaryGrade,    Label: 'Grade',       ![@UI.Importance]: #Medium },
        { $Type: 'UI.DataField', Value: Experience,     Label: 'Experience',  ![@UI.Importance]: #Medium },
        {
            $Type      : 'UI.DataField',
            Value      : Status,
            Label      : 'Status',
            Criticality: StatusCriticality,
            ![@UI.Importance]: #High
        },
        { $Type: 'UI.DataField', Value: LeaveBalance,   Label: 'Leave Bal.',  ![@UI.Importance]: #Medium }
    ],

    // Filter bar
    UI.SelectionFields: [ EmpId, FullName, DeptId, Status, IsActive ],

    // Object Page — General Information
    UI.FieldGroup #GeneralInformation: {
        $Type: 'UI.FieldGroupType',
        Label: 'General Information',
        Data : [
            { $Type: 'UI.DataField', Value: EmpId,       Label: 'Employee ID'   },
            { $Type: 'UI.DataField', Value: FirstName,   Label: 'First Name'    },
            { $Type: 'UI.DataField', Value: LastName,    Label: 'Last Name'     },
            { $Type: 'UI.DataField', Value: FullName,    Label: 'Full Name'     },
            { $Type: 'UI.DataField', Value: Gender,      Label: 'Gender'        },
            { $Type: 'UI.DataField', Value: DateOfBirth, Label: 'Date of Birth' },
            { $Type: 'UI.DataField', Value: Phone,       Label: 'Phone'         },
            { $Type: 'UI.DataField', Value: Email,       Label: 'Email'         },
            { $Type: 'UI.DataField', Value: Designation, Label: 'Designation'   },
            { $Type: 'UI.DataField', Value: DeptId,      Label: 'Department'    },
            { $Type: 'UI.DataField', Value: Location,    Label: 'Location'      }
        ]
    },

    // Object Page — Salary & Employment
    UI.FieldGroup #SalaryDetails: {
        $Type: 'UI.FieldGroupType',
        Label: 'Salary & Employment',
        Data : [
            { $Type: 'UI.DataField', Value: Salary,       Label: 'Salary'        },
            { $Type: 'UI.DataField', Value: JoiningDate,  Label: 'Joining Date'  },
            {
                $Type      : 'UI.DataField',
                Value      : Status,
                Label      : 'Status',
                Criticality: StatusCriticality
            },
            { $Type: 'UI.DataField', Value: IsActive,     Label: 'Active'        },
            { $Type: 'UI.DataField', Value: LeaveBalance, Label: 'Leave Balance' },
            { $Type: 'UI.DataField', Value: SalaryGrade,  Label: 'Salary Grade'  },
            { $Type: 'UI.DataField', Value: Experience,   Label: 'Experience'    }
        ]
    },

    // Object Page facets
    UI.Facets: [
        { $Type: 'UI.ReferenceFacet', ID: 'GeneralInfo',      Label: 'General Information',  Target: '@UI.FieldGroup#GeneralInformation' },
        { $Type: 'UI.ReferenceFacet', ID: 'SalaryInfo',       Label: 'Salary & Employment',  Target: '@UI.FieldGroup#SalaryDetails'      },
        { $Type: 'UI.ReferenceFacet', ID: 'SalaryHistory',    Label: 'Salary History',        Target: 'SalaryHistories/@UI.LineItem'      },
        { $Type: 'UI.ReferenceFacet', ID: 'LeaveHistory',     Label: 'Leave Requests',        Target: 'LeaveRequests/@UI.LineItem'        },
        { $Type: 'UI.ReferenceFacet', ID: 'AttendanceHistory',Label: 'Attendance',            Target: 'Attendances/@UI.LineItem'          },
        { $Type: 'UI.ReferenceFacet', ID: 'PayrollHistory',   Label: 'Payroll',               Target: 'Payrolls/@UI.LineItem'             }
    ],

    Capabilities.InsertRestrictions: { Insertable: true },
    Capabilities.UpdateRestrictions: { Updatable : true },
    Capabilities.DeleteRestrictions: { Deletable : true },

    UI.CreateHidden: false,
    UI.UpdateHidden: { $edmJson: { $Not: { $Path: 'IsEditable' } } },
    UI.DeleteHidden: { $edmJson: { $Not: { $Path: 'IsEditable' } } }
);

// ══════════════════════════════════════════════════════════════════
// DEPARTMENTS
// ══════════════════════════════════════════════════════════════════
annotate service.Departments with {
    DeptId   @title: 'Department ID';
    DeptName @title: 'Department Name';
    Location @title: 'Location';
}

// ══════════════════════════════════════════════════════════════════
// SALARY HISTORIES
// ══════════════════════════════════════════════════════════════════
annotate service.SalaryHistories with {
    Currency       @( UI.Hidden, Semantics.currencyCode: true );
    PreviousSalary @( title: 'Previous Salary', Semantics.amount.currencyCode: 'Currency' );
    NewSalary      @( title: 'New Salary',      Semantics.amount.currencyCode: 'Currency' );
    EffectiveDate  @title: 'Effective Date';
    Reason         @title: 'Reason';
    ChangedBy      @title: 'Changed By';
}

annotate service.SalaryHistories with @(
    UI.LineItem: [
        { $Type: 'UI.DataField', Value: EffectiveDate,  Label: 'Effective Date'  },
        { $Type: 'UI.DataField', Value: PreviousSalary, Label: 'Previous Salary' },
        { $Type: 'UI.DataField', Value: NewSalary,      Label: 'New Salary'      },
        { $Type: 'UI.DataField', Value: Reason,         Label: 'Reason'          },
        { $Type: 'UI.DataField', Value: ChangedBy,      Label: 'Changed By'      }
    ]
);

// ══════════════════════════════════════════════════════════════════
// LEAVE REQUESTS
// ══════════════════════════════════════════════════════════════════
annotate service.LeaveRequests with {
    StatusCriticality @UI.Hidden;
    EmpId     @title: 'Employee ID';
    LeaveType @title: 'Leave Type';
    FromDate  @title: 'From Date';
    ToDate    @title: 'To Date';
    NoOfDays  @title: 'Days';
    Status    @title: 'Status';
    ApprovedBy @title: 'Approved By';
    Reason    @( title: 'Reason', UI.Placeholder: 'Reason for leave...' );
}

annotate service.LeaveRequests with actions {
    approve @(
        Core.OperationAvailable: { $edmJson: { $Eq: [ { $Path: 'in/Status' }, 'Pending' ] } }
    );
    rejectLeave @(
        Core.OperationAvailable: { $edmJson: { $Eq: [ { $Path: 'in/Status' }, 'Pending' ] } }
    );
    cancel @(
        Core.OperationAvailable: { $edmJson: { $Eq: [ { $Path: 'in/Status' }, 'Pending' ] } }
    );
};

annotate service.LeaveRequests with @(
    UI.LineItem: [
        { $Type: 'UI.DataField', Value: LeaveType,  Label: 'Leave Type', ![@UI.Importance]: #High   },
        { $Type: 'UI.DataField', Value: FromDate,   Label: 'From',       ![@UI.Importance]: #High   },
        { $Type: 'UI.DataField', Value: ToDate,     Label: 'To',         ![@UI.Importance]: #High   },
        { $Type: 'UI.DataField', Value: NoOfDays,   Label: 'Days',       ![@UI.Importance]: #Medium },
        {
            $Type      : 'UI.DataField',
            Value      : Status,
            Label      : 'Status',
            Criticality: StatusCriticality,
            ![@UI.Importance]: #High
        },
        { $Type: 'UI.DataField', Value: ApprovedBy, Label: 'Approved By', ![@UI.Importance]: #Medium },
        { $Type: 'UI.DataField', Value: Reason,     Label: 'Reason',      ![@UI.Importance]: #Low   },
        { $Type: 'UI.DataFieldForAction', Label: 'Approve', Action: 'EmployeeService.approve'     },
        { $Type: 'UI.DataFieldForAction', Label: 'Reject',  Action: 'EmployeeService.rejectLeave' },
        { $Type: 'UI.DataFieldForAction', Label: 'Cancel',  Action: 'EmployeeService.cancel'      }
    ]
);

// ══════════════════════════════════════════════════════════════════
// ATTENDANCES
// ══════════════════════════════════════════════════════════════════
annotate service.Attendances with {
    StatusCriticality @UI.Hidden;
    AttDate      @title: 'Date';
    AttStatus    @title: 'Status';
    CheckIn      @title: 'Check In';
    CheckOut     @title: 'Check Out';
    WorkingHours @title: 'Working Hours';
}

annotate service.Attendances with @(
    UI.LineItem: [
        { $Type: 'UI.DataField', Value: AttDate,      Label: 'Date',          ![@UI.Importance]: #High   },
        {
            $Type      : 'UI.DataField',
            Value      : AttStatus,
            Label      : 'Status',
            Criticality: StatusCriticality,
            ![@UI.Importance]: #High
        },
        { $Type: 'UI.DataField', Value: CheckIn,      Label: 'Check In',      ![@UI.Importance]: #High   },
        { $Type: 'UI.DataField', Value: CheckOut,     Label: 'Check Out',     ![@UI.Importance]: #High   },
        { $Type: 'UI.DataField', Value: WorkingHours, Label: 'Working Hours', ![@UI.Importance]: #Medium },
        { $Type: 'UI.DataFieldForAction', Label: 'Mark Attendance', Action: 'EmployeeService.Employees/EmployeeService.markAttendanceBound' },
        { $Type: 'UI.DataFieldForAction', Label: 'Check Out',       Action: 'EmployeeService.Employees/EmployeeService.checkOutBound'       }
    ]
);

// ══════════════════════════════════════════════════════════════════
// PAYROLLS
// ══════════════════════════════════════════════════════════════════
annotate service.Payrolls with {
    Currency       @( UI.Hidden, Semantics.currencyCode: true );
    PayCriticality @UI.Hidden;
    BasicSalary @( title: 'Basic Salary', Semantics.amount.currencyCode: 'Currency' );
    HRA         @( title: 'HRA',          Semantics.amount.currencyCode: 'Currency' );
    Allowances  @( title: 'Allowances',   Semantics.amount.currencyCode: 'Currency' );
    Deductions  @( title: 'Deductions',   Semantics.amount.currencyCode: 'Currency' );
    Tax         @( title: 'Tax',          Semantics.amount.currencyCode: 'Currency' );
    NetSalary   @( title: 'Net Salary',   Semantics.amount.currencyCode: 'Currency' );
    PayMonth    @title: 'Pay Month';
    PayStatus   @title: 'Pay Status';
    PaymentDate @title: 'Payment Date';
}

annotate service.Payrolls with @(
    UI.LineItem: [
        { $Type: 'UI.DataField', Value: PayMonth,    Label: 'Pay Month',    ![@UI.Importance]: #High   },
        { $Type: 'UI.DataField', Value: BasicSalary, Label: 'Basic Salary', ![@UI.Importance]: #High   },
        { $Type: 'UI.DataField', Value: HRA,         Label: 'HRA',          ![@UI.Importance]: #Medium },
        { $Type: 'UI.DataField', Value: Allowances,  Label: 'Allowances',   ![@UI.Importance]: #Medium },
        { $Type: 'UI.DataField', Value: Deductions,  Label: 'Deductions',   ![@UI.Importance]: #Medium },
        { $Type: 'UI.DataField', Value: Tax,         Label: 'Tax',          ![@UI.Importance]: #Medium },
        { $Type: 'UI.DataField', Value: NetSalary,   Label: 'Net Salary',   ![@UI.Importance]: #High   },
        {
            $Type      : 'UI.DataField',
            Value      : PayStatus,
            Label      : 'Pay Status',
            Criticality: PayCriticality,
            ![@UI.Importance]: #High
        },
        { $Type: 'UI.DataField', Value: PaymentDate, Label: 'Payment Date', ![@UI.Importance]: #Medium },
        { $Type: 'UI.DataFieldForAction', Label: 'Process Payroll', Action: 'EmployeeService.processPayroll' }
    ]
);
