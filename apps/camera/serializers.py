from rest_framework import serializers

from apps.camera.models import OcrScan


class OcrScanSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
    manual_entry_required = serializers.SerializerMethodField()

    class Meta:
        model = OcrScan
        fields = [
            "id",
            "image_url",
            "source",
            "raw_text",
            "candidate_plates",
            "detected_plate",
            "confirmed_plate",
            "confidence",
            "is_confirmed",
            "manual_entry",
            "manual_entry_required",
            "notes",
            "created_at",
        ]

    def get_image_url(self, obj):
        request = self.context.get("request")
        if not obj.image:
            return None
        url = obj.image.url
        if request:
            return request.build_absolute_uri(url)
        return url

    def get_manual_entry_required(self, obj):
        return not bool(obj.final_plate)


class OcrUploadSerializer(serializers.Serializer):
    image = serializers.ImageField()
    source = serializers.ChoiceField(choices=OcrScan.Source.choices, default=OcrScan.Source.ENTRY)

