import frappe
import json

@frappe.whitelist()
def rename_selected_customers(customer_names):
    names = json.loads(customer_names)
    
    success_count = 0
    failed_customers = []

    for name in names:
        # Fetch the target custom ID and preserve the original customer display name
        custom_new_id = frappe.db.get_value("Customer", name, "custom_new_customer_id")
        original_customer_name = frappe.db.get_value("Customer", name, "customer_name")
        
        if custom_new_id and custom_new_id.strip() != name:
            try:
                # 1. Perform the core link and ID renaming
                frappe.rename_doc("Customer", name, custom_new_id.strip(), force=True, merge=False)
                
                # 2. Force the original display name back onto the field to prevent it from matching the new ID
                frappe.db.set_value("Customer", custom_new_id.strip(), "customer_name", original_customer_name)
                
                success_count += 1
            except Exception as e:
                failed_customers.append(f"{name}: {str(e)}")
        else:
            failed_customers.append(f"{name}: No valid 'custom_new_customer_id' found or matches current.")

    return {
        "success_count": success_count,
        "failed": failed_customers
    }