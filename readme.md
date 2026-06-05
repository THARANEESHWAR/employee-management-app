# SAP Employee Management Application

A full-stack enterprise application built from scratch 
using SAP Cloud Application Programming Model (CAP) 
and deployed live on SAP BTP Cloud Foundry.

## 🔗 Live Application
https://9450e8eatrial-dev-employee-app.cfapps.us10-001.hana.ondemand.com

## 🛠️ Tech Stack
- SAP CAP (Node.js) — Backend + OData V4
- SAP Fiori Elements — Frontend UI
- SAP HANA Cloud — Database (HDI Container)
- SAP BTP Cloud Foundry — Deployment
- MTA Build Tool — Packaging

## ✨ Features
- Auto Employee ID generation (E001, E002...)
- 6 CDS entities with associations
- 7 field validations on every transaction
- Department dropdown from live database
- Status management (Active/Inactive/On Leave)
- Salary History auto-tracked on every change
- Leave Request management with approval
- Attendance tracking
- Payroll processing with HRA + tax calculation
- Soft delete — data never permanently lost
- SalaryGrade calculated on-the-fly (never stored)
- 5-tab Object Page with full enterprise UI

## 📁 Project Structure
\`\`\`
employee-app/
├── db/
│   ├── schema.cds        ← 6 entities + 5 enums
│   └── data/             ← CSV seed data
├── srv/
│   ├── employee-service.cds  ← OData V4 service
│   └── employee-service.js   ← Business logic
├── app/
│   └── employee-list/    ← Fiori Elements UI
├── mta.yaml              ← BTP deployment config
└── package.json
\`\`\`

## 👨‍💻 Author
**Tharaneeshwar S**  
Senior Analyst A5 — Capgemini  
SAP UI5/Fiori Full Stack Developer  
SAP Certified Associate — CAP Backend Developer