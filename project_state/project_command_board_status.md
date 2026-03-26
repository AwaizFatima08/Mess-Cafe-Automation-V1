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
## Update Entry - 23-Mar-2026 00:26

### Completed
Phase 4 fully completed and validated
Dashboard performance optimization implemented
Date-based caching introduced
Firestore query optimization (employee date-scoped queries)
Issuance workflow hardened
Confirmation dialog added
Duplicate issuance prevention implemented
Issued state update validated
Issued metadata (timestamp + operator) displayed
Firestore issues resolved
Security rule misconfiguration identified and isolated
Temporary open-rule strategy applied for development continuity
Firestore indexing aligned
Missing composite index identified and created (employee_number + reservation_date)
Employee Today Menu screen fully restored and optimized
Flutter compatibility fixes
Sealed class issue resolved (removed invalid snapshot extension)
Full system validation completed
Employee booking flow → OK
Admin / Supervisor dashboard → OK
Issuance → OK
Final project chronology restructured and locked (Phase 5–13)
Master continuity snapshot prepared
Backup framework finalized and executed
### Ongoing
System running in controlled development mode
Firestore rules temporarily open
Monitoring runtime performance under real usage
Preparing transition to business-layer development (Phase 5 onward)
### Next
System running in controlled development mode
Firestore rules temporarily open
Monitoring runtime performance under real usage
Preparing transition to business-layer development (Phase 5 onward)
### Decisions / Risks
Start Phase 5 — Rate Engine (manual, date-based)
Immediate tasks in next phase:
Design Firestore schema for rate storage
Create admin UI for rate entry
Link rates with menu items (date-bound)
Ensure compatibility with future reporting module

### Master Snapshot at closeout in 23-3-26
MESS & CAFÉ AUTOMATION V1 — MASTER CONTINUITY SNAPSHOT (LOCKED)
Project Owner

Dr. Humayun Shahzad
Chief Medical Officer — Fatima Fertilizer

🔒 CURRENT SYSTEM STATE
PHASE 1 → PHASE 4 COMPLETE
SYSTEM STABLE
CORE OPERATIONS VALIDATED
READY FOR FEATURE EXPANSION (BUSINESS LAYER)
✅ COMPLETED DEVELOPMENT (CONSOLIDATED)
🔵 Phase 1 — Foundation
Flutter app structure
Firebase Auth + Firestore integration
Role-based navigation skeleton
🔵 Phase 2 — Identity & Governance
Employee Master (source of truth)
Signup validation against employee records
Admin approval workflow
Role assignment (employee / supervisor / admin)
🔵 Phase 3 — Core Operations Engine
Employee Side
Today Menu screen
Meal booking (multi-option)
Quantity handling
Dine-in / takeaway split
Cutoff timing enforcement
Admin / Supervisor Side
Guest booking
Proxy booking
Reservation review screen
Supervisor / manager control flow
🔵 Phase 3.7 — Guest Control Layer
Admin / supervisor restricted guest booking
Booking traceability
🔵 Phase 3.8 — Dashboard (Major Milestone)
Operational dashboard implemented
Meal-wise summary (Breakfast/Lunch/Dinner)
Issued / Pending / Cancelled tracking
Segmentation:
Employee vs Guest
Self vs Proxy
Dining mode:
Dine-in vs Takeaway
Booking source:
Employee app
Supervisor console
Admin console
Operator visibility
🔵 Phase 4 — Hardening & Performance (THIS CHAT)
Performance Optimization
Query optimization (date-scoped)
Firestore index tuning
Local caching (date-based)
Issuance System
Issue meal workflow
Status transition validation
Safe update logic
Stability Fixes
Firestore rule misconfiguration isolated
Profile load failure debugged
Composite index dependency resolved
Sealed class issue resolved
📍 CURRENT FOOTPRINT
System Capability
End-to-end meal lifecycle working
Role-based access working
Dashboard operational
Issuance validated
Employee experience optimized
Technical Status
Flutter analyze → ✅ clean
Firestore queries → optimized
Indexing → aligned
Runtime errors → resolved
Temporary Condition
🔓 Firestore rules = OPEN (development mode)
🧠 CORE ARCHITECTURE (LOCKED)
Identity Model
users.uid → system identity
employee_number → business identity
Reservation Model
one document = one reservation line
quantity stored per line
status controls lifecycle
Dashboard Model
no backend aggregation
client-side computation
date-based caching
Index Strategy
create only when required by Firestore
no speculative indexing
📂 DART FILE INDEX + INTERLINKAGE
🔐 Core Engine
meal_reservation_service.dart

Central service used by:

today_menu_screen.dart
guest_meal_booking_screen.dart
dashboard_screen.dart

Handles:

create reservation
validate request
fetch reservations (date / employee)
issuance updates
👨‍🍳 Employee Layer
today_menu_screen.dart

Uses:

meal_reservation_service

Functions:

load menu
create booking
cancel booking
show user-specific reservations
🧑‍💼 Admin / Supervisor Layer
dashboard_screen.dart

Uses:

meal_reservation_service

Functions:

KPI metrics
segmentation
operator visibility
issuance control
guest_meal_booking_screen.dart

Uses:

meal_reservation_service

Functions:

guest booking
proxy booking
override logic
user_management_screen.dart
user approval
role assignment
employee_master_management_screen.dart
employee data management
admin_dashboard_shell.dart
navigation + routing hub
menu_management_screen.dart
menu item creation
weekly_menu_template_screen.dart
weekly template design
monthly_menu_builder_screen.dart
menu cycle assignment
active_menu_preview_screen.dart
resolved menu view
reports_screen.dart (placeholder)
future analytics module
🔗 SYSTEM FLOW (SIMPLIFIED)
Employee → Reservation → Firestore
                         ↓
                 meal_reservation_service
                         ↓
        ----------------------------------
        | Dashboard | Issuance | Reports |
        ----------------------------------
🚀 FINAL LOCKED DEVELOPMENT CHRONOLOGY (V1)
🔵 Phase 5 — Rate Engine (Manual)
Scope
manual rate entry
date-based pricing
linked to menu items
Structure (LOCKED)
menu_item_id
effective_date
rate
🟢 Phase 6 — User Feedback Mechanism
Scope
feedback per meal/date
category-based input
optional anonymity
🟡 Phase 7 — Push / Pull Notifications
Scope
booking confirmation
reminders
admin announcements
Core Design (CRITICAL)
notification_type
target_user
payload
🟠 Phase 8 — Attendance System (Standalone Module)
Scope
event creation
attendance tracking
notification-driven participation
Constraint
no linkage to meals
🔴 Phase 9 — Reporting & Analytics Dashboard
Scope
daily / weekly / monthly reports
cost per head (uses Phase 5)
consumption trends
guest vs employee analysis
🟣 Phase 10 — UI Refinement
Scope
branding (logos)
splash screens
UI polishing
⚫ Phase 11 — Security & Stability Hardening
Scope
Firestore rules (final)
role-based access enforcement
validation layer
error handling standardization
🧪 Phase 12 — TEST VERSION
separate environment
controlled rollout
🚀 Phase 13 — PRODUCTION LAUNCH (V1 COMPLETE)
🔮 FUTURE VERSION ROADMAP (LOCKED)
Version 2
BBQ
Café
Tuck shop
Bakery
Version 3
Procurement
Order generation
Inventory
Version 4
Recipe-based costing
Version 5
Finance & automated billing
Version 6
Event management
⚠️ CRITICAL JUNCTIONS (MUST NOT BREAK)
🔴 Rate Engine Link
reservation → menu_item → rate (date-based)
🔴 Notification System = Backbone

Connects:

reservations
feedback
attendance
📊 CURRENT POSITION
SYSTEM COMPLETE (CORE)
→ READY FOR BUSINESS LAYER EXPANSION
→ NO BLOCKING ISSUES
→ STABLE BASELINE ACHIEVED


----------------------------------------------------------
## Update Entry - 26-Mar-2026 23:39

### Completed today:
- Phase 7 notification requirements reviewed and locked.
- Notification architecture finalized as a two-layer model:
  - Administrative notifications
  - Transactional notifications
- Administrative notification types locked:
  - menu item announcement
  - menu cycle announcement
  - special event announcement
  - club administration announcement
- Transactional notification types locked:
  - meal booking confirmation
  - meal booking cancellation confirmation
  - meal issuance confirmation
- Delivery channels finalized for both layers:
  - in-app notification history
  - push notification
  - registered email
- Governance rule finalized:
  - new menu items will not be auto-circulated
  - menu item notifications will be admin-triggered only after review and publish decision
- Trigger discipline finalized:
  - administrative notifications = manual publish
  - transactional notifications = system-triggered after confirmed workflow completion
- Phase 7 implementation direction aligned toward database-first preparation before coding.

### Currently ongoing:
- Preparing database structure for Phase 7 notification module.
- Planning final Firestore document structure for notifications and delivery tracking.
- Holding implementation until database layer is created and reviewed.

### Next step:
- Define final Firestore collections/documents for Phase 7.
- Create notification-related database structure first.
- Then resume from the same point for implementation blueprint and code integration.

### Decisions / risks:
- Decision: Phase 7 will use a two-layer employee notification model rather than a generic alert engine.
- Decision: Administrative notifications require explicit admin review/publish action.
- Decision: Transactional notifications will be sent only after successful booking/cancellation/issuance state change.
- Decision: All transactional events will also go to app, push, and email.
- Risk: Push + email delivery will require backend dispatch handling and should not be treated as client-only logic.
- Risk: Notification spam avoided by keeping menu-item circulation manual and controlled.
- Risk: Meal issuance confirmation must be tied to actual issuance event, not assumed workflow state.

## Resume Point — Phase 7
Phase 7 requirement is fully locked.

### Locked model:
Two-layer notification system

#### Administrative notifications:
- menu item announcement
- menu cycle announcement
- special event announcement
- club administration announcement

#### Transactional notifications:
- meal booking confirmation
- meal booking cancellation confirmation
- meal issuance confirmation

### Locked delivery channels:
- in-app notification history
- push notification
- registered email

### Locked governance:
- new menu items are admin-triggered only
- no auto-circulation on item creation
- administrative notifications require explicit review/publish
- transactional notifications trigger only after confirmed workflow completion

### Immediate next work:
Database-first preparation:
- finalize Firestore collection/document structure
- then proceed with implementation blueprint and file impact map

----------------------------------------------------------
## Update Entry - 26-Mar-2026 23:45

### Completed
- [not provided]

### Ongoing
- [not provided]

### Next
- [not provided]

### Decisions / Risks
- [not provided]

