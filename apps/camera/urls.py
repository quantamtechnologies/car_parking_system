from django.urls import path

from apps.camera.views import RecognizePlateAPIView

urlpatterns = [
    path("anpr/recognize/", RecognizePlateAPIView.as_view(), name="anpr-recognize"),
]

