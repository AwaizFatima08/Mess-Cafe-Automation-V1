# MESS & CAFÉ AUTOMATION V1 — MASTER PROJECT SNAPSHOT (POST PHASE 8 LOCK)

**Project Owner:** Dr. Humayun Shahzad  
**Organization:** Fatima Fertilizer  
**System Name:** Mess & Café Automation System  
**Current Position:** Post Phase 8 complete, preparing for Phase 9  
**Snapshot Purpose:** Canonical reference baseline for all future continuity, planning, and phase-wise snapshots

---

## 1. Project Identity

Mess & Café Automation System — Fatima Fertilizer

### Version 1 Scope (Locked)
Mess operations only:
- Breakfast
- Lunch
- Dinner

### Version 1 Operating Principles
- Employee self-service booking
- Role-based admin/supervisor control
- Manual operational governance where required
- Manual rate entry for costing
- In-app notification engine
- Event attendance module independent of meal reservation flow
- Firebase/Firestore cloud-first architecture

### Future Expansion Path
- Café
- Retail / tuck shop
- Bakery / BBQ workflows
- Procurement
- Inventory
- Finance / billing automation
- Governance layer
- Commercial multi-tenant architecture

---

## 2. Current System State

### System Classification
**FUNCTIONAL + GOVERNED + FIELD-VALIDATED + EVENT-ENABLED + READY FOR ANALYTICS CONSOLIDATION**

This system is no longer a raw prototype.  
It is now a controlled, operational, modular application with stable business flow and validated cross-module linkage.

### Current Maturity
- Core identity and access model stabilized
- Reservation engine mature
- Rate engine live
- Cost dashboard live
- Feedback loop live
- Notification system live
- Event attendance system live
- Event report export live
- Admin and employee workflows field tested

---

## 3. Locked Architecture

### Identity Model
- `uid` = system identity
- `employee_number` = business identity

### Critical Linkage Rule
- `employees.employee_number ↔ users.employee_number`

This linkage is critical and must never be broken.

### System Backbone
Menu  
→ Reservation  
→ Issuance / consumption  
→ Rate application  
→ Cost reporting  
→ Feedback  
→ Notifications  
→ Event attendance (parallel independent module)  
→ Reporting / analytics layer

### Design Rule
Transactional truth must remain separate from analytical views.

---

## 4. Current Firestore Footprint

### Core Collections
- `employees`
- `users`
- `menu_items`
- `daily_menus`
- `weekly_menu_templates`
- `meal_reservations`
- `meal_rates`
- `meal_feedback`
- `notifications`
- `notification_deliveries`

### Event Collections
- `events`
- `event_attendance_responses`
- `event_attendance_summaries`
- `event_note_templates`

### Architecture Notes
- Event attendance is intentionally independent from meal reservation logic
- Notification engine is reused by event module
- Event summary supports incremental update with fallback rebuild path
- Export format for Phase 8 event reporting is XLSX

---

## 5. Phase-Wise Development Status

## Phase 1 — Foundation ✅
Completed:
- Flutter app base
- Firebase integration
- Firebase Authentication
- Base admin/employee navigation
- Firestore connectivity

## Phase 2 — Identity & Governance Alignment ✅
Completed:
- Employee master concept established
- Signup validation against employee records
- Approval workflow
- Role assignment and role enforcement
- User identity alignment with business identity

## Phase 3 — Menu & Reservation Core ✅
Completed:
- Menu item management
- Weekly template engine
- Monthly menu builder
- Menu cycle handling
- Daily/active menu resolution
- Employee meal booking
- Future booking
- Dine-in / takeaway
- Quantity handling
- Cutoff enforcement

### Phase 3.7 — Guest / Proxy Workflow ✅
Completed:
- Guest booking by controlled roles
- Proxy booking support
- Reservation traceability
- Role-controlled overrides

### Phase 3.8 — Operational Dashboard ✅
Completed:
- Admin dashboard operational visibility
- Meal-wise summary
- Issued / pending / cancelled tracking
- Employee vs guest segmentation
- Dine-in vs takeaway visibility
- Operator / source visibility

## Phase 4 — Stabilization & Performance ✅
Completed:
- Query optimization
- Date-scoped Firestore reads
- Caching improvements
- Issuance workflow hardening
- Duplicate issuance prevention
- Issued state validation
- Composite index alignment
- Runtime bottlenecks resolved

## Phase 5 — Rate Engine ✅
Completed:
- Manual rate entry
- Previous-day actual costing model
- Item-level rate application
- Combo treated as item
- Reservation backfill:
  - `unit_rate`
  - `amount`

## Phase 5.5 — Cost Reporting ✅
Completed:
- Daily cost dashboard
- Meal-wise costing
- Item-wise costing
- Employee vs guest split
- Average cost per unit
- Rated vs unrated visibility

## Phase 6 — Feedback System ✅
Completed:
- Meal feedback submission
- Rating capture
- Issue tagging
- Anonymous option
- Open / close workflow
- Feedback dashboard
- Item-level analysis
- Duplicate prevention
- Employee-side feedback from meal history

## Phase 6 Extension — Employee Experience Layer ✅
Completed:
- My meal history screen
- Monthly consumption visibility
- Cost visibility
- Line-level details
- Inline feedback trigger

## Phase 7 — Notification System ✅
Completed:
- Event-driven in-app notification engine
- Two-layer model:
  - transactional
  - administrative
- Booking confirmation notification
- Booking cancellation notification
- Meal issuance notification
- Administrative announcement pipeline
- Notification badge
- Notification history screen
- Read/unread tracking
- Admin notification history filtering

### Phase 7 Deferred Items
Deferred intentionally:
- Email delivery
- Push notification delivery
- Retry logic
- Expiry / archival logic

## Phase 8 — Event Attendance Module ✅
Completed:
- Event Firestore schema
- Event models
- Attendance response model
- Summary model
- Note template model
- Event attendance service
- Admin event management screen
- Employee event invitation detail screen
- Employee event dashboard widget
- Notification routing to event detail
- Cutoff enforcement
- Edit/update until cutoff
- Pending and report views
- Incremental summary updates
- Rebuild fallback retained
- XLSX export
- Field testing completed

---

## 6. Current Functional Footprint

### Identity & Governance
- Employee master management
- User registration validation
- Approval and role assignment
- Role-based navigation

### Menu & Scheduling
- Menu item creation
- Weekly template design
- Monthly menu building
- Active menu preview
- Menu resolution engine

### Reservation Operations
- Employee booking
- Guest booking
- Proxy booking
- Future booking
- Dine-in / takeaway
- Quantity
- Cutoff enforcement
- Reservation status lifecycle
- Issuance workflow

### Financial Layer
- Manual rate entry
- Rate backfill to reservations
- Amount calculation
- Daily cost dashboard

### Feedback Layer
- Meal feedback capture
- Dashboard analytics
- Inline employee feedback from history

### Notification Layer
- In-app notifications
- Badge count
- Transactional and administrative routing

### Event Layer
- Event creation
- Publish / close / cancel
- Employee event response
- Category-wise attendance counts
- Event reporting and export

---

## 7. Canonical Dart File Inventory (Live)

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

## 9. Current Known Design Decisions (Locked)

- Event attendance remains independent from meal reservation logic
- `userUid` in employee flow comes from FirebaseAuth current user
- Manual rate entry remains the costing method in V1
- Notifications in V1 are in-app only
- Email and push remain deferred
- Transactional truth stays in transactional collections
- Event summary remains incremental with rebuild fallback retained
- Export format currently prioritized as XLSX
- Role routing and governance must remain controlled and explicit
- No procurement automation in V1
- No billing automation in V1
- Multi-tenant thinking should guide future architecture, but not complicate V1 unnecessarily

---

## 10. Current Risks / Controlled Limitations

### Accepted / Intentional
- In-app only notifications
- No push/email dispatch engine yet
- No automated archival/expiry of notifications
- No deep analytics orchestration layer yet
- Reporting remains domain-fragmented
- `reports_screen.dart` has not yet been fully elevated to unified analytics dashboard
- No pre-aggregated analytics collections except event summaries
- Cost analytics currently daily-focused rather than full range/trend capable

### Operational Notes
- Phase 8 is stable enough to serve as reporting/analytics design baseline
- Existing domain modules should be reused, not rewritten

---

## 11. Phase 9 — Planned Development (Detailed)

# Phase 9 Objective
Convert separate reporting modules into a unified management reporting and analytics layer.

## Phase 9 Positioning
Phase 9 is **not** the first reporting feature.  
Phase 9 is the **consolidation and orchestration phase**.

## Phase 9A — Analytics Foundation
Planned:
- analytics filter model
- dashboard KPI model
- trend point models
- unified analytics orchestration service
- attendance analytics service
- cost analytics service
- feedback analytics service
- event analytics service
- analytics export service

### Proposed New Models
- `analytics_filter_model.dart`
- `dashboard_kpi_model.dart`
- `attendance_trend_point.dart`
- `cost_trend_point.dart`
- `feedback_trend_point.dart`
- `event_trend_point.dart`

### Proposed New Services
- `analytics_service.dart`
- `attendance_analytics_service.dart`
- `cost_analytics_service.dart`
- `feedback_analytics_service.dart`
- `event_analytics_service.dart`
- `analytics_export_service.dart`

## Phase 9B — Unified Reporting Dashboard
Primary target:
- upgrade `reports_screen.dart` into unified management dashboard

Planned sections:
- date range filter
- grouping selector (day / week / month)
- KPI cards
- attendance summary
- cost summary
- feedback insight summary
- event participation summary
- drill-down entry cards to detailed screens

## Phase 9C — Trend & Comparison Layer
Planned:
- daily / weekly / monthly trend data
- guest vs employee comparisons
- dine-in vs takeaway comparisons
- booking vs issuance conversion
- cost per head
- low-rating frequency
- event response trend

## Phase 9D — Export Standardization
Planned:
- consolidated management workbook
- attendance export
- cost export
- feedback export
- event export integration
- standardized XLSX export structure

## Phase 9E — Performance Review
Planned only if required:
- identify slow queries
- session caching where useful
- daily summary collections only if performance demands them

---

## 12. Planned Development to End of Version 1

## Phase 9 — Reporting & Analytics Consolidation
See full Phase 9 plan above.

## Phase 10 — UI Refinement & Branding
Planned:
- logo integration
- splash / launch visuals
- visual consistency pass
- spacing / card polish
- typography cleanup
- final cosmetic harmonization

## Phase 11 — Security & Stability Hardening
Planned:
- tighten Firestore rules
- role enforcement review
- validation review
- error handling standardization
- final production hardening

## Phase 12 — Controlled Test Version
Planned:
- limited rollout
- monitored usage
- defect logging
- issue correction
- user acceptance validation

## Phase 13 — Production Launch (V1 Complete)
Planned:
- stable deployment
- controlled live use
- closeout of V1 scope
- handoff to operational governance

---

## 13. Post V1 Roadmap

## Version 2
Operational expansion:
- Weekly BBQ
- Café
- Tuck shop
- Bakery

Reuse expected from V1:
- identity
- menu items
- menu templates
- cycle engine
- notifications
- rates where applicable

## Version 3
Operational backend:
- Procurement
- Purchase tracking
- Stock movement
- Inventory controls

## Version 4
Costing intelligence:
- Recipe-based costing
- ingredient linkage
- operational costing refinement

## Version 5
Financial automation:
- Finance integration
- automated monthly billing
- ledger logic
- payroll/accounting linkage if later approved

## Version 6
Broader hospitality/event layer:
- Event management expansion
- event booking
- catering workflows
- event billing
- operational hospitality controls

## Commercialization Direction
The project should remain aligned toward:
- organization-level isolation
- future multi-tenant architecture
- SaaS-ready separation of data domains
- no data mixing between organizations in later versions

---

## 14. Current Strategic Position

This system is now:
- architecture-driven
- governance-controlled
- modular
- cloud-first
- expandable
- commercialization-aware

Current reality:
- strong operational base exists
- business logic chain is functioning
- analytics consolidation is the next major milestone
- project is approaching V1 tail, but still requires disciplined finish

---


## 16. Snapshot Lock Statement

This document is the new canonical project baseline.  
Older snapshots remain useful as historical references, but future planning should now anchor to this document unless replaced by a later master snapshot.

