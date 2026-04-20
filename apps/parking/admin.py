from django.contrib import admin

from apps.parking.models import ParkingSession, ParkingSlot, ParkingZone, Vehicle


@admin.register(ParkingZone)
class ParkingZoneAdmin(admin.ModelAdmin):
    list_display = ("name", "zone_type", "priority", "is_active")
    list_filter = ("zone_type", "is_active")
    search_fields = ("name",)


@admin.register(ParkingSlot)
class ParkingSlotAdmin(admin.ModelAdmin):
    list_display = ("zone", "code", "status", "is_manual_only")
    list_filter = ("status", "zone", "is_manual_only")
    search_fields = ("code", "zone__name")


@admin.register(Vehicle)
class VehicleAdmin(admin.ModelAdmin):
    list_display = ("plate_number", "vehicle_type", "owner_name", "phone_number", "is_active")
    list_filter = ("vehicle_type", "is_active")
    search_fields = ("plate_number", "owner_name", "phone_number")


@admin.register(ParkingSession)
class ParkingSessionAdmin(admin.ModelAdmin):
    list_display = ("vehicle", "slot", "status", "entry_time", "exit_time", "total_fee")
    list_filter = ("status", "entry_time")
    search_fields = ("vehicle__plate_number", "slot__code", "slot__zone__name")

