
from django.urls import path,include

urlpatterns = [
    path("api/common/", include("apps.common.urls")),
    path("api/invoice/", include("apps.invoice.urls")),
    path("api/sales/", include("apps.sales.urls")),
]
