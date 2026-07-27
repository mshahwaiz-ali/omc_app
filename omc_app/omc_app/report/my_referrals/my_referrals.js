frappe.query_reports["My Referrals"] = {
  filters: [
    {
      fieldname: "search",
      label: __("Search"),
      fieldtype: "Data",
      placeholder: __("Customer, email, mobile, referral code"),
    },
    {
      fieldname: "account_status",
      label: __("Account Status"),
      fieldtype: "Select",
      options: "\nActive\nApproved\nPending\nPending Review\nInactive\nRejected",
    },
  ],

  formatter(value, row, column, data, default_formatter) {
    const formatted = default_formatter(value, row, column, data);

    if (column.fieldname === "account_status") {
      const status = String(value || "").toLowerCase();
      if (["active", "approved"].includes(status)) {
        return `<span class="indicator-pill green">${formatted}</span>`;
      }
      if (["rejected", "inactive"].includes(status)) {
        return `<span class="indicator-pill red">${formatted}</span>`;
      }
      return `<span class="indicator-pill orange">${formatted}</span>`;
    }

    return formatted;
  },
};
