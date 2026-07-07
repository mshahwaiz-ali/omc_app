1. App ka simple client-facing explanation

Client ko aise samjhao:

“OMC House mobile app customers ke liye ek digital service portal hai. Customer app se OMC services browse karta hai, account banata hai, required documents upload karta hai, service request submit karta hai, apni request ka status track karta hai, payment/receipt upload karta hai, support ticket raise karta hai, notifications receive karta hai, tax calculator aur expense tracker use karta hai. OMC staff backend/Frappe se customer profiles, service requests, documents, payments, leads, tasks aur support tickets manage karta hai.”

App ke core modules README mein listed hain: Authentication, Home, Service Catalogue, Service Request, My Services/case tracking, Documents, Payments, Tax Calculator, Expense Tracker, Support, Notifications, Knowledge/News, Profile, Settings, Internal Workspace, Leads, Customers, Tasks.

2. User categories — kis type ka user kya kar sakta hai
A. Guest user

Guest woh user hai jo login/signup se pehle app open karega.

Guest kya kar sakta hai
Feature	Guest access
Login screen	Yes
Signup screen	Yes
Service catalogue	Backend API guest allowed hai
Knowledge/news	Guest allowed hai
Tax calculator	Guest allowed hai
Support config / contact channels	Guest allowed hai
Personal dashboard, documents, payments, my services	No, login required

Router ke hisaab se agar user authenticated nahi hai aur protected route kholta hai, app usay /login par bhej deti hai.

Backend side pe service catalogue allow_guest=True hai, yani services list public dikha sakte hain.

B. Signup user / Pending customer

Signup screen par user ye data deta hai:

Field	Purpose
Full name	Customer/applicant identity
Email	Login ID
Mobile number	Contact
WhatsApp number	Communication
CNIC	Verification
Register as	Customer, Consultant, Business Partner, Tax Associate
Address	Contact/address record
Password	App login
Tax Associate extra fields	Education, experience, remarks

Frontend signup form roles define karta hai: Customer, Consultant, Business Partner, Tax Associate.
Signup frontend ye role customer_type aur register_as mein backend ko bhejta hai.

Backend signup abhi kya karta hai

Backend signup:

Email validate karta hai.
Agar Frappe User nahi hai to new Website User create karta hai.
Password set karta hai.
OMC Customer Profile create/update karta hai.
Profile ka customer_status = Pending aur approval_status = Pending Review set karta hai.
Preferences create karta hai.

Important point: backend current code mein customer_type, register_as, address, education, experience, remarks, whatsapp_no ko properly save karta hua visible nahi hua. Signup screen ye fields bhej rahi hai, lekin backend sign_up() mostly email, password, full_name, phone, company_name, cnic, ntn hi read kar raha hai.

Client ko kya bolna chahiye?

Client ko bolo:

“Signup ke baad user ka profile automatically approved nahi hota. System usay Pending Review state mein rakhta hai. OMC team backend mein profile review karegi, documents/identity/role verify karegi, phir customer ko active/approved access degi.”

Lekin technical sach ye hai: abhi code user ko enabled Website User banata hai, aur password set hone ke baad woh login kar sakta hai. Profile pending hai, lekin current backend ne pending user ko app ke customer features se fully block nahi kiya. Isliye consultant/applicant wali concern valid hai.

3. Consultant / Tax Associate issue — “apply kar diya to app open na ho”

Ye sab se important security/business point hai.

Current behavior

Signup screen mein consultant/tax associate role option hai.
Lekin backend sign_up() mein user enabled create hota hai:

user.enabled = 1
user.user_type = "Website User"

Aur profile pending status set hota hai:

customer_status = Pending
approval_status = Pending Review
Risk

Agar koi “Consultant” ya “Tax Associate” ban ke apply kare, to:

account create ho sakta hai,
login ho sakta hai,
normal customer area tak access mil sakta hai,
lekin internal workspace nahi milega, kyunki internal workspace sirf System Manager role se allowed hai.
Recommended final rule

Client ko ye model explain karo:

Signup ke baad 3-stage approval flow hona chahiye
Stage	Status	User access
Applied	Pending Review	Sirf limited screen: “Application under review”
Approved Customer	Approved	Services, documents, payments, support
Approved OMC User / Consultant	Approved + role assigned	Internal/assigned modules only
Best production approach

Backend mein ye enforce hona chahiye:

Customer signup
User profile pending rahe, app login kar sakta hai ya nahi — business decision.
Consultant / Tax Associate signup
App ka full customer dashboard na khule. Sirf “Your application is under review” screen dikhe.
OMC approval from Frappe
Admin profile approve kare, role assign kare, active flag set kare.
Role based feature access
Flutter UI sirf hide na kare; backend API bhi permission check kare.

Repo roadmap bhi ye rule mention karta hai: backend permissions real protection honi chahiye, UI hiding alone security nahi hai.

4. Login/session ka workflow
Login kaise hota hai
User email/password enter karta hai.
Flutter FrappeClient Frappe ke standard /api/method/login par request bhejta hai.
Frappe session cookie return karta hai.
App cookie secure storage mein save karti hai.
App get_session_user() call karti hai.
Backend user roles + internal workspace permission return karta hai.
Router authenticated user ko /home par bhej deta hai.

Dio client har request ke saath session cookie ya API token attach karne ke liye interceptor use karta hai.

Session restore

App restart hone par secure storage se user/session read hota hai, phir backend se session verify hota hai. Agar session invalid ho to local session clear ho jata hai.

5. Main app navigation — app ke menus

Bottom navigation mein 5 primary tabs hain:

Tab	Purpose
Home	Dashboard shortcuts
Services	Service catalogue
Track	My Services / service cases
Docs	Customer documents
More	Extra modules/settings/support

Code mein ye tabs defined hain: Home, Services, Track, Docs, More.

More menu groups

More screen mein ye groups hain:

Account
Menu	Kaam
Profile	Personal info/account details
Notifications	Service updates/tax alerts
Settings	Theme, notification preferences, language
Services
Menu	Kaam
Dashboard	Service summary, docs, activity
Payments	Invoices, dues, receipt uploads
Tax Calculator	Salary tax estimate
Knowledge & News	Tax guides/FBR updates/OMC news
Personal Expense Tracker	Income/expense/balance tracking
Help
Menu	Kaam
Support	Tickets, WhatsApp, contact channels
Workspace

Internal Workspace sirf tab dikhta hai jab:

user ke paas backend permission ho, aur
backend mobile config mein internal workspace enabled ho.

Abhi backend config mein internal_workspace_enabled: False hai. Iska matlab System Manager role ke bawajood mobile app mein internal workspace hidden reh sakta hai jab tak config true na ho.

6. Services workflow — customer service kaise request karega

Client ko ye flow dikhao:

Customer login/signup
        ↓
Services tab
        ↓
Service catalogue se service select
        ↓
Service detail / required documents dekhe
        ↓
Request form fill kare
        ↓
Backend OMC Service Request banata hai
        ↓
Documents upload hotay hain
        ↓
Customer My Services mein tracking dekhta hai
        ↓
OMC team backend se status update karti hai
        ↓
Customer notifications/timeline mein updates dekhta hai

README mein typical customer flow bhi exactly ye define karta hai: login, home, service select, request form, required documents, backend case creation, file upload, My Services tracking, payments/documents/notifications updates.

Backend mein service request kaise banti hai

create_service():

current user ka customer profile nikalta hai,
selected service resolve karta hai,
OMC Service Request create karta hai,
status Open set karta hai,
customer profile/name/email/phone attach karta hai,
timeline entry “Request Created” banata hai.
7. Service tracking kaise kaam karti hai

Customer My Services mein apni service cases dekhta hai.

Backend get_service_cases():

current customer profile nikalta hai,
sirf us profile ki OMC Service Request list return karta hai,
title, status, priority, service, description, dates return karta hai.

Detail screen mein backend:

case status,
progress percent,
next step,
required/submitted/missing documents,
timeline,
customer action required,
internal capabilities return karta hai.

Status mapping:

Status	Progress
Open	10%
Waiting for Customer	35%
In Progress	60%
Under Review	80%
Completed	100%
Cancelled	0%
8. Documents/images/files kahan jaati hain?
Upload flow

File upload two-step hai:

App pehle Frappe upload_file endpoint call karti hai.
File Frappe File system mein private file ke طور پر attach hoti hai.
Phir app/backend us file URL ko OMC Service Document ya OMC Service Payment record mein save karta hai.

Flutter upload method doctype, docname, is_private, aur file multipart ke saath /api/method/upload_file call karta hai.

Configured upload doctypes:

Upload type	Doctype
Service request attachment	OMC Service Request
Customer document record	OMC Service Document
Payment receipt	OMC Service Payment
Document upload rules

Backend document upload mein:

allowed file types: PDF, JPG, JPEG, PNG, DOC, DOCX,
max size: 10 MB,
max files per case: 20,
file owner check,
wrong service request/file reuse block,
file private force karta hai.

upload_service_document() phir OMC Service Document create karta hai aur timeline entry “Document Uploaded” banata hai.

Payment receipt upload rules

Payment receipts ke liye allowed files: PDF, JPG, JPEG, PNG; max 10 MB. Backend receipt ko OMC Service Payment se attach karta hai aur private enforce karta hai.

9. Payments workflow

Client ko bolo:

“OMC backend customer ke service request ke against payment/invoice record banata hai. Customer app mein pending payment dekhta hai, receipt upload karta hai. OMC staff receipt review karke payment ko Paid/Rejected/Under Review mark karta hai.”

Customer payment list sirf uski service requests ke related OMC Service Payment records return karti hai.

Receipt upload ke baad payment status Receipt Submitted hota hai aur service timeline mein update add hota hai.

Internal user payment receipt review kar sakta hai; allowed statuses: Under Review, Paid, Rejected, Cancelled. Paid/Rejection ke liye receipt required hai.

10. Notifications workflow

Notifications OMC Notification DocType se aati hain.

Customer ko visible notifications milti hain based on:

customer profile,
recipient user,
visible_to_customer flag,
read/unread status.

Notification detail open karne par backend usay read mark kar deta hai.

Payment review aur support ticket status changes customer notification create karte hain.

11. Support workflow

Support module mein customer:

support config dekhta hai,
WhatsApp/phone/email channel dekhta hai,
support ticket create karta hai,
ticket replies add karta hai,
ticket status follow karta hai.

Backend fallback support channels provide karta hai: WhatsApp, phone, email.

Support topics bhi backend se aate hain: Income Tax, POS & Digital Invoicing, Sales Tax, Technical Support, Payment Support.

create_support_ticket() ticket create karta hai with subject, message, priority, customer profile, contact details, optional service request reference.

Customer reply add kar sakta hai; closed/cancelled ticket par reply block hoti hai.

OMC internal user ticket status update kar sakta hai; status options: Open, Waiting for Customer, Resolved, Closed, Cancelled.

12. Settings workflow

Settings backend mein OMC Customer Preference se linked hain.

Default preferences:

Setting	Default
Service updates	On
Document reminders	On
Payment alerts	On
Tax alerts	On
Email notifications	On
WhatsApp notifications	On
Theme	system
Language	en

Update API allowed fields:

service updates,
document reminders,
payment alerts,
tax alerts,
email notifications,
WhatsApp notifications,
theme: system/light/dark,
language.

Client ko bolo:

“Settings user-specific hain. Customer apne notification preferences aur theme/language update kar sakta hai. Backend preferences save karta hai, isliye same account par settings persistent rahengi.”

13. Internal Workspace — OMC staff perspective

Internal workspace ka purpose:

Leads
Customers
Tasks
Open services
Support tickets
Documents
Payments due
Unread notifications

Backend summary ye counts return karta hai.

Current permission rule

Abhi backend mein internal workspace sirf System Manager role ke liye allowed hai.

Yani current repo mein “OMC Manager”, “OMC Staff”, “Support Agent”, “Document Reviewer” jaisi dedicated roles final nahi dikh rahi. Production ke liye ye add karna best hoga.

OMC staff kya karega
Role idea	App/backend work
OMC Admin	Users, roles, services, system config
OMC Manager	Service case status, tasks, customer follow-up
Support Agent	Support tickets, replies, customer contact
Document Reviewer	Uploaded docs approve/reject
Payment Reviewer	Receipt review, payment status
Sales/CRM user	Leads, customers, tasks

Current backend APIs internal actions protect karte hain. Example: service case status update aur document approval/rejection secured API mein internal access check ke baad hi hota hai.

14. Leads/customers/tasks workflow
Leads

Internal user lead create/list/detail kar sakta hai.

create_lead() internal access require karta hai aur title/name/company/email/phone/source/service_interest/notes save karta hai.

Customers

Internal user all OMC Customer Profile records list/detail dekh sakta hai: name, email, phone, company, CNIC, NTN, status, approval status, active flag.

Tasks

Internal user tasks list/detail dekh sakta hai: title, status, priority, due date, assigned_to, customer_profile, service_request, support_ticket.

15. Tax calculator

Tax calculator guest/public API hai. User monthly/yearly income deta hai, backend estimated tax calculate karta hai. Response explicitly bolta hai estimate only, filing ke liye verified nahi.

Client ko bolo:

“Tax calculator user ko quick estimate deta hai, final filing advice nahi. OMC team final tax verification karegi.”

16. Expense tracker

Expense tracker logged-in customer ke profile se linked hai.

Features:

categories list,
income/expense entries,
create/update/delete entry,
income/expense/balance summary.

Client ko bolo:

“Expense tracker customer ke personal finance tracking ke liye hai. User income/expense entries save karta hai, app summary show karti hai.”

17. Backend/Frappe mein kaam kaise hoga

Frappe mein main DocTypes conceptually ye honge:

Doctype	Purpose
OMC Customer Profile	Customer/applicant profile
OMC Customer Preference	Settings/preferences
OMC Service	Service catalogue
OMC Service Required Document	Service-wise required docs
OMC Service Request	Customer service case
OMC Service Document	Uploaded customer docs
OMC Service Payment	Payment/receipt tracking
OMC Service Timeline	Case updates/tracking
OMC Notification	Customer notifications
OMC Support Ticket	Support/helpdesk
OMC Support Channel	WhatsApp/phone/email config
OMC Support Topic	Support categories
OMC Lead	CRM leads
OMC Task	Internal tasks
OMC Expense Entry	Customer expense tracker
OMC Push Token	Push notification device tokens

Ye names repo APIs se directly appear ho rahe hain.

18. Client ko batane ke liye final polished pitch
One-liner

OMC House App ek customer service + compliance portal hai jahan customer OMC services request, documents, payments, support, tax tools aur service tracking mobile se manage karta hai, aur OMC team Frappe backend se poora operation control karti hai.

Business value
For customer	For OMC team
Services mobile se request	Manual WhatsApp/file chaos kam
Required documents clear	Documents service case se attached
Status tracking	Timeline aur status centralized
Payment receipt upload	Payment review workflow
Support ticket	Support history maintained
Notifications	Customer follow-up automatic
Profile/settings	Customer data organized
Tax/expense tools	App utility/value increase
Knowledge/news	OMC authority/content channel


20. Recommended final approval model

Boss, client ko confidently explain karne ke liye ye model use karo:

Signup
  ↓
OMC Customer Profile: Pending Review
  ↓
OMC Admin reviews in Frappe
  ↓
Decision:
  ├── Reject / Keep Pending → user sees limited under-review screen
  ├── Approve as Customer → services/docs/payments/support access
  ├── Approve as Consultant / Tax Associate → applicant/partner workflow only
  └── Approve as OMC Staff → internal role assigned, workspace access

Backend enforcement required:

Rule	Backend action
Pending user	Block service create/payment/doc upload or show limited profile
Customer approved	Allow customer modules
Consultant applicant	No customer data/internal workspace
OMC staff	Role-based permission
Internal actions	Server-side role check
Documents/payments	File ownership + private file checks
Final summary

App ka main flow strong hai: login, service catalogue, service request, file upload, tracking, payments, notifications, support, settings, internal workspace foundation.
Security direction bhi sahi hai: internal workspace backend role check se protected hai.
Main pending production fix: signup approval ko enforce karna hoga, warna consultant/tax associate apply karke normal customer app access le sakta hai. Current profile pending hota hai, but login/access block fully implemented nahi dikh raha.

# OMC App — Updated User Access, Guest Mode, Signup Approval & Backend-Driven Content Plan

## 1. Guest Mode ka final approach

App open hote hi user ko direct login wall par force nahi karenge. App mein **“Continue as Guest”** option add hoga.

Guest user app explore kar sakega, lekin sensitive ya action-based features locked rahenge.

### Guest user ko kya allow hoga

Guest user ye cheezen dekh/use kar sakega:

* Home / public app intro
* Services catalogue preview
* Knowledge / tax awareness / news
* Tax calculator
* Support contact information
* Public service information
* Subscription / package information

### Guest user ke liye locked features

Guest user ye features use nahi kar sakega:

* Service request create karna
* My Services / service tracking
* Documents upload/view
* Customer dashboard
* Support ticket create karna
* Internal/customer-specific notifications
* Customer-specific data

UI mein ye features ya to hidden honge ya locked card ke form mein show honge. Jab guest locked feature par click karega to app usay message show karegi:

> “Please create an account or subscribe to access this feature.”

Yahan se user signup/login/subscription flow par ja sakta hai.

---

## 2. Guest user ka backend record

Guest mode mein bhi app ek temporary/guest identity maintain karegi.

Purpose:

* Analytics ke liye
* Guest activity track karne ke liye
* Later conversion ke liye
* Device/session mapping ke liye

Backend mein guest ke liye ek lightweight record create ho sakta hai, example:

* Guest ID: `GUEST-10001`
* Device ID
* App version
* Platform
* First opened date
* Last active date
* Interested services
* Conversion status

Lekin guest ko actual service request create karne ki permission nahi hogi.

---

## 3. Signup approval ka final rule

Signup ke baad user ko instantly full customer access nahi milega.

Jab user signup karega, backend mein uska profile create hoga with status:

* `customer_status = Pending`
* `approval_status = Pending Review`

Jab tak backend team user ko verify/approve nahi karti, app us user ko **limited verified-pending user** treat karegi. Practically uska access guest jaisa hoga, lekin profile backend mein available hogi.

### Pending user ko kya milega

Pending user:

* Login kar sakta hai
* Basic profile screen dekh sakta hai
* Public services dekh sakta hai
* Knowledge/tax calculator use kar sakta hai
* Verification status dekh sakta hai

Pending user nahi kar sakega:

* Service request create
* Documents upload
* My Services track
* Customer dashboard access
* Customer-specific support ticket create

App message show karegi:

> “Your account is under review. OMC team will verify your profile before enabling service access.”

---

## 4. Approved customer access

Backend team jab user verify karegi, then profile status update hoga:

* `customer_status = Active`
* `approval_status = Approved`
* role: `OMC Customer`

Approved customer ko full customer features milenge:

* Service request create
* My Services / tracking
* Required documents upload
* Service documents view
* Customer dashboard
* Notifications
* Support tickets
* Profile/settings
* Tax calculator
* Expense tracker
* Knowledge/news

---

## 5. Consultant / Tax Associate / Business Partner signup flow

Signup screen mein user register as select karega:

* Customer
* Consultant
* Business Partner
* Tax Associate

Agar koi user Consultant, Business Partner ya Tax Associate ke طور par signup karta hai, to usay direct app access nahi milega.

### Flow

```text
Signup
  ↓
Profile created as Pending Review
  ↓
OMC team backend mein review karegi
  ↓
Role verify/adjust karegi
  ↓
Approve ya reject karegi
  ↓
Approved role ke hisaab se app access milega
```

Agar user ne galat role select kiya ho, OMC admin backend mein role change kar sakega before approval.

Example:

* User ne “Consultant” select kiya
* Backend team dekhti hai ke woh actually customer hai
* Admin uska role `OMC Customer` kar dega
* Approve karne ke baad usay customer features milenge

---

## 6. Role-based access final rule

Security sirf Flutter UI par depend nahi karegi.

Final rule:

* UI se feature hide/lock hoga
* Backend se bhi permission check hoga

Matlab agar koi API direct hit kare, phir bhi backend unauthorized action block karega.

### Roles suggestion

Frappe mein ye roles banane chahiye:

| Role                  | Purpose                            |
| --------------------- | ---------------------------------- |
| OMC Customer          | Approved customer                  |
| OMC Pending User      | Signup done but not verified       |
| OMC Consultant        | Approved consultant                |
| OMC Business Partner  | Approved partner                   |
| OMC Tax Associate     | Approved tax associate             |
| OMC Support Agent     | Support tickets handle karega      |
| OMC Document Reviewer | Documents verify karega            |
| OMC Service Manager   | Service cases/status manage karega |
| OMC Admin             | Full OMC control                   |
| System Manager        | Frappe/system admin                |

---

## 7. Har user ka data separate aur linked hoga

Har user/customer ka data backend mein properly linked hoga.

Example:

```text
User: user10001@example.com
  ↓
OMC Customer Profile: CUST-10001
  ↓
Service Requests
  ↓
Documents
  ↓
Support Tickets
  ↓
Notifications
  ↓
Expense Entries
  ↓
Activity Timeline
```

Backend mein OMC team customer profile open karegi to us user se linked data easily visible hona chahiye:

* Basic profile
* Signup role
* Approval status
* Services requested
* Documents uploaded
* Support tickets
* Notifications
* Activity history
* Assigned staff/tasks
* Notes/remarks
* Verification decision

Isse OMC team ko proper customer history mil jayegi.

---

## 8. Service request access rule

Service request sirf approved customer ko allow hogi.

Guest aur pending user ko service request create karne ki permission nahi hogi.

Reason:

* Random app download karne wala service spam na kare
* OMC ko verified user ka record mile
* Har service request proper customer profile se linked ho
* Backend mein traceability rahe

### Final rule

| User type                        | Service request create               |
| -------------------------------- | ------------------------------------ |
| Guest                            | No                                   |
| Pending user                     | No                                   |
| Approved customer                | Yes                                  |
| Consultant/Partner/Tax Associate | Role-specific, approval ke baad      |
| OMC internal user                | Backend/internal workflow ke through |

---

## 9. Backend-driven services

Services hardcoded nahi honi chahiye.

Frappe backend mein `OMC Service` DocType hoga. OMC team Frappe se services manage karegi:

* Service title
* Description
* Category
* Price/fee label
* Completion time
* Required documents
* Service icon
* Featured status
* Active/inactive status
* Sort order
* Service instructions

Mobile app service cards backend se data fetch karenge. Agar OMC team service change karegi, app update ke bina service card update ho jayega.

This is better because:

* App redeploy ki zarurat nahi hogi
* OMC admin services khud manage kar sakega
* Seasonal/new services easily add hongi
* Pricing/description/update backend se control hoga

---

## 10. Knowledge, tax alerts, news and updates backend-driven

Knowledge/news/tax alerts bhi hardcoded nahi hone chahiye.

Frappe mein separate DocTypes ban sakte hain:

### Suggested DocTypes

| Doctype                 | Purpose                                          |
| ----------------------- | ------------------------------------------------ |
| OMC Knowledge Article   | Guides, tax help, service education              |
| OMC Tax Alert           | FBR/tax updates and reminders                    |
| OMC App Banner          | Home screen banners                              |
| OMC Announcement        | General announcements                            |
| OMC FAQ                 | Frequently asked questions                       |
| OMC Service Category    | Service grouping                                 |
| OMC Subscription Plan   | Paid/locked feature packages                     |
| OMC Feature Access Rule | Which role/subscription can access which feature |

Isse OMC team backend se content manage karegi. Mobile app automatically latest content show karegi.

---

## 11. Subscription / locked feature plan

Guest aur non-subscribed users ke liye kuch premium features locked show kiye ja sakte hain.

Example:

* Advanced tax tools
* Detailed reports
* Expense tracker advanced features
* Premium knowledge content
* Consultant support
* Priority support
* Business compliance package

Locked card par click karne se user ko subscription/package screen show hogi.

Example message:

> “This feature is available for subscribed customers. Please choose a package to continue.”

Backend mein `OMC Subscription Plan` aur `OMC Customer Subscription` type DocTypes ban sakte hain.

---

## 12. Signup email notifications

Signup ke baad email workflow add karna hai.

### User ko email

Signup ke baad user ko email jae:

> “Your OMC account has been created. Your profile is under review. OMC team will notify you after verification.”

### OMC team ko email

OMC admin/support team ko email jae:

> “New signup received. Please review and approve/reject the user.”

Email mein user details hon:

* Name
* Email
* Phone
* WhatsApp
* CNIC
* Register as
* Address
* Education/experience if Tax Associate
* Signup date

### Approval ke baad email

Jab backend team approve kare:

> “Your OMC account has been verified. You can now access OMC services.”

### Rejection/pending info email

Agar reject ya more information required ho:

> “Your OMC account needs additional verification. Please contact OMC support or update your information.”

---

## 13. Payment module clarification

OMC app ka payment module abhi direct payment collection ke liye nahi hoga.

App payment gateway se money collect nahi karegi.

Instead, agar future mein zarurat ho, payment module ka use sirf tracking ke liye hoga:

* OMC team payment/invoice/due record create kare
* Customer due/payment instruction dekhe
* Customer receipt/proof upload kare
* OMC team backend se receipt verify kare
* Status update ho: Pending, Receipt Submitted, Paid, Rejected

Agar abhi OMC payment collect nahi karna chahti, to Payments feature hidden/disabled rakha ja sakta hai.

---

## 14. Final user hierarchy

```text
Guest
  ↓
Signed up / Pending Review
  ↓
Approved Customer
  ↓
Subscribed Customer / Premium Customer
```

Separate internal side:

```text
OMC Admin
OMC Manager
OMC Support Agent
OMC Document Reviewer
OMC Tax Associate
OMC Consultant
OMC Business Partner
```

---

## 15. Final workflow summary

```text
Guest opens app
  ↓
Explores services, knowledge, calculator
  ↓
Tries locked feature
  ↓
App asks login/signup/subscription
  ↓
User signs up
  ↓
Backend creates pending customer profile
  ↓
OMC team receives email notification
  ↓
OMC team verifies user in Frappe
  ↓
Role/status approved
  ↓
User gets approval email
  ↓
Approved features unlock
  ↓
User creates service request
  ↓
Documents upload
  ↓
OMC team processes case
  ↓
Timeline/notifications update customer
```

---

## 16. Implementation decision

Final decision:

* Guest mode will exist.
* Guest can explore but cannot create service requests.
* Signup users stay pending until backend approval.
* Pending users get limited/guest-like access.
* Approved customers can use service workflows.
* Consultant/partner/tax associate users require backend approval.
* Flutter will hide/lock features.
* Backend will also enforce permissions.
* Services, knowledge, tax alerts, announcements and subscription content will be backend-driven through Frappe DocTypes.
* User data will be linked through `OMC Customer Profile`.
* Email notifications will be added for signup, internal review and approval.
* Payment collection will not be active unless explicitly required; payment section can be hidden or used only for receipt/status tracking.
