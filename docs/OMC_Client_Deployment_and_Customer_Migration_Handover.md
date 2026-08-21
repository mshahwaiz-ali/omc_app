OMC App - Client Installation & Customer Migration Guide

This guide is for installing the new OMC App on the existing ERPNext/Frappe site and migrating existing ERP customers into OMC Customer Profiles.

Replace <site> with the actual ERP site name before running the commands.

1. Go to the Frappe Bench

cd /path/to/frappe-bench

Confirm the site and installed apps:

bench list-sites
bench --site <site> list-apps

The client ERP should remain on Frappe / ERPNext v14.

2. Take a Full Backup

Before installing or removing any app, take a backup.

bench --site <site> backup --with-files

Do not continue until the backup is complete.

3. Place the OMC App in the Bench

Copy the supplied omc_app folder into:

frappe-bench/apps/omc_app

Then install the Python package if required:

./env/bin/pip install -e apps/omc_app

Confirm that the app imports correctly:

./env/bin/python -c "import omc_app; print('OMC App import: OK')"

4. Install OMC App on the ERP Site

bench --site <site> install-app omc_app

Then run:

bench --site <site> migrate
bench --site <site> clear-cache

Confirm installation:

bench --site <site> list-apps

omc_app should appear in the installed apps list.

Important

bench migrate does not bulk-create historical OMC customer profiles.

Historical customer migration is a separate controlled operation described below.

5. Validate ERP Compatibility

Run the OMC ERP compatibility check:

bench --site <site> execute omc_app.setup.operations.validate_site

Expected result should contain:

compatible: true

If validation fails, stop and resolve the reported ERP contract issue before continuing.

6. Remove the Old Lead App

Only remove the old lead_app after OMC App has been installed and compatibility validation has passed.

First take another backup if desired:

bench --site <site> backup --with-files

Uninstall the old app:

bench --site <site> uninstall-app lead_app --yes

Then remove its app folder only after successful uninstall:

rm -rf apps/lead_app

Run migration and clear cache:

bench --site <site> migrate
bench --site <site> clear-cache

Run the compatibility check again:

bench --site <site> execute omc_app.setup.operations.validate_site

If this validation fails after removing lead_app, stop and restore/review the ERP metadata before going further.

Existing Customer Migration

The migration is designed to be safe and idempotent.

It:

creates OMC Customer Profiles only for safely identifiable existing ERP customers;

does not bulk-create Frappe Users;

does not change passwords;

does not convert internal/System Users into customers;

skips ambiguous customer identities for manual review;

can be safely re-run without duplicating migrated profiles.

7. Run Customer Migration Dry Run

This command is read-only:

bench --site <site> execute omc_app.api.customer_migration.dry_run

Review the returned counts before continuing.

8. Run Migration Preflight

This command is also read-only:

bench --site <site> execute omc_app.api.customer_migration.preflight

Check these fields carefully:

create_customer_profile
reuse_customer_profile
user_accounts_to_create
blocker_counts
warning_counts
identity_review

user_accounts_to_create should remain:

0

9. Review Blocked Customers

To inspect migration collision/blocker cases:

bench --site <site> execute omc_app.api.customer_migration.blocker_details

Internal/System User identity collisions must remain manual-review cases.

Do not force-link these customers automatically.

10. Review Ambiguous Customer Identities

To view customers that require identity review:

bench --site <site> execute omc_app.api.customer_migration.identity_review_details \
  --kwargs '{"offset":0,"limit":100}'

For the next page:

bench --site <site> execute omc_app.api.customer_migration.identity_review_details \
  --kwargs '{"offset":100,"limit":100}'

The report intentionally does not print raw email, CNIC, phone, or tax identifiers.

The referenced ERP Customer/Lead records can be reviewed manually where required.

11. Take the Final Pre-Migration Backup

Immediately before the write operation:

bench --site <site> backup --with-files

12. Apply the Customer Migration

Run only after the dry run and preflight have been reviewed.

bench --site <site> execute omc_app.api.customer_migration.apply \
  --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100,"commit":True}'

Important

Use Python-style True exactly as shown above.

Do not replace it with lowercase true on this Frappe v14 setup.

The migration will skip blocked and ambiguous customers instead of guessing their identity.

13. Verify Migration

Run preflight again:

bench --site <site> execute omc_app.api.customer_migration.preflight

After a successful full migration, safely migrated profiles should normally move from:

create_customer_profile > 0

to:

create_customer_profile: 0
reuse_customer_profile: <number already migrated>

And:

user_accounts_to_create: 0

should remain unchanged.

14. Optional Idempotency Check

The migration is designed to be re-runnable.

Running the same apply command again should reuse existing profiles rather than create duplicates:

bench --site <site> execute omc_app.api.customer_migration.apply \
  --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100,"commit":True}'

Expected behavior:

profiles_created: 0
profiles_reused: <already migrated profiles>
user_accounts_created: 0

15. Restart / Clear Cache

After deployment and migration:

bench --site <site> clear-cache
bench restart

If the production environment uses Supervisor/Nginx, verify the services are healthy after restart.

Reference from the Tested Client Database Rehearsal

The local rehearsal performed before handover produced these results:

Total ERP Customers:                 4,886
Safely identifiable:                4,717
Activation-ready email customers:   3,245
Profiles safely migrated:           3,236
Deferred claim-on-signup:           1,472
Identity review:                      169
Internal-user hard blockers:            9
Mobile collision warnings:              8
Frappe Users bulk-created:               0

After migration:

create_customer_profile: 0
reuse_customer_profile: 3236
user_accounts_to_create: 0

A complete second migration run created:

profiles_created: 0
profiles_reused: 3236
user_accounts_created: 0

These figures are a reference from the tested dataset. The production site should always use its own dry_run and preflight output as the authoritative result.

Final Checklist

Before declaring deployment complete, confirm:

Full site backup completed.

OMC App folder is present in apps/omc_app.

omc_app is installed on the site.

bench migrate completed successfully.

OMC ERP compatibility validation passed.

Old lead_app was removed only after compatibility validation.

Compatibility validation still passes after old app removal.

Customer migration dry_run reviewed.

Customer migration preflight reviewed.

Hard blockers and identity-review cases were not force-migrated.

Final backup was taken before migration apply.

Customer migration apply completed successfully.

Post-migration preflight shows no remaining safe profiles to create.

No Frappe Users were bulk-created by migration.

Cache/restart completed and ERP site is working normally.

Stop Conditions

Stop the deployment and investigate before continuing if:

OMC compatibility validation fails;

bench migrate fails;

the site cannot load after an app change;

customer migration reports unexpected blockers;

user_accounts_to_create is not 0;

the migration result differs materially from the reviewed preflight;

required ERP fields disappear after removing the old app.

Use the latest backup for recovery if a deployment step causes an unexpected site or database issue.