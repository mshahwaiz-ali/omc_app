from frappe import _


def get_data():
    return [
        {
            "module_name": "OMC App",
            "color": "red",
            "icon": "octicon octicon-device-mobile",
            "type": "module",
            "label": _("OMC App"),
            "items": [
                {
                    "type": "doctype",
                    "name": "OMC Mobile Quick Action",
                    "label": _("Mobile Quick Actions"),
                    "description": _("Control Home quick actions for the mobile app."),
                },
                {
                    "type": "doctype",
                    "name": "OMC Mobile Settings",
                    "label": _("Mobile Settings"),
                    "description": _("Control mobile app feature flags and backend settings."),
                },
            ],
        }
    ]
