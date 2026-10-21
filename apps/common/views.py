from decimal import Decimal
from django.db import connection, transaction
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .serializers import ItemSerializer


def dictfetchall(cursor):
    """Return all rows from a cursor as a dict"""
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def dictfetchone(cursor):
    """Return one row from a cursor as a dict"""
    columns = [col[0] for col in cursor.description]
    row = cursor.fetchone()
    if not row:
        return None
    return dict(zip(columns, row))


@api_view(["GET", "POST"])
def items_view(request):
    """
    GET: List all Items from DB using database cursor and stored procedure (sp_get_all_items).
    POST: Insert an Item into DB using database cursor and stored procedure (sp_insert_item).
    """
    if request.method == "POST":
        serializer = ItemSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        item_code = serializer.validated_data.get("item_code")
        item_name = serializer.validated_data.get("item_name")
        uom = serializer.validated_data.get("uom", "NOS")
        unit_price = serializer.validated_data.get("unit_price", Decimal("0.00"))

        try:
            with connection.cursor() as cursor:
                # Call PostgreSQL Stored Procedure with cursor
                cursor.execute(
                    "CALL sp_insert_item(%s, %s, %s, %s, %s);",
                    [item_code, item_name, uom, unit_price, None],
                )
                row = cursor.fetchone()
                item_id = row[0] if row else None

            return Response(
                {
                    "status": "success",
                    "message": "Item inserted successfully using database cursor and stored procedure (sp_insert_item)",
                    "data": {
                        "item_id": item_id,
                        "item_code": item_code,
                        "item_name": item_name,
                        "uom": uom,
                        "unit_price": str(unit_price),
                    },
                },
                status=status.HTTP_201_CREATED,
            )
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    # GET: Retrieve all items via stored procedure refcursor
    try:
        with transaction.atomic():
            with connection.cursor() as cursor:
                cursor.execute("CALL sp_get_all_items(%s);", ["cur_items"])
                cursor.execute('FETCH ALL FROM "cur_items";')
               # print(cursor.description)
                items = dictfetchall(cursor)

        serializer = ItemSerializer(items, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

