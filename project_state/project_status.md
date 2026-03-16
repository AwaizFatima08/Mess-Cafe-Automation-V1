# ==========================================================
# MESS & CAFE AUTOMATION SYSTEM
# VERSION 1 PROJECT STATE FILE
# ==========================================================

Project Name: Mess & Cafe Automation Version 1

Project Owner: Dr. Humayun Shahzad  
Assistant Developer: Awaiz Fatima  

Development Environment:
Local development on NAS system

Production Environment:
Google Cloud Platform (Firebase + Cloud Run)

Repository:
https://github.com/AwaizFatima08/Mess-Cafe-Automation-V1

Project Start:
2026

----------------------------------------------------------
PROJECT OBJECTIVE
----------------------------------------------------------

Develop a mobile based automation system for the club mess
at Fatima Fertilizer Company to manage:

• Meal attendance
• Menu planning
• Food preparation forecasting
• Monthly billing
• Employee dashboard

The system will initially support:

Breakfast  
Lunch  
Dinner

Later versions will expand into a complete club ERP
including cafe, tuck shop, inventory and procurement.

----------------------------------------------------------
SYSTEM ARCHITECTURE (VERSION 1)
----------------------------------------------------------

Client Layer
-------------
Android mobile application built in Flutter.

Users:
Employees
Mess Manager
System Administrator


Cloud Backend
-------------
Google Cloud Platform

Services used:

Firebase Authentication
Cloud Firestore
Cloud Run
Firebase Cloud Messaging (future)

There will be NO physical server or database on-premise.

All application data will be stored in Google Cloud.

----------------------------------------------------------
DATA STORAGE MODEL
----------------------------------------------------------

Primary Database:
Cloud Firestore

Collections used in Version 1:

employees
menu_items
daily_menus
meal_bookings
attendance_records
billing_ledger

Firestore provides:

• real-time synchronization
• scalable cloud storage
• mobile SDK integration
• security rules

----------------------------------------------------------
BACKEND BUSINESS LOGIC
----------------------------------------------------------

Backend Services hosted on Cloud Run.

Responsibilities:

• booking cutoff validation
• duplicate booking prevention
• attendance posting rules
• manager administrative actions
• billing calculations
• secure API endpoints

----------------------------------------------------------
VERSION 1 MODULES
----------------------------------------------------------

Employee Master
---------------
Employee information database.

Menu Management
---------------
Daily menu entry for breakfast, lunch and dinner.

Meal Booking
------------
Employees select meals before cutoff time.

Attendance Dashboard
--------------------
Mess manager sees expected attendance for upcoming meals.

Attendance Recording
--------------------
Actual served attendance recorded during meal service.

Billing System
--------------
Monthly billing calculated automatically.

Employee Dashboard
------------------
Employees can view meal history and bill summary.

----------------------------------------------------------
EXCLUDED FROM VERSION 1
----------------------------------------------------------

These modules are intentionally postponed:

Cafe Ordering
Tuck Shop POS
Inventory Management
Procurement Module
Recipe Costing Engine
Event / Party Management
WhatsApp Notification System
Email Transaction Alerts
Payment Gateway Integration

----------------------------------------------------------
FIRESTORE COLLECTION STRUCTURE
----------------------------------------------------------

employees
---------
employee_number
full_name
department
designation
mobile
email
status
created_at

menu_items
----------
item_name
meal_type
base_price
active

daily_menus
-----------
menu_date
meal_type
cutoff_time
published
items[]

meal_bookings
-------------
employee_id
menu_id
booking_time
status

attendance_records
------------------
booking_id
attendance_status
marked_time
counter

billing_ledger
--------------
employee_id
date
description
amount
billing_month
status

----------------------------------------------------------
PROJECT DIRECTORY STRUCTURE
----------------------------------------------------------

~/projects/mess_cafe_automation_v1

mobile_app/
Flutter application

backend_services/
Cloud Run API services

cloud_config/
Firebase configuration
Firestore rules
Cloud Run deployment configs

docs/
Project documents

scripts/
Maintenance and backup scripts

logs/
Local development logs

project_state/
Project state and development history

----------------------------------------------------------
BACKUP POLICY
----------------------------------------------------------

Daily backup of project source code to NAS.

Backup location:

/NAS_BACKUPS/mess_cafe_automation_v1

Backup contents:

• source code
• Firebase configuration files
• documentation
• deployment scripts
• project state files

Database backups are not required locally because
Firestore is managed by Google Cloud.

----------------------------------------------------------
GIT VERSION CONTROL
----------------------------------------------------------

Repository maintained on GitHub.

Daily automatic commit and push scheduled through cron.

Git repository contains:

• Flutter source code
• backend service code
• cloud configuration
• documentation

----------------------------------------------------------
DEVELOPMENT ROADMAP
----------------------------------------------------------

PHASE 1 – CLOUD FOUNDATION

Create Firebase project  
Register Android app  
Configure Flutter Firebase connection  
Enable Firebase Authentication  
Create Firestore database  


PHASE 2 – DATA MODEL

Create Firestore collections

employees
menu_items
daily_menus
meal_bookings
attendance_records
billing_ledger


PHASE 3 – MOBILE APPLICATION

Employee login screen  
Menu display screen  
Meal booking module  
Booking cancellation  
Booking history


PHASE 4 – MANAGER MODULE

Menu publishing interface  
Attendance dashboard  
Attendance marking  


PHASE 5 – BILLING ENGINE

Monthly bill calculation  
Employee bill summary  
Manager billing dashboard  


----------------------------------------------------------
LONG TERM EXPANSION
----------------------------------------------------------

Version 2

Cafe ordering system  
Tuck shop POS  
Inventory tracking  


Version 3

Procurement management  
Supplier database  
Recipe costing engine  


Version 4

Event and party management  
Budget based menu planning  
Automated procurement planning  


Version 5

WhatsApp notifications  
Email alerts  
Employee self-service portal  

## 2026-03-14 — Development Milestone

### System Status
✔ Firebase Authentication working  
✔ Firestore connected to `(default)` database  
✔ Firestore rules configured correctly  
✔ Collections created:
- employees
- users
- menu_items
- daily_menus

### Flutter Application
✔ Flutter app successfully running on Galaxy Tab S9 FE  
✔ Login and logout functional  
✔ App successfully reading `daily_menus` from Firestore  
✔ Menu items resolved from `menu_items` collection  
✔ Breakfast menu displayed correctly in the app

### Repository Maintenance
✔ Removed large SDK archive files from repository history  
✔ Added Google Cloud SDK paths to `.gitignore`  
✔ Git push successfully completed after repository cleanup

### Next Development Step
Implement **Meal Booking System**

Planned tasks:
- Create `meal_bookings` collection
- Add **Book Meal** button in Flutter UI
- Save bookings to Firestore
- Implement booking deadline logic
- Extend support to lunch and dinner menus
----------------------------------------------------------
NOTES
----------------------------------------------------------

This file is the primary operational memory of the project.

It must be updated after each major milestone to
maintain continuity and context.

==========================================================
END OF FILE
==========================================================


## Update Entry - 15-Mar-2026 01:40

### Completed
-

### Ongoing
-

### Next
-

### Decisions / Risks
-



## Update Entry - 16-Mar-2026 01:40

### Completed
-

### Ongoing
-

### Next
-

### Decisions / Risks
-

