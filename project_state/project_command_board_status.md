Mess & Café Automation Platform — Master Project Snapshot

Last Consolidated Update: 23-Mar-2026

1. Project Identity

Mess & Café Automation System — Fatima Fertilizer

System evolving into:

Integrated Hospitality + Facility Management Ecosystem

2. Current System Footprint
System Status

FUNCTIONAL + HARDENED + READY FOR FIELD VALIDATION

Core Capabilities
Identity & Access
Firebase Authentication
Role-based routing
Admin-controlled user approval workflow
Strict employee master linkage
Admin System
Dashboard (with pending approvals)
User Management (fully hardened)
Employee Master Management
Menu Management
Weekly Template Builder
Menu Cycle Engine
Active Menu Preview
Bulk Upload System
Reports (basic; Phase 8 upgrade planned)
Employee System
Dashboard with today's menu
Date-based navigation
Reservation system:
breakfast / lunch / dinner
dine-in / takeaway
quantity selection
future booking
cutoff enforcement
Core Engines
Menu Resolver Engine
Reservation Engine
Identity Validation Engine
3. Architecture (Locked)
uid → system identity
employee_number → business identity

Linkage Rule:

employees.employee_number ↔ users.employee_number

This linkage is critical and must never be broken.

4. Dart File Inventory & Interlinkage
Entry Point
lib/main.dart

Flow:

Login → UserProfileService → Role Routing → Dashboard Shell
Core Services
lib/services/user_profile_service.dart
lib/services/user_role_service.dart
lib/services/employee_identity_service.dart
lib/services/meal_reservation_service.dart

Interlinkage:

UserProfileService → users collection
EmployeeIdentityService → users + employees validation
MealReservationService → reservations + menu resolver
UserRoleService → role-based access control
Admin Module
lib/admin/screens/admin_dashboard_shell.dart
lib/admin/screens/dashboard_screen.dart
lib/admin/screens/user_management_screen.dart
lib/admin/screens/employee_master_management_screen.dart
lib/admin/screens/menu_management_screen.dart
lib/admin/screens/weekly_menu_template_screen.dart
lib/admin/screens/menu_cycle_management_screen.dart
lib/admin/screens/active_menu_preview_screen.dart
lib/admin/screens/bulk_upload_screen.dart
lib/admin/screens/reports_screen.dart

Flow:

AdminDashboardShell
→ DashboardScreen
→ UserManagementScreen → EmployeeIdentityService
→ WeeklyTemplateScreen
→ MenuCycleManagementScreen
→ ActiveMenuPreview
Employee Module
lib/employee/screens/employee_dashboard_shell.dart
lib/employee/screens/employee_dashboard_screen.dart
lib/employee/screens/today_menu_screen.dart

Flow:

EmployeeDashboard → TodayMenuScreen → MealReservationService → MenuResolverService
Models
lib/models/meal_option_selection.dart
lib/models/meal_booking_request.dart
lib/models/meal_reservation.dart
lib/models/reservation_settings.dart
lib/models/resolved_meal_option.dart
lib/models/daily_resolved_menu.dart
Menu Engine Flow
menu_items
  ↓
weekly_menu_templates
  ↓
menu_cycles
  ↓
menu_resolver_service
  ↓
daily_resolved_menu
5. Development Progression
Phase 1 — Foundation
Firebase + Flutter setup
Authentication
Admin UI base
Menu system base
Phase 2 — Database Alignment
Schema standardization
CSV import/export
Identity model correction
Template + cycle synchronization
Phase 3 — Admin Hardening (Completed)
Approval workflow
Search and filters
Audit trail
Duplicate protection
Approval validation enforcement
Pending approvals dashboard
UI Stabilization
Keyboard glitch fixed
Dropdown focus corrected
Date picker behavior improved
6. Ongoing Work
Tablet-based real testing
Approval scenario validation
Reservation flow validation
Menu cycle validation
7. Final Chronological Roadmap
Phase 3.6 — Admin UX Optimization
Pending-first view
Faster approval workflow
Reduced admin friction
Phase 3.7 — Guest Meal Workflow
Manager/supervisor guest booking
Guest tagging
Reporting inclusion
Phase 4 — Stability Layer
Logging improvements
Error handling
UI polishing
Phase 5 — Notifications
Email notifications (primary)
Push notifications (FCM)
WhatsApp (optional, later)
Phase 6 — Employee Feedback System
Ratings:
food quality
menu selection
ambience
service
Comments field
Feedback analytics foundation
Phase 7 — Rate Entry System
Manual daily rate entry
Linked to menu items
Used for monthly billing
No procurement automation
Phase 8 — Analytics Dashboard (V1 Final)
Attendance (daily/weekly/monthly)
Dine-in vs takeaway
Guest meals
Cost per head
Consumption trends
8. Version 1 Launch Strategy
Step 1 — Test Version
Limited users
Real environment testing
Feedback collection
Step 2 — Production Version
Stability verified
Bugs resolved
Feedback incorporated
9. Post Version 1 Expansion (No Core Development Required)

Modules:

Weekly BBQ
Café
Tuck Shop
Bakery

Reuse:

menu items
templates
cycles

Only adjustment:

operating time rules
Timing Rules
BBQ: 19:00–23:00 (weekly)
Café: 17:00–23:00
Tuck Shop: 15:00–23:00
Bakery: 17:00–22:00
10. Enterprise Modules (Post V1)
Procurement
Inventory
Finance & Accounts
Recipe-based costing
11. Final Module
Event Management
event booking
catering
attendance
billing
12. System Flow
Employee → Reservation → Meal Engine
                 ↓
           Attendance Data
                 ↓
         Feedback System (Phase 6)
                 ↓
         Rate System (Phase 7)
                 ↓
         Analytics (Phase 8)
                 ↓
         Decision Layer
13. Strategic Position

This system is now:

Architecture-driven
Governance-controlled
Modular and scalable
Ready for real-world validation
14. Final Lock Point

STATUS: READY FOR FIELD TESTING
NEXT: REAL USER FEEDBACK → CONTROLLED DEVELOPMENT

----------------------------------------------------------
## Update Entry - 24-Mar-2026 00:26

### Completed
- [not provided]

### Ongoing
- [not provided]

### Next
- [not provided]

### Decisions / Risks
- [not provided]

