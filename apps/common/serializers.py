from rest_framework import serializers


class ItemSerializer(serializers.Serializer):
    item_id = serializers.IntegerField(read_only=True)
    item_code = serializers.CharField(max_length=20, required=True)
    item_name = serializers.CharField(max_length=100, required=True)
    uom = serializers.CharField(max_length=10, default="NOS")
    unit_price = serializers.DecimalField(max_digits=12, decimal_places=2, default=0)
    is_active = serializers.BooleanField(default=True)
    created_at = serializers.DateTimeField(read_only=True)
