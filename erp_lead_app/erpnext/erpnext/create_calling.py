import frappe
from frappe.utils.background_jobs import enqueue

@frappe.whitelist()
def trigger_bulk_calling_creation(customer_list):
    if not customer_list:
        frappe.throw("No customers selected.")

    if isinstance(customer_list, str):
        import json
        customer_list = json.loads(customer_list)

    enqueue(
        method="erpnext.create_calling.process_customer_calling_queue",
        queue="long",
        timeout=3000,
        customer_list=customer_list,
        now=frappe.flags.in_test
    )
    
    frappe.msgprint("Bulk calling creation has been queued. Existing 2026 records will be automatically skipped.")
    return {"status": "queued"}


def process_customer_calling_queue(customer_list):
    # 1. Look up existing logs using your field mapping layout ('client' instead of 'customer')
    existing_records = frappe.get_all(
        "Calling", 
        filters={
            "year": "2026",
            "client": ["in", customer_list]
        },
        fields=["client"],
        pluck="client"
    )
    already_created = set(existing_records)
    filtered_customer_list = [cust for cust in customer_list if cust not in already_created]
    
    if not filtered_customer_list:
        return

    # 2. Fetch all missing attributes including 'contact_no' for the dynamic mobile mapping
    customer_data = frappe.get_all(
        "Customer",
        filters={"name": ["in", filtered_customer_list]},
        fields=["name", "service_type", "sales_person", "contact_no"]
    )
    customer_map = {cust["name"]: cust for cust in customer_data}

    # 3. Safe database operations loop
    chunk_size = 200
    today = frappe.utils.getdate() # Safe date processing in background workers
    
    for i in range(0, len(filtered_customer_list), chunk_size):
        chunk = filtered_customer_list[i:i + chunk_size]
        
        for customer in chunk:
            try:
                details = customer_map.get(customer, {})
                
                doc = frappe.get_doc({
                    "doctype": "Calling",
                    "date": today,
                    "client": customer,
                    "mobile_no": details.get("contact_no") or "",
                    "year": "2026",
                    "calling_source": "Customer",
                    "cnic_ntn": "tax_id",
                    "status": "Pending",
                    "service_type": details.get("service_type"),
                    "sales_person": details.get("sales_person")
                })
                doc.insert(ignore_permissions=True)
                
            except Exception as e:
                frappe.log_error(
                    title=f"Failed to create calling record for {customer}",
                    message=frappe.get_traceback()
                )
        
        frappe.db.commit()

@frappe.whitelist()
def sync_missing_calling_details():
    """
    Triggers a background worker to find and patch historical calling logs
    with missing Customer fields.
    """
    enqueue(
        method="erpnext.create_calling.process_sync_missing_details",
        queue="long",
        timeout=3000,
        now=frappe.flags.in_test
    )
    return {"status": "queued"}


def process_sync_missing_details():
    """
    Background worker that fetches incomplete Calling entries and patches them.
    """
    # 1. Fetch all 2026 records where fields are empty, missing, or null
    incomplete_logs = frappe.db.sql("""
        SELECT name, client 
        FROM `tabCalling` 
        WHERE year = '2026' 
          AND (mobile_no IS NULL OR mobile_no = '' 
               OR sales_person IS NULL OR sales_person = '' 
               OR service_type IS NULL OR service_type = ''
               OR cnic_ntn IS NULL OR cnic_ntn = '')
    """, as_dict=True)

    if not incomplete_logs:
        return

    # Extract distinct customer names needing synchronization
    customer_names = list(set([log['client'] for log in incomplete_logs if log['client']]))

    if not customer_names:
        return

    # 2. Bulk fetch data fields directly from the Customer DocType
    customer_data = frappe.get_all(
        "Customer",
        filters={"name": ["in", customer_names]},
        fields=["name", "contact_no", "sales_person", "service_type", "tax_id"]
    )
    customer_map = {cust["name"]: cust for cust in customer_data}

    # 3. Step through updating logs in transactional chunks
    chunk_size = 200
    for i in range(0, len(incomplete_logs), chunk_size):
        chunk = incomplete_logs[i:i + chunk_size]
        
        for log in chunk:
            customer_info = customer_map.get(log['client'])
            if not customer_info:
                continue # Skip if customer reference doesn't exist anymore

            # Use database set values to avoid triggering slow validation hooks during patch loops
            frappe.db.set_value('Calling', log['name'], {
                'mobile_no': customer_info.get('contact_no') or '',
                'sales_person': customer_info.get('sales_person') or '',
                'service_type': customer_info.get('service_type') or '',
                'cnic_ntn': customer_info.get('tax_id') or ''
            }, update_modified=False) # update_modified=False keeps the original timestamp clean

        # Safely commit records batch by batch 
        frappe.db.commit()