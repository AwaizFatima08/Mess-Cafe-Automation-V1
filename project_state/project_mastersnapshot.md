MASTER PROJECT SNAPSHOT — VERSION 1 (POST PHASE 9 + PHASE 10 LOCK)
🧭 Project Identity

Product Engine (Future): Club Manager
V1 Deployment Name: FFL Management Club

Organization: Fatima Fertilizer
Owner: Dr. Humayun Shahzad

🎯 Version 1 Scope (LOCKED)

Mess operations only:

Breakfast
Lunch
Dinner
🧠 Version 1 Operating Philosophy
Operational simplicity over automation
Manual governance where required
Cloud-first architecture (Firebase)
Modular expansion path preserved
Multi-tenant future awareness (non-intrusive in V1)
📍 CURRENT SYSTEM STATE
🔷 SYSTEM STATUS

STABLE + FIELD-VALIDATED + ANALYTICS ENABLED + READY FOR PRODUCT FINISHING

You now have:

Transaction system ✔
Operational control system ✔
Event system ✔
Analytics system ✔

👉 System has transitioned into a decision-support platform

🧱 CORE ARCHITECTURE (LOCKED)
Identity Model
uid → system identity
employee_number → business identity
Critical Rule

employees.employee_number ↔ users.employee_number
👉 Must never break

Data Strategy (VERY IMPORTANT)
Firestore = transactional source of truth
Analytics = derived via fetch + in-memory filtering
No heavy index dependency
Universal timestamp parser implemented
📊 FIRESTORE FOOTPRINT
Core Collections
employees
users
menu_items
daily_menus
weekly_menu_templates
meal_reservations
meal_rates
meal_feedback
notifications
notification_deliveries
Event Layer
events
event_attendance_responses
event_attendance_summaries
event_note_templates
🧩 PHASE-WISE DEVELOPMENT (UPDATED)
Phase 1 — Foundation ✅
Flutter + Firebase setup
Base navigation
Phase 2 — Identity & Governance ✅
Employee master
Signup validation
Approval workflow
Role routing
Phase 3 — Menu & Reservation Engine ✅
Menu management
Weekly templates
Monthly builder
Booking system
Cutoff enforcement
Quantity / dine-in / takeaway
Phase 3.7 — Guest / Proxy ✅
Guest booking
Proxy booking
Role overrides
Phase 3.8 — Operational Dashboard ✅
Reservation visibility
Issuance tracking
Segmentation
Phase 4 — Stabilization ✅
Query optimization
Index alignment
Issuance hardening
Phase 5 — Rate Engine ✅
Manual rate entry
Backfill into reservations
Phase 5.5 — Cost Reporting ✅
Daily cost dashboard
Cost breakdowns
Phase 6 — Feedback System ✅
Rating system
Feedback dashboard
Employee feedback loop
Phase 7 — Notification System ✅
In-app notifications
Badge + history
Admin visibility
Phase 8 — Event Module ✅
Event lifecycle
Attendance tracking
Notifications integration
XLSX export
Phase 9 — Analytics Engine ✅ (NEWLY COMPLETED)
Implemented
1. Attendance Analytics
total attendance
employee vs guest
meal-wise
trends
2. Cost Analytics
total cost
per head
guest vs employee
trends
3. Feedback Analytics
rating distribution
average rating
KPI cards
Phase 9 Key Architectural Decisions
❌ Avoid complex Firestore queries
✅ Fetch-all + filter in Dart
✅ Universal timestamp parser
✅ Only issued meals considered
📁 UPDATED DART FILE INVENTORY (POST PHASE 9)
Analytics Layer (NEW)
Services
lib/analytics/services/
- attendance_analytics_service.dart
- cost_analytics_service.dart
- feedback_analytics_service.dart
Models
lib/analytics/models/
- analytics_filter_model.dart
- attendance_analytics_result.dart
- cost_analytics_result.dart
- feedback_analytics_result.dart
UI
lib/analytics/screens/
- analytics_dashboard_screen.dart
Total System (Updated)
~60+ Dart files (expanded from 54)
Modular architecture maintained
🔗 INTERLINKAGE (UPDATED WITH ANALYTICS)
analytics_dashboard_screen
   ↓
analytics_filter_model
   ↓
[attendance | cost | feedback]_analytics_service
   ↓
Firestore collections
   ↓
In-memory aggregation
   ↓
KPI + charts
⚠️ LOCKED BUSINESS RULE
if (data['is_issued'] != true) skip;

👉 Ensures:

real consumption
no over-reporting
🚧 KNOWN LIMITATIONS (ACCEPTED)
fetch-all strategy not scalable at large scale
no caching layer
no pagination
no export (to be handled in Phase 10)
no real-time streaming
🎯 PHASE 10 — FINALIZED DEVELOPMENT PLAN
Objective

Convert system into polished, deployable product

🔹 Phase 10A — Theme & Branding
App name → FFL Management Club
Bright green theme
Central theme file
Logo integration
Files
lib/core/theme/app_theme.dart
lib/core/constants/app_constants.dart
🔹 Phase 10B — Authentication UX
Forgot password
Admin password reset
Persistent login
Files
lib/auth/screens/login_screen.dart
lib/services/auth_service.dart
lib/admin/screens/user_management_screen.dart
🔹 Phase 10C — Employee UX + Performance
Fix slow transitions
Smooth navigation
Light animations
Loading states
Files
lib/employee/screens/employee_dashboard_screen.dart
lib/employee/screens/today_menu_screen.dart
🔹 Phase 10D — Reservation Optimization (CRITICAL)
Employee number search
Hybrid filtering
Sorting
KPI header
Files
lib/admin/screens/dashboard_screen.dart
lib/services/meal_reservation_service.dart

Optional:

lib/widgets/reservation_filter_bar.dart
🔹 Phase 10E — Admin Dashboard Refinement
Scroll-friendly UI
Dense but readable
Clear grouping
Files
lib/admin/screens/admin_dashboard_shell.dart
lib/admin/screens/dashboard_screen.dart
🔹 Phase 10F — Performance Optimization
parallel data fetch
remove redundant calls
reduce rebuilds
preload predictable data
🔹 Phase 10G — Export Layer
Deliverables
CSV export (priority)
PDF export (secondary)
Files
lib/services/export_service.dart
lib/utils/csv_generator.dart
lib/utils/pdf_generator.dart
⚡ PERFORMANCE PRINCIPLE

👉 Never block UI on data fetch

🔍 RESERVATION UX (FINAL MODEL)

Top:

search (employee no.)
filters

Middle:

KPI summary

Bottom:

optimized list
🔐 AUTH MODEL (FINAL)
email-based identity (hidden)
forgot password
admin reset
persistent login
🚀 DEVELOPMENT ROADMAP (UPDATED)
Remaining V1 Phases
Phase 10 — UI + UX + Performance (CURRENT)
Phase 11 — Security Hardening
Phase 12 — Controlled Testing
Phase 13 — Production Launch
🔮 POST V1 ROADMAP
Version 2
Café
BBQ
Tuck shop
Version 3
Inventory
Procurement
Version 4
Recipe costing
Version 5
Billing automation
Version 6
Full hospitality platform
🧱 STRATEGIC POSITION

You now have:

👉 Operational System → Analytical System → Product Layer (in progress)

Next step:

👉 Product → Deployment → Scale

##### Canonical Dart File Inventory (Pre phase 9)

### Entry Point
- `lib/main.dart`

### Core Constants
- `lib/core/constants/reservation_constants.dart`

### Models
- `lib/models/daily_resolved_menu.dart`
- `lib/models/event_attendance_response_model.dart`
- `lib/models/event_attendance_summary_model.dart`
- `lib/models/event_model.dart`
- `lib/models/event_note_template_model.dart`
- `lib/models/meal_booking_request.dart`
- `lib/models/meal_option_selection.dart`
- `lib/models/meal_reservation.dart`
- `lib/models/reservation_settings.dart`
- `lib/models/resolved_meal_option.dart`

### Core / Shared Services
- `lib/services/employee_identity_service.dart`
- `lib/services/employee_registration_service.dart`
- `lib/services/event_attendance_service.dart`
- `lib/services/meal_cost_reporting_service.dart`
- `lib/services/meal_feedback_service.dart`
- `lib/services/meal_rate_service.dart`
- `lib/services/meal_reservation_service.dart`
- `lib/services/my_meal_history_service.dart`
- `lib/services/notification_service.dart`
- `lib/services/user_profile_service.dart`
- `lib/services/user_role_service.dart`

### Admin Services
- `lib/admin/services/menu_resolver_service.dart`

### Admin Screens
- `lib/admin/screens/active_menu_preview_screen.dart`
- `lib/admin/screens/admin_dashboard_shell.dart`
- `lib/admin/screens/bulk_upload_screen.dart`
- `lib/admin/screens/dashboard_screen.dart`
- `lib/admin/screens/employee_master_management_screen.dart`
- `lib/admin/screens/event_management_screen.dart`
- `lib/admin/screens/guest_meal_booking_screen.dart`
- `lib/admin/screens/meal_cost_dashboard_screen.dart`
- `lib/admin/screens/meal_feedback_dashboard_screen.dart`
- `lib/admin/screens/meal_rate_management_screen.dart`
- `lib/admin/screens/menu_cycle_management_screen.dart`
- `lib/admin/screens/menu_management_screen.dart`
- `lib/admin/screens/monthly_menu_builder_screen.dart`
- `lib/admin/screens/reports_screen.dart`
- `lib/admin/screens/user_management_screen.dart`
- `lib/admin/screens/weekly_menu_template_screen.dart`

### Admin Widgets
- `lib/admin/widgets/add_menu_item_dialog.dart`
- `lib/admin/widgets/admin_section_placeholder_card.dart`
- `lib/admin/widgets/edit_menu_item_dialog.dart`
- `lib/admin/widgets/pending_approvals_card.dart`

### Employee Screens
- `lib/employee/screens/employee_dashboard_screen.dart`
- `lib/employee/screens/employee_dashboard_shell.dart`
- `lib/employee/screens/employee_signup_screen.dart`
- `lib/employee/screens/event_invitation_detail_screen.dart`
- `lib/employee/screens/meal_feedback_submission_screen.dart`
- `lib/employee/screens/my_meal_history_screen.dart`
- `lib/employee/screens/today_menu_screen.dart`

### Employee Widgets
- `lib/employee/widgets/employee_event_invitations_section.dart`

### Shared Screens / Widgets
- `lib/shared/screens/notifications_screen.dart`
- `lib/shared/widgets/notification_badge.dart`

### Live File Count
- 54 Dart files
- 15 directories

---

## 8. Interlinkage Map

## Application Entry Flow
`main.dart`  
→ authentication state  
→ `user_profile_service.dart`  
→ `user_role_service.dart`  
→ role-based dashboard shell

## Identity & User Governance Flow
`employee_registration_service.dart`  
→ validates against employee master  
→ `employee_identity_service.dart`  
→ `users` + `employees` linkage  
→ `user_management_screen.dart`  
→ approval / role assignment

## Admin Navigation Flow
`admin_dashboard_shell.dart`  
→ `dashboard_screen.dart`  
→ `employee_master_management_screen.dart`  
→ `user_management_screen.dart`  
→ `menu_management_screen.dart`  
→ `weekly_menu_template_screen.dart`  
→ `monthly_menu_builder_screen.dart`  
→ `menu_cycle_management_screen.dart`  
→ `active_menu_preview_screen.dart`  
→ `bulk_upload_screen.dart`  
→ `meal_rate_management_screen.dart`  
→ `meal_cost_dashboard_screen.dart`  
→ `meal_feedback_dashboard_screen.dart`  
→ `event_management_screen.dart`  
→ `reports_screen.dart`

## Menu Engine Flow
`menu_management_screen.dart`  
→ menu items stored  
→ `weekly_menu_template_screen.dart`  
→ `monthly_menu_builder_screen.dart` / `menu_cycle_management_screen.dart`  
→ `lib/admin/services/menu_resolver_service.dart`  
→ resolved daily menu  
→ `active_menu_preview_screen.dart` and employee view

## Employee Booking Flow
`employee_dashboard_shell.dart`  
→ `employee_dashboard_screen.dart`  
→ `today_menu_screen.dart`  
→ `meal_reservation_service.dart`  
→ `meal_reservations`

## Guest / Proxy Booking Flow
`guest_meal_booking_screen.dart`  
→ `meal_reservation_service.dart`  
→ reservation creation / controlled override

## Issuance / Reservation Lifecycle Flow
`dashboard_screen.dart`  
→ reads operational reservations  
→ issuance action through `meal_reservation_service.dart`  
→ reservation lifecycle status update

## Rate / Cost Flow
`meal_rate_management_screen.dart`  
→ `meal_rate_service.dart`  
→ writes item/date rates  
→ updates reservation financial fields  
→ `meal_cost_reporting_service.dart`  
→ `meal_cost_dashboard_screen.dart`

## Feedback Flow
`my_meal_history_screen.dart`  
→ `meal_feedback_submission_screen.dart`  
→ `meal_feedback_service.dart`  
→ `meal_feedback_dashboard_screen.dart`

## Employee Transparency Flow
`my_meal_history_service.dart`  
→ `my_meal_history_screen.dart`  
→ line-level historical meal and cost visibility

## Notification Flow
system event  
→ `notification_service.dart`  
→ `notifications` + `notification_deliveries`  
→ `notification_badge.dart`  
→ `notifications_screen.dart`

## Event Attendance Flow
`event_management_screen.dart`  
→ `event_attendance_service.dart`  
→ `events`, `event_attendance_responses`, `event_attendance_summaries`  
→ `notification_service.dart`  
→ employee notification  
→ `event_invitation_detail_screen.dart`  
→ employee response submission/update  
→ `employee_event_invitations_section.dart` reflects live status

## Reporting Flow (Current)
Domain-specific reporting currently exists in:
- `dashboard_screen.dart`
- `meal_cost_dashboard_screen.dart`
- `meal_feedback_dashboard_screen.dart`
- `event_management_screen.dart` reporting/export section
- `reports_screen.dart` remains the logical consolidation point for Phase 9

---

