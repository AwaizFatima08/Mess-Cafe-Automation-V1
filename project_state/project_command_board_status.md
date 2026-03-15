# Mess & Café Automation Platform - Live Project Command Board

_Last updated: 15-Mar-2026_

## 1) Completed Development
- Foundation: Flutter, Firebase, Firestore, device deployment, Git repository, cloud project
- Authentication: login, logout, Firebase email/password
- Admin shell and core admin navigation completed
- Menu management module completed
- Weekly menu template builder completed
- Menu cycle management completed
- Menu resolver engine created and operational
- Firestore connectivity and live data binding verified on tablet
- Project maintenance baseline: NAS backup scripts, Git push workflow, updated markdown state files
- Firestore CSV import/export toolkit created in `firebase_tools`
- Menu item bulk upload completed successfully
- Employee bulk upload completed successfully

## 2) Ongoing Development
- Role and permission framework refinement
- Dashboard architecture design for employee, admin, developer, café manager, and mess/club roles
- Weekly template data model upgrade to support `item_id + item_mode`
- Production-grade Firestore schema refinement and controlled dropdown collections
- Reservation and billing workflow planning

## 3) Next Verified Steps
- [x] Admin dashboard shell
- [x] Employee bulk upload
- [x] Menu item bulk upload
- [x] Weekly menu template builder
- [x] Menu cycle creation and save
- [x] Menu resolver service creation
- [ ] Controlled dropdown master collections
- [ ] Weekly template structure upgrade (`item_id` + `item_mode`)
- [ ] Resolver update for `item_mode`
- [ ] Employee Today's Menu screen
- [ ] Reservation / attendance booking flow for breakfast, lunch, dinner
- [ ] Admin reservation summary dashboard
- [ ] Kitchen / mess operations dashboard
- [ ] Café manager dashboard
- [ ] Developer dashboard
- [ ] Monthly billing generation with inclusive vs optional logic
- [ ] Reports and analytics

## 4) Version 1 Locked Scope
### 4.1 Operational scope
- Mess system only
- Breakfast, lunch, dinner
- Employee-wise menu visibility
- Meal reservation / attendance booking
- Manual and bulk upload for employees and menu items
- Weekly templates and menu cycle based menu engine
- Employee/customer phone number captured in profile
- Employee interface, admin interface, manager dashboard, kitchen/mess operations interface
- Estimated rate handling for menu items
- Billing foundation for inclusive vs optional items

### 4.2 Business rules
- Users can self-create an account if not yet in the database, subject to later approval logic if adopted
- Menu planning is controlled through weekly templates and menu cycles
- Same menu item may be inclusive in one context and optional in another
- Therefore `item_mode` will not be stored in `menu_items`; it will be assigned during menu building
- Rates remain estimated until recipe-costing and purchase-costing are introduced in later versions
- Admin and Developer can create/suspend users, add menu items, and change rates

## 5) Parking Lot / Future Ideas
### Versioned roadmap
- V2: Café management
- V3: Tuck shop management
- V4: Bakery management
- V5: Inventory / bulk store
- V6: Purchase management
- V7: Recipe and service costing
- V8: Event management
- V9: Automated billing
- V10: Email / WhatsApp push messaging
- V11: Asset management

## 6) Verification Log
| Date | Module | What was verified | By | Result | Notes |
|---|---|---|---|---|---|
| 14-Mar-2026 | Foundation | Flutter/Firebase/Menu display | Dr. Humayun | Pass | Stable baseline |
| 14-Mar-2026 | Admin Module | Admin dashboard shell, menu screens, template flow | Dr. Humayun | Pass | Core admin structure functioning |
| 14-Mar-2026 | Menu Cycle Engine | Menu cycle saved successfully | Dr. Humayun | Pass | Cycle persistence working |
| 14-Mar-2026 | Menu Resolver | Resolver service created | Dr. Humayun | Pass | Backend menu planning logic operational |
| 15-Mar-2026 | Bulk Upload Framework | CSV export/import pipeline | Dr. Humayun | Pass | Firestore ↔ CSV workflow established |
| 15-Mar-2026 | Master Data | menu_items bulk upload | Dr. Humayun | Pass | 92 items uploaded and visible in app |
| 15-Mar-2026 | Master Data | employees bulk upload | Dr. Humayun | Pass | 311 employees uploaded successfully |

## 7) Change Notes
- `menu_items` is now treated as a master catalog only.
- `item_mode` will be assigned during weekly template / menu-building stage.
- Employee master schema refined and bulk imported.
- Current employee fields include:
  - `docId`
  - `prefix`
  - `employee_number`
  - `name`
  - `department`
  - `designation`
  - `grade`
  - `house_type`
  - `house_number`
  - `status`
  - `landline_extension`
  - `phone_number`
  - `user_role`
- Locked prefix values:
  - `FFL`, `PFL`, `FFT`, `FAS`, `OSL`, `ESB`
- Locked grade values:
  - `MT-1` to `MT-6`
  - `M-6`, `M-7`, `M-8`, `M-9`, `M-9A`, `M-10`, `M-11`, `M-12`, `M-12A`, `M-13`
- Locked house types:
  - `A`, `B`, `B-Modified`, `C`, `D`, `D-Modified`, `E`, `EM`, `MOQ`, `BOQ`
- House number range planned as dropdown:
  - `1` to `150`
- Role direction confirmed:
  - `employee`
  - `mess_staff`
  - `admin`
  - `super_admin`
  - `developer`
- Designation and user role will remain separate concepts.
- Future interface planning confirmed for:
  - Employee dashboard
  - Admin dashboard
  - Developer dashboard
  - Café manager dashboard
  - Mess / club role dashboards
---

## 8) Future System Expansion Roadmap

The Mess & Café Automation Platform is designed to evolve into a **complete hospitality and facility management ecosystem** for Fatima Fertilizer Club and related facilities.

The following modules are planned for future versions beyond Version 1.

### 8.1 Café Management Module
Expansion of the current mess system to support café operations.

Planned features:
- café product catalog
- barista order terminal
- POS-style ordering interface
- quick billing
- optional item purchases
- employee and guest billing
- sales reporting

---

### 8.2 Bakery Management Module
Dedicated module for bakery production and sales.

Planned features:
- bakery product catalog
- batch production planning
- daily baking schedules
- expiry tracking
- bakery sales tracking
- event-based bakery orders

---

### 8.3 Tuck Shop / Convenience Store Module
Management of tuck shop or small retail outlets within the club.

Planned features:
- retail product catalog
- barcode/quick item selection
- POS sales interface
- stock tracking
- retail sales reporting

---

### 8.4 Event Management Module
Management of club events and catering.

Planned features:
- event booking
- hall reservation
- menu selection for events
- guest count tracking
- event billing
- coordination with kitchen and bakery

---

### 8.5 Procurement Management Module
Centralized purchasing and vendor coordination.

Planned features:
- supplier database
- purchase order generation
- approval workflow
- delivery tracking
- price history and supplier comparison

Future capability:

Automatic purchase order generation based on:

- menu plans
- recipe consumption
- inventory thresholds

---

### 8.6 Inventory Management Module
Warehouse and kitchen stock management.

Planned features:
- ingredient stock tracking
- warehouse and kitchen store separation
- stock movement logs
- stock alerts and reorder levels
- stock valuation reports

---

### 8.7 Accounts and Billing Module
Financial integration for operations.

Planned features:
- employee meal billing
- optional item billing
- café sales accounting
- event billing
- departmental reports
- export to accounting systems

---

### 8.8 Recipe-Based Costing Module
Advanced cost control system for food production.

Planned features:
- recipe definition
- ingredient quantity mapping
- cost calculation per dish
- cost vs selling price analysis
- profitability analysis
- integration with procurement and inventory modules

This module will later enable **automatic cost estimation and dynamic pricing support**.

---

### Long-Term Vision

The platform will gradually evolve from a **mess automation tool** into a **fully integrated hospitality and facility management system** covering:

- mess
- café
- bakery
- tuck shop
- events
- procurement
- inventory
- financial billing
- operational analytics

# Mess & Café Automation V1 — Project Command Board Status
## Update: 16-Mar-2026

### Milestone Reached
Menu Engine Upgrade and Admin Review Controls completed.

### Completed Today
- Upgraded weekly menu template structure from plain item ID arrays to structured entries:
  - `item_id`
  - `item_mode`
- Updated `menu_resolver_service.dart` to support:
  - old weekly template format
  - new weekly template format
  - old menu cycle field names
  - new menu cycle field names
- Weekly Menu Templates screen upgraded:
  - Create / Edit tab added
  - Saved Templates tab added
  - Edit existing templates working
  - Activate / deactivate templates working
  - Floating scroll buttons added and working
- Menu Cycle Management screen upgraded:
  - Create / Edit tab added
  - Saved Cycles tab added
  - Review existing cycles working
  - Edit existing cycles working
  - Activate / deactivate cycle working
- Active Menu Preview screen added to admin dashboard
- Consolidated preview now shows:
  - Breakfast
  - Lunch Combo 1
  - Lunch Combo 2
  - Dinner Combo 1
  - Dinner Combo 2

### Current Stable State
Admin-side menu foundation is now operational end-to-end:
- menu items
- weekly templates
- menu cycles
- resolver
- active menu preview

### Remaining Next Priorities
1. Add compact daily summary preview for saved templates
2. Add compact preview for saved menu cycles
3. Improve debug-session stability / observe disconnect behavior
4. Begin employee-facing "Today's Menu" screen
5. Start reservation engine after employee menu is visible

### Important Architecture Notes
- `item_mode` is stored in weekly template entries, not in `menu_items`
- cycle field naming standard going forward:
  - `breakfast_template_id`
  - `lunch_combo_1_template_id`
  - `lunch_combo_2_template_id`
  - `dinner_combo_1_template_id`
  - `dinner_combo_2_template_id`
- backward compatibility retained in resolver for earlier saved cycles/templates

### Current Package Name
`com.fatimafertilizer.employee_flutter_app`
