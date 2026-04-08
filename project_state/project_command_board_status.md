# Mess & Café Automation Platform — Consolidated Command Board & Project Snapshot

**Project:** Mess & Café Automation System — Fatima Fertilizer (FFL Management Club)  
**Project Owner:** Dr. Humayun Shahzad  
**Architecture:** Flutter + Firebase Authentication + Cloud Firestore  
**Last Updated:** 07-Apr-2026  

---

# 1. STRATEGIC POSITION

The system has evolved from a prototype into a:

- modular
- governed
- operational
- scalable
- commercialization-ready platform

👉 Current focus is NOT feature development  
👉 Current focus is **system validation under real usage**

---

# 2. CURRENT SYSTEM STATE

## STATUS:
**FEATURE-COMPLETE + SCHEMA-LOCKED + UNDER CONTROLLED FIELD TESTING**

### System Characteristics:
- Schema: LOCKED & ALIGNED
- Flutter: Analyzer clean (0 issues)
- Core flows: Functionally working
- UI: Stabilized
- Data layer: Normalized (legacy overlap handled via resolvers)

---

# 3. CORE MODULE STATUS

## ✅ VALIDATED MODULES

### Identity & Governance
- Firebase authentication
- Employee master linkage
- Signup validation
- Role-based routing
- Authorization workflows

### Employee Master
- Data loading stable
- Name resolution fixed (`full_name` fallback)
- Search implemented:
  - employee number
  - name
  - email
  - CNIC last 4 digits

---

## 🔄 UNDER FIELD VALIDATION

### Menu System
- Menu item management ✔
- Weekly template engine ✔
- Menu cycle + resolver ✔
- Active menu generation ✔

### Weekly Template Engine
- Meal-type isolation ✔
- Food-type filtering ✔
- Search within selection ✔
- Template save/edit ✔
- Duplicate item handling via `base_unit` ✔

---

## ⏳ PENDING VALIDATION

### Reservation Flow
- Employee booking
- Guest / proxy booking
- Dine-in / takeaway logic
- Option selection integrity

### Feedback System
- Submission eligibility
- Duplicate prevention
- Dashboard consistency

### Analytics Dashboard
- Meal counts
- Cost reporting
- Feedback aggregation
- Cross-validation with raw data

### Notification System
- Event triggers
- Delivery visibility
- Badge indicators

---

# 4. SYSTEM ARCHITECTURE SNAPSHOT

## Core Identity Chain (LOCKED)

auth.uid  
→ users  
→ employee_number  
→ employees  

⚠️ Critical — must not be altered

---

## Firestore Collections

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

## Core Functional Flows

### Menu Engine
menu_items  
→ weekly_menu_templates  
→ menu_cycles  
→ menu_resolver_service  
→ daily_menus  

---

### Reservation Flow
today_menu_screen  
→ meal_reservation_service  
→ meal_reservations  

---

### Cost Flow
meal_reservations  
→ meal_rates  
→ cost_analytics_service  
→ dashboards  

---

### Feedback Flow
meal_history  
→ meal_feedback_service  
→ feedback dashboard  

---

### Notification Flow
notification_service  
→ notification UI  

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

# 5. CURRENT FIELD TESTING MODE

## Testing Philosophy:
👉 **Production Simulation**

### Approach:
- One issue → isolate → fix → verify → move forward
- No assumptions
- No batch fixing

---

## Discipline Rules (STRICT)

❌ No schema changes  
❌ No refactoring  
❌ No feature expansion  

✔ Only bug fixes  
✔ Only targeted usability improvements  

---

# 6. CURRENT KNOWN SYSTEM CHARACTERISTICS

### Multi-field name handling (temporary)
- display_name
- employee_name
- name
- full_name (legacy)

👉 Resolver implemented  
👉 Cleanup deferred

---

### Mixed legacy + normalized data
Collections affected:
- menu_items
- employees
- meal_feedback

👉 Backward compatibility maintained  
👉 No immediate risk  

---

### Firestore indexes
- Being created dynamically  
- No blocking issues  

---

### Performance
- Acceptable for current dataset  
- Large-scale testing pending  

---

# 7. ACTIVE RISKS (CONTROLLED)

| Area | Status |
|------|--------|
| Legacy schema overlap | Controlled via resolvers |
| Null timestamps | Present in old records |
| Performance | Acceptable, monitor |
| Data consistency | Under validation |

---

# 8. SHORT-TERM DECISIONS (LOCKED)

- Search is **explicit only** (no live filtering)
- Filters reset on meal-type change
- `base_unit` used for item differentiation
- Menu filtering strictly based on:
  - available_meal_types
  - is_active
  - is_visible
- Field testing discipline strictly enforced

---

# 9. LONG-TERM DECISIONS (PARKED)

### Food Types
- Admin flow required
- Deferred until post field testing

### Meal Types
- No regular admin access
- Future **super-admin configuration only**
- Structural layer (not operational data)

### Future Enhancements
- Base item + variants model
- Serving size filters
- Advanced analytics based on unit types
- Multi-tenant architecture expansion

---

# 10. CURRENT EXECUTION PHASE

## Phase 11 — Controlled Field Testing

### Validation Sequence:

1. Menu Resolution Engine 🔄
2. Weekly Template Engine 🔄
3. Reservation Flow ⏳
4. Feedback System ⏳
5. Analytics Dashboard ⏳
6. Notification System ⏳

---

## Phase 11 Closure Criteria:

- No blank screens
- Menu → Template → Resolver stable
- Reservation → Rate → Cost chain validated
- Feedback correctly linked per meal
- Analytics consistent across modules
- Notification system stable
- UI stable under repeated usage

---

# 11. NEXT PHASES

## Phase 12 — Pilot Deployment
- APK rollout
- Multi-user testing
- Real workflow validation

## Phase 13 — Production Launch
- Security hardening
- Performance validation
- Deployment closure

---

# 12. MAINTENANCE & BACKUP

### Backup Command:
```bash
bash /home/humayun/projects/mess_cafe_automation_v1/scripts/backup/mess_maintenance.sh

----------------------------------------------------------
## Update Entry - 08-Apr-2026 01:47

## Phase 11 – Final Validation Progress (Date: 08-Apr-2026)

### Status
Phase 11 is in final field testing stage. Core modules validated and stabilized. System is functionally operational with targeted fixes implemented.

### Completed Validations
- Menu creation, resolver, and employee display validated
- Reservation flows (employee, guest, proxy) validated
- Issuance flow working with row-level loading optimization
- Feedback system simplified and validated
- Meal rate entry, costing, and analytics validated
- Notifications working for booking lifecycle

### Fixes Implemented
- Restored event module in admin sidebar
- Implemented row-level issuance loading state
- Simplified feedback UI (single rating model)
- Optimized meal rate bulk save (dirty tracking + batch updates)
- Identified and prepared fix for breakfast special item display (base_unit inclusion)

### Pending Field Validation
- Event module full lifecycle (create → publish → response)
- Meal rate bulk save performance under larger dataset
- Feedback end-to-end validation (submission → dashboard)
- Breakfast special item display clarity (name + base_unit)

### Decisions Locked
- No schema changes during field testing
- No refactoring or feature expansion
- Feedback category retained only in schema, removed from UI
- Batch update strategy for performance optimization
- Field testing treated as production simulation

### Next Steps
- Execute full field testing scenarios
- Validate pending fixes
- Identify and isolate remaining defects
- Prepare Phase-11 closure


----------------------------------------------------------
## Update Entry - 09-Apr-2026 01:17

### Completed
- [not provided]

### Ongoing
- [not provided]

### Next
- [not provided]

### Decisions / Risks
- [not provided]

