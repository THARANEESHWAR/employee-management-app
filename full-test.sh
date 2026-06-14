#!/bin/bash
B="http://localhost:4004/odata/v4/employee"
UI="http://localhost:4004"
ANON=""
EMP="-u employee:employee@123"
MGR="-u manager:manager@123"
ADM="-u admin:admin@123"
PASS=0; FAIL=0; FAILED_TESTS=""

chk() { # chk <num> <desc> <expected> <actual>
  if [ "$3" = "$4" ]; then PASS=$((PASS+1)); echo "PASS  $1. $2"
  else FAIL=$((FAIL+1)); FAILED_TESTS="$FAILED_TESTS\n$1. $2 (expected $3, got $4)"; echo "FAIL  $1. $2 (expected $3, got $4)"; fi
}
code() { curl -s -o /dev/null -w "%{http_code}" "$@"; }

echo "════════ SECTION 1: AUTHENTICATION ════════"
chk 1  "Anonymous blocked from Employees"        401 $(code "$B/Employees")
chk 2  "Anonymous blocked from metadata"          401 $(code "$B/\$metadata")
chk 3  "Wrong password rejected"                  401 $(code -u employee:wrongpass "$B/Employees")
chk 4  "employee login works"                     200 $(code $EMP "$B/Employees?\$top=1")
chk 5  "manager login works"                      200 $(code $MGR "$B/Employees?\$top=1")
chk 6  "admin login works"                        200 $(code $ADM "$B/Employees?\$top=1")

echo "════════ SECTION 2: ROLE ACCESS MATRIX ════════"
# Employees entity
chk 7  "employee READ Employees"                  200 $(code $EMP "$B/Employees?\$top=1")
chk 8  "employee CREATE Employee blocked"         403 $(code $EMP -X POST -H "Content-Type: application/json" -d '{}' "$B/Employees")
chk 9  "manager CREATE Employee blocked"          403 $(code $MGR -X POST -H "Content-Type: application/json" -d '{}' "$B/Employees")
chk 10 "admin CREATE Employee draft allowed"      201 $(code $ADM -X POST -H "Content-Type: application/json" -d '{}' "$B/Employees")
# Departments
chk 11 "employee READ Departments"                200 $(code $EMP "$B/Departments")
chk 12 "employee WRITE Department blocked"        403 $(code $EMP -X POST -H "Content-Type: application/json" -d '{"DeptId":"D99","DeptName":"X"}' "$B/Departments")
chk 13 "admin WRITE Department allowed"           201 $(code $ADM -X POST -H "Content-Type: application/json" -d '{"DeptId":"D99","DeptName":"Test Dept","Location":"Chennai"}' "$B/Departments")
# SalaryHistories
chk 14 "employee READ SalaryHistories blocked"    403 $(code $EMP "$B/SalaryHistories")
chk 15 "manager READ SalaryHistories allowed"     200 $(code $MGR "$B/SalaryHistories")
chk 16 "admin READ SalaryHistories allowed"       200 $(code $ADM "$B/SalaryHistories")
# Payrolls
chk 17 "employee READ Payrolls blocked"           403 $(code $EMP "$B/Payrolls")
chk 18 "manager READ Payrolls allowed"            200 $(code $MGR "$B/Payrolls")
chk 19 "admin READ Payrolls allowed"              200 $(code $ADM "$B/Payrolls")
# LeaveRequests + Attendances readable by all
chk 20 "employee READ LeaveRequests"              200 $(code $EMP "$B/LeaveRequests?\$top=1")
chk 21 "employee READ Attendances"                200 $(code $EMP "$B/Attendances?\$top=1")

echo "════════ SECTION 3: EMPLOYEE CRUD + VALIDATIONS (draft flow) ════════"
# Happy path: create draft, patch fields, activate
DRAFT=$(curl -s $ADM -X POST -H "Content-Type: application/json" -d '{}' "$B/Employees" | python3 -c "import sys,json; print(json.load(sys.stdin)['ID'])")
chk 22 "Draft created with auto EmpId" 200 $(code $ADM "$B/Employees(ID=$DRAFT,IsActiveEntity=false)")
PATCH=$(code $ADM -X PATCH -H "Content-Type: application/json" -d '{"FirstName":"Test","LastName":"User","Email":"test.user@company.com","Phone":"9876543210","DeptId":"D001","Salary":85000,"JoiningDate":"2024-01-15","Designation":"Tester","Gender":"Male"}' "$B/Employees(ID=$DRAFT,IsActiveEntity=false)")
chk 23 "Draft fields patched"                     200 $PATCH
ACT=$(curl -s $ADM -X POST -H "Content-Type: application/json" -d '{}' "$B/Employees(ID=$DRAFT,IsActiveEntity=false)/EmployeeService.draftActivate")
NEWEMP=$(echo "$ACT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('EmpId','FAIL'))" 2>/dev/null)
FULLN=$(echo "$ACT"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('FullName','FAIL'))" 2>/dev/null)
chk 24 "Draft activated -> new employee created"  "E" "${NEWEMP:0:1}"
chk 25 "FullName auto-computed"                   "Test User" "$FULLN"

# Validation failures via draft activate
mkdraft() { # mkdraft <json-fields> -> activation HTTP code
  local D=$(curl -s $ADM -X POST -H "Content-Type: application/json" -d '{}' "$B/Employees" | python3 -c "import sys,json; print(json.load(sys.stdin)['ID'])")
  curl -s -o /dev/null $ADM -X PATCH -H "Content-Type: application/json" -d "$1" "$B/Employees(ID=$D,IsActiveEntity=false)"
  code $ADM -X POST -H "Content-Type: application/json" -d '{}' "$B/Employees(ID=$D,IsActiveEntity=false)/EmployeeService.draftActivate"
}
chk 26 "Reject: empty first name"        400 $(mkdraft '{"FirstName":"","LastName":"X","Email":"a@b.co","DeptId":"D001","Salary":50000}')
chk 27 "Reject: missing department"      400 $(mkdraft '{"FirstName":"A","LastName":"B","Email":"a2@b.co","DeptId":null,"Salary":50000}')
chk 28 "Reject: invalid department"      400 $(mkdraft '{"FirstName":"A","LastName":"B","Email":"a3@b.co","DeptId":"NOPE","Salary":50000}')
chk 29 "Reject: zero salary"             400 $(mkdraft '{"FirstName":"A","LastName":"B","Email":"a4@b.co","DeptId":"D001","Salary":0}')
chk 30 "Reject: salary over cap"         400 $(mkdraft '{"FirstName":"A","LastName":"B","Email":"a5@b.co","DeptId":"D001","Salary":99999999}')
chk 31 "Reject: bad email format"        400 $(mkdraft '{"FirstName":"A","LastName":"B","Email":"not-an-email","DeptId":"D001","Salary":50000}')
chk 32 "Reject: duplicate email"         400 $(mkdraft '{"FirstName":"A","LastName":"B","Email":"test.user@company.com","DeptId":"D001","Salary":50000}')
chk 33 "Reject: future joining date"     400 $(mkdraft '{"FirstName":"A","LastName":"B","Email":"a6@b.co","DeptId":"D001","Salary":50000,"JoiningDate":"2030-01-01"}')
chk 34 "Reject: bad phone"               400 $(mkdraft '{"FirstName":"A","LastName":"B","Email":"a7@b.co","DeptId":"D001","Salary":50000,"Phone":"12345"}')

# UPDATE + salary history
EID=$(curl -s $ADM "$B/Employees?\$filter=EmpId%20eq%20'E001'&\$select=ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['value'][0]['ID'])")
HIST_BEFORE=$(curl -s $ADM "$B/SalaryHistories?\$filter=EmpId%20eq%20'E001'&\$count=true&\$top=0" | python3 -c "import sys,json; print(json.load(sys.stdin)['@odata.count'])")
# FE edit flow: draftEdit -> patch -> activate
curl -s -o /dev/null $ADM -X POST -H "Content-Type: application/json" -d '{"PreserveChanges":true}' "$B/Employees(ID=$EID,IsActiveEntity=true)/EmployeeService.draftEdit"
curl -s -o /dev/null $ADM -X PATCH -H "Content-Type: application/json" -d '{"Salary":91000}' "$B/Employees(ID=$EID,IsActiveEntity=false)"
chk 35 "Edit+activate employee (salary change)" 200 $(code $ADM -X POST -H "Content-Type: application/json" -d '{}' "$B/Employees(ID=$EID,IsActiveEntity=false)/EmployeeService.draftActivate")
HIST_AFTER=$(curl -s $ADM "$B/SalaryHistories?\$filter=EmpId%20eq%20'E001'&\$count=true&\$top=0" | python3 -c "import sys,json; print(json.load(sys.stdin)['@odata.count'])")
chk 36 "Salary history auto-recorded"             "$((HIST_BEFORE+1))" "$HIST_AFTER"
GRADE=$(curl -s $ADM "$B/Employees(ID=$EID,IsActiveEntity=true)?\$select=SalaryGrade" | python3 -c "import sys,json; print(json.load(sys.stdin)['SalaryGrade'])")
chk 37 "SalaryGrade recomputed (91000 -> Grade A)" "Grade A" "$GRADE"

echo "════════ SECTION 4: SOFT DELETE ════════"
E4=$(curl -s $ADM "$B/Employees?\$filter=EmpId%20eq%20'E004'&\$select=ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['value'][0]['ID'])")
chk 38 "employee DELETE blocked"                  403 $(code $EMP -X DELETE "$B/Employees(ID=$E4,IsActiveEntity=true)")
chk 39 "admin DELETE returns success"             204 $(code $ADM -X DELETE "$B/Employees(ID=$E4,IsActiveEntity=true)")
SOFT=$(curl -s $ADM "$B/Employees(ID=$E4,IsActiveEntity=true)?\$select=Status,IsActive" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['Status'], d['IsActive'])")
chk 40 "Record kept as Resigned + inactive"       "Resigned False" "$SOFT"

echo "════════ SECTION 5: LEAVE WORKFLOW ════════"
# Create a leave request via draft flow (employee can do this)
LD=$(curl -s $EMP -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests" | python3 -c "import sys,json; print(json.load(sys.stdin)['ID'])")
curl -s -o /dev/null $EMP -X PATCH -H "Content-Type: application/json" -d '{"EmpId":"E002","LeaveType":"Casual","FromDate":"2026-07-01","ToDate":"2026-07-03","Reason":"Family function"}' "$B/LeaveRequests(ID=$LD,IsActiveEntity=false)"
LACT=$(curl -s $EMP -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests(ID=$LD,IsActiveEntity=false)/EmployeeService.draftActivate")
LDAYS=$(echo "$LACT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('NoOfDays'))" 2>/dev/null)
LSTAT=$(echo "$LACT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Status'))" 2>/dev/null)
chk 41 "Employee creates leave request"           "3" "$LDAYS"
chk 42 "New request starts as Pending"            "Pending" "$LSTAT"
# Validation: From > To
LD2=$(curl -s $EMP -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests" | python3 -c "import sys,json; print(json.load(sys.stdin)['ID'])")
curl -s -o /dev/null $EMP -X PATCH -H "Content-Type: application/json" -d '{"EmpId":"E002","FromDate":"2026-07-10","ToDate":"2026-07-01","Reason":"x"}' "$B/LeaveRequests(ID=$LD2,IsActiveEntity=false)"
chk 43 "Reject: FromDate after ToDate"            400 $(code $EMP -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests(ID=$LD2,IsActiveEntity=false)/EmployeeService.draftActivate")
# Insufficient balance
LD3=$(curl -s $EMP -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests" | python3 -c "import sys,json; print(json.load(sys.stdin)['ID'])")
curl -s -o /dev/null $EMP -X PATCH -H "Content-Type: application/json" -d '{"EmpId":"E002","FromDate":"2026-07-01","ToDate":"2026-12-31","Reason":"long"}' "$B/LeaveRequests(ID=$LD3,IsActiveEntity=false)"
chk 44 "Reject: insufficient leave balance"       400 $(code $EMP -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests(ID=$LD3,IsActiveEntity=false)/EmployeeService.draftActivate")
# Approve / reject / cancel permissions and transitions
chk 45 "employee cannot approve"                  403 $(code $EMP -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests(ID=$LD,IsActiveEntity=true)/EmployeeService.approve")
chk 46 "employee cannot reject"                   403 $(code $EMP -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests(ID=$LD,IsActiveEntity=true)/EmployeeService.reject")
chk 47 "employee CAN cancel own pending request"  200 $(code $EMP -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests(ID=$LD,IsActiveEntity=true)/EmployeeService.cancel")
chk 48 "cancel again fails (not Pending)"         400 $(code $EMP -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests(ID=$LD,IsActiveEntity=true)/EmployeeService.cancel")
# Approve flow with balance deduction
PEND=$(curl -s $MGR "$B/LeaveRequests?\$filter=Status%20eq%20'Pending'&\$select=ID,EmpId,NoOfDays&\$top=1" | python3 -c "import sys,json; v=json.load(sys.stdin)['value']; print(v[0]['ID'] if v else 'NONE')")
PEMP=$(curl -s $MGR "$B/LeaveRequests(ID=$PEND,IsActiveEntity=true)?\$select=EmpId,NoOfDays" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['EmpId'],d['NoOfDays'])")
PE=$(echo $PEMP | cut -d' ' -f1); PD=$(echo $PEMP | cut -d' ' -f2)
BAL_BEFORE=$(curl -s $MGR "$B/Employees?\$filter=EmpId%20eq%20'$PE'&\$select=LeaveBalance" | python3 -c "import sys,json; print(json.load(sys.stdin)['value'][0]['LeaveBalance'])")
chk 49 "manager approves pending leave"           200 $(code $MGR -X POST -H "Content-Type: application/json" -d '{"remarks":"ok"}' "$B/LeaveRequests(ID=$PEND,IsActiveEntity=true)/EmployeeService.approve")
BAL_AFTER=$(curl -s $MGR "$B/Employees?\$filter=EmpId%20eq%20'$PE'&\$select=LeaveBalance" | python3 -c "import sys,json; print(json.load(sys.stdin)['value'][0]['LeaveBalance'])")
chk 50 "leave balance deducted correctly"         "$((BAL_BEFORE-PD))" "$BAL_AFTER"
APPBY=$(curl -s $MGR "$B/LeaveRequests(ID=$PEND,IsActiveEntity=true)?\$select=ApprovedBy" | python3 -c "import sys,json; print(json.load(sys.stdin)['ApprovedBy'])")
chk 51 "ApprovedBy = real logged-in user"         "manager" "$APPBY"
chk 52 "double-approve blocked"                   400 $(code $MGR -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests(ID=$PEND,IsActiveEntity=true)/EmployeeService.approve")
chk 53 "approve nonexistent leave -> 404"         404 $(code $MGR -X POST -H "Content-Type: application/json" -d '{}' "$B/LeaveRequests(ID=99999999-0000-0000-0000-000000000000,IsActiveEntity=true)/EmployeeService.approve")

echo "════════ SECTION 6: PAYROLL ════════"
chk 54 "employee blocked from processPayroll"     403 $(code $EMP -X POST -H "Content-Type: application/json" -d '{"empId":"E001","payMonth":"2026-08"}' "$B/processPayroll")
chk 55 "manager blocked from processPayroll"      403 $(code $MGR -X POST -H "Content-Type: application/json" -d '{"empId":"E001","payMonth":"2026-08"}' "$B/processPayroll")
PAY=$(curl -s $ADM -X POST -H "Content-Type: application/json" -d '{"empId":"E001","payMonth":"2026-08"}' "$B/processPayroll" | python3 -c "import sys,json; print(json.load(sys.stdin).get('value',''))")
chk 56 "admin processes payroll"                  "Payroll processed" "$(echo $PAY | cut -d' ' -f1-2)"
# verify net < gross in stored record
NETOK=$(curl -s $ADM "$B/Payrolls?\$filter=EmpId%20eq%20'E001'%20and%20PayMonth%20eq%20'2026-08'" | python3 -c "
import sys,json; p=json.load(sys.stdin)['value'][0]
gross=p['BasicSalary']+p['HRA']+p['Allowances']
print('OK' if float(p['NetSalary'])<gross and abs(float(p['Tax'])-gross*0.10)<2 else 'BAD')")
chk 57 "net salary < gross, tax = 10%"            "OK" "$NETOK"
chk 58 "duplicate payroll month blocked"          400 $(code $ADM -X POST -H "Content-Type: application/json" -d '{"empId":"E001","payMonth":"2026-08"}' "$B/processPayroll")
chk 59 "invalid payMonth format blocked"          400 $(code $ADM -X POST -H "Content-Type: application/json" -d '{"empId":"E001","payMonth":"08-2026"}' "$B/processPayroll")
chk 60 "payroll for unknown employee -> 404"      404 $(code $ADM -X POST -H "Content-Type: application/json" -d '{"empId":"E999","payMonth":"2026-08"}' "$B/processPayroll")

echo "════════ SECTION 7: ATTENDANCE ════════"
chk 61 "mark attendance works"                    200 $(code $EMP -X POST -H "Content-Type: application/json" -d '{"empId":"E002","status":"Present"}' "$B/markAttendance")
chk 62 "double mark same day blocked"             400 $(code $EMP -X POST -H "Content-Type: application/json" -d '{"empId":"E002","status":"Present"}' "$B/markAttendance")
chk 63 "invalid status rejected"                  400 $(code $EMP -X POST -H "Content-Type: application/json" -d '{"empId":"E003","status":"Sleeping"}' "$B/markAttendance")
chk 64 "checkout without check-in blocked"        400 $(code $EMP -X POST -H "Content-Type: application/json" -d '{"empId":"E003"}' "$B/checkOut")
chk 65 "checkout after check-in works"            200 $(code $EMP -X POST -H "Content-Type: application/json" -d '{"empId":"E002"}' "$B/checkOut")
chk 66 "double checkout blocked"                  400 $(code $EMP -X POST -H "Content-Type: application/json" -d '{"empId":"E002"}' "$B/checkOut")

echo "════════ SECTION 8: METADATA, UI ROUTES & VALUE HELP ════════"
chk 67 "OData service document"                   200 $(code $ADM "$B/")
chk 68 "Fiori UI index.html served"               200 $(code $ADM "$UI/com.employee.employeelist/index.html")
chk 69 "UI manifest.json served"                  200 $(code $ADM "$UI/com.employee.employeelist/manifest.json")
chk 70 "UI annotations served via metadata"       200 $(code $ADM "$B/\$metadata")
MD=$(curl -s $ADM "$B/\$metadata")
chk 71 "bound approve action in metadata"         yes $(echo "$MD" | grep -q '"approve"\|Name="approve"' && echo yes || echo no)
chk 72 "OperationAvailable (greyed buttons) set"  yes $(echo "$MD" | grep -q 'OperationAvailable' && echo yes || echo no)
chk 73 "IsActionCritical (confirm dialog) set"    yes $(echo "$MD" | grep -q 'IsActionCritical' && echo yes || echo no)
chk 74 "no emojis left in annotations"            0 $(echo "$MD" | grep -c '💰\|🏖\|⭐\|🔵\|📅' || true)
# Department value help + expand
chk 75 "Employees expand Department works"        200 $(code $ADM "$B/Employees?\$expand=Department&\$top=1")
chk 76 "Employees expand all children"            200 $(code $ADM "$B/Employees?\$expand=SalaryHistories,LeaveRequests,Attendances,Payrolls&\$top=1")
VIRT=$(curl -s $EMP "$B/Employees?\$select=EmpId,Experience,SalaryGrade&\$top=1" | python3 -c "import sys,json; v=json.load(sys.stdin)['value'][0]; print('OK' if v.get('Experience') and v.get('SalaryGrade') else 'MISSING')")
chk 77 "virtual fields in list query (UI bug fix)" "OK" "$VIRT"
chk 78 "draft-union list query (FE pattern)"      200 $(code $ADM "$B/Employees?\$count=true&\$select=EmpId,Experience,SalaryGrade&\$expand=DraftAdministrativeData(\$select=DraftUUID,InProcessByUser)&\$filter=(IsActiveEntity%20eq%20false%20or%20SiblingEntity/IsActiveEntity%20eq%20null)&\$top=2")

echo ""
echo "═══════════════════════════════════════════"
echo "RESULT: $PASS passed, $FAIL failed (of $((PASS+FAIL)))"
[ -n "$FAILED_TESTS" ] && echo -e "FAILED:$FAILED_TESTS"
