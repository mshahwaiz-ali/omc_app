import frappe

_AUTOMATIC_NAMING_SERIES_DOCTYPES = (
    'OMC Customer Profile',
    'OMC Expense Budget',
    'OMC Expense Entry',
    'OMC Service Document',
    'OMC Service Payment',
    'OMC Service Request',
    'OMC Support Ticket',
    'OMC Support Ticket Message',
)

_ONBOARDING_WORKSPACE_LINK = {
    'hidden': 0,
    'is_query_report': 0,
    'label': 'Onboarding Slides',
    'link_count': 0,
    'link_to': 'OMC Onboarding Slide',
    'link_type': 'DocType',
    'onboard': 0,
    'type': 'Link',
}


def sync_desk_metadata():
    """Keep Desk metadata aligned with the source-controlled OMC app."""
    _hide_automatic_naming_series_fields()
    _remove_standalone_tax_slab_links()
    _ensure_onboarding_workspace_link()
    frappe.clear_cache()


def _hide_automatic_naming_series_fields():
    for doctype in _AUTOMATIC_NAMING_SERIES_DOCTYPES:
        field = frappe.db.get_value(
            'DocField',
            {'parent': doctype, 'fieldname': 'naming_series'},
            ['name', 'default', 'options'],
            as_dict=True,
        )
        if not field:
            continue

        values = {'hidden': 1, 'read_only': 1, 'no_copy': 1}
        if not field.default:
            options = [
                option.strip()
                for option in (field.options or '').splitlines()
                if option.strip()
            ]
            if len(options) == 1:
                values['default'] = options[0]

        frappe.db.set_value('DocField', field.name, values, update_modified=False)


def _remove_standalone_tax_slab_links():
    links = frappe.get_all(
        'Workspace Link',
        filters={
            'parent': 'OMC App',
            'parenttype': 'Workspace',
            'link_to': 'OMC Tax Slab',
        },
        pluck='name',
    )
    for link_name in links:
        frappe.db.delete('Workspace Link', {'name': link_name})


def _workspace_row_payload(row):
    payload = {}
    for field in row.meta.fields:
        fieldname = field.fieldname
        if not fieldname:
            continue
        value = row.get(fieldname)
        if value is not None:
            payload[fieldname] = value
    return payload


def _ensure_onboarding_workspace_link():
    """Expose the editable onboarding content without exposing auth internals."""
    if not frappe.db.exists('Workspace', 'OMC App'):
        return

    workspace = frappe.get_doc('Workspace', 'OMC App')
    if any(
        str(row.get('link_to') or '').strip() == 'OMC Onboarding Slide'
        for row in workspace.get('links') or []
    ):
        return

    links = []
    inserted = False
    for row in workspace.get('links') or []:
        payload = _workspace_row_payload(row)
        if (
            not inserted
            and str(payload.get('type') or '').strip() == 'Card Break'
            and str(payload.get('label') or '').strip() == 'Tax Calculator'
        ):
            links.append(dict(_ONBOARDING_WORKSPACE_LINK))
            inserted = True
        links.append(payload)

    if not inserted:
        links.append(dict(_ONBOARDING_WORKSPACE_LINK))

    workspace.set('links', links)
    workspace.flags.ignore_permissions = True
    workspace.save(ignore_permissions=True)
