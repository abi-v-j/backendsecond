from django.urls import path
from . import views

app_name = "common"

urlpatterns = [
       path("items/", views.items_view, name="items"),


]