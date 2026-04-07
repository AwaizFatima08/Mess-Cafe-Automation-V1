## 2. Project Evolution Journey

This project represents a first-generation system built from scratch with evolving understanding of:

- system design
- database modeling
- workflow orchestration
- application layering

The development did not follow a strictly pre-defined architecture from the beginning. Instead, it evolved through iterative implementation, correction, and eventual stabilization.

---

### Phase 1–3: Initial Build (Exploratory Development)

The system began with:

- Flutter-based UI structure
- Firebase integration
- Basic menu and reservation workflows

At this stage:

- Scope was not fully finalized
- Database structure was evolving dynamically
- Features were added based on immediate needs

This resulted in:

- rapid visible progress
- but weak foundational structure

---

### Phase 3–8: Expansion Phase (Feature Growth)

During this phase, multiple modules were added:

- guest booking
- dashboards
- rate engine
- cost reporting
- feedback system
- notifications
- event module

Key characteristic of this phase:

👉 **Feature velocity was high, but architectural control was low**

New features were often added based on:

- operational enthusiasm
- stakeholder requests
- perceived completeness requirements

This created:

- strong individual modules
- but weak inter-module consistency

---

### Critical Realization (Post Phase 8–10)

After building most modules, a major issue became evident:

> “Individual modules were working fine, but integration was poor.”

Key symptoms:

- data inconsistencies across modules
- broken linkage between:
  - reservations
  - rates
  - cost analytics
  - feedback
- blank screens due to mismatched queries
- difficulty in debugging due to inconsistent schema

This marked the transition point from:

👉 **Feature Development → System Correction**

---

### Phase 10–11: Stabilization & Hardening

At this stage:

- full schema was redesigned and locked
- naming conventions standardized
- identity chain finalized
- resolver-based approach introduced
- duplicate and legacy patterns removed

System transitioned into:

👉 **Controlled, governed architecture**

---

### Phase 11: Field Testing (Current State)

The system is now:

- feature complete
- schema locked
- analyzer clean

Development focus has shifted to:

- real workflow validation
- data integrity verification
- system behavior under usage

This phase operates under strict discipline:

- no schema changes
- no refactoring
- no feature expansion
- only bug fixes based on observed behavior

---

### Evolution Summary

The system evolved through:

1. exploratory development  
2. uncontrolled feature expansion  
3. integration failure realization  
4. architectural correction  
5. controlled stabilization  
6. production-simulation validation  

This journey provides critical insights for rebuilding the system in a cleaner, structured way.

## 3. Key Learnings & Critical Mistakes

This project highlighted several foundational mistakes that significantly impacted development time, system stability, and rework effort.

These lessons form the basis of the rebuild strategy.

---

### 3.1 Lack of Initial Planning

#### Issue:
- No complete scope definition at project start
- No structured design or position paper
- No identification of required tools and architecture

#### Impact:
- Frequent rework
- inconsistent implementation patterns
- unclear system boundaries

#### Learning:
👉 A system must be designed **on paper first**, before writing code

---

### 3.2 No Database Design Understanding (Firestore)

#### Issue:
- No prior understanding of Firestore structure
- Schema evolved dynamically during development
- Inconsistent field naming across collections

#### Impact:
- severe integration issues later
- query mismatches across modules
- data inconsistency
- blank screens in dashboards

#### Learning:
👉 Database schema must be:
- designed upfront
- normalized
- consistently named

Firestore flexibility does NOT eliminate the need for structure

---

### 3.3 Schema Inconsistency

#### Issue:
- same concepts represented with different field names
- lack of controlled vocabulary
- no unified identifiers across modules

#### Impact:
- broken pipelines:
  - reservation → rate → cost → feedback
- complex debugging
- fragile queries

#### Learning:
👉 Schema consistency is more important than feature completeness

---

### 3.4 Scope Drift (Uncontrolled Feature Addition)

#### Issue:
- features added mid-development based on enthusiasm and requests
- no version boundary control
- no feature freeze discipline

#### Impact:
- delayed stabilization
- integration breakdown
- increased complexity
- rework across multiple modules

#### Learning:
👉 Once a version scope is defined:
- it must be frozen
- new ideas go to **next version backlog**

---

### 3.5 Poor Integration Planning

#### Issue:
- modules developed independently
- no end-to-end workflow validation during development

#### Impact:
- modules worked individually
- system failed as a whole

#### Learning:
👉 Always validate:
- data flow across modules
- not just module functionality

---

### 3.6 Absence of Core Position Paper

#### Issue:
- no formal document defining:
  - system purpose
  - architecture
  - constraints
  - scope boundaries

#### Impact:
- design decisions changed over time
- lack of alignment

#### Learning:
👉 Every system must begin with:
- a **core position document**
- a **command board**

---

### 3.7 Late Realization of Architecture Importance

#### Issue:
- architecture was not enforced early
- layering (UI / service / data) evolved later

#### Impact:
- inconsistent service usage
- duplicate logic
- refactoring effort in later phases

#### Learning:
👉 Architecture must be:
- defined early
- enforced strictly

---

### 3.8 Summary of Key Lessons

- Plan completely before starting
- Freeze scope for each version
- Design schema before writing code
- Maintain naming consistency across all collections
- Validate system flows, not just screens
- Separate:
  - UI
  - business logic
  - data layer
- Avoid mid-development feature expansion

---

### Final Reflection

> “If this system were to be built again, the entire structure would be designed first — both in mind and on paper — before writing a single line of code.”

This insight forms the foundation for the clean rebuild strategy.

## 4. Clean System Architecture (Final Design)

This section defines the **ideal architecture of the system**, derived from lessons learned during development.

It represents the **target structure for rebuild (V2)**.

---

# 4.1 Architectural Principles

The system must follow these core principles:

### 1. Separation of Concerns
- UI (Screens)
- Business Logic (Services)
- Data Layer (Firestore)

👉 No mixing responsibilities

---

### 2. Single Source of Truth
Each domain must have:
- one authoritative collection
- one consistent identifier

---

### 3. Schema First Approach
- Database schema must be finalized before coding
- No dynamic field creation during development

---

### 4. Controlled Vocabulary
All status and type fields must be:
- predefined
- consistent across collections

---

### 5. Resolver-Based Read Model
- Raw data is never directly used in UI
- Resolver services create **final usable objects**

---

### 6. Version Discipline
- Scope frozen per version
- New features go to next version

---

# 4.2 System Layering

The system is divided into 3 layers:

---

## 4.2.1 Presentation Layer (UI)

Location:
```plaintext
lib/admin/screens/
lib/employee/screens/

Responsibilities:
handle all business logic
manage Firestore reads/writes
enforce rules
transform data
Examples:
meal_reservation_service
meal_rate_service
menu_resolver_service
4.2.3 Data Layer (Firestore)
Responsibilities:
store normalized data
maintain relationships via IDs
remain schema-consistent
4.3 Core Identity Model (LOCKED)
auth.uid
   ↓
users (auth mapping)
   ↓
employee_number
   ↓
employees (master record)
Rules:
uid = system identity
employee_number = business identity

⚠️ This chain must NEVER be altered

4.4 Core Domains & Data Model
4.4.1 Menu Domain
Collections:
menu_items
weekly_menu_templates
menu_cycles
daily_menus
Flow:
menu_items
→ weekly_menu_templates
→ menu_cycles
→ menu_resolver_service
→ daily_menus
menu_items
item_Id
name
food_type
available_meal_types
base_unit
estimated_price
is_active
is_visible
weekly_menu_templates
template_id
template_name
weekday
meal_type
item_ids[]
menu_cycles
date
template_id
meal_type
daily_menus (resolved)
date
meal_type
final menu options
4.4.2 Reservation Domain
Collection:
meal_reservations
Flow:
UI → meal_reservation_service → meal_reservations
Key Fields:
employee_number
date
meal_type
menu_item_id
quantity
reservation_status
service_mode (dine-in / takeaway)
4.4.3 Rate & Cost Domain
Collections:
meal_rates
Flow:
meal_reservations
→ meal_rates
→ cost_analytics_service
Key Fields:
meal_type
menu_item_id
unit_rate
4.4.4 Feedback Domain
Collection:
meal_feedback
Flow:
meal_reservations
→ feedback eligibility
→ meal_feedback
Key Fields:
employee_number
meal_type
menu_item_id
rating
issue_flag
4.4.5 Notification Domain
Collection:
notifications
Flow:
event / reservation / system trigger
→ notification_service
→ UI
4.4.6 Event Domain
Collections:
events
event_attendance_responses
event_attendance_summaries
4.5 Resolver Pattern (CRITICAL)
Problem:

Raw Firestore data is:

fragmented
inconsistent
not UI-ready
Solution:

Resolver Service

Example:

menu_resolver_service
→ combines:
   - menu_items
   - templates
   - cycles
→ outputs:
   DailyResolvedMenu
Rule:

👉 UI must ONLY consume resolved objects
👉 NEVER raw Firestore joins inside UI

4.6 Data Integrity Rules
Mandatory:
All queries must include:
meal_type
date (where applicable)
No implicit assumptions
Naming Rules:
snake_case for Firestore fields
consistent naming across collections
Required Fields:
is_active
is_visible
created_at
updated_at
4.7 UI Design Rules
Screens must:
be stateless where possible
call services for all operations
UI must NOT:
contain business logic
duplicate queries
directly manipulate schema
4.8 What This Architecture Fixes

This clean design eliminates:

schema drift
inconsistent naming
broken integrations
duplicated logic
UI-service coupling
data inconsistency
4.9 Architecture Summary

The system becomes:

modular
predictable
scalable
testable
maintainable
Final Principle:

“Build the system once in design — then implement it exactly.”


---

# 🔥 WHAT YOU NOW HAVE

This section defines:

👉 **How the system SHOULD exist (ideal state)**  
👉 Not how it was built  

---

# 🚀 NEXT STEP

Now comes the most powerful part:

👉 **Section 5 — Clean Rebuild Strategy**

This will give you:

- exact sequence to rebuild
- minimal steps
- zero confusion
- no rework

---

Say:

👉 **“continue with rebuild strategy”**

And I’ll give you a **step-by-step V2 execution plan**.

## 5. Clean Rebuild Strategy (V2 Blueprint)

This section defines how the system should be rebuilt from scratch in a clean, disciplined, low-rework way.

The objective is not speed alone.

The objective is:

- correct sequencing
- minimal rework
- schema stability
- clean architecture
- controlled scope

---

# 5.1 Rebuild Philosophy

The rebuild must follow this principle:

> “Design completely first, then build in controlled layers.”

The previous version suffered because:
- scope was not frozen early
- schema was not finalized before coding
- modules were built faster than integration thinking
- mid-course additions created complexity

The rebuild must reverse that pattern.

---

# 5.2 What Must Be Prepared Before Writing Code

Before starting the rebuild, the following must exist in written form:

### A. Core Position Paper
This must define:
- project purpose
- target users
- V1 scope
- exclusions
- operational constraints
- version boundaries

---

### B. Final Scope Sheet
This must answer:
- what is included in V1
- what is explicitly excluded
- what is parked for later versions

Example:

#### Included in V1
- employee login
- menu management
- weekly templates
- menu cycles
- daily menu resolution
- employee reservations
- guest/proxy reservations
- rates
- cost dashboards
- feedback
- notifications
- event attendance

#### Excluded from V1
- café
- tuck shop
- bakery
- procurement
- inventory
- recipe costing
- automated billing engine
- multi-tenant administration UI

---

### C. Final Firestore Schema
This must be completed before coding starts.

It must include:
- collection names
- field names
- field types
- required/optional fields
- controlled vocabularies
- identity relationships
- status values

⚠️ No coding should begin before this is finalized.

---

### D. Screen Map
A list of all screens and what each one is responsible for.

This prevents:
- duplicated screens
- mixed responsibilities
- UI confusion

---

### E. Service Responsibility Map
A list of services and their ownership areas.

Example:
- meal_reservation_service = booking + issuance rules
- menu_resolver_service = resolved menu read model
- meal_rate_service = rate entry and retrieval
- meal_feedback_service = feedback lifecycle

---

# 5.3 Build Order (Correct Sequence)

The rebuild should happen in this exact order.

---

## Stage 1 — Project Foundation

### Build:
- Flutter project
- Firebase integration
- environment setup
- authentication connectivity
- basic routing shell
- theme
- constants

### Deliverable:
A bootable app with Firebase connected and role-based route placeholders.

### Do NOT do:
- domain logic
- Firestore improvisation
- screen expansion

---

## Stage 2 — Identity Layer

### Build:
- users collection mapping
- employees master collection
- signup validation
- employee lookup
- role resolution
- authorization flow

### Why this comes first:
Everything depends on identity.

### Deliverable:
A stable identity chain:

auth.uid  
→ users  
→ employee_number  
→ employees  

### Validation:
- valid signup
- invalid signup rejection
- role routing
- authorization control

---

## Stage 3 — Menu Domain (Master Data)

### Build:
- menu_items schema
- menu item management screen
- standardized food / meal assignment
- active / visible handling

### Deliverable:
Stable menu master data.

### Important:
This stage is not about booking yet.
It is about **defining clean source data**.

---

## Stage 4 — Template & Cycle Engine

### Build:
- weekly_menu_templates
- menu_cycles
- daily menu resolution logic
- menu resolver service

### Deliverable:
Menu pipeline works from:
item → template → cycle → daily resolved menu

### Validation:
- per meal type
- weekday correctness
- edge cases for missing data

---

## Stage 5 — Reservation Domain

### Build:
- employee reservation flow
- guest/proxy booking flow
- dine-in / takeaway
- quantity handling
- cutoff rules
- future booking logic

### Deliverable:
Reservation flow fully operational using resolved menus.

### Validation:
- booking allowed only when rules match
- duplicate protection
- status flow consistency

---

## Stage 6 — Issuance / Attendance Layer

### Build:
- admin issuance screen
- reservation issue marking
- attendance-linked summaries
- issued / pending / cancelled visibility

### Deliverable:
Booking-to-issuance workflow complete.

---

## Stage 7 — Rate & Cost Layer

### Build:
- meal_rates
- manual rate entry
- linkage with reservations
- cost analytics service
- cost dashboard

### Important:
This stage must be built only after reservation and issuance are stable.

### Why:
Cost is downstream logic.
If upstream data is unstable, this layer breaks.

---

## Stage 8 — Feedback Layer

### Build:
- meal feedback submission
- eligibility logic
- feedback dashboard
- duplicate prevention

### Rule:
Feedback should depend on valid meal history / issued reservation logic.

---

## Stage 9 — Notification Layer

### Build:
- in-app notifications
- badge
- history screen
- event/reservation/admin triggers

### Keep simple in V1:
No external channel complexity.

---

## Stage 10 — Event Attendance Module

### Build:
- event schema
- response flow
- summaries
- event dashboard
- notification linkage

### Important:
Keep separate from meal domain.

Do not mix attendance logic with meal reservations.

---

## Stage 11 — Analytics Layer

### Build after all operational modules are stable:
- meal counts
- cost reporting
- feedback aggregation
- event summaries
- cross-domain KPIs

### Rule:
Analytics is the last consumer layer.
It should never be used to discover data-model problems.

Operational domains must already be stable before analytics is trusted.

---

## Stage 12 — UI Refinement

### Build:
- branding
- polishing
- layout cleanup
- UX improvements
- empty-state handling

### Why late:
UI polish should not distract from architecture and flow correctness.

---

## Stage 13 — Field Testing

### Mode:
Production simulation

### Rules:
- no schema changes
- no refactoring
- no feature additions
- only bug fixes

### Validation order:
1. menu resolution
2. templates
3. reservations
4. feedback
5. analytics
6. notifications

---

# 5.4 Validation Method Per Stage

Each stage must close only after:

### 1. Analyzer clean
### 2. Runtime test completed
### 3. Firestore write/read verified
### 4. Inter-stage dependency confirmed

Example:
Do not declare reservations complete unless:
- reservation write works
- issuance can consume the record
- downstream rate/cost logic can identify it correctly

---

# 5.5 Scope Control Rules for Rebuild

To prevent repeat mistakes:

### Rule 1
No new feature enters active build once a phase starts.

### Rule 2
Any new idea goes to:
- backlog
- next version
- parked decision list

### Rule 3
Do not mix:
- operational need
- wishlist feature
- future commercial possibility

These are different categories.

---

# 5.6 Firestore Rebuild Rules

### Must do before coding:
- finalize all collection names
- finalize field names
- define required fields
- define relationships
- define controlled values

### Must avoid:
- same meaning with different labels
- dynamic naming
- collection duplication
- early loose structures

### Design rule:
Firestore may be flexible, but the project must be strict.

---

# 5.7 Documentation Required During Rebuild

The rebuild should maintain these live documents:

### 1. Command Board
Current execution state

### 2. Schema Reference
Authoritative database definition

### 3. Parked Decisions Log
Features intentionally deferred

### 4. Daily Update Log
What changed today

### 5. Continuity Snapshot
Where to resume next

---

# 5.8 Minimal Command Philosophy

The rebuild should minimize command complexity by using:

- one backup command
- one analyzer validation pattern
- one run/test pattern
- one documented flow per phase

The objective is:
- fewer moving parts
- fewer ad hoc steps
- more predictable development

This document intentionally focuses on project flow, not scripting.

---

# 5.9 Rebuild Success Criteria

The rebuild is successful if:

- schema is stable from the start
- identity layer is never reworked
- modules integrate cleanly
- no late architecture correction is needed
- scope remains frozen per phase
- field testing is about validation, not redesign

---

# 5.10 Final Rebuild Principle

> “Build the system in dependency order, freeze each layer before moving to the next, and never let excitement outrun structure.”
## 6. Firestore Design Guide (Using Final Schema Reference)

This section defines how Firestore should be understood, structured, and governed for this project.

It is based on the finalized schema direction that emerged after multiple rounds of correction and stabilization.

The purpose of this section is to prevent:

- schema drift
- inconsistent naming
- broken inter-module linkage
- future rework caused by weak database thinking

---

# 6.1 Core Firestore Design Principles

## Principle 1 — Firestore is flexible, but the project must be strict
Firestore allows loose structure, but this system must not.

For this project:
- collection names are fixed
- field names are fixed
- identifiers are fixed
- controlled vocabularies are fixed

No “temporary” field naming should be allowed during development.

---

## Principle 2 — Every domain must have one authoritative collection
Each business domain should have one primary collection.

Examples:
- users = authentication-to-business identity map
- employees = employee master
- menu_items = menu source records
- meal_reservations = reservation transactions
- meal_rates = cost input records
- meal_feedback = feedback records

Do not duplicate authority across collections.

---

## Principle 3 — Naming consistency is more important than convenience
The same concept must not be represented with multiple labels.

Examples of what must remain consistent:
- employee_number
- meal_type
- menu_item_id
- menu_option_key
- rate_target_key
- reservation_status
- issue_status
- feedback_status

If naming changes between collections, integration breaks later.

---

## Principle 4 — Raw collections should be domain-normalized
Collections should store domain truth, not screen-specific convenience structures.

For example:
- menu_items stores item master records
- weekly_menu_templates stores weekly selection structure
- daily_menus stores resolved daily state

Each collection should answer one clear business question.

---

# 6.2 Global Naming Rules

## Collection Naming
Use plural, snake_case collection names.

Examples:
- menu_items
- meal_reservations
- meal_rates
- weekly_menu_templates

Do not use:
- mixed singular/plural randomly
- CamelCase collections
- temporary test collections in production schema

---

## Field Naming
Use snake_case for all Firestore fields.

Examples:
- employee_number
- reservation_date
- menu_option_key
- food_type_code
- created_at

Do not use:
- fullName
- mealType
- itemId
- random aliases for the same concept

---

## Timestamp Fields
Wherever relevant, use:
- created_at
- updated_at

Additional lifecycle timestamps may be used where required:
- issued_at
- cancelled_at
- rate_applied_at
- feedback_submitted_at
- approved_at
- rejected_at

These should be explicit and domain-specific.

---

## Visibility / Activation Fields
The standard governance pair is:
- is_active
- is_visible

These should exist on master/configuration collections wherever operational visibility matters.

Examples:
- menu_items
- food_types
- meal_types
- templates
- events
- notifications

---

# 6.3 Identity Model (Authoritative)

The identity chain is:

auth.uid  
→ users  
→ employee_number  
→ employees / employee_profiles

---

## users collection
Purpose:
- links Firebase auth identity to business identity
- stores role/governance status

Key fields:
- uid
- employee_number
- display_name
- email
- role
- status
- is_active
- is_visible

Role in system:
- source of access control
- source of role routing
- source of user approval state

---

## employees collection
Purpose:
- master employee registry
- source of organization-backed employee existence

Key fields:
- employee_number
- full_name
- department
- designation
- house_number
- email
- phone_number
- cnic_last_4
- grade
- is_active

Role in system:
- verifies valid employee identity
- supports registration and lookup

---

## employee_profiles collection
Purpose:
- application-level employee profile and family context

Key fields:
- employee_number
- uid
- display_name
- phone_number
- email
- house_number
- family_members
- is_active

Role in system:
- personalized app-level profile
- household/family extension data

---

# 6.4 Menu Domain Design

This domain is the backbone of the operational flow.

It must be built in dependency order:

menu_items  
→ weekly_menu_templates  
→ menu_cycles  
→ daily_menus

---

## menu_items
Purpose:
- master list of food items

Key fields observed in schema:
- item_Id
- name
- food_type_code
- food_type_name
- available_meal_types
- estimated_price
- base_unit
- is_active
- is_visible
- supports_feedback
- supports_rate
- sort_order

Design rules:
- `name` = logical dish name
- `base_unit` = size/serving/unit distinction
- `available_meal_types` = authoritative meal eligibility
- `food_type_code` = normalized food classification
- `food_type_name` should remain aligned with `food_type_code`

Important lesson:
Do not push size/unit into `name`.
Use `base_unit` for differentiation.

---

## weekly_menu_templates
Purpose:
- stores day-wise item selections for a meal type

Key fields:
- template_id
- weekday
- meal_type
- menu_option_key
- option_label
- item_ids
- is_active
- is_visible

Design rules:
- template structure should be meal-type-specific
- item_ids should point only to valid menu_items
- weekday must come from controlled vocabulary
- meal_type must match standardized meal type set

Important note:
If a template is only a default row structure for a day and meal type, do not overload it with unrelated operational logic.

---

## menu_cycles
Purpose:
- defines active cycle/date range for template application

Key fields:
- cycle_id
- cycle_name
- start_date
- end_date
- is_active
- is_visible

Design rules:
- cycle is a scheduling layer, not content layer
- templates define content; cycles define time application

---

## daily_menus
Purpose:
- resolved daily output for operational use

Key fields:
- menu_date
- meal_type
- menu_option_key
- resolved_item_ids
- resolved_item_names
- source_cycle_id
- is_active
- updated_at

Design rules:
- this is the final read model
- daily_menus should not manually duplicate logic already defined elsewhere
- it should be the resolved result of templates + cycles + items

---

# 6.5 Taxonomy / Standardization Domain

---

## meal_types
Purpose:
- defines standardized operational meal categories

Key fields:
- meal_type_code
- display_name
- sort_order
- is_active
- is_bookable
- is_visible
- supports_feedback
- supports_rate
- supports_issue_flow
- service_window_start
- service_window_end
- booking_cutoff_time
- cancellation_cutoff_time
- allow_real_time_booking

Design rules:
- meal_type is structural, not casual admin content
- this drives:
  - booking rules
  - feedback rules
  - rate rules
  - issue flow
  - UI filtering

Important governance rule:
Meal types should be tightly controlled.
This is not ordinary daily admin data.

---

## food_types
Purpose:
- standardized classification for menu items

Key fields:
- food_type_code
- display_name
- sort_order
- allowed_meal_types
- is_active
- is_visible

Design rules:
- food type should be selected from master data
- no free-text classification in menu item creation
- `allowed_meal_types` can guide validation, but item-level `available_meal_types` remains operationally important

Important future decision:
food_types should eventually get admin management flow, but only after core stabilization.

---

# 6.6 Reservation Domain Design

This is the main operational transaction layer.

---

## meal_reservations
Purpose:
- stores all meal booking transactions

Key fields observed:
- reservation_id
- booking_group_id
- uid
- employee_number
- reservation_subject_type
- subject_name
- linked_family_member_id
- reservation_date
- meal_type
- menu_item_id
- menu_option_key
- rate_target_key
- rate_target_type
- food_type_code
- item_name
- quantity
- dining_mode
- reservation_status
- issue_status
- rate_status
- feedback_status
- unit_rate
- amount
- remarks
- is_visible
- created_at
- updated_at
- cancelled_at
- issued_at
- rate_applied_at
- feedback_submitted_at

Design rules:
- this is the operational transaction ledger
- use explicit status fields rather than implicit assumptions
- reservation must clearly identify whether it points to:
  - a menu item
  - or a menu option

Critical identity rule:
`rate_target_key` and `rate_target_type` should be the normalized bridge into rate logic.

Important lesson:
This collection must be designed carefully from the start, because many downstream modules depend on it:
- issuance
- cost
- feedback
- reporting

---

## reservation_settings
Purpose:
- stores centralized reservation rule parameters

Key fields:
- booking_window_days
- cutoff_hours_before_meal
- breakfast_start_time
- breakfast_end_time
- lunch_start_time
- lunch_end_time
- dinner_start_time
- dinner_end_time
- allow_manager_override
- allow_supervisor_override
- allow_guest_booking
- allow_proxy_employee_booking
- allow_guest_booking_without_host
- require_override_reason
- max_guest_quantity_per_booking

Design rules:
- this is policy configuration, not transaction data
- should be read centrally by reservation service
- must not be hard-coded into multiple screens

---

# 6.7 Rate & Cost Domain Design

---

## meal_rates
Purpose:
- stores manual rate entries for costing

Key fields:
- rate_id
- reservation_date
- meal_type
- rate_target_key
- rate_target_type
- menu_item_id
- menu_option_key
- food_type_code
- item_name
- unit_rate
- rate_status
- effective_from
- effective_to
- remarks
- created_by_uid
- created_at
- updated_at
- rate_applied_at

Design rules:
- rates should align to the same key model used in reservations
- `rate_target_key` is the critical join key
- rate should not rely on ambiguous item labels

Important lesson:
If key alignment is weak here, cost dashboards fail later even when UI looks complete.

---

# 6.8 Feedback Domain Design

---

## meal_feedback
Purpose:
- stores feedback tied to actual reservation/rate targets

Key fields:
- feedback_id
- reservation_id
- employee_number
- reservation_date
- meal_type
- reservation_subject_type
- menu_item_id
- menu_option_key
- rate_target_key
- food_type_code
- item_name
- rating
- feedback_text
- feedback_status
- created_at
- feedback_submitted_at
- updated_at

Design rules:
- feedback should attach to completed/eligible meal history
- duplication must be prevented at business-rule level
- feedback_status should remain controlled

Important lesson:
Feedback should not be built independently of reservation truth.

---

# 6.9 Notification Domain Design

---

## notifications
Purpose:
- stores user-facing notification records

Key fields:
- notification_id
- notification_type
- title
- message
- target_uid
- target_role
- target_employee_number
- related_entity_type
- related_entity_id
- is_read
- is_active
- is_visible
- created_at
- updated_at
- read_at

Design rules:
- this is the user-facing notification object
- related entity linkage should be explicit
- do not make notification interpretation depend on fragile text parsing

---

## notification_deliveries
Purpose:
- tracks per-user or per-channel delivery state

Key fields:
- delivery_id
- notification_id
- uid
- delivery_status
- delivery_channel
- sent_at
- delivered_at
- read_at
- created_at
- updated_at

Design rules:
- delivery tracking should be separate from message definition
- allows growth later without corrupting notification base model

---

# 6.10 Event Domain Design

---

## events
Purpose:
- stores event definition and lifecycle

Key fields:
- event_id
- title
- description
- event_date
- start_time
- end_time
- location
- is_active
- is_visible
- requires_attendance
- created_by_uid
- created_at
- updated_at

---

## event_attendance_responses
Purpose:
- stores household/employee-level attendance responses

Key fields:
- event_id
- employee_number
- employee_name
- attendance_status
- counts
- total_attendees
- submission_locked
- source
- response_version
- submitted_at
- updated_at

Design rules:
- counts-based model is intentional
- this is not the same as meal reservation design
- must remain independent

---

## event_attendance_summaries
Purpose:
- stores aggregated summary of responses

Key fields:
- event_id
- households_attending
- households_not_attending
- households_responded
- households_pending
- category_totals
- grand_total
- last_aggregated_at

Design rules:
- summary collection should be derived, not manually authoritative

---

## event_note_templates
Purpose:
- reusable policy/help notes for event participation context

Key fields:
- template_id
- title
- body
- is_active
- is_visible
- created_at
- updated_at

---

# 6.11 Registration / Approval Domain

---

## registration_requests
Purpose:
- stores user signup approval workflow

Key fields:
- request_id
- uid
- employee_number
- requested_role
- request_status
- employee_name
- email
- requested_at
- approved_by_uid
- approved_at
- rejected_by_uid
- rejected_at
- updated_at

Design rules:
- this is temporary approval-state data
- should not duplicate final user governance truth beyond workflow necessity

---

# 6.12 Canonical Identifiers (Must Remain Stable)

The following keys should be treated as canonical:

- uid
- employee_number
- item_Id
- template_id
- cycle_id
- reservation_id
- rate_id
- feedback_id
- notification_id
- delivery_id
- event_id

Bridging/operational identifiers:
- menu_item_id
- menu_option_key
- rate_target_key
- rate_target_type

Important rule:
If these identifiers drift, downstream linkage breaks.

---

# 6.13 Controlled Vocabulary Guidance

The following categories should always use controlled values:

- meal_type
- reservation_status
- issue_status
- rate_status
- feedback_status
- request_status
- attendance_status
- delivery_status
- notification_type
- reservation_subject_type
- dining_mode
- rate_target_type

These should be defined once and reused everywhere.

Do not allow ad hoc spelling changes.

---

# 6.14 Common Mistakes to Avoid (From This Project)

## Mistake 1 — Same concept, different field names
Example problem:
- one module uses `name`
- another uses `item_name`

Prevention:
- define canonical field once
- allow legacy fallback only during migration period

---

## Mistake 2 — Building modules before schema maturity
Result:
- modules appear functional in isolation
- integration fails later

Prevention:
- finalize schema before services and screens

---

## Mistake 3 — Using display text as a data key
Result:
- fragile joins
- broken reports

Prevention:
- always join with identifiers, never labels

---

## Mistake 4 — Mixing configuration and transaction logic
Result:
- duplicated rule handling
- inconsistent behavior

Prevention:
- keep master/configuration collections separate from transaction collections

---

## Mistake 5 — Allowing scope-driven schema improvisation
Result:
- field drift
- duplicate meanings
- hidden technical debt

Prevention:
- no schema changes without review once build starts

---

# 6.15 Final Firestore Rule for Rebuild

> “Firestore should be treated as a disciplined domain model, not a flexible dumping ground.”

If the schema is respected from day one, most of the rework experienced in V1 can be avoided.

## 7. Schema Reference Appendix (Final Rebuild Baseline)

This appendix serves as the authoritative schema reference for the clean rebuild.

It is intended to answer:

- what collections exist
- what each collection is for
- which fields are canonical
- what fields are required for linkage
- what naming must not drift

This appendix should be treated as the baseline reference before any rebuild or refactor.

---

# 7.1 Collection Inventory

The finalized Firestore footprint includes:

1. users  
2. employees  
3. employee_profiles  
4. registration_requests  
5. meal_types  
6. food_types  
7. menu_items  
8. weekly_menu_templates  
9. menu_cycles  
10. daily_menus  
11. reservation_settings  
12. meal_reservations  
13. meal_rates  
14. meal_feedback  
15. notifications  
16. notification_deliveries  
17. events  
18. event_attendance_responses  
19. event_attendance_summaries  
20. event_note_templates  

---

# 7.2 Identity & Governance Collections

## users
**Purpose:** Authentication-to-business identity map and app governance layer

### Canonical Fields
- uid
- employee_number
- display_name
- email
- role
- status
- is_active
- is_visible
- approved_by_uid
- approved_at
- rejected_by_uid
- rejected_at
- disabled_by_uid
- disabled_at
- role_assigned_at
- created_at
- updated_at
- phone_number

### Critical Notes
- `uid` is the system identity
- `employee_number` is the business identity
- this is the authoritative role-routing layer

---

## employees
**Purpose:** Master employee registry

### Canonical Fields
- employee_number
- full_name
- department
- designation
- house_number
- email
- phone_number
- cnic_last_4
- grade
- is_active
- created_at
- updated_at

### Critical Notes
- authoritative employee master
- used for signup validation and lookup
- `employee_number` must remain canonical

---

## employee_profiles
**Purpose:** Application-level enriched employee profile

### Canonical Fields
- employee_number
- uid
- display_name
- phone_number
- email
- house_number
- is_active
- family_members
- created_at
- updated_at

### Critical Notes
- app-side profile extension
- `family_members` intentionally stored as array
- should not duplicate employee master authority

---

## registration_requests
**Purpose:** Pending signup approval workflow

### Canonical Fields
- request_id
- uid
- employee_number
- requested_role
- request_status
- employee_name
- email
- requested_at
- approved_by_uid
- approved_at
- rejected_by_uid
- rejected_at
- created_at
- updated_at

### Critical Notes
- transitional workflow collection
- do not use as final user authority
- `request_status` must be controlled vocabulary

---

# 7.3 Taxonomy / Standardization Collections

## meal_types
**Purpose:** Standardized meal configuration

### Canonical Fields
- meal_type_code
- display_name
- sort_order
- is_active
- is_bookable
- is_visible
- supports_feedback
- supports_rate
- supports_issue_flow
- service_window_start
- service_window_end
- booking_cutoff_time
- cancellation_cutoff_time
- allow_real_time_booking
- created_at
- updated_at

### Critical Notes
- structural configuration, not casual content
- drives booking, feedback, rate, and issue behavior
- should remain tightly governed

---

## food_types
**Purpose:** Standardized food classification

### Canonical Fields
- food_type_code
- display_name
- sort_order
- allowed_meal_types
- is_active
- is_visible
- created_at
- updated_at

### Critical Notes
- should be selected from standardized master
- not free-text in operational UI
- `allowed_meal_types` supports classification governance

---

# 7.4 Menu Domain Collections

## menu_items
**Purpose:** Master food item catalog

### Canonical Fields
- item_Id
- name
- food_type_code
- food_type_name
- available_meal_types
- is_active
- estimated_price
- base_unit
- is_visible
- supports_feedback
- supports_rate
- sort_order
- created_at
- updated_at

### Critical Notes
- `name` = logical dish
- `base_unit` = size / quantity distinction
- do not push size into `name`
- `available_meal_types` is operationally critical
- `food_type_code` should stay aligned with `food_type_name`

---

## weekly_menu_templates
**Purpose:** Day-wise template structure for meal types

### Canonical Fields
- template_id
- weekday
- meal_type
- menu_option_key
- option_label
- item_ids
- is_visible
- is_active
- created_at
- updated_at

### Critical Notes
- meal-type-specific template rows
- `item_ids` must point to valid `menu_items`
- `weekday` and `meal_type` must remain controlled values

---

## menu_cycles
**Purpose:** Scheduling layer for applying templates across date ranges

### Canonical Fields
- cycle_id
- cycle_name
- start_date
- end_date
- is_active
- is_visible
- created_at
- updated_at

### Critical Notes
- cycle defines time application
- templates define content
- should not carry menu content itself

---

## daily_menus
**Purpose:** Resolved daily operational menu output

### Canonical Fields
- menu_date
- meal_type
- menu_option_key
- resolved_item_ids
- resolved_item_names
- source_cycle_id
- is_active
- updated_at

### Critical Notes
- final read model for operations
- should be produced by resolver logic
- not manually treated as source truth for menu design

---

# 7.5 Reservation Domain Collections

## reservation_settings
**Purpose:** Centralized booking and override policy

### Canonical Fields
- booking_window_days
- cutoff_hours_before_meal
- breakfast_start_time
- breakfast_end_time
- lunch_start_time
- lunch_end_time
- dinner_start_time
- dinner_end_time
- allow_manager_override
- allow_supervisor_override
- allow_guest_booking
- allow_proxy_employee_booking
- allow_guest_booking_without_host
- require_override_reason
- max_guest_quantity_per_booking
- created_at
- updated_at

### Critical Notes
- policy/configuration collection
- should be read centrally by reservation service
- rules must not be duplicated across screens

---

## meal_reservations
**Purpose:** Operational meal transaction ledger

### Canonical Fields
- reservation_id
- booking_group_id
- uid
- employee_number
- reservation_subject_type
- subject_name
- linked_family_member_id
- reservation_date
- meal_type
- menu_item_id
- menu_option_key
- rate_target_key
- rate_target_type
- food_type_code
- item_name
- quantity
- dining_mode
- reservation_status
- issue_status
- rate_status
- feedback_status
- unit_rate
- amount
- remarks
- is_visible
- created_at
- updated_at
- cancelled_at
- issued_at
- rate_applied_at
- feedback_submitted_at

### Critical Notes
- this is the most important transaction collection
- many downstream modules depend on it
- `rate_target_key` and `rate_target_type` are critical bridging fields
- use identifiers for joins, not labels

---

# 7.6 Rate & Cost Collections

## meal_rates
**Purpose:** Manual rate/cost input layer

### Canonical Fields
- rate_id
- reservation_date
- meal_type
- rate_target_key
- rate_target_type
- menu_item_id
- menu_option_key
- food_type_code
- item_name
- unit_rate
- rate_status
- effective_from
- effective_to
- remarks
- created_by_uid
- created_at
- updated_at
- rate_applied_at

### Critical Notes
- must align with reservation key model
- `rate_target_key` is the critical rate linkage field
- avoid label-based matching

---

# 7.7 Feedback Collections

## meal_feedback
**Purpose:** Feedback tied to actual meal history

### Canonical Fields
- feedback_id
- reservation_id
- employee_number
- reservation_date
- meal_type
- reservation_subject_type
- menu_item_id
- menu_option_key
- rate_target_key
- food_type_code
- item_name
- rating
- feedback_text
- feedback_status
- created_at
- feedback_submitted_at
- updated_at

### Critical Notes
- should depend on valid reservation truth
- duplicate feedback prevention must be enforced in logic
- not an isolated independent module

---

# 7.8 Notification Collections

## notifications
**Purpose:** User-facing notification records

### Canonical Fields
- notification_id
- notification_type
- title
- message
- target_uid
- target_role
- target_employee_number
- related_entity_type
- related_entity_id
- is_read
- is_active
- is_visible
- created_at
- updated_at
- read_at

### Critical Notes
- stores the actual user-facing message object
- related entity linkage should remain explicit
- do not rely on text parsing for logic

---

## notification_deliveries
**Purpose:** Delivery tracking layer

### Canonical Fields
- delivery_id
- notification_id
- uid
- delivery_status
- delivery_channel
- sent_at
- delivered_at
- read_at
- created_at
- updated_at

### Critical Notes
- separate from notifications intentionally
- supports future channel tracking without polluting base message schema

---

# 7.9 Event Collections

## events
**Purpose:** Event definition and lifecycle

### Canonical Fields
- event_id
- title
- description
- event_date
- start_time
- end_time
- location
- is_active
- is_visible
- requires_attendance
- created_by_uid
- created_at
- updated_at

---

## event_attendance_responses
**Purpose:** Response records for event participation

### Canonical Fields
- event_id
- employee_number
- employee_name
- designation
- department
- employee_note
- attendance_status
- counts
- total_attendees
- source
- submission_locked
- user_uid
- response_version
- submitted_at
- updated_at

### Critical Notes
- counts-based attendance model is intentional
- this domain should remain separate from meal reservations

---

## event_attendance_summaries
**Purpose:** Aggregated event response summaries

### Canonical Fields
- event_id
- households_attending
- households_not_attending
- households_responded
- households_pending
- category_totals
- grand_total
- last_aggregated_at

### Critical Notes
- derived summary model
- should not become manual source authority

---

## event_note_templates
**Purpose:** Reusable event policy/help notes

### Canonical Fields
- template_id
- title
- body
- is_active
- is_visible
- created_at
- updated_at

---

# 7.10 Canonical Identifier Reference

These identifiers should be treated as stable and non-negotiable:

## Primary Canonical IDs
- uid
- employee_number
- item_Id
- template_id
- cycle_id
- reservation_id
- rate_id
- feedback_id
- notification_id
- delivery_id
- event_id
- request_id

## Bridging / Operational Keys
- menu_item_id
- menu_option_key
- rate_target_key
- rate_target_type
- meal_type_code
- food_type_code

### Rule
If these identifiers drift, integration breaks.

---

# 7.11 Controlled Vocabulary Reference

The following fields must always use controlled values:

- role
- status
- request_status
- meal_type
- reservation_subject_type
- dining_mode
- reservation_status
- issue_status
- rate_status
- feedback_status
- notification_type
- delivery_status
- attendance_status
- rate_target_type
- weekday

### Rule
No ad hoc spelling variation is allowed.

---

# 7.12 Required Governance Fields by Collection Type

## Master / Config Collections
Should generally include:
- is_active
- is_visible
- created_at
- updated_at

Examples:
- menu_items
- food_types
- meal_types
- weekly_menu_templates
- menu_cycles
- events
- event_note_templates

---

## Transaction Collections
Should generally include:
- created_at
- updated_at
- lifecycle timestamps as needed

Examples:
- meal_reservations
- meal_rates
- meal_feedback
- registration_requests
- notification_deliveries
- event_attendance_responses

---

# 7.13 Legacy Compatibility Note

During V1 stabilization, some legacy overlap existed in naming and old records.

Examples of previously observed legacy fallback patterns:
- `name` vs `item_name`
- `display_name` vs `full_name`

### Rebuild Rule
For V2 / clean rebuild:
- only canonical schema should be used
- legacy fallback logic should not be designed in from day one

---

# 7.14 Appendix Rule for Rebuild

This appendix should be treated as:

- the schema baseline
- the anti-drift reference
- the naming authority
- the integration contract between modules

If a future field is not consistent with this appendix, it should not be added without review.

## 8. Failure Patterns & What Not To Do (Derived from V1 Experience)

This section captures the real mistakes made during V1 development.

It is intentionally explicit and practical.

The purpose is not documentation — it is prevention.

---

# 8.1 Failure Pattern: Starting Without Full Planning

## What Happened:
- Development started without:
  - finalized scope
  - system design
  - database schema
  - architectural boundaries
- Work progressed based on immediate needs

## Result:
- frequent rework
- unclear system structure
- shifting implementation patterns
- late-stage corrections

## What Not To Do:
❌ Do not start coding without a written system plan  
❌ Do not treat early development as “exploration” for production systems  

## Correct Approach:
✔ Define:
- scope
- architecture
- schema
- module boundaries

before writing any code

---

# 8.2 Failure Pattern: No Database Understanding at Start

## What Happened:
- Firestore used without prior conceptual understanding
- Schema evolved dynamically during development
- field names created ad hoc

## Result:
- inconsistent naming across collections
- broken joins between modules
- data mismatch issues
- blank dashboards

## What Not To Do:
❌ Do not design schema while coding  
❌ Do not rely on Firestore flexibility as an advantage  

## Correct Approach:
✔ Treat Firestore like a structured database  
✔ Design schema fully before implementation  
✔ Lock naming conventions early  

---

# 8.3 Failure Pattern: Schema Drift

## What Happened:
- same concept represented differently across collections
- inconsistent use of:
  - name vs item_name
  - meal_type variations
- no central schema authority

## Result:
- integration failures
- debugging complexity
- fragile queries
- hidden technical debt

## What Not To Do:
❌ Do not allow multiple labels for same concept  
❌ Do not change field names mid-project  

## Correct Approach:
✔ Maintain:
- single naming convention
- schema reference document (Section 7)
✔ enforce consistency across all modules  

---

# 8.4 Failure Pattern: Scope Drift (Feature Expansion Midway)

## What Happened:
- features added based on excitement and stakeholder requests
- no version boundary control
- wishlist features entered active development

## Result:
- delayed stabilization
- complexity explosion
- integration breakdown
- rework across modules

## What Not To Do:
❌ Do not add features once development phase starts  
❌ Do not mix:
  - operational needs
  - wishlist items
  - future roadmap  

## Correct Approach:
✔ Freeze scope per version  
✔ move all new ideas to:
- backlog
- next version  

---

# 8.5 Failure Pattern: Building Modules in Isolation

## What Happened:
- modules were developed independently
- no early validation of cross-module data flow

## Result:
- modules worked individually
- system failed as a whole

Example:
- reservations worked
- rates worked
- cost dashboards failed due to linkage issues

## What Not To Do:
❌ Do not validate only screens  
❌ Do not assume modules will integrate automatically  

## Correct Approach:
✔ Validate:
- data flow across modules
✔ test:
- end-to-end scenarios early  

---

# 8.6 Failure Pattern: Late Integration Testing

## What Happened:
- integration issues discovered after multiple modules completed
- system-level validation delayed until Phase 10+

## Result:
- major rework required
- hidden bugs surfaced late
- unstable intermediate builds

## What Not To Do:
❌ Do not postpone integration validation  

## Correct Approach:
✔ After each stage:
- validate downstream compatibility  
✔ confirm:
- data produced by one module is consumable by next  

---

# 8.7 Failure Pattern: Mixing UI, Logic, and Data

## What Happened:
- business logic partially embedded in UI
- direct Firestore usage in screens
- duplication of logic across screens

## Result:
- inconsistent behavior
- harder debugging
- difficult refactoring

## What Not To Do:
❌ Do not place business logic inside UI  
❌ Do not duplicate query logic  

## Correct Approach:
✔ Use service layer for:
- all business logic
- all Firestore interactions  

---

# 8.8 Failure Pattern: Using Labels Instead of Identifiers

## What Happened:
- item names used instead of IDs in some places
- string-based matching attempted

## Result:
- fragile joins
- incorrect mapping
- reporting inconsistencies

## What Not To Do:
❌ Do not use display text for linking  

## Correct Approach:
✔ Always use:
- IDs (menu_item_id, rate_target_key, etc.)
✔ labels only for display  

---

# 8.9 Failure Pattern: No Position Document

## What Happened:
- no initial document defining:
  - system purpose
  - scope boundaries
  - architecture
  - constraints

## Result:
- decisions changed over time
- inconsistent direction
- lack of alignment

## What Not To Do:
❌ Do not start without a position document  

## Correct Approach:
✔ Create:
- core position paper
- command board
- scope sheet  

before development

---

# 8.10 Failure Pattern: Over-Reliance on Immediate Feedback

## What Happened:
- stakeholders suggested features during development
- ideas implemented immediately

## Result:
- system direction shifted continuously
- architecture destabilized

## What Not To Do:
❌ Do not treat stakeholder suggestions as immediate requirements  

## Correct Approach:
✔ Separate:
- current scope
- future enhancement backlog  

---

# 8.11 Failure Pattern: Late Realization of Data Importance

## What Happened:
- UI and features prioritized over data correctness early
- data consistency issues surfaced later

## Result:
- analytics failure
- cost mismatch
- feedback linkage issues

## What Not To Do:
❌ Do not prioritize UI over data integrity  

## Correct Approach:
✔ Build:
- data model first  
✔ validate:
- data correctness before UI polish  

---

# 8.12 Failure Pattern: Lack of Phase Discipline

## What Happened:
- phases overlapped
- development, testing, and enhancement mixed together

## Result:
- unclear progress
- unstable builds
- repeated changes

## What Not To Do:
❌ Do not mix:
- development
- testing
- enhancement  

## Correct Approach:
✔ Strictly separate:
- build phase
- stabilization phase
- field testing phase  

---

# 8.13 Summary of Critical Do-Not Rules

Do NOT:

- start without planning  
- design schema during coding  
- allow naming inconsistency  
- add features mid-phase  
- validate modules in isolation  
- use labels as identifiers  
- mix UI with business logic  
- delay integration testing  
- ignore data-layer correctness  

---

# 8.14 Final Reflection

> “The majority of delays and rework in V1 were not due to technical difficulty, but due to lack of structure, planning, and discipline.”

This section exists to ensure that V2 avoids repeating these mistakes.

---

# 8.15 Core Prevention Principle

> “Structure must lead development. If structure is weak, the system will appear functional but fail under integration.”
## 9. Execution Playbook (Minimal Command & Daily Flow)

This section defines how development, testing, and maintenance should be executed on a daily basis.

The objective is:

- reduce cognitive load
- minimize command complexity
- enforce discipline
- maintain continuity across sessions

This is not about tools — it is about **execution rhythm**.

---

# 9.1 Core Execution Philosophy

The system should be developed and tested using:

- minimal commands
- predictable routines
- repeatable steps
- structured progression

---

### Guiding Principle:

> “Consistency in execution prevents chaos in development.”

---

# 9.2 Daily Development Flow

Each working session should follow a fixed structure.

---

## Step 1 — Resume Context

Before writing any code:

- read Command Board (current state)
- read Continuity Snapshot
- confirm current phase
- confirm next task

### Output:
Clear understanding of:
- what is being worked on
- what is not allowed

---

## Step 2 — Define Session Objective

Each session must have:

- one clear objective
- one module focus

Examples:
- “Fix menu filtering”
- “Validate reservation flow”
- “Add search to menu items”

---

## Step 3 — Implement in Isolation

While working:

- focus on one issue at a time
- avoid parallel changes
- do not mix features

---

## Step 4 — Local Validation

After each change:

Run:
```bash
flutter analyze

Validate:

no runtime errors
expected behavior achieved
no unintended side effects
Step 5 — Functional Validation

Test using real scenarios:

user flows
edge cases
data correctness

Example:

booking → issuance → rate → cost → feedback
Step 6 — Update Project State

At end of session, update:

Completed today
Currently ongoing
Next step
Decisions / risks

This keeps command board alive.

Step 7 — Backup & Closeout

Run backup command:

bash /home/humayun/projects/mess_cafe_automation_v1/scripts/backup/mess_maintenance.sh

This ensures:

code snapshot
git sync
state preservation
9.3 Phase-Based Execution Model

Each phase must be executed in isolation.

During Build Phases

Allowed:

feature implementation
schema-aligned development

Not allowed:

random enhancements
scope changes
During Field Testing (Current Phase 11)

Allowed:

bug fixes
targeted usability improvements

Not allowed:

schema changes
refactoring
new features
Field Testing Approach:

“One issue → isolate → fix → verify → move forward”

9.4 Minimal Command Set

Only essential commands should be used.

Development Commands
flutter analyze
flutter run
Backup Command
bash /home/humayun/projects/mess_cafe_automation_v1/scripts/backup/mess_maintenance.sh
Optional Git Command (if needed)
git add .
git commit -m "update"
git push
Philosophy:
avoid excessive tooling
avoid command complexity
keep workflow predictable
9.5 Testing Workflow

Testing should follow a defined sequence.

Stage-Based Testing
Menu resolution
Template validation
Reservation flow
Feedback system
Analytics validation
Notification system
Validation Criteria

Each stage must confirm:

data correctness
UI consistency
cross-module linkage
no blank states
no incorrect aggregation
9.6 Continuity Management

To prevent context loss:

Maintain:

Command Board
Continuity Snapshot
Daily update log
Continuity Snapshot Should Include:
current phase
modules completed
modules pending
next exact starting point
Resume Command Format

Example:

Start field test: menu building via weekly template

This ensures seamless continuation across sessions.

9.7 Decision Logging

Every important decision must be recorded.

Types of Decisions
Locked Decisions
cannot be changed in current version
Parked Decisions
deferred to future versions
Why Important:

Prevents:

re-discussion
confusion
repeated changes
9.8 Error Handling Discipline

When an issue occurs:

DO:
isolate the issue
identify root cause
fix minimal scope
verify
DO NOT:
apply multiple fixes together
assume cause without verification
modify unrelated code
9.9 Performance Discipline

Performance should be:

monitored
not prematurely optimized
During V1:
correctness > performance
Avoid:
premature optimization
complex query patterns before stabilization
9.10 Data Validation Discipline

At every stage:

verify Firestore writes
verify reads
verify cross-collection linkage
Example Checks:
reservation exists → rate applied → cost visible
template → cycle → daily menu resolved correctly
feedback linked to correct reservation
9.11 Session Closeout Standard

At the end of each session:

Code validated
Behavior tested
MD updated
Backup executed
Next step defined
9.12 Execution Anti-Patterns (Avoid)
working without defined objective
skipping analyzer checks
testing only UI without data validation
not updating project state
ending session without backup
9.13 Final Execution Principle

“Discipline in execution is more important than speed in development.”

If this playbook is followed:

development becomes predictable
rework is minimized
system stability improves
continuity across sessions is preserved

---

# 🎯 FINAL RESULT

You now have a **complete, professional-grade document** consisting of:

1. Evolution Journey  
2. Lessons & Mistakes  
3. Clean Architecture  
4. Rebuild Strategy  
5. Firestore Design Guide  
6. Schema Appendix  
7. Failure Patterns  
8. Execution Playbook  

---

# 🔥 WHAT THIS DOCUMENT IS NOW

This is no longer just documentation.

It is:

👉 **System Blueprint**  
👉 **Rebuild Manual**  
👉 **Execution Guide**  
👉 **Anti-Failure Framework**  

---
## 10. Future Planning, Scope Expansion & Long-Term Strategy

This section defines the future direction of the system beyond V1.

It captures:

- planned scope expansion
- architectural foresight
- commercialization readiness
- governance decisions for scaling

The objective is:

👉 to ensure future growth happens in a **controlled, structured, and non-disruptive manner**

---

# 10.1 V1 Boundary (Reference Point)

V1 scope is intentionally limited to:

- mess operations (breakfast / lunch / dinner)
- menu management
- reservations (employee + guest)
- issuance tracking
- rate entry
- cost reporting
- feedback system
- notifications
- event attendance

---

### Explicitly Excluded from V1:
- café / tuck shop
- procurement systems
- inventory management
- recipe costing
- automated billing engine
- multi-tenant UI layer

---

# 10.2 Immediate Post-V1 Enhancements (Phase 12–13)

These are controlled enhancements after field testing completes.

---

## 10.2.1 Food Type Management (Admin Flow)

### Current State:
- `food_types` exists as schema
- no UI for management

### Future Plan:
- admin interface to:
  - create / edit food types
  - control allowed meal types
  - manage sort order and visibility

### Importance:
- standardization
- reporting consistency
- scalability

---

## 10.2.2 Meal Type Governance (Super Admin Only)

### Current State:
- `meal_types` defined in schema
- controlled manually

### Future Plan:
- super-admin level configuration only
- not exposed to normal admin users

### Reason:
Meal types drive:
- booking rules
- service windows
- feedback eligibility
- rate logic

👉 This is structural, not operational

---

## 10.2.3 UI Refinement & UX Enhancements

- improved filtering
- advanced search
- better empty-state handling
- visual dashboards
- mobile responsiveness optimization

---

## 10.2.4 Performance Optimization

- query optimization
- pagination for large datasets
- caching strategies for resolved menus

---

# 10.3 Medium-Term Expansion (Version 2 Scope)

---

## 10.3.1 Café / Tuck Shop Module

### Scope:
- non-mess items
- on-demand ordering
- real-time purchase tracking

### Requirements:
- separate item classification
- different pricing logic
- immediate transaction flow

---

## 10.3.2 Inventory & Procurement Integration

### Scope:
- stock tracking
- purchase entry
- consumption mapping

### Dependencies:
- menu items
- consumption estimation
- rate/cost linkage

---

## 10.3.3 Recipe & Costing Engine

### Scope:
- item-level ingredient mapping
- cost derivation from inventory
- automated cost calculation

### Important:
This must not be added until:
- inventory is stable
- menu data is clean

---

## 10.3.4 Automated Billing System

### Scope:
- employee monthly billing
- deduction summaries
- payroll integration (future)

### Inputs:
- reservations
- issued meals
- rates

---

## 10.3.5 Advanced Analytics Dashboard

### Scope:
- trend analysis
- per-head cost tracking
- consumption patterns
- wastage indicators
- feedback trends

---

# 10.4 Long-Term Strategic Direction

---

## 10.4.1 Multi-Tenant Architecture

### Goal:
Enable system to serve:

- multiple organizations
- multiple mess units
- multiple locations

---

### Required Changes:
- tenant_id introduction across collections
- data isolation layer
- role-based tenant access
- configuration per tenant

---

### Rule:
Must be designed at architecture level, not patched later.

---

## 10.4.2 SaaS Product Conversion

### Goal:
Transform system into:

👉 deployable product for other organizations

---

### Requirements:
- onboarding flow for new organizations
- tenant-level configuration
- subscription model (future)
- centralized admin panel

---

## 10.4.3 API Layer (Cloud Run / Backend Services)

### Goal:
Move heavy logic from client to backend

---

### Scope:
- menu resolution
- analytics computation
- reporting APIs
- notification triggers

---

### Benefit:
- scalability
- security
- performance

---

## 10.4.4 Role Hierarchy Expansion

### Future Roles:
- super admin
- organization admin
- mess manager
- supervisor
- auditor

---

## 10.4.5 Audit & Compliance Layer

### Scope:
- change logs
- approval tracking
- historical data auditing
- reporting for management

---

# 10.5 Data Model Evolution Strategy

---

## Rule 1:
No breaking schema changes in production

---

## Rule 2:
Use:
- additive changes only
- backward-compatible fields

---

## Rule 3:
If redesign needed:
- version collections
- migrate gradually

---

# 10.6 Feature Expansion Discipline

All future features must follow:

---

## Step 1:
Define feature in planning document

## Step 2:
Evaluate impact on:
- schema
- services
- UI

## Step 3:
Classify:
- V1 extension
- V2 feature
- long-term roadmap

## Step 4:
Implement only after:
- design approval
- scope alignment

---

# 10.7 Risks in Future Expansion

- uncontrolled feature addition
- schema drift
- breaking existing flows
- overloading UI with complexity

---

## Prevention:
- maintain command board discipline
- update schema appendix before changes
- enforce version boundaries

---

# 10.8 Long-Term Vision

The system should evolve into:

- a unified food service management platform
- covering:
  - mess
  - café
  - events
  - inventory
  - costing
  - analytics

---

## Final Vision:

> “A modular, scalable, multi-tenant platform capable of managing food services across organizations with controlled governance and real-time operational visibility.”

---

# 10.9 Final Strategic Principle

> “Expansion must be deliberate, not reactive. Every new feature must respect the architecture, not reshape it.”
## Architecture Diagram

```mermaid
flowchart TB

subgraph Presentation Layer
    A1[Admin Screens]
    A2[Employee Screens]
end

subgraph Service Layer
    S1[User Profile Service]
    S2[Menu Resolver Service]
    S3[Meal Reservation Service]
    S4[Meal Rate Service]
    S5[Feedback Service]
    S6[Notification Service]
    S7[Analytics Services]
end

subgraph Data Layer (Firestore)
    D1[users]
    D2[employees]
    D3[menu_items]
    D4[weekly_templates]
    D5[menu_cycles]
    D6[daily_menus]
    D7[meal_reservations]
    D8[meal_rates]
    D9[meal_feedback]
    D10[notifications]
    D11[events]
end

A1 --> S1
A1 --> S2
A1 --> S3
A1 --> S4
A1 --> S7

A2 --> S1
A2 --> S2
A2 --> S3
A2 --> S5
A2 --> S6

S1 --> D1
S1 --> D2

S2 --> D3
S2 --> D4
S2 --> D5
S2 --> D6

S3 --> D7
S4 --> D8
S5 --> D9
S6 --> D10
S7 --> D7
S7 --> D8
S7 --> D9

D11 --> S6


---

# 🔗 2. IDENTITY FLOW DIAGRAM (CRITICAL)

```md
## Identity Flow

```mermaid
flowchart LR

A[Firebase Auth UID]
--> B[users collection]

B --> C[employee_number]

C --> D[employees collection]

C --> E[employee_profiles]



👉 This is your **non-negotiable backbone**

---

# 🍽️ 3. MENU RESOLUTION FLOW

```md
## Menu Resolution Flow

```mermaid
flowchart LR

A[menu_items]
--> B[weekly_menu_templates]

B --> C[menu_cycles]

C --> D[menu_resolver_service]

D --> E[daily_menus]

E --> F[UI: Today Menu]



---

# 📅 4. WEEKLY TEMPLATE FLOW

```md
## Weekly Template Flow

```mermaid
flowchart TB

A[Select Meal Type]
--> B[Filter menu_items]

B --> C[Search + Food Type Filter]

C --> D[Select Items]

D --> E[Assign to Weekday]

E --> F[Save Template]

F --> G[weekly_menu_templates collection]



---

# 🧾 5. RESERVATION FLOW

```md
## Reservation Flow

```mermaid
flowchart LR

A[User selects menu]
--> B[today_menu_screen]

B --> C[meal_reservation_service]

C --> D[meal_reservations]

D --> E[Admin Issuance]

E --> F[Issued / Pending Status]


---

# 💰 6. RATE → COST FLOW

```md
## Rate & Cost Flow

```mermaid
flowchart LR

A[meal_reservations]
--> B[meal_rate_service]

B --> C[meal_rates]

C --> D[cost_analytics_service]

D --> E[Cost Dashboard]


---

# 💬 7. FEEDBACK FLOW

```md
## Feedback Flow

```mermaid
flowchart LR

A[Issued Meal]
--> B[Eligibility Check]

B --> C[User Feedback Submission]

C --> D[meal_feedback]

D --> E[Feedback Dashboard]


---

# 🔔 8. NOTIFICATION FLOW

```md
## Notification Flow

```mermaid
flowchart LR

A[Event / Reservation / Admin Action]
--> B[notification_service]

B --> C[notifications]

C --> D[notification_deliveries]

D --> E[User UI + Badge]


---

# 🎉 9. EVENT ATTENDANCE FLOW

```md
## Event Attendance Flow

```mermaid
flowchart LR

A[Event Created]
--> B[Notification Sent]

B --> C[User Response]

C --> D[event_attendance_responses]

D --> E[Aggregation Logic]

E --> F[event_attendance_summaries]


---

# 🧠 10. END-TO-END SYSTEM FLOW (MOST IMPORTANT)

This is your **full system lifecycle**

```md
## End-to-End Flow

```mermaid
flowchart TB

A[menu_items]
--> B[weekly_templates]

B --> C[menu_cycles]

C --> D[daily_menus]

D --> E[User Booking]

E --> F[meal_reservations]

F --> G[Issuance]

G --> H[meal_rates]

H --> I[Cost Analytics]

G --> J[Feedback]

J --> K[Feedback Dashboard]

I --> L[Analytics Dashboard]


---

# 🧩 11. FUTURE MULTI-TENANT ARCHITECTURE (FORWARD LOOK)

```md
## Future Multi-Tenant Architecture

```mermaid
flowchart TB

A[Tenant A]
B[Tenant B]
C[Tenant C]

A --> D[(Firestore)]
B --> D
C --> D

D --> E[Shared Services Layer]

E --> F[Admin Panels per Tenant]
E --> G[User Apps per Tenant]

---

# 🔥 HOW TO USE THESE

## Option 1 (Best for you now)
- Paste into your MD file
- Works in:
  - VS Code (with Mermaid plugin)
  - GitHub markdown preview

---

## Option 2 (For presentation)
- Import into:
  - draw.io
  - PowerPoint
  - Notion

---

# 🎯 FINAL RESULT

You now have:

### Documentation
✔ Full blueprint  
✔ Schema  
✔ Rebuild strategy  

### Visual Layer
✔ Architecture diagram  
✔ Flow diagrams  
✔ End-to-end lifecycle  

---

# 🧠 FINAL ADVICE

These diagrams are not just visuals.

They are:

👉 **debugging tools**  
👉 **training tools**  
👉 **scaling reference**  

---
