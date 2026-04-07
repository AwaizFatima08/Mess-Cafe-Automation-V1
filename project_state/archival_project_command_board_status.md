# Mess & Café Automation Platform — Archival Project Log & Historical Snapshot

**Project:** Mess & Café Automation System — Fatima Fertilizer (FFL Management Club)  
**Project Owner:** Dr. Humayun Shahzad  
**Architecture:** Flutter + Firebase Authentication + Cloud Firestore  

---

# 1. PROJECT EVOLUTION SUMMARY

This document captures the **complete historical evolution** of the system from:

Prototype → Feature Expansion → Stabilization → Schema Hardening → Field Testing

---

# 2. DEVELOPMENT TIMELINE (CONSOLIDATED)

## Phase 1 — Foundation ✅
- Flutter app initialized
- Firebase Auth + Firestore integration
- Base navigation and dashboard shell

---

## Phase 2 — Identity & Governance ✅
- Employee master database
- Signup validation
- Approval workflow
- Role-based routing

---

## Phase 3 — Core System Build ✅
- Menu item management
- Weekly template engine
- Monthly menu builder
- Menu cycle engine
- Active menu resolver
- Employee booking
- Dine-in / takeaway
- Future booking
- Cutoff enforcement

---

## Phase 3.7 — Guest Control ✅
- Guest meal booking
- Proxy booking
- Role-restricted overrides

---

## Phase 3.8 — Dashboard Layer ✅
- Reservation dashboards
- Meal summaries
- Segmentation (employee vs guest)
- Source/operator visibility

---

## Phase 4 — Stabilization & Performance ✅
- Query optimization
- Firestore indexing
- Duplicate prevention
- Runtime stability

---

## Phase 5 — Rate Engine ✅
- Manual rate entry
- Item-based costing
- Reservation financial backfill

---

## Phase 5.5 — Cost Reporting ✅
- Daily cost dashboard
- Meal-wise breakdown
- Item-level costing
- Average cost metrics

---

## Phase 6 — Feedback System ✅
- Feedback submission
- Issue tagging
- Dashboard tracking
- Duplicate prevention

---

## Phase 6 Extension — Experience Layer ✅
- Meal history
- Cost visibility
- Inline feedback

---

## Phase 7 — Notification System ✅
- In-app notifications
- Badge system
- Read/unread tracking
- Admin filtering

---

## Phase 8 — Event Module ✅
- Event lifecycle
- Attendance tracking
- Summary aggregation
- XLSX export
- Field validation

---

## Phase 9 — Analytics (PARTIAL / TRANSITIONAL)
- Initial analytics dashboards created
- Cost / feedback / attendance services added
- Later deprioritized in favor of stabilization

---

## Phase 10 — UI & Branding (PARTIAL)
- Branding strategy defined (FFL Management Club)
- Authentication UX finalized
- Performance strategy outlined

---

## Phase 11 — Schema Hardening & Stabilization (ACTIVE)

### Key Milestone:
👉 System transitioned from **feature development → operational validation**

---

# 3. SCHEMA HARDENING (04-Apr-2026)

## Completed:

- Standardized naming across all collections
- Unified identity keys:
  - menu_item_id vs menu_option_key
- Removed redundant collections
- Converted subcollections → structured arrays
- Locked vocabularies:
  - reservation_status
  - issue_status
  - feedback_status
  - response_status

---

## Critical Architectural Lock:

auth.uid  
→ users  
→ employee_number  
→ employees  

⚠️ Immutable identity chain

---

# 4. FIRESTORE STRUCTURE (FINALIZED)

Collections:

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
- events
- notifications
- event_attendance_responses
- event_attendance_summaries

---

# 5. HISTORICAL BOTTLENECKS (NOW RESOLVED)

## Earlier Issues:
- Blank screens (rate / cost / feedback)
- Missing meal_type propagation
- Broken cost pipeline
- Inconsistent rate application
- Query inefficiencies

## Resolution:
- Schema alignment
- Resolver corrections
- Service-layer fixes
- UI empty-state handling

---

# 6. DART FOOTPRINT (HISTORICAL SNAPSHOT)

### Core Areas:
- Admin screens
- Employee screens
- Services layer
- Models
- Widgets
- Constants & themes

### Key Files:
- menu_management_screen.dart
- weekly_menu_template_screen.dart
- meal_reservation_service.dart
- cost_analytics_service.dart
- meal_feedback_service.dart

---
# 16. DART FILE STRUCTURE (PROJECT TREE)

## Root
lib/

---

## 16.1 Core Layer
lib/
├── main.dart  
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   └── reservation_constants.dart
│   └── theme/
│       └── app_theme.dart

---

## 16.2 Admin Module
lib/admin/
├── screens/
│   ├── admin_dashboard_shell.dart
│   ├── dashboard_screen.dart
│   ├── menu_management_screen.dart
│   ├── weekly_menu_template_screen.dart
│   ├── monthly_menu_builder_screen.dart
│   ├── menu_cycle_management_screen.dart
│   ├── active_menu_preview_screen.dart
│   ├── guest_meal_booking_screen.dart
│   ├── employee_master_management_screen.dart
│   ├── user_management_screen.dart
│   ├── meal_rate_management_screen.dart
│   ├── meal_cost_dashboard_screen.dart
│   ├── meal_feedback_dashboard_screen.dart
│   ├── analytics_dashboard_screen.dart
│   └── bulk_upload_screen.dart

---

## 16.3 Employee Module
lib/employee/
├── screens/
│   ├── employee_dashboard_shell.dart
│   ├── employee_dashboard_screen.dart
│   ├── today_menu_screen.dart
│   └── employee_signup_screen.dart

---

## 16.4 Services Layer
lib/services/
├── meal_reservation_service.dart
├── meal_rate_service.dart
├── meal_feedback_service.dart
├── user_profile_service.dart
├── user_role_service.dart
├── employee_identity_service.dart
├── employee_registration_service.dart
├── menu_resolver_service.dart
├── notification_service.dart

---

## 16.5 Analytics Layer
lib/analytics/
├── services/
│   ├── cost_analytics_service.dart
│   └── feedback_analytics_service.dart
├── screens/
│   └── analytics_dashboard_screen.dart

---

## 16.6 Models
lib/models/
├── meal_reservation.dart
├── meal_booking_request.dart
├── meal_option_selection.dart
├── reservation_settings.dart
├── daily_resolved_menu.dart
├── resolved_meal_option.dart
├── event_note_template_model.dart

---

## 16.7 Shared Widgets
lib/widgets/
├── add_menu_item_dialog.dart
├── edit_menu_item_dialog.dart
├── admin_section_placeholder_card.dart
├── notification_badge.dart

---

# 17. MODULE INTERLINKAGE (REFERENCE MAP)

## Startup Flow
main.dart  
→ Firebase Auth  
→ user_profile_service  
→ user_role_service  
→ dashboard shell  

---

## Menu Engine
menu_management_screen  
→ weekly_menu_template_screen  
→ menu_cycle_management_screen  
→ menu_resolver_service  
→ daily menus  

---

## Reservation Flow
today_menu_screen  
→ meal_reservation_service  
→ meal_reservations  

---

## Rate & Cost Flow
meal_rate_management_screen  
→ meal_rate_service  
→ cost_analytics_service  
→ meal_cost_dashboard_screen  

---

## Feedback Flow
today_menu_screen / history  
→ meal_feedback_service  
→ meal_feedback_dashboard_screen  

---

## Notification Flow
notification_service  
→ notification_badge  
→ UI  

---

# 7. SYSTEM INTERLINKAGE (REFERENCE)

## Menu Flow
menu_items → templates → cycles → resolver → daily_menus

## Reservation Flow
UI → reservation_service → meal_reservations

## Cost Flow
reservations → rates → analytics

## Feedback Flow
history → feedback → dashboard

---

# 8. TRANSITION TO FIELD TESTING

## Trigger Point:
06-Apr-2026

System declared:
- Feature complete
- Schema locked
- Analyzer clean

---

# 9. FIELD TESTING MODEL (PHASE 11)

## Definition:
👉 Production Simulation

## Rules:
- No schema changes
- No refactoring
- No feature expansion
- Only bug fixes

---

# 10. FIELD TESTING SEQUENCE

1. Menu Resolution
2. Weekly Templates
3. Reservation Flow
4. Feedback System
5. Analytics
6. Notifications

---

# 11. UPDATE LOGS (PRESERVED)

---

## 29-Mar-2026

### Completed:
- Fixed Firestore indexes
- Timestamp parsing stabilized
- Analytics services validated

### Decision:
- Fetch-all strategy adopted (performance tradeoff accepted)

---

## 30-Mar-2026

### Completed:
- Branding strategy finalized
- Auth UX decisions locked
- Performance optimization strategy defined

---

## 04-Apr-2026

### Completed:
- Full schema hardening
- Naming standardization
- Identity model lock
- Event attendance model finalized

---

## 06-Apr-2026

### Completed:
- Full Dart code review
- Flutter analyzer clean
- Model layer validation
- UI refinement

### Transition:
👉 Entered field testing phase

---

## 07-Apr-2026

### Completed:
- Fixed Firestore typing issues
- Stabilized search (explicit execution model)
- Fixed search UI bugs
- Fixed weekly template filtering
- Enforced meal-type isolation
- Added food type filter
- Added base_unit display

### Ongoing:
- Weekly template validation
- Real data testing

---

# 12. DECISIONS (HISTORICAL + CURRENT)

## Locked Decisions:
- Schema frozen
- Manual costing model retained
- Notifications in-app only (V1)
- Event system separate from meals
- Search explicit (no live filtering)

---

## Parked Decisions:
- food_types admin flow
- meal_types admin control (future super-admin only)
- multi-tenant expansion
- advanced analytics enhancements

---

# 13. RISKS (ARCHIVAL VIEW)

- Legacy data overlap
- Performance under large dataset
- Partial index dependency
- UI state inconsistencies (historically)

---

# 14. CURRENT POSITION (AS OF 07-APR-2026)

System is:

- Feature-complete
- Schema-governed
- Operational
- Under field validation

---

# 15. FORWARD PATH (HISTORICAL + CURRENT)

## Immediate:
- Validate templates
- Build menus
- Validate reservation flow

## Next:
- Pilot deployment (Phase 12)

## Final:
- Production launch (Phase 13)

---

# 16. BACKUP & MAINTENANCE

Command:

bash /home/humayun/projects/mess_cafe_automation_v1/scripts/backup/mess_maintenance.sh

Includes:
- code snapshot
- git sync
- project state update

---

# END OF ARCHIVAL SNAPSHOT
