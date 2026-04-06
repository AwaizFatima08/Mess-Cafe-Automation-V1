# Mess & Café Automation Platform — Consolidated Project Command Board Status

**Last Consolidated Update:** 28-Mar-2026  
**System State:** Post Phase 8 complete, preparing Phase 9

---

## 1. Project Identity

**Project:** Mess & Café Automation System — Fatima Fertilizer

**Strategic Direction:**  
Evolving toward an integrated hospitality, facility, and later multi-tenant operational platform.

---

## 2. Current System Status

**FUNCTIONAL + GOVERNED + FIELD-VALIDATED + EVENT-ENABLED + READY FOR ANALYTICS CONSOLIDATION**

The system has progressed from prototype status into a controlled operational application.

---

## 3. Consolidated Development Progress

## Phase 1 — Foundation ✅
- Flutter application structure established
- Firebase Auth and Firestore integrated
- Base navigation and dashboard shell structure created

## Phase 2 — Identity & Governance ✅
- Employee master database established
- Signup validation against employee master
- Approval workflow implemented
- Role assignment and controlled routing enforced

## Phase 3 — Core Menu & Reservation System ✅
- Menu item management
- Weekly template engine
- Monthly menu builder
- Menu cycle engine
- Active menu resolution
- Employee booking
- Dine-in / takeaway
- Future booking
- Cutoff enforcement
- Quantity support

## Phase 3.7 — Guest / Proxy Control ✅
- Guest meal booking
- Proxy booking by controlled roles
- Booking traceability
- Controlled override pathway

## Phase 3.8 — Operational Dashboard ✅
- Dashboard visibility for reservations
- Meal-wise summaries
- Issued / pending / cancelled views
- Employee vs guest segmentation
- Dining mode segmentation
- Operator/source visibility

## Phase 4 — Stabilization & Performance ✅
- Query optimization
- Firestore index alignment
- Date-based caching
- Issuance workflow hardening
- Duplicate issuance prevention
- Runtime stability improvements
- Controlled development continuity maintained

## Phase 5 — Rate Engine ✅
- Manual daily rate entry
- Menu-item-linked costing
- Reservation financial backfill (`unit_rate`, `amount`)

## Phase 5.5 — Cost Reporting ✅
- Daily cost dashboard
- Meal-wise cost breakdown
- Item-wise cost breakdown
- Employee vs guest split
- Average cost metrics
- Rated vs unrated visibility

## Phase 6 — Feedback System ✅
- Meal feedback submission
- Feedback dashboard
- Rating and issue tagging
- Anonymous option
- Close/resolve lifecycle
- Duplicate prevention

## Phase 6 Extension — Employee Experience ✅
- Meal history dashboard
- Cost visibility
- Inline feedback trigger from history

## Phase 7 — Notification System ✅
- In-app notification engine
- Transactional notifications
- Administrative notifications
- Notification badge
- Notification history screen
- Read/unread tracking
- Admin history filtering

## Phase 8 — Event Attendance Module ✅
- Event schema
- Event lifecycle controls
- Event models
- Event attendance service
- Admin event management
- Employee response flow
- Notification integration
- Event dashboard visibility
- Incremental summaries
- XLSX export
- Field validation completed

---

## 4. Current Dart Footprint Summary

### Live Inventory
- 54 Dart files
- 15 directories

### Major Modules
- Core services
- Admin screens
- Employee screens
- Shared notification UI
- Event attendance models/services
- Rate, cost, feedback, reservation services

### Current Consolidation Point
`reports_screen.dart` remains the logical anchor for unified Phase 9 reporting.

---

## 5. Current Locked Decisions

- V1 remains mess-only
- Costing remains manual-entry based
- Notifications remain in-app for V1
- Event attendance remains separate from meal reservations
- XLSX remains preferred export format
- Multi-tenant awareness should inform future design but not complicate current V1 unnecessarily
- Existing services should be reused rather than rewritten

---

## 6. Current Known Gaps

- Reporting is still domain-fragmented
- No unified analytics orchestration layer yet
- `reports_screen.dart` has not yet been elevated into full management dashboard
- Cost analytics is daily-focused and not yet trend/range capable
- No consolidated KPI model yet
- No standardized analytics export layer yet

---

## 7. Current Phase

## Active Position
**Preparing Phase 9 — Unified Reporting & Analytics Consolidation**

---

## 8. Immediate Next Work

### Phase 9A — Foundation
- Define analytics filter model
- Define KPI model
- Add analytics orchestration service
- Add attendance / cost / feedback / event analytics services

### Phase 9B — Unified Reports Screen
- Upgrade `reports_screen.dart`
- Add date range filters
- Add KPI cards
- Add cross-domain summary panels

### Phase 9C — Trends and Comparisons
- Attendance trends
- Cost trends
- Booking vs issuance
- Guest vs employee
- Dine-in vs takeaway
- Feedback and event insights

### Phase 9D — Export Standardization
- Consolidated XLSX reporting
- Sectioned exports by domain

---

## 9. Planned Roadmap to V1 Completion

- Phase 9 — Reporting & analytics consolidation
- Phase 10 — UI refinement and branding
- Phase 11 — Security and stability hardening
- Phase 12 — Controlled test version
- Phase 13 — Production launch

---

## 10. Post V1 Roadmap

- Version 2 — BBQ / Café / Tuck shop / Bakery
- Version 3 — Procurement / inventory
- Version 4 — Recipe-based costing
- Version 5 — Financial automation / billing
- Version 6 — Expanded event and hospitality workflows

---

## 11. Strategic Position

The system is now:
- modular
- governed
- operational
- expandable
- commercialization-aware

The next milestone is not a new operational engine.  
It is the unification of reporting and analytics into a management decision layer.

---



----------------------------------------------------------
## Update Entry - 29-Mar-2026 01:46

### Completed
Fixed Firestore index failures
Implemented robust timestamp parsing
Stabilized analytics services (attendance, cost, feedback)
Validated analytics dashboard end-to-end

### Ongoing
Phase 9 closure validation

### Next
Phase 10 (UI refinement + export)

### Decisions / Risks
Adopted fetch-all strategy (no index dependency)
Accepted performance tradeoff for V1 stability
Data consistency ensured via parser layer

----------------------------------------------------------
## Update Entry - 30-Mar-2026 23:17

### Completed
Phase 10 scope finalized
Branding strategy defined (FFL Management Club)
Authentication UX decisions locked
Reservation optimization model finalized
Performance optimization strategy defined

### Ongoing
Phase 10 planning

### Next
Phase 10A → Theme + Branding implementation

### Decisions / Risks
Email as primary auth identity (hidden)
Admin password reset enabled
Hybrid filtering approach selected
Performance optimization added as core Phase 10 component
No schema redesign allowed

----------------------------------------------------------
## Update Entry - 04-Apr-2026 00:02

# ==========================================================
# FFL MANAGEMENT CLUB — MASTER CONTINUATION SNAPSHOT
# VERSION 1 — PHASE 11 (HARDENING & STABILIZATION)
# ==========================================================

Project Owner: Dr. Humayun Shahzad  
Project: Mess & Café Automation (FFL Management Club)  
Architecture: Flutter + Firebase Authentication + Cloud Firestore  
Current Phase: Phase 11 — Security, Performance & Data Integrity Hardening  
System Status: Feature-Complete (V1 Scope) — NOT YET DEPLOYMENT-CLOSED  

---

# 1. SYSTEM OVERVIEW

The system has successfully completed:

- Authentication & role-based routing
- Employee identity linkage
- Menu engine (template → cycle → resolver)
- Meal booking (employee + guest/proxy)
- Meal issuance & attendance tracking
- Rate entry module
- Feedback module
- Notification layer
- Admin dashboards (attendance, cost, feedback)
- UI structure and navigation shells

System has transitioned from **feature development → operational hardening stage**.

---

# 2. CURRENT SYSTEM STATUS

## Stable Components

- Firebase authentication and role routing ✔
- Employee booking flow ✔
- Guest/proxy booking ✔
- Meal issuance ✔
- Attendance analytics ✔
- Admin dashboard loading ✔
- Firestore indexing ✔

## Critical Observation

System is **functionally complete but operationally inconsistent**, specifically in:

- Rate application
- Cost computation
- Feedback eligibility
- Current-day data rendering

---

# 3. CORE IDENTITY ARCHITECTURE (LOCKED)


- `uid` = system identity  
- `employee_number` = business identity  

⚠️ This chain is **critical** and must not be altered.

auth.uid → users → employee_number → employees

---

# 4. FIRESTORE COLLECTION STRUCTURE

Active collections:

- employees
- users
- registration_requests
- menu_items
- weekly_menu_templates
- menu_cycles
- daily_menus
- meal_reservations
- reservation_settings
- meal_rates
- meal_feedback

---

# 5. CURRENT BOTTLENECKS

## 5.1 Blank Screens (CRITICAL)

Affected modules:
- Rate Management
- Cost Dashboard
- Feedback Dashboard

### Root Causes

- Missing / inconsistent `meal_type`
- Missing `unit_rate`
- Query mismatch across collections
- UI not handling empty states

---

## 5.2 Rate Application Failure

- Rates not consistently applied to reservations
- Incorrect filtering using `meal_type` + `menu_item_id`
- Downstream cost calculation failure

---

## 5.3 Cost Analytics Breakdown

- Attendance visible ✔  
- Cost = blank ❌  

➡ Indicates broken linkage:

meal_reservations → meal_rates → cost reporting


---

## 5.4 Query Inefficiency

Current issue:
- Fetching all meal types (breakfast/lunch/dinner)

Required fix:
- Lazy loading (single meal type)
- Reduce Firestore reads
- Implement caching

---

## 5.5 Firestore Rules (PARTIAL)

- Write rules controlled ✔  
- Read rules still open ⚠️  

---

# 6. DART FILE INVENTORY (CURRENT)

## Core Entry
- lib/main.dart

## Employee Screens
- employee_dashboard_shell.dart
- employee_dashboard_screen.dart
- today_menu_screen.dart
- employee_signup_screen.dart

## Admin Screens
- admin_dashboard_shell.dart
- dashboard_screen.dart
- menu_management_screen.dart
- menu_cycle_management_screen.dart
- weekly_menu_template_screen.dart
- monthly_menu_builder_screen.dart
- active_menu_preview_screen.dart
- bulk_upload_screen.dart
- reports_screen.dart
- user_management_screen.dart

## Extended Admin Modules
- guest_meal_booking_screen.dart
- employee_master_management_screen.dart
- meal_rate_management_screen.dart
- meal_cost_dashboard_screen.dart
- meal_feedback_dashboard_screen.dart

## Services
- meal_reservation_service.dart
- employee_identity_service.dart
- user_profile_service.dart
- user_role_service.dart
- employee_registration_service.dart
- menu_resolver_service.dart
- meal_rate_service.dart
- meal_feedback_service.dart
- cost_analytics_service.dart
- notification_service.dart

## Models
- meal_reservation.dart
- meal_booking_request.dart
- meal_option_selection.dart
- reservation_settings.dart
- daily_resolved_menu.dart
- resolved_meal_option.dart

## Widgets
- add_menu_item_dialog.dart
- admin_section_placeholder_card.dart
- notification_badge.dart

## Constants / Theme
- reservation_constants.dart
- app_constants.dart
- app_theme.dart

---

# 7. SYSTEM INTERLINKAGE (CRITICAL FLOWS)

## 7.1 App Startup Flow

main.dart
→ Firebase Auth
→ user_profile_service
→ user_role_service
→ Route to Dashboard Shell


---

## 7.2 Identity Flow

users → employee_identity_service → employees


---

## 7.3 Menu Engine

menu_items
→ weekly_menu_templates
→ menu_cycles
→ menu_resolver_service
→ DailyResolvedMenu


---

## 7.4 Booking Flow

today_menu_screen
→ meal_reservation_service
→ meal_reservations


---

## 7.5 Guest Booking

guest_meal_booking_screen
→ meal_reservation_service


---

## 7.6 Issuance Flow

dashboard_screen
→ meal_reservation_service.getReservationsForDate()
→ markReservationIssued()


---

## 7.7 Rate & Cost Flow (BROKEN ZONE)

meal_reservations
→ meal_rate_service
→ meal_cost_reporting_service
→ cost_analytics_service
→ meal_cost_dashboard_screen


---

## 7.8 Feedback Flow

meal_history
→ meal_feedback_submission_screen
→ meal_feedback_service
→ meal_feedback_dashboard_screen


---

## 7.9 Notification Flow

notification_service
→ notifications_screen
→ notification_badge


---

# 8. MAINTENANCE & BACKUP SYSTEM

Scripts:

- mess_maintenance.sh (daily closeout)
- import_collection.js
- export_collection.js

Backup includes:
- code snapshot
- git push
- project state update

---

# 9. CURRENT DEVELOPMENT SNAPSHOT

Status:

- Architecture stable ✔
- Features implemented ✔
- UI integrated ✔
- Firestore connected ✔

Remaining work:

- Fix rate pipeline
- Fix cost calculation
- Fix feedback eligibility
- Optimize queries
- Stabilize UI states

---

# 10. PHASE 11 — CLOSURE CRITERIA

Phase 11 will close ONLY when:

- No blank screens (rate/cost/feedback)
- Rates correctly applied per meal_type
- Cost dashboard reflects live data
- Feedback works correctly per meal
- Queries optimized (lazy loading)
- Firestore rules secured (production-safe)

---

# 11. WAY FORWARD

## Immediate Actions

1. Validate reservation → rate → cost chain
2. Audit meal_rate_service.dart
3. Fix meal_type propagation everywhere
4. Ensure unit_rate exists for all issued meals
5. Replace eager queries with lazy queries
6. Fix UI empty-state handling

---

## Phase 12 — Pilot Testing

- APK deployment
- Multi-user testing
- Real workflow validation
- Data consistency checks

---

## Phase 13 — Production Launch

- Final rule hardening
- Performance validation
- Deployment closure

---

# 12. RESUME COMMAND (FOR ANY PLATFORM)

Resume **FFL Management Club V1 from Phase 11 hardening checkpoint**.

Focus ONLY on:

- Rate consistency
- Cost calculation integrity
- Feedback linkage
- Query optimization

DO NOT:

- Add new features
- Expand scope
- Modify architecture

---

# ==========================================================
# END OF SNAPSHOT
# ==========================================================

## 📅 Date: 04-04-2026

### ✅ Completed Today:
- Full schema hardening completed across all collections
- Standardized naming conventions across:
  - users
  - employees
  - employee_profiles
  - meal_types
  - food_types
  - menu_items
  - weekly_menu_templates
  - menu_cycles
  - meal_reservations
  - meal_rates
  - meal_feedback
  - events
  - notifications
  - event_attendance_responses
  - event_attendance_summaries
- Removed redundant collection:
  - meal_type_settings (merged into meal_types)
- Converted family_members from subcollection → array inside employee_profiles
- Finalized event attendance model using counts-based structure
- Aligned summaries with responses (strict aggregation model)
- Defined and locked all status vocabularies:
  - reservation_status
  - issue_status
  - rate_status
  - feedback_status
  - response_status
- Locked identity model:
  - menu_item_id vs menu_option_key (mutually exclusive)
  - rate_target_key unified across reservations, rates, feedback
- Eliminated schema drift sources and duplicate definitions

---

### 🔄 Currently Ongoing:
- Transition planning from schema → code alignment
- Identification of service-level inconsistencies causing:
  - blank screens
  - incomplete writes
  - duplicate queries

---

### ⏭ Next Steps:
1. Align Dart models with locked schema
2. Refactor `meal_reservation_service` (highest priority)
3. Fix reservation → issuance → rate → cost → feedback pipeline
4. Remove parallel/duplicate query patterns
5. Standardize empty-state handling (no silent blank screens)
6. Review Firestore indexes after query stabilization

---

### ⚠️ Decisions / Risks:
- Schema is now LOCKED — no further structural changes without full review
- All future changes must respect:
  - controlled vocabularies
  - single source of truth per domain
- Risk of legacy code mismatch with new schema — to be handled module-wise
- Event system diverges intentionally (counts-based vs per-person meals) — acceptable and locked

----------------------------------------------------------
## Update Entry - 06-Apr-2026 02:07

### Completed today:

Phase 11 coding review finalized across all modules
Final framework files reviewed (main.dart, constants, theme)
app_theme.dart corruption identified and fully restored
Flutter analyzer clean (0 issues)
Model layer validation completed (meal_reservation, reservation_settings, meal_booking_request)
UI refinement applied (Creative Team section enhancement)

### Currently ongoing:

Transition from development to structured field testing phase

### Next step:

Execute controlled field testing:
Auth & profile routing
Menu resolver validation
Reservation workflows
Dashboard consistency
Event & notification flow
Analytics sanity checks

### Decisions / risks:

Schema locked — no structural changes allowed
Only targeted fixes based on real field behavior
Resolver remains strictly read-only
Minor parked items (notification badge, identity propagation) deferred to post-field-test stabilization

----------------------------------------------------------
## Update Entry - 07-Apr-2026 00:40

### Completed
- [not provided]

### Ongoing
- [not provided]

### Next
- [not provided]

### Decisions / Risks
- [not provided]

