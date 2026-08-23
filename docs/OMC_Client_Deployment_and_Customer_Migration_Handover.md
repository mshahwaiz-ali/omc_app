OMC App — Client Installation & Existing Customer Migration

This guide is for installing the supplied OMC App on an existing Frappe / ERPNext v14 site.

The ERP site is assumed to already be running correctly. The client only needs to copy the supplied omc_app folder, install it on the site, run the required database migration, and then run the OMC existing-data migration.

Replace your.site.name below with the actual ERP site name.

1. Go to the Frappe Bench

cd /path/to/frappe-bench

Check the available sites:

bench list-sites

Set the site name once:

SITE="your.site.name"

Confirm the current installed apps:

bench --site "$SITE" list-apps

2. Take a Full Backup

Before installing or removing any app:

bench --site "$SITE" backup --with-files

Do not continue until the backup completes successfully.

3. Copy the OMC App Folder

Copy the supplied folder into:

frappe-bench/apps/omc_app

Confirm it is present:

ls apps/omc_app

Install/register the Python package in the Bench environment:

./env/bin/pip install -e apps/omc_app

Confirm the app can be imported:

./env/bin/python -c "import omc_app; print('OMC App import: OK')"

If omc_app is not already present in sites/apps.txt, add it:

grep -qxF 'omc_app' sites/apps.txt || echo 'omc_app' >> sites/apps.txt

4. Install OMC App on the ERP Site

bench --site "$SITE" install-app omc_app

Confirm:

bench --site "$SITE" list-apps

omc_app should now appear in the installed apps list.

5. Run Frappe Database Migration

bench --site "$SITE" migrate
bench --site "$SITE" clear-cache

Why is bench migrate required?

Copying the OMC folder only places the application code on the server.

bench migrate updates the ERP site's database and Frappe metadata so they match the installed OMC App. It applies the OMC DocTypes, fields, schema changes, patches, and other required site-level metadata.

In simple terms:

Copy OMC App
    ↓
Install OMC App
    ↓
bench migrate
    ↓
Database/site structure becomes ready for OMC

bench migrate does not migrate the client's historical customers, staff, or referral relationships. That is handled by the OMC data-migration command below.

6. Remove the Old Lead App (If Applicable)

If the old Lead app is still installed, first confirm its exact app name:

bench --site "$SITE" list-apps

Take another backup before removal:

bench --site "$SITE" backup --with-files

Then uninstall the old app using its actual app name:

bench --site "$SITE" uninstall-app OLD_APP_NAME --yes

After successful uninstall, remove its old folder from apps/ if required.

Then run:

bench --site "$SITE" migrate
bench --site "$SITE" clear-cache

Do not guess the old app name. Use the exact name shown by list-apps.

7. Run OMC Migration Preflight

Before writing historical data, run the read-only preflight:

bench --site "$SITE" execute   omc_app.api.customer_migration.preflight

Review the output, especially:

total_customers

safely_identifiable

activation_ready_import

deferred_claim_on_signup

identity_review

create_customer_profile

reuse_customer_profile

user_accounts_to_create

blocker_counts

warning_counts

user_accounts_to_create should remain:

0

The migration does not bulk-create customer login Users.

8. Take the Final Pre-Migration Backup

Immediately before the write migration:

bench --site "$SITE" backup --with-files

9. Run the OMC Existing-Data Migration

Run:

bench --site "$SITE" execute   omc_app.api.customer_migration.apply   --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100}'

This is the single migration command required after installation.

It automatically performs the required phases:

Synchronizes eligible existing internal staff.

Creates/updates OMC Staff Access.

Creates referral codes for eligible referral-capable staff.

Migrates or reuses safely identifiable OMC Customer Profiles.

Links historical customer referral relationships where they can be proven.

Creates historical acquisition attribution records.

Leaves ambiguous or unsafe records in review instead of guessing.

The migration is designed to be idempotent, so existing correct records are reused rather than duplicated.

It does not:

bulk-create Frappe Users;

change passwords;

enable disabled users;

promote Website Users into System Users;

force-link ambiguous customers;

guess missing historical referrers.

10. Verify the Migration Result

Run the read-only preflight again:

bench --site "$SITE" execute   omc_app.api.customer_migration.preflight

Confirm that:

safely migrated profiles are now being reused;

user_accounts_to_create is still 0;

any remaining blockers/review cases are expected exceptions rather than forced mappings.

If required, blocker details can be viewed with:

bench --site "$SITE" execute   omc_app.api.customer_migration.blocker_details

11. Clear Cache and Restart

After installation and data migration:

bench --site "$SITE" clear-cache
bench restart

Confirm the ERP site opens normally and that omc_app is installed:

bench --site "$SITE" list-apps

Final Deployment Flow

Existing ERPNext v14 Site
        ↓
Take Backup
        ↓
Copy omc_app to apps/omc_app
        ↓
Install OMC App
        ↓
bench migrate
        ↓
Remove old Lead app if applicable
        ↓
Run OMC migration preflight
        ↓
Take final backup
        ↓
Run ONE OMC migration command
        ↓
Clear cache + restart
        ↓
OMC backend is ready for use

Important Stop Conditions

Stop and investigate before continuing if:

install-app fails;

bench migrate fails;

the ERP site stops loading;

user_accounts_to_create is not 0;

the migration exits with an unexpected exception;

removing the old app removes required ERP metadata;

migration results differ materially from the reviewed preflight.

Do not manually force-link ambiguous identities. Use the latest backup if recovery is required.

Final Checklist

Full site backup completed

omc_app copied to apps/omc_app

OMC App installed on the correct site

bench migrate completed successfully

Old Lead app removed if applicable

Migration preflight reviewed

user_accounts_to_create = 0

Final backup taken

Unified OMC migration completed

Post-migration preflight reviewed

Cache cleared

Bench/services restarted

ERP site opens normally

omc_app appears in list-apps
